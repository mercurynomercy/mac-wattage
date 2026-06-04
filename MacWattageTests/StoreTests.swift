import XCTest
@testable import MacWattage

final class StoreTests: XCTestCase {

    func testCollectionIntervalDefaultsToTen() {
        let store = Store(defaults: MockUserDefaults())
        XCTAssertEqual(store.collectionInterval, 10, "Default collection interval should be 10 seconds")
    }

    func testSettingIntervalPersistsAndReadsBack() {
        let defaults = MockUserDefaults()
        let store = Store(defaults: defaults)

        // Change interval to 60 seconds
        store.collectionInterval = 60
        XCTAssertEqual(store.collectionInterval, 60, "Stored interval should read back as set value")

        // Verify it's stored in the mock defaults
        let saved = defaults.object(forKey: StoreKey.collectionInterval) as? Int
        XCTAssertEqual(saved, 60, "Value should be persisted in UserDefaults")
    }

    func testLogDirectoryDefaultsToApplicationSupport() {
        let store = Store(defaults: MockUserDefaults())

        // The default should be Application Support/Mac Wattage
        let expectedPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Mac Wattage").path

        XCTAssertEqual(store.logDirectory.path, expectedPath ?? "",
            "Default log directory should be Application Support/Mac Wattage")
    }

    func testLogDirectoryPathPersistsString() {
        let defaults = MockUserDefaults()
        let store = Store(defaults: defaults)

        // Set a custom path via logDirectoryPath
        let customPath = "/tmp/custom-macwattage"
        store.logDirectoryPath = customPath

        XCTAssertEqual(defaults.string(forKey: StoreKey.logDirectoryPath),
            customPath, "Custom log directory path should be stored")

        // Create a new store with same defaults and verify it reads the custom path
        let freshStore = Store(defaults: defaults)
        XCTAssertEqual(freshStore.logDirectoryPath, customPath, "Custom path should be read back")
    }

}
