# Data Layer — Task List

## B1: PowerRecord Models + Supporting Types

- [ ] Define `PowerRecord` in `Data/PowerRecord.swift`:
  - [ ] Properties: `id: UUID`, `timestamp: Date`, `watts: Double`, `isCharging: Bool?`
  - [ ] Conforms to `Codable`, `Identifiable`
  - [ ] Convenience init with default id and timestamp
- [ ] Define `DailyAverage`:
  - [ ] Properties: `id: UUID`, `date: Date` (midnight), `averageWatts: Double`
  - [ ] Conforms to `Codable`, `Identifiable`
- [ ] Define `MonthlyTotal`:
  - [ ] Properties: `id: UUID`, `yearMonth: String` ("YYYY-MM"), `totalKWh: Double`
  - [ ] Conforms to `Codable`, `Identifiable`
- [ ] Define `DateRange`:
  - [ ] Properties: `start: Date`, `end: Date`

## B2: PowerLogServiceProtocol + Implementation

- [ ] Define `PowerLogServiceProtocol` in `Data/PowerLogService.swift`:
  - [ ] `func append(_ record: PowerRecord) async throws`
  - [ ] `func records(in range: DateRange) -> [PowerRecord]`
  - [ ] `func recentRecords(count: Int) -> [PowerRecord]`
  - [ ] `func sessionAverage() -> Double` (1-hour rolling window)
  - [ ] `func sessionPeak() -> Double` (max in 1-hour window)
  - [ ] `func currentWatts() -> Double` (latest record watts, or 0.0)
  - [ ] `func dailyAverages(for days: Int) -> [DailyAverage]`
  - [ ] `func monthlyTotals(for months: Int) -> [MonthlyTotal]`
  - [ ] `func clearAll() async throws`

- [ ] Implement PowerLogService:
  - [ ] Initialize with `directory: URL`, create directory if not exists
  - [ ] Set up serial dispatch queue (`writeQueue`) for thread-safe writes
  - [ ] Load existing data into memory buffers on init:
    - `loadDailyBuffer()`: read daily-log.plist, decode to [PowerRecord], handle errors gracefully
    - `loadMonthlyBuffer()`: read monthly-log.plist, decode to [MonthlyTotal], handle errors gracefully
  - [ ] `append()`: journal mode write
    - Encode dailyBuffer to Data (PropertyListEncoder, iso8601 dates)
    - Write to temp file: `daily-log.plist.tmp`
    - Move temp → daily-log.plist (atomic rename)
  - [ ] `records(in:)`: filter buffer by date range (timestamp >= start && timestamp <= end)
  - [ ] `recentRecords(count:)`: return Array(buffer.suffix(count))
  - [ ] `sessionAverage()`: filter last hour, compute mean of watts (return 0.0 if empty)
  - [ ] `sessionPeak()`: filter last hour, return max watts (return 0.0 if empty)
  - [ ] `currentWatts()`: return buffer.last?.watts ?? 0.0
  - [ ] `dailyAverages(for:)`: for each day offset, filter records in that day's range
    - Compute mean watts per day (return 0.0 for days with no data)
    - Return array reversed so oldest is first (left-to-right chart order)
  - [ ] `monthlyTotals(for:)`: for each month offset, filter records in that month's range
    - kWh formula: `(avgWatts × secondsInMonth) / (1000.0 × 3600.0)`
    - yearMonth format: `String(format: "%04d-%02d", year, month)`
    - Return array reversed so oldest is first (bottom-to-top list order)

## B3: RotationManager

- [ ] Define rotation logic in `Data/RotationManager.swift`:
  - [ ] Store last rotation timestamp as ISO8601 string in UserDefaults key `"lastRotationMonth"`
  - [ ] `checkAndRotate(dailyService:)`: called on app launch only
    - Read last rotation month from UserDefaults (or nil for first launch)
    - Compare with current year-month components
    - If different month → trigger rotation, save new timestamp

- [ ] Rotation process:
  - [ ] Get all daily records before current month start date
  - [ ] Group old records by year-month using `formatYearMonth(from:)` helper
  - [ ] For each group: compute avg watts, convert to kWh using `avgWatts × recordCount × 10 / (1000×3600)`
    - Note: each record represents 10 seconds of power consumption at default interval
  - [ ] Merge with existing monthly totals (avoid duplicates by yearMonth)
  - [ ] Save merged list to monthly-log.plist via file write (journal mode same as daily)
  - [ ] Clear old records from daily buffer and re-write daily-log.plist (keep current month only)

## B4: Store

- [ ] Define `UserDefaultsProtocol` for testability in `Data/Store.swift`:
  - Methods: `integer(forKey:)`, `bool(forKey:)`, `string(forKey:)`, `set(_:forKey:)`, `object(forKey:)`
  - Extension: `UserDefaults` conforms to it

- [ ] Implement Store class with properties backed by UserDefaults:
  - `collectionInterval`: Int, default=10, keys="collectionInterval"
    - On init: set to 10 if not already stored
  - `logDirectory`: URL, default=~/Library/Application Support/Mac Wattage/
    - On get: check UserDefaults for path string, fall back to default directory URL
    - On set: store the `.path` string in UserDefaults

- [ ] Implement `autoLaunchAtLogin`:
  - Bool, default=false, key="autoLaunchAtLogin"
  - On init: set to false if not already stored
  - On set: call `updateLoginItems(_:)` with new value

- [ ] Implement Login Items management (`LSSharedFileList`):
  - `updateLoginItems(_:)`: get current login items list via LSSharedFileList
    - If enable=true: check if Mac Wattage.app already present, add via LSSharedFileListInsertItemURL
    - If enable=false: find item with lastPathComponent == "Mac Wattage.app", remove via items.removeItem

## Dependencies Between Subtasks

```
B1 (Models) → B2, B3 use these types for storage and rotation
B2 (PowerLogService) → B1 uses models, provides CRUD that RotationManager calls into
B3 (RotationManager) → depends on B2 for daily records, writes to monthly-log.plist
B4 (Store) independent → used by App entry point and Settings UI
```
