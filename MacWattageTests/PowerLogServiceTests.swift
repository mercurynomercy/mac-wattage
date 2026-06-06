import XCTest
@testable import MacWattage

final class PowerLogServiceTests: XCTestCase {

    var tempDir: URL!
    var service: PowerLogServiceProtocol!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MacWattageTests-\(UUID().uuidString)"
        )
        service = PowerLogService(directory: tempDir)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Append + currentWatts

    func testAppendRecordUpdatesCurrentWatts() async {
        let record = PowerRecord(watts: 25.0, isCharging: true)
        try! await service.append(record)

        XCTAssertEqual(service.currentWatts(), 25.0, "currentWatts should reflect the appended record")
    }

    func testCurrentWattsReturnsZeroWhenNoData() {
        XCTAssertEqual(service.currentWatts(), 0.0, "currentWatts should be 0 when no data exists")
    }

    // MARK: - Session average with known values

    func testSessionAverageWithKnownValues() async {
        // Append 0,10,20,...,90 → average = (0+10+...+90)/10 = 45.0
        for i in 0..<10 {
            let record = PowerRecord(watts: Double(i * 10), isCharging: nil)
            try! await service.append(record)
        }

        let avg = service.sessionAverage()
        XCTAssertEqual(avg, 45.0, accuracy: 0.1, "Session average of 0..90 should be ~45.0")
    }

    func testSessionAverageEmptyReturnsZero() {
        XCTAssertEqual(service.sessionAverage(), 0.0, "Average of no data should be 0")
    }

    // MARK: - Session peak

    func testSessionPeakReturnsMax() async {
        let values = [10.0, 50.0, 30.0, 80.0, 20.0]
        for v in values {
            let record = PowerRecord(watts: v, isCharging: nil)
            try! await service.append(record)
        }

        XCTAssertEqual(service.sessionPeak(), 80.0, "Session peak should be the max value")
    }

    func testSessionPeakEmptyReturnsZero() {
        XCTAssertEqual(service.sessionPeak(), 0.0, "Peak of no data should be 0")
    }

    // MARK: - Daily averages with known data points

    func testDailyAveragesWithKnownData() async {
        let calendar = Calendar.current
        let now = Date()

        // Put 3 records on today with watts values 10, 20, 30 → avg = 20
        for dayOffset in [0, 1] {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)

            if dayOffset == 0 {
                for w in [10.0, 20.0, 30.0] {
                    let record = PowerRecord(id: UUID(), timestamp: dayStart + Double(w), watts: w, isCharging: nil)
                    try! await service.append(record)
                }
            } else {
                // Yesterday: 2 records with watts 5, 15 → avg = 10
                let record1 = PowerRecord(id: UUID(), timestamp: dayStart + 5, watts: 5, isCharging: nil)
                try! await service.append(record1)

                let record2 = PowerRecord(id: UUID(), timestamp: dayStart + 15, watts: 15, isCharging: nil)
                try! await service.append(record2)
            }
        }

        let dailyAvgs = service.dailyAverages(for: 2)
        XCTAssertEqual(dailyAvgs.count, 2, "Should return averages for 2 days")

        // Oldest day first (reversed): yesterday avg = ~10
        XCTAssertEqual(dailyAvgs[0].averageWatts, 10.0, accuracy: 1.0)
    }

    func testDailyAveragesEmptyReturnsSevenDays() {
        let avgs = service.dailyAverages(for: 7)
        XCTAssertEqual(avgs.count, 7, "Should return entries for all requested days")
    }

    // MARK: - Clear all

    func testClearAllRemovesRecords() async {
        try! await service.append(PowerRecord(watts: 42.0, isCharging: nil))
        XCTAssertGreaterThan(service.currentWatts(), 0)

        try! await service.clearAll()
        XCTAssertEqual(service.currentWatts(), 0.0, "currentWatts should be 0 after clearAll")
        XCTAssertEqual(service.sessionAverage(), 0.0, "session average should be 0 after clearAll")
    }

    func testClearAllRemovesDataFromDisk() async {
        try! await service.append(PowerRecord(watts: 42.0, isCharging: nil))

        // Verify files exist on disk
        let dailyLogURL = tempDir.appendingPathComponent("daily-log.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dailyLogURL.path))

        try! await service.clearAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dailyLogURL.path), "Daily log should be deleted")
    }

    // MARK: - File persistence

    func testFilePersistence() async {
        let record = PowerRecord(watts: 35.0, isCharging: true)
        try! await service.append(record)

        // Create a new service pointing to the same directory
        let freshService = PowerLogService(directory: tempDir)

        XCTAssertEqual(freshService.currentWatts(), 35.0, "Reloaded service should have persisted data")
    }

    // MARK: - Recent records

    func testRecentRecordsReturnsLastN() async {
        for i in 0..<15 {
            let record = PowerRecord(watts: Double(i), isCharging: nil)
            try! await service.append(record)
        }

        let recent = service.recentRecords(count: 5)
        XCTAssertEqual(recent.count, 5, "Should return last 5 records")
        XCTAssertEqual(recent[0].watts, 10.0) // First of the last 5
        XCTAssertEqual(recent[4].watts, 14.0) // Last record
    }

    // MARK: - Seconds buffer flush

    func testFlushSecondsBufferWritesToDailyLog() async {
        // Append 60 records with known wattage → flush should produce one record averaging them.
        let targetWatts: Double = 42.0
        for _ in 0..<60 {
            let record = PowerRecord(watts: targetWatts, isCharging: nil)
            try! await service.append(record)
        }

        // Before flush, daily log has the raw records (append writes immediately).
        XCTAssertEqual(
            service.recentRecords(count: 100).count, 60,
            "Daily log should have the raw records before flush"
        )

        // Flush the seconds buffer.
        try! await service.flushSecondsBuffer()

        let afterFlush = service.recentRecords(count: 100)
        XCTAssertEqual(afterFlush.count, 61, "Daily log should have raw + one flushed record")
        XCTAssertEqual(
            afterFlush[0].watts, targetWatts, accuracy: 0.1,
            "Flushed record should have average wattage"
        )

        // Seconds buffer should be cleared.
        XCTAssertEqual(service.sessionAverage(), 0.0, "Session average should reset after flush")
    }

    func testFlushEmptyBufferDoesNothing() async {
        let beforeCount = service.recentRecords(count: 100).count

        try! await service.flushSecondsBuffer()

        let afterCount = service.recentRecords(count: 100).count
        XCTAssertEqual(beforeCount, afterCount, "Flushing empty buffer should not write anything")
    }

}
