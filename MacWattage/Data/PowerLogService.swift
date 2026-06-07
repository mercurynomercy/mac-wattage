import Foundation

/// Protocol abstraction for power log operations. Enables test doubles and dependency injection.
public protocol PowerLogServiceProtocol {
    /// Append a new power measurement record to the daily log. Thread-safe (uses serial write queue).
    func append(_ record: PowerRecord) async throws

    /// Filter records within a date range (inclusive on both ends).
    func records(in range: DateRange) -> [PowerRecord]

    /// Return the most recent N records.
    func recentRecords(count: Int) -> [PowerRecord]

    /// Return the last `count` watts values from the live seconds buffer — used for the sparkline chart.
    func sparklineWatts(count: Int) -> [Double]

    /// Average watts over the last 1 hour (rolling window). Returns 0.0 if no data.
    func sessionAverage() -> Double

    /// Peak (max) watts over the last 1 hour. Returns 0.0 if no data.
    func sessionPeak() -> Double

    /// Watts from the most recent record, or 0.0 if no data exists yet.
    func currentWatts() -> Double

    /// Compute daily average watts for the last N days.
    func dailyAverages(for days: Int) -> [DailyAverage]

    /// Compute total kWh for the last N months.
    func monthlyTotals(for months: Int) -> [MonthlyTotal]

    /// Clear all daily and monthly log data. Thread-safe (uses serial write queue).
    func clearAll() async throws

    /// Records to be considered for rotation — all records before the current month.
    func oldRecords(before date: Date) -> [PowerRecord]

    /// Remove records older than `date` from the daily buffer and re-write to disk.
    func removeOldRecords(before date: Date) async throws

    /// Read stored monthly totals for rotation merge.
    func readMonthlyTotals() -> [MonthlyTotal]

    /// Write merged monthly totals to disk.
    func writeMonthlyTotals(_ totals: [MonthlyTotal]) async throws

    /// Flush the 120-second rolling buffer to daily-log as one aggregated record.
    func flushSecondsBuffer() async throws
}

/// Key names for UserDefaults-backed store settings.
public enum StoreKey {
    static let collectionInterval = "collectionInterval"
    static let logDirectoryPath   = "logDirectoryPath"
    static let autoLaunchAtLogin  = "autoLaunchAtLogin"
}


/// Manages power data persistence (daily + monthly logs) with in-memory buffering and journal-mode writes.
/// Thread-safe: all file I/O goes through a serial dispatch queue; in-memory reads are lock-free.
public final class PowerLogService: PowerLogServiceProtocol {

    private let fileManager: FileManager
    private let dailyLogURL: URL
    private let monthlyLogURL: URL

    /// Serial queue ensures ordered, non-concurrent writes.
    private let writeQueue: DispatchQueue

    /// In-memory daily buffer — only written on `writeQueue`.
    private var dailyBuffer: [PowerRecord] = []

    /// In-memory rolling buffer of the last 120 records (≈2 minutes at 1s interval).
    /// Used for real-time avg/peak metrics. New records appended; oldest removed when over 120.
    private var secondsBuffer: [PowerRecord] = []

    /// Maximum number of records kept in the seconds buffer.
    private let maxSecondsBuffer = 120

    /// In-memory monthly buffer — set once at init, read-only thereafter.
    private var monthlyBuffer: [MonthlyTotal] = []

    /// Encoder/decoder for PropertyList format. Dates encoded as absolute time (TimeInterval).
    private let encoder: PropertyListEncoder = .init()

    private let decoder: PropertyListDecoder = .init()

    /// Initializes service, creates the log directory if needed, and loads existing data into memory buffers.
    public init(directory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.dailyLogURL = directory.appendingPathComponent("daily-log.plist")
        self.monthlyLogURL = directory.appendingPathComponent("monthly-log.plist")
        self.writeQueue = DispatchQueue(label: "com.macwattage.data.write", qos: .utility)

        // Ensure directory exists; log a warning if it fails so disk persistence issues are visible.
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            NSLog("[PowerLogService] Failed to create log directory '\(directory.path)': \(error.localizedDescription)")
            #endif
        }

