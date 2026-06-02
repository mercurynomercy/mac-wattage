# Tests — Task List

## F1: XCTest Target Setup in Xcode Project

- [ ] Add `MacWattageTests` target (XCTest) to the Xcode project
- [ ] Verify test scheme builds and runs: `xcodebuild test -scheme MacWattageTests`
- [ ] Add mock implementations to `MacWattageTests`:

### MockUserDefaults (in Tests/Mocks.swift)
- [ ] Conforms to `UserDefaultsProtocol`
- [ ] Internal dictionary storage: `var values: [String: Any] = [:]`
- [ ] Implement all protocol methods to read/write from the dictionary

### MockPowerLogService (in Tests/Mocks.swift)
- [ ] Conforms to `PowerLogServiceProtocol`
- [ ] Properties: `appendedRecords: [PowerRecord] = []`, `rotationTriggered: Bool`
- [ ] Implement all protocol methods (return sensible defaults, track calls)

## F2: PowerEstimatorTests — Metrics Layer Unit Tests

- [ ] Create `MacWattageTests/PowerEstimatorTests.swift`
- [ ] Test: M2 base at idle (0% CPU, 0% GPU) → ~5W
- [ ] Test: M2 base at full load (100% CPU, 100% GPU) → ~90W
- [ ] Test: M2 base at half load (50% CPU, 50% GPU) → ~47.5W
- [ ] Test: M1 Pro at half load (50% CPU, 50% GPU) → ~47.5W
- [ ] Test: M1 Ultra max power > M1 base max power (ordering check)
- [ ] Test: Different chip generations produce different results at same utilization

## F3: PlatformDetectorTests — Metrics Layer Integration Tests

- [ ] Create `MacWattageTests/PlatformDetectorTests.swift`
- [ ] Test: `detectPlatform()` returns `.studio` or `.laptop` (no crash, valid enum)
- [ ] Test: `detectChipGeneration()` returns a valid `.m*` case (no crash, valid enum)
- [ ] Note: These are runtime tests — they verify the methods don't crash and return valid values

## F4: PowerLogServiceTests — Data Layer Unit Tests

- [ ] Create `MacWattageTests/PowerLogServiceTests.swift`
- [ ] Setup: create temp directory, initialize service with it
- [ ] Teardown: remove temp directory after each test
- [ ] Test: append record + verify `currentWatts()` returns correct value
- [ ] Test: session average with known values (append 0,10,20,...,90 → expect ~45.0)
- [ ] Test: session peak returns max value from appended records
- [ ] Test: dailyAverages for 7 days with known data points
- [ ] Test: clearAll removes all records and resets currentWatts to 0.0
- [ ] Test: file persistence — append, reload from disk, verify data intact

## F5: RotationManagerTests — Data Layer Unit Tests

- [ ] Create `MacWattageTests/RotationManagerTests.swift`
- [ ] Test: rotation triggers when month boundary detected (mock UserDefaults with previous month)
- [ ] Test: no rotation within same month (mock UserDefaults with current month)

## F6: StoreTests — Data Layer Unit Tests

- [ ] Create `MacWattageTests/StoreTests.swift`
- [ ] Test: collectionInterval defaults to 10 on fresh init
- [ ] Test: setting a different interval persists and reads back correctly (mock UserDefaults)
- [ ] Test: logDirectory defaults to Application Support/Mac Wattage on fresh init

## Dependencies Between Subtasks

```
F1 (Setup) → F2, F3, F4, F5, F6 all depend on mocks from F1
F2 (PowerEstimatorTests) → independent of other test modules
F3 (PlatformDetectorTests) → independent runtime tests
F4 (PowerLogServiceTests) → depends on B2 implementation being complete
F5 (RotationManagerTests) → depends on B3 implementation being complete
F6 (StoreTests) → depends on B4 implementation being complete
```
