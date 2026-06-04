import XCTest
@testable import MacWattage

// MARK: - MockUserDefaults

/// A mock UserDefaults implementation backed by an internal dictionary.
final class MockUserDefaults: NSObject, UserDefaultsProtocol {

    var values: [String: Any] = [:]

    func integer(forKey key: String, defaultValue: Int) -> Int {
        values[key] as? Int ?? defaultValue
    }

    var boolForKey: (String) -> Bool {
        return { key in self.values[key] as? Bool ?? false }
    }

    func string(forKey key: String) -> String? {
        values[key] as? String
    }

    func setAny(_ value: Any?, forKey key: String) {
        values[key] = value ?? NSNull()
    }

    func object(forKey key: String) -> Any? {
        let obj = values[key]
        guard !(obj is NSNull) else { return nil }
        return obj
    }

    func removeObject(forKey key: String) {
        values.removeValue(forKey: key)
    }

    func url(forKey key: String) -> URL? {
        guard let str = string(forKey: key) else { return nil }
        return URL(string: str)
    }

    func reset() {
        values.removeAll()
    }
}

// MARK: - MockPowerLogService

/// A mock PowerLogService that tracks calls and stores appended records in memory.
final class MockPowerLogService: NSObject, PowerLogServiceProtocol {

    var appendedRecords: [PowerRecord] = []
    var rotationTriggered: Bool = false

    func append(_ record: PowerRecord) async throws {
        appendedRecords.append(record)
    }

    func records(in range: DateRange) -> [PowerRecord] {
        appendedRecords.filter { $0.timestamp >= range.start && $0.timestamp <= range.end }
    }

    func recentRecords(count: Int) -> [PowerRecord] {
        Array(appendedRecords.suffix(count))
    }

    func sessionAverage() -> Double {
        guard !appendedRecords.isEmpty else { return 0.0 }
        let sum = appendedRecords.reduce(0.0) { $0 + $1.watts }
        return sum / Double(appendedRecords.count)
    }

    func sessionPeak() -> Double {
        appendedRecords.map(\.watts).max() ?? 0.0
    }

    func currentWatts() -> Double {
        appendedRecords.last?.watts ?? 0.0
    }

    func dailyAverages(for days: Int) -> [DailyAverage] { [] }

    func monthlyTotals(for months: Int) -> [MonthlyTotal] { [] }

    func clearAll() async throws {
        appendedRecords.removeAll()
    }

    func oldRecords(before date: Date) -> [PowerRecord] { [] }
    func removeOldRecords(before date: Date) async throws {}
    func readMonthlyTotals() -> [MonthlyTotal] { [] }
    func writeMonthlyTotals(_ totals: [MonthlyTotal]) async throws {}

    /// Convenience to append records in bulk (synchronous).
    func appendSync(_ record: PowerRecord) {
        appendedRecords.append(record)
    }

    /// Reset all state.
    func reset() {
        appendedRecords.removeAll()
        rotationTriggered = false
    }
}