        // Load existing data into memory buffers
        loadDailyBuffer()
        loadMonthlyBuffer()
    }

    // MARK: - Core Operations

    public func append(_ record: PowerRecord) async throws {
        // Add to seconds buffer (rolling window, max 120 records) — thread-safe.
        await MainActor.run { [self] in
            self.secondsBuffer.append(record)
            if self.secondsBuffer.count > maxSecondsBuffer {
                self.secondsBuffer.removeFirst(self.secondsBuffer.count - maxSecondsBuffer)
            }
        }

        try writeQueue.sync { [dailyBuffer] in
            var buffer = dailyBuffer  // Copy for mutation on the serial queue
            buffer.append(record)

            let data = try encoder.encode(buffer)
            let tempURL = dailyLogURL.deletingPathExtension().appendingPathExtension("tmp")
            try data.write(to: tempURL, options: [.atomic])

            // Atomic rename via move
            try? fileManager.removeItem(at: dailyLogURL)  // Ignore error if doesn't exist
            try? fileManager.moveItem(at: tempURL, to: dailyLogURL)

            // Update the in-memory buffer
            self.dailyBuffer = buffer  // Direct property assignment from within sync block on the queue itself
        }
    }

    public func records(in range: DateRange) -> [PowerRecord] {
        dailyBuffer.filter { $0.timestamp >= range.start && $0.timestamp <= range.end }
    }

    public func recentRecords(count: Int) -> [PowerRecord] {
        Array(dailyBuffer.suffix(count))
    }

    public func sparklineWatts(count: Int) -> [Double] {
        secondsBuffer.suffix(count).map(\.watts)
    }

    // MARK: - Session Statistics (120-second rolling window from seconds buffer)

    public func sessionAverage() -> Double {
        let records = secondsBuffer  // Last ~120 one-second samples (~2 minutes)
        guard !records.isEmpty else { return 0.0 }
        let sum = records.reduce(0.0) { $0 + $1.watts }
        return sum / Double(records.count)
    }

    public func sessionPeak() -> Double {
        let records = secondsBuffer  // Last ~120 one-second samples (~2 minutes)
        return records.map(\.watts).max() ?? 0.0
    }

    public func currentWatts() -> Double {
        secondsBuffer.last?.watts ?? dailyBuffer.last?.watts ?? 0.0
    }

    // MARK: - Chart Data

    public func dailyAverages(for days: Int) -> [DailyAverage] {
        let calendar = Calendar.current
        var averages: [DailyAverage] = []

        for dayOffset in 0 ..< days {
            let originalDate = calendar.date(
                byAdding: .day, value: -dayOffset, to: Date()
            ) ?? Date.distantPast

            let dayStart = calendar.startOfDay(for: originalDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? Date.distantFuture
            let records = dailyBuffer.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }

            let sumWatts = records.reduce(0.0) { $0 + $1.watts }
            let avg = records.isEmpty ? 0.0 : sumWatts / Double(records.count)
            // Flush model: each record ≈ 1 minute of average watts. kWh = sum(watts) / 60000.
            let kWh = sumWatts / 60_000.0

            averages.append(DailyAverage(id: UUID(), date: dayStart, averageWatts: avg, totalKWh: kWh))
        }

        // Reverse so oldest first (left to right on chart)
        return averages.reversed()
    }

    public func monthlyTotals(for months: Int) -> [MonthlyTotal] {
        let calendar = Calendar.current
        var totals: [MonthlyTotal] = []


        for monthOffset in 0 ..< months {
            guard let originalDate = calendar.date(
                byAdding: .month, value: -monthOffset, to: Date()
            ) else { continue }

            let monthStart = calendar.startOfDay(for: originalDate)
            let monthEnd = calendar.date(
                byAdding: .month, value: 1, to: monthStart
            ) ?? Date.distantFuture

            let records = dailyBuffer.filter { $0.timestamp >= monthStart && $0.timestamp < monthEnd }
            guard !records.isEmpty else { continue }

            // Flush model: each record represents 1 minute (60s) of average watts.
            // kWh = sum(watts × 60s) / (1000 × 3600) = sum(watts) / 60000
            let totalKWh = records.reduce(0.0) { $0 + $1.watts } / 60_000.0

            let yearMonth = String(format: "%04d-%02d",
                calendar.component(.year, from: monthStart),
                calendar.component(.month, from: monthStart))

            totals.append(MonthlyTotal(id: UUID(), yearMonth: yearMonth, totalKWh: totalKWh))
        }

        return totals.reversed()
    }

    // MARK: - Management

    // Note: kept `async throws` for protocol conformance even though sync implementation.
    public func clearAll() async throws {
        writeQueue.sync { [dailyBuffer] in
            // Remove all records from the buffer copy first, then clear disk files
            _ = dailyBuffer  // Discard old capture — we mutate self.dailyBuffer directly

            try? fileManager.removeItem(at: dailyLogURL)
            try? fileManager.removeItem(at: monthlyLogURL)

            self.dailyBuffer.removeAll()  // Direct assignment from within sync block on the queue itself
            secondsBuffer.removeAll()     // Also clear rolling buffer
        }
    }

    // MARK: - Loading

    private func loadDailyBuffer() {
        guard fileManager.fileExists(atPath: dailyLogURL.path) else {
            #if DEBUG
            NSLog("[PowerLogService] loadDailyBuffer: file not found at \(dailyLogURL.path)")
            #endif
            return
        }

        do {
            let data = try Data(contentsOf: dailyLogURL)
            // Try decoding as array of PowerRecord first (new format with id field)
            do {
                dailyBuffer = try decoder.decode([PowerRecord].self, from: data)
                #if DEBUG
                NSLog("[PowerLogService] loadDailyBuffer: loaded \(dailyBuffer.count) records from daily-log.plist")
                #endif
            } catch {
                // Fallback to decoding as just [Double] (old format from previous versions)
                dailyBuffer = []
            }
        } catch {
            // Corrupted file or decode error — start fresh with empty buffer
            #if DEBUG
            NSLog("[PowerLogService] loadDailyBuffer: decode failed — \(error.localizedDescription)")
            #endif
            dailyBuffer = []
        }
    }

    private func loadMonthlyBuffer() {
        guard fileManager.fileExists(atPath: monthlyLogURL.path) else { return }

        do {
            let data = try Data(contentsOf: monthlyLogURL)
            // Try decoding as array of MonthlyTotal first (new format with id field)
            do {
                monthlyBuffer = try decoder.decode([MonthlyTotal].self, from: data)
            } catch {
                // Fallback to decoding as just [Double] (old format from previous versions)
                monthlyBuffer = []
            }
        } catch {
            // Corrupted file or decode error — start fresh with empty buffer
            monthlyBuffer = []
        }
    }

    // MARK: - Rotation Support (protocol conformance)

    public func oldRecords(before date: Date) -> [PowerRecord] {
        dailyBuffer.filter { $0.timestamp < date }
    }

    public func removeOldRecords(before date: Date) async throws {
        try writeQueue.sync { [dailyBuffer] in
            var buffer = dailyBuffer
            let calendar = Calendar.current
            let startOfMonth = calendar.startOfDay(for: date)

            // Remove records before current month
            buffer.removeAll { $0.timestamp < startOfMonth }

            let data = try encoder.encode(buffer)
            let tempURL = dailyLogURL.deletingPathExtension().appendingPathExtension("tmp")
            try data.write(to: tempURL, options: [.atomic])

            try? fileManager.removeItem(at: dailyLogURL)
            try? fileManager.moveItem(at: tempURL, to: dailyLogURL)

            self.dailyBuffer = buffer
        }
    }

    public func readMonthlyTotals() -> [MonthlyTotal] {
        monthlyBuffer
    }

    public func writeMonthlyTotals(_ totals: [MonthlyTotal]) async throws {
        try writeQueue.sync {
            let data = try encoder.encode(totals)
            let tempURL = monthlyLogURL.deletingPathExtension().appendingPathExtension("tmp")
            try data.write(to: tempURL, options: [.atomic])

            try? fileManager.removeItem(at: monthlyLogURL)
            try? fileManager.moveItem(at: tempURL, to: monthlyLogURL)

            self.monthlyBuffer = totals
        }
    }

    // MARK: - Seconds Buffer Flush

    public func flushSecondsBuffer() async throws {
        let records = await MainActor.run { [secondsBuffer] in Array(secondsBuffer) }
        guard !records.isEmpty else { return }

        // Compute average wattage from all records in the buffer.
        let avgWatts = records.reduce(0.0) { $0 + $1.watts } / Double(records.count)
        let flushRecord = PowerRecord(watts: avgWatts, isCharging: records.last?.isCharging)

        // Append to daily buffer (one record per flush cycle ≈ 1 minute).
        try await append(flushRecord)

        // Clear flushed records from the rolling buffer.
        await MainActor.run { [self] in
            self.secondsBuffer.removeAll()
        }

        #if DEBUG
        NSLog("[PowerLogService] flushSecondsBuffer: wrote avg=%.1fW for %d records", avgWatts, records.count)
        #endif
    }

}
