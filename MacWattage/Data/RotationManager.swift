import Foundation

/// Handles monthly data rotation — moves old daily records into monthly totals and clears them from the daily log.
public final class RotationManager {

    private let userDefaults: UserDefaultsProtocol?

    /// Creates a manager with optional custom UserDefaults backing. Pass nil to use standard defaults.
    public init(userDefaults: UserDefaultsProtocol?) {
        self.userDefaults = userDefaults
    }

    /// Called on app launch — triggers rotation if the month has changed since last rotation.
    public func checkAndRotate(dailyService: PowerLogServiceProtocol) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        formatter.dateFormat = "yyyy-MM"
        let currentMonthStr = formatter.string(from: Date())

        if userDefaults?.string(forKey: "lastRotationMonth") == currentMonthStr {
            return  // Already rotated this month
        }

        performRotation(dailyService: dailyService, currentMonthStr: currentMonthStr)
    }

    private func performRotation(dailyService: PowerLogServiceProtocol, currentMonthStr: String) {
        // Save rotation timestamp early to prevent re-processing on next launch,
        // even if there are no old records to rotate.
        userDefaults?.setAny(currentMonthStr, forKey: "lastRotationMonth")

        let calendar = Calendar(identifier: .gregorian)

        // Parse "yyyy-MM" into first day of that month
        let parts = currentMonthStr.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        guard let monthStart = calendar.date(from: comps) else { return }

        // 1. Get old records (before current month)
        let oldRecords = dailyService.oldRecords(before: monthStart)
        guard !oldRecords.isEmpty else { return }

        // 2. Group by year-month
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let grouped = Dictionary(grouping: oldRecords) { record in
            formatter.dateFormat = "yyyy-MM"
            let dayStart = calendar.startOfDay(for: record.timestamp)
            return formatter.string(from: dayStart)
        }

        // 3. Compute kWh per group and merge with existing monthly totals
        var newTotals: [MonthlyTotal] = grouped.map { yearMonth, records in
            let avgWatts = records.reduce(0.0) { $0 + $1.watts } / Double(records.count)
            // kWh = avgWatts × totalSeconds / (1000×3600), where seconds ≈ recordCount × collectionInterval
            let totalKWh = (avgWatts * Double(records.count) * 10.0) / (1000.0 * 3600.0)
            return MonthlyTotal(id: UUID(), yearMonth: yearMonth, totalKWh: round(totalKWh * 100) / 100)
        }

        // Merge with existing (avoid duplicates by yearMonth)
        let existing = dailyService.readMonthlyTotals()
        let seenMonths: Set<String> = Set(newTotals.map(\.yearMonth))
        for existingTotal in existing {
            if !seenMonths.contains(existingTotal.yearMonth) {
                newTotals.append(existingTotal)
            }
        }

        // Sort by year-month ascending
        newTotals.sort { $0.yearMonth < $1.yearMonth }

        // 4. Write merged totals and clear old daily records (fire-and-forget)
        Task {
            do {
                try await dailyService.writeMonthlyTotals(newTotals)
                try await dailyService.removeOldRecords(before: monthStart)
            } catch {
                // Rotation failure is non-fatal — data preserved in daily buffer
                Logger.warning("Rotation failed: \(error)")
            }
        }
    }

}
