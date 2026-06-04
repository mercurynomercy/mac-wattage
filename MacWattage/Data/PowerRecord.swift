import Foundation

/// Represents a single power consumption measurement. Codable for plist storage, Identifiable for SwiftUI list display.
public struct PowerRecord: Codable, Identifiable {
    public let id: UUID
    /// Timestamp of the measurement. Encoded as ISO 8601 in plist storage.
    public let timestamp: Date
    /// Estimated system power draw in watts (TDP-based).
    public let watts: Double
    /// Whether the Mac is charging. nil for desktop Macs without batteries.
    public let isCharging: Bool?

    /// Creates a record with auto-generated UUID and current timestamp.
    public init(id: UUID = UUID(), timestamp: Date = Date(), watts: Double, isCharging: Bool?) {
        self.id = id; self.timestamp = timestamp; self.watts = watts; self.isCharging = isCharging
    }

    /// Coding keys for custom encoding — timestamps use ISO 8601 format.
    enum CodingKeys: String, CodingKey { case id, timestamp, watts, isCharging }
}

/// Daily average power consumption for chart display. Codable and Identifiable.
public struct DailyAverage: Codable, Identifiable {
    public let id: UUID
    /// Start of the day (midnight, local timezone).
    public let date: Date
    /// Average watts across all records in that day.
    public let averageWatts: Double

    enum CodingKeys: String, CodingKey { case id, date, averageWatts }
}

/// Monthly total energy consumption in kWh for chart display. Codable and Identifiable.
public struct MonthlyTotal: Codable, Identifiable {
    public let id: UUID
    /// Month identifier in "YYYY-MM" format (e.g., "2025-01").
    public let yearMonth: String
    /// Total energy consumed in kilowatt-hours for the month.
    public let totalKWh: Double

    enum CodingKeys: String, CodingKey { case id, yearMonth, totalKWh }
}

/// A contiguous date range used for filtering records.
public struct DateRange {
    public let start: Date
    /// End date (exclusive — records at exactly this time are not included).
    public let end: Date

    /// Creates a range spanning the specified number of days ending at `end`.
    public static func lastDays(_ days: Int, from end: Date = Date()) -> DateRange {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? Date.distantPast
        return DateRange(start: start, end: end)
    }

    /// Creates a range for the calendar day of `date`.
    public static func day(_ date: Date, using calendar: Calendar = .current) -> DateRange? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        return DateRange(start: startOfDay, end: endOfDay)
    }
}
