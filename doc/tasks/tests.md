# Tests — Task List

## F1: XCTest Target Setup in Xcode Project + Package.swift

- [x] Create `Package.swift` with:
  - [x] MacWattage library target (8 source files, macOS 13.0+ platform)
  - [x] MacWattageTests test target (6 source files, depends on MacWattage)
  - [x] Zero external dependencies (only Apple frameworks via Foundation imports)

- [x] Add mock implementations to `MacWattageTests/Mocks.swift`:
  - [x] `MockUserDefaults` — conforms to `UserDefaultsProtocol`, internal dictionary storage, all protocol methods implemented
  - [x] `MockPowerLogService` — conforms to `PowerLogServiceProtocol`, tracks appendedRecords, rotationTriggered

## F2: PowerEstimatorTests — Metrics Layer Unit Tests (15 tests)

- [x] Create `MacWattageTests/PowerEstimatorTests.swift`
- [x] Test: M2 base at idle (0% CPU, 0% GPU) → ~5W
- [x] Test: M2 base at full load (100% CPU, 100% GPU) → ~55W
- [x] Test: M2 base at half load (50% CPU, 50% GPU) → ~30W
- [x] Test: M1 Pro at half load (50% CPU, 50% GPU) → ~49W
- [x] Test: M1 Ultra max power > M1 base max power (ordering check)
- [x] Test: Different chip generations produce different results at same utilization (base < pro < max < ultra)
- [x] Additional tests: M2 Pro idle, Max/Ultra full/half load, negative/over-1 clamping, M1/M2 same-profile pairs

## F3: PlatformDetectorTests — Metrics Layer Integration Tests (2 tests)

- [x] Create `MacWattageTests/PlatformDetectorTests.swift`
- [x] Test: `detectPlatform()` returns `.studio` or `.laptop` (no crash, valid enum)
- [x] Test: `detectChipGeneration()` returns a valid `.m*` case (no crash, valid enum)
- [x] Note: These are runtime tests — verify the methods don't crash and return valid values

## F4: PowerLogServiceTests — Data Layer Unit Tests (12 tests)

- [x] Create `MacWattageTests/PowerLogServiceTests.swift`
- [x] Setup: create temp directory, initialize service with it
- [x] Teardown: remove temp directory after each test (override tearDown)
- [x] Test: append record + verify `currentWatts()` returns correct value (async)
- [x] Test: session average with known values (append 0,10,...,90 → expect ~45.0)
- [x] Test: session peak returns max value from appended records (async)
- [x] Test: dailyAverages for 2 days with known data points (async)
- [x] Test: clearAll removes all records and resets currentWatts to 0.0 (async)
- [x] Test: file persistence — append, reload from disk via fresh service, verify data intact (async)
- [x] Additional tests: recentRecords count verification, empty-day averages

## F5: RotationManagerTests — Data Layer Unit Tests (2 tests)

- [x] Create `MacWattageTests/RotationManagerTests.swift`
- [x] Test: rotation triggers when month boundary detected (mock UserDefaults with previous month)
  - Verifies timestamp is updated to current month even when no old records exist (guard early return)
- [x] Test: no rotation within same month (mock UserDefaults with current month)
  - Verifies timestamp remains unchanged when already rotated

## F6: StoreTests — Data Layer Unit Tests (4 tests)

- [x] Create `MacWattageTests/StoreTests.swift`
- [x] Test: collectionInterval defaults to 10 on fresh init (mock UserDefaults)
- [x] Test: setting a different interval persists and reads back correctly via MockUserDefaults
- [x] Test: logDirectory defaults to Application Support/Mac Wattage on fresh init
- [x] Test: custom logDirectoryPath persists and reads back correctly

## Dependencies Between Subtasks

```
F1 (Setup) → F2, F3, F4, F5, F6 all depend on mocks from F1
F2 (PowerEstimatorTests) → independent of other test modules (pure math, no I/O)
F3 (PlatformDetectorTests) → independent runtime tests (hardware detection)
F4 (PowerLogServiceTests) → depends on B2 implementation, uses temp directories for file I/O
F5 (RotationManagerTests) → depends on B3 implementation, uses MockUserDefaults + MockPowerLogService
F6 (StoreTests) → depends on B4 implementation, uses MockUserDefaults for UserDefaults isolation

All tests run via `swift test` — 35 total, all passing.
```
