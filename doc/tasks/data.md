# Data Layer — Task List

## B1: PowerRecord Models + Supporting Types

- [x] Define `PowerRecord` in `Data/PowerRecord.swift`:
  - [x] Properties: `id: UUID`, `timestamp: Date`, `watts: Double`, `isCharging: Bool?`
  - [x] Conforms to `Codable`, `Identifiable`
  - [x] Convenience init with default id and timestamp: `init(id: UUID = UUID(), timestamp: Date = Date(), watts: Double, isCharging: Bool?)`
- [x] Define `DailyAverage`:
  - [x] Properties: `id: UUID`, `date: Date` (midnight), `averageWatts: Double`
  - [x] Conforms to `Codable`, `Identifiable`
- [x] Define `MonthlyTotal`:
  - [x] Properties: `id: UUID`, `yearMonth: String` ("YYYY-MM"), `totalKWh: Double`
  - [x] Conforms to `Codable`, `Identifiable`
- [x] Define `DateRange`:
  - [x] Properties: `start: Date`, `end: Date`
  - [x] Static helpers: `lastDays(_:from:)`, `day(using:)`

## B2: PowerLogServiceProtocol + Implementation

- [x] Define `PowerLogServiceProtocol` in `Data/PowerLogService.swift`:
  - [x] `func append(_ record: PowerRecord) async throws`
  - [x] `func records(in range: DateRange) -> [PowerRecord]`
  - [x] `func recentRecords(count: Int) -> [PowerRecord]`
  - [x] `func sessionAverage() -> Double` (1-hour rolling window)
  - [x] `func sessionPeak() -> Double` (max in 1-hour window)
  - [x] `func currentWatts() -> Double` (latest record watts, or 0.0)
  - [x] `func dailyAverages(for days: Int) -> [DailyAverage]`
  - [x] `func monthlyTotals(for months: Int) -> [MonthlyTotal]`
  - [x] `func clearAll() async throws`
- [x] Implement PowerLogService:
  - [x] Initialize with `directory: URL`, create directory if not exists
  - [x] Set up serial dispatch queue (`writeQueue`) for thread-safe writes
  - [x] Load existing data into memory buffers on init:
    - `loadDailyBuffer()`: read daily-log.plist, decode to [PowerRecord], handle errors gracefully
    - `loadMonthlyBuffer()`: read monthly-log.plist, decode to [MonthlyTotal], handle errors gracefully
  - [x] `append()`: journal mode write (encode to temp file, atomic rename)
  - [x] `records(in:)`: filter buffer by date range (timestamp >= start && timestamp <= end)
  - [x] `recentRecords(count:)`: return Array(buffer.suffix(count))
  - [x] `sessionAverage()`: filter last hour, compute mean of watts (return 0.0 if empty)
  - [x] `sessionPeak()`: filter last hour, return max watts (return 0.0 if empty)
  - [x] `currentWatts()`: return buffer.last?.watts ?? 0.0
  - [x] `dailyAverages(for:)`: for each day offset, filter records in that day's range
    - Compute mean watts per day (return 0.0 for days with no data)
    - Return array reversed so oldest is first (left-to-right chart order)
  - [x] `monthlyTotals(for:)`: for each month offset, filter records in that month's range
    - kWh formula: `(avgWatts × secondsInMonth) / (1000.0 × 3600.0)`
    - yearMonth format: `String(format: "%04d-%02d", year, month)`
    - Return array reversed so oldest is first (bottom-to-top list order)

## B3: RotationManager

- [x] Define rotation logic in `Data/RotationManager.swift`:
  - [x] Store last rotation timestamp as ISO8601 string in UserDefaults key `"lastRotationMonth"`
  - [x] `checkAndRotate(dailyService:)`: called on app launch only
    - Read last rotation month from UserDefaults (or nil for first launch)
    - Compare with current year-month components
    - If different month → trigger rotation, save new timestamp

- [x] Rotation process:
  - [x] Get all daily records before current month start date
  - [x] Group old records by year-month using `formatYearMonth(from:)` helper
  - [x] For each group: compute avg watts, convert to kWh using `avgWatts × recordCount × 10 / (1000×3600)`
    - Note: each record represents 10 seconds of power consumption at default interval
  - [x] Merge with existing monthly totals (avoid duplicates by yearMonth)
  - [x] Save merged list to monthly-log.plist via file write (journal mode same as daily)
  - [x] Clear old records from daily buffer and re-write daily-log.plist (keep current month only)

## B4: Store

- [x] Define `UserDefaultsProtocol` for testability in `Data/Store.swift`:
  - [x] Methods: `integer(forKey:,defaultValue:)`, `boolForKey`, `string(forKey:)`, `setAny(_:forKey:)`, `object(forKey:)`
  - [x] Extension: `UserDefaults` conforms to it

- [x] Implement Store class with properties backed by UserDefaults:
  - [x] `collectionInterval`: Int, default=10, key="collectionInterval"
    - On init: set to 10 if not already stored
  - [x] `logDirectoryPath`: String? (user-configured path) + computed `logDirectory: URL`
    - On get: check UserDefaults for path string, fall back to default directory URL

- [x] Implement `autoLaunchAtLogin`:
  - [x] Bool, default=false, key="autoLaunchAtLogin"
  - [x] On init: set to false if not already stored
  - [x] On set: call `updateLoginItems(_:)` with new value

- [x] Implement Login Items management (`SMLoginItemSetEnabled`):
  - `updateLoginItems(_:)`: use dlopen/dlsym to call SMLoginItemSetEnabled
    - If enable=true: add Mac Wattage.helper bundle identifier as login item
    - If enable=false: remove the helper login item

## Dependencies Between Subtasks

```
B1 (Models) → B2, B3 use these types for storage and rotation
B2 (PowerLogService) → B1 uses models, provides CRUD that RotationManager calls into
B3 (RotationManager) → depends on B2 for daily records, writes to monthly-log.plist
B4 (Store) independent → used by App entry point and Settings UI
```
