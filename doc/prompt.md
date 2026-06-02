# Mac Wattage — Vibe Coding Master Prompt

## 1. Project Overview

You are building **Mac Wattage**, a macOS menu bar app that tracks system power consumption in real time. The app runs silently in the background, collecting power data at configurable intervals and presenting it through a menu bar widget and popover dashboard. It supports both Mac Studio (desktop, no battery) and MacBook models with battery.

**Core features**:

- Menu bar widget showing current watts + session avg/peak + sparkline
- Popover dashboard with 7-day daily chart and monthly kWh totals
- Configurable data collection (10s default, 60s alternative)
- Automatic monthly data rotation (daily → monthly totals)
- User-configurable log storage location and clear-all logs
- Auto-launch at login option

**Constraints**:

- **Zero external dependencies** — Swift + SwiftUI only
- **Apple Silicon only** (M1/M2/M3/M4/M5 series, including Pro/Max/Ultra)
- **Minimum macOS 13 Ventura** (for `MenuBarExtra` API)
- **Xcode native build** — no Node.js, Python, or other runtime
- **Full test coverage** for non-UI modules — all tests must pass

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Mac Wattage                          │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   UI Layer   │    │   Data Layer │    │ Metrics Layer│  │
│  │              │    │              │    │              │  │
│  │ • MenuBar    │    │ • PowerLog   │    │ • IOKit      │  │
│  │   Widget     │    │   Service    │    │   Adapter    │  │
│  │ • Popover    │    │              │    │              │  │
│  │   Dashboard  │    │ • Store      │    │ • Estimator  │  │
│  │ • Settings   │    │              │    │              │  │
│  │   Window     │    │ • Rotation   │    │ • Platform   │  │
│  │              │    │   Manager    │    │   Detector   │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                   │           │
│         └───────────────────┼───────────────────┘           │
│                             │                               │
│                     ┌───────┴───────┐                       │
│                     │   Scheduler   │                       │
│                     │   (Timer)     │                       │
│                     └───────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

**Dependency order** (build in this order):

```
Shared (Logger) → Metrics → Data → Scheduler → UI
```

---

## 3. Tech Stack

| Category             | Choice                                        |
| -------------------- | --------------------------------------------- |
| Language             | Swift 6.0+ (with strict concurrency)          |
| UI Framework         | SwiftUI + AppKit integration where needed     |
| Menu Bar Integration | `MenuBarExtra` (macOS 13+)                    |
| Data Storage         | BinaryPropertyList (.plist) + UserDefaults    |
| Chart Rendering      | Custom SwiftUI (no external charting library) |
| Testing              | XCTest (built into Xcode)                     |
| Build Tool           | Xcode (native Swift project template)         |
| Power APIs           | IOKit, mach, Metal Performance Queries        |

---

## 4. Project Structure

```
MacWattage/
├── MacWattageApp.swift              // @main entry point
├── AppDelegate.swift                 // NSApplicationDelegate (login items, lifecycle)
│
├── Metrics/
│   ├── IOKitAdapter.swift           // Protocol + implementation for hardware reads
│   ├── PowerEstimator.swift         // Utilization → watts conversion
│   └── PlatformDetector.swift       // MacBook vs desktop detection
│
├── Data/
│   ├── PowerRecord.swift            // Codable models
│   ├── PowerLogService.swift        // Append, read, aggregate, session stats
│   ├── RotationManager.swift        // Monthly rotation logic
│   └── Store.swift                  // UserDefaults + Login Items management
│
├── UI/
│   ├── MenuBarWidgetView.swift      // Menu bar icon + current watts + sparkline
│   ├── PowerPopoverView.swift       // Dashboard popover (current, 7-day, monthly)
│   ├── SettingsWindowView.swift     // Dedicated NSWindow for settings
│   ├── Charts/
│   │   ├── SparklineView.swift      // Menu bar sparkline
│   │   ├── BarChartView.swift       // 7-day bar chart
│   │   └── MonthlyTotalsView.swift  // Monthly bar list
│   └── ViewModels/
│       ├── MenuBarViewModel.swift   // @MainActor observable object
│       └── PopoverViewModel.swift   // @MainActor observable object
│
├── Scheduler/
│   └── CollectionTimer.swift         // Timer-driven collection loop
│
├── Shared/
│   └── Logger.swift                  // Console logging utility
│
└── MacWattageTests/                  // XCTest target
    ├── PowerEstimatorTests.swift
    ├── PlatformDetectorTests.swift
    ├── PowerLogServiceTests.swift
    ├── RotationManagerTests.swift
    ├── StoreTests.swift
    └── Mocks.swift                   // MockUserDefaults, MockPowerLogService
```

---

## 5. Key Design Decisions

| Decision         | Choice                                 | Rationale                                                          |
| ---------------- | -------------------------------------- | ------------------------------------------------------------------ |
| Data format      | Binary plist                           | Native macOS, compact, fast I/O, no external deps                  |
| Storage layout   | Two files (daily + monthly)            | Independent rotation; daily log is large, monthly is small         |
| Chart rendering  | Custom SwiftUI paths                   | Zero dependencies; charts are simple enough to build               |
| Settings UI      | Dedicated NSWindow                     | Full-featured panel with file picker, toggles, destructive actions |
| Session stats    | 1-hour rolling window since login      | Captures meaningful recent behavior without being stale            |
| Power estimation | Hardware sensors primary, TDP fallback | Accurate when available, functional on all Apple Silicon           |
| Data rotation    | Automatic on month boundary            | Keeps daily log manageable; preserves monthly history              |
| Threading        | Background collection, main-thread UI  | Prevents UI freeze; @MainActor ensures thread safety               |
| Login items      | User-controlled toggle                 | Respects user preference; not forced                               |
| Minimum macOS    | 13 Ventura                             | Required for MenuBarExtra API                                      |

---

## 6. API Contracts

### IOKitAdapterProtocol

```swift
protocol IOKitAdapterProtocol {
    func cpuUtilization() -> Double        // [0.0, 1.0]
    func gpuUtilization() -> Double        // [0.0, 1.0]
    func isCharging() -> Bool?             // nil = desktop
    func batteryLevel() -> Double?         // nil = desktop, [0.0, 1.0] = laptop
}
```

### PowerEstimatorProtocol

```swift
protocol PowerEstimatorProtocol {
    func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double  // watts
}
```

### PowerLogServiceProtocol

```swift
protocol PowerLogServiceProtocol {
    func append(_ record: PowerRecord) async throws
    func records(in range: DateRange) -> [PowerRecord]
    func recentRecords(count: Int) -> [PowerRecord]
    func sessionAverage() -> Double
    func sessionPeak() -> Double
    func currentWatts() -> Double
    func dailyAverages(for days: Int) -> [DailyAverage]
    func monthlyTotals(for months: Int) -> [MonthlyTotal]
    func clearAll() async throws
}
```

### UserDefaultsProtocol

```swift
protocol UserDefaultsProtocol {
    var integer(forKey: String) -> Int { get set }
    var bool(forKey: String) -> Bool { get set }
    func string(forKey: String) -> String?
    func set(_ value: Any?, forKey: String)
    func object(forKey: String) -> Any?
}
```

### Data Models

```swift
struct PowerRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let watts: Double
    let isCharging: Bool?  // nil for desktop Macs
}

struct DailyAverage: Codable, Identifiable {
    let id: UUID
    let date: Date       // Start of day (midnight)
    let averageWatts: Double
}

struct MonthlyTotal: Codable, Identifiable {
    let id: UUID
    let yearMonth: String  // "2025-01" format
    let totalKWh: Double
}
```

---

## 7. Execution Plan

You are the **Main Agent**. Follow this execution plan strictly. Do NOT skip steps. Do NOT parallelize module implementations.

### Phase 0: Project Setup

**Action**: Create the Xcode project structure.

1. Create directory structure:

   ```
   MacWattage/
   ├── MacWattage/           # Main app source
   ├── MacWattageTests/      # Test source
   ├── MacWattage.xcodeproj/ # Xcode project
   └── .gitignore
   ```

2. Create `.gitignore` with standard macOS/Xcode ignores:

   ```
   *.xcuserdata
   *.xcworkspace
   DerivedData/
   build/
   *.pbxuser
   *.mode1v3
   *.mode2v3
   *.perspectivev3
   .DS_Store
   ```

3. Create the Xcode project file (`MacWattage.xcodeproj/project.pbxproj`) with:
   - Target: `MacWattage` (macOS, SwiftUI, minimum deployment 13.0)
   - Target: `MacWattageTests` (macOS, XCTest, minimum deployment 13.0)
   - Test target linked to main target
   - All source files added to appropriate targets
   - Bundle identifier: `com.macwattage.app`
   - Product name: `Mac Wattage`

4. Create placeholder source files (empty but with correct module imports):
   - `MacWattage/MacWattageApp.swift`
   - `MacWattage/AppDelegate.swift`
   - `MacWattage/Metrics/IOKitAdapter.swift`
   - `MacWattage/Metrics/PowerEstimator.swift`
   - `MacWattage/Metrics/PlatformDetector.swift`
   - `MacWattage/Data/PowerRecord.swift`
   - `MacWattage/Data/PowerLogService.swift`
   - `MacWattage/Data/RotationManager.swift`
   - `MacWattage/Data/Store.swift`
   - `MacWattage/UI/MenuBarWidgetView.swift`
   - `MacWattage/UI/PowerPopoverView.swift`
   - `MacWattage/UI/SettingsWindowView.swift`
   - `MacWattage/UI/Charts/SparklineView.swift`
   - `MacWattage/UI/Charts/BarChartView.swift`
   - `MacWattage/UI/Charts/MonthlyTotalsView.swift`
   - `MacWattage/UI/ViewModels/MenuBarViewModel.swift`
   - `MacWattage/UI/ViewModels/PopoverViewModel.swift`
   - `MacWattage/Scheduler/CollectionTimer.swift`
   - `MacWattage/Shared/Logger.swift`
   - `MacWattageTests/Mocks.swift`
   - `MacWattageTests/PowerEstimatorTests.swift`
   - `MacWattageTests/PlatformDetectorTests.swift`
   - `MacWattageTests/PowerLogServiceTests.swift`
   - `MacWattageTests/RotationManagerTests.swift`
   - `MacWattageTests/StoreTests.swift`

5. Verify project compiles (empty, no errors).

### Phase 1: Shared Module

**Action**: Spawn subagent for Shared module.

**Subagent prompt**:

```
Implement the Shared/Logger.swift file for Mac Wattage.

Requirements:
- Create a Logger enum with two static methods: warning() and error()
- Both methods accept a message string and optional file/function/line parameters with defaults
- Extract filename from full path using (file as NSString).lastPathComponent
- Print format: [MacWattage WARNING] filename:line function - message
- Print format: [MacWattage ERROR] filename:line function - message
- No external dependencies, no logging framework

After implementation:
- Verify the file compiles by building the MacWattage target
- Update doc/tasks/shared.md: check all [ ] items to [x]
- Update doc/tasks/progress.md: update Shared module progress and overall percentage
```

**Main Agent verification**:

- Check `doc/tasks/shared.md` — all items should be checked
- Verify `Shared/Logger.swift` exists and compiles
- Continue to Phase 2 only if Shared module is complete

### Phase 2: Metrics Layer

**Action**: Spawn subagent for Metrics module.

**Subagent prompt**:

```
Implement the Metrics Layer for Mac Wattage. This module has 3 sub-modules.

### A1: IOKitAdapterProtocol + Implementation

Create Metrics/IOKitAdapter.swift with:

1. Protocol `IOKitAdapterProtocol`:
   - func cpuUtilization() -> Double — CPU usage fraction [0.0, 1.0]
   - func gpuUtilization() -> Double — GPU usage fraction [0.0, 1.0]
   - func isCharging() -> Bool? — nil for desktop Macs
   - func batteryLevel() -> Double? — nil for desktop, fraction [0.0, 1.0]

2. Concrete class `IOKitAdapter`:
   - cpuUtilization(): use host_processor_info() with PROCESSOR_CPU_LOAD_INFO
     - Calculate total vs idle time across all cores
     - Return 1.0 - (idle / total) clamped to [0.0, 1.0]
     - Return 0.0 if mach call fails (never throw)
   - gpuUtilization(): use Metal Performance Queries or IOService matching
     - Return 0.0 if GPU service not found (fallback)
   - isCharging(): use IOPowerSourcesCopyPowerSourceInfo()
     - Read kIOPowerSourcesInfoExternalConnectedKeyName
     - Return nil if power source info unavailable
   - batteryLevel(): use IOPowerSourcesCopyPowerSourceInfo()
     - Read kIOPowerSourcesInfoBatteryPercentKeyName and divide by 100
     - Return nil if unavailable

### A2: PowerEstimatorProtocol + Implementation

Create Metrics/PowerEstimator.swift with:

1. Protocol `PowerEstimatorProtocol`:
   - func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double

2. Enum `ChipGeneration`: m1Base, m2Base, m1Pro, m2Pro, m1Max, m2Max, m1Ultra

3. Struct `ChipProfile` with per-chip constants:
   - Base: idle=3W, cpuMax=40W, gpuMax=15W
   - Pro: idle=5W, cpuMax=60W, gpuMax=30W
   - Max: idle=8W, cpuMax=100W, gpuMax=60W
   - Ultra: idle=10W, cpuMax=120W, gpuMax=80W

4. Implementation:
   - Hardware sensor reading path (primary): read from IOKit power sensors via SMC
   - TDP-based estimation (fallback): idlePower + cpuUtil × (cpuMaxPower - idlePower) + gpuUtil × gpuMaxPower
   - Chip profile selection based on ChipGeneration
   - Default to M2 base if chip detection fails

### A3: PlatformDetector

Create Metrics/PlatformDetector.swift with:

1. Enum `MacPlatform`: .studio, .laptop

2. detectPlatform():
   - Use IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))
   - Return .laptop if battery service found, .studio otherwise

3. detectChipGeneration():
   - Use sysctlbyname("machdep.cpu.brand_string") to read CPU string
   - Parse for "Ultra", "Max", "Pro" keywords and M1/M2 prefix
   - Default to .m2Base if detection fails

After implementation:
- Verify the project compiles (build MacWattage target)
- Update doc/tasks/metrics.md: check all [ ] items to [x]
- Update doc/tasks/progress.md: update Metrics Layer progress and overall percentage
```

**Main Agent verification**:

- Check `doc/tasks/metrics.md` — all items should be checked
- Verify `Metrics/` files exist and compile
- Continue to Phase 3 only if Metrics module is complete

### Phase 3: Data Layer

**Action**: Spawn subagent for Data module.

**Subagent prompt**:

```
Implement the Data Layer for Mac Wattage. This module has 4 sub-modules.

### B1: PowerRecord Models + Supporting Types

Create Data/PowerRecord.swift with:

1. `PowerRecord`: id: UUID, timestamp: Date, watts: Double, isCharging: Bool?
   - Conforms to Codable, Identifiable
   - Convenience init with default id and timestamp

2. `DailyAverage`: id: UUID, date: Date (midnight), averageWatts: Double
   - Conforms to Codable, Identifiable

3. `MonthlyTotal`: id: UUID, yearMonth: String ("YYYY-MM"), totalKWh: Double
   - Conforms to Codable, Identifiable

4. `DateRange`: start: Date, end: Date

### B2: PowerLogServiceProtocol + Implementation

Create Data/PowerLogService.swift with:

1. Protocol `PowerLogServiceProtocol`:
   - func append(_ record: PowerRecord) async throws
   - func records(in range: DateRange) -> [PowerRecord]
   - func recentRecords(count: Int) -> [PowerRecord]
   - func sessionAverage() -> Double (1-hour rolling window)
   - func sessionPeak() -> Double (max in 1-hour window)
   - func currentWatts() -> Double (latest record watts, or 0.0)
   - func dailyAverages(for days: Int) -> [DailyAverage]
   - func monthlyTotals(for months: Int) -> [MonthlyTotal]
   - func clearAll() async throws

2. Implementation `PowerLogService`:
   - Initialize with directory: URL, create directory if not exists
   - Set up serial dispatch queue (writeQueue) for thread-safe writes
   - Load existing data into memory buffers on init:
     - loadDailyBuffer(): read daily-log.plist, decode to [PowerRecord], handle errors gracefully
     - loadMonthlyBuffer(): read monthly-log.plist, decode to [MonthlyTotal], handle errors gracefully
   - append(): journal mode write (encode to temp file, then rename)
   - records(in:): filter buffer by date range
   - recentRecords(count:): return Array(buffer.suffix(count))
   - sessionAverage(): filter last hour, compute mean of watts (return 0.0 if empty)
   - sessionPeak(): filter last hour, return max watts (return 0.0 if empty)
   - currentWatts(): return buffer.last?.watts ?? 0.0
   - dailyAverages(for:): for each day offset, filter records in that day's range, compute mean watts per day
   - monthlyTotals(for:): for each month offset, filter records in that month's range, compute kWh = (avgWatts × secondsInMonth) / (1000.0 × 3600.0)

### B3: RotationManager

Create Data/RotationManager.swift with:

1. checkAndRotate(dailyService:): called on app launch
   - Read last rotation month from UserDefaults key "lastRotationMonth"
   - Compare with current year-month components
   - If different month → trigger rotation, save new timestamp

2. Rotation process:
   - Get all daily records before current month start date
   - Group old records by year-month
   - For each group: compute avg watts, convert to kWh using avgWatts × recordCount × 10 / (1000×3600)
   - Merge with existing monthly totals (avoid duplicates by yearMonth)
   - Save merged list to monthly-log.plist via file write (journal mode)
   - Clear old records from daily buffer and re-write daily-log.plist

### B4: Store

Create Data/Store.swift with:

1. Protocol `UserDefaultsProtocol`:
   - Methods: integer(forKey:), bool(forKey:), string(forKey:), set(_:forKey:), object(forKey:)
   - Extension: UserDefaults conforms to it

2. Store class with properties backed by UserDefaults:
   - collectionInterval: Int, default=10, key="collectionInterval"
   - logDirectory: URL, default=~/Library/Application Support/Mac Wattage/
   - autoLaunchAtLogin: Bool, default=false, key="autoLaunchAtLogin"
     - On set: call updateLoginItems(_) with new value

3. Login Items management:
   - updateLoginItems(_:): get current login items list via LSSharedFileList
     - If enable=true: check if Mac Wattage.app already present, add via LSSharedFileListInsertItemURL
     - If enable=false: find item with lastPathComponent == "Mac Wattage.app", remove via items.removeItem

After implementation:
- Verify the project compiles (build MacWattage target)
- Update doc/tasks/data.md: check all [ ] items to [x]
- Update doc/tasks/progress.md: update Data Layer progress and overall percentage
```

**Main Agent verification**:

- Check `doc/tasks/data.md` — all items should be checked
- Verify `Data/` files exist and compile
- Continue to Phase 4 only if Data module is complete

### Phase 4: Tests for Metrics + Data

**Action**: Spawn subagent for Tests module (Metrics + Data tests only).

**Subagent prompt**:

```
Implement unit tests for Mac Wattage Metrics and Data modules.

### Setup: Mocks

Create MacWattageTests/Mocks.swift with:

1. `MockUserDefaults`: conforms to UserDefaultsProtocol
   - Internal dictionary storage: var values: [String: Any] = [:]
   - Implement all protocol methods to read/write from dictionary

2. `MockPowerLogService`: conforms to PowerLogServiceProtocol
   - Properties: appendedRecords: [PowerRecord] = [], rotationTriggered: Bool
   - Implement all protocol methods (return sensible defaults, track calls)

### PowerEstimatorTests

Create MacWattageTests/PowerEstimatorTests.swift with:

1. Test: M2 base at idle (0% CPU, 0% GPU) → ~5W
2. Test: M2 base at full load (100% CPU, 100% GPU) → ~90W
3. Test: M2 base at half load (50% CPU, 50% GPU) → ~47.5W
4. Test: M1 Pro at half load (50% CPU, 50% GPU) → ~47.5W
5. Test: M1 Ultra max power > M1 base max power (ordering check)
6. Test: Different chip generations produce different results at same utilization

### PlatformDetectorTests

Create MacWattageTests/PlatformDetectorTests.swift with:

1. Test: detectPlatform() returns .studio or .laptop (no crash, valid enum)
2. Test: detectChipGeneration() returns a valid .m* case (no crash, valid enum)
3. Note: These are runtime tests — verify methods don't crash and return valid values

### PowerLogServiceTests

Create MacWattageTests/PowerLogServiceTests.swift with:

1. Setup: create temp directory, initialize service with it
2. Teardown: remove temp directory after each test
3. Test: append record + verify currentWatts() returns correct value
4. Test: session average with known values (append 0,10,20,...,90 → expect ~45.0)
5. Test: session peak returns max value from appended records
6. Test: dailyAverages for 7 days with known data points
7. Test: clearAll removes all records and resets currentWatts to 0.0
8. Test: file persistence — append, reload from disk, verify data intact

### RotationManagerTests

Create MacWattageTests/RotationManagerTests.swift with:

1. Test: rotation triggers when month boundary detected (mock UserDefaults with previous month)
2. Test: no rotation within same month (mock UserDefaults with current month)

### StoreTests

Create MacWattageTests/StoreTests.swift with:

1. Test: collectionInterval defaults to 10 on fresh init
2. Test: setting a different interval persists and reads back correctly (mock UserDefaults)
3. Test: logDirectory defaults to Application Support/Mac Wattage on fresh init

After implementation:
- Run ALL tests: xcodebuild test -scheme MacWattageTests -destination 'platform=macOS,arch=arm64'
- ALL tests must pass (exit code 0)
- If any test fails, fix the test or the code and re-run until all pass
- Update doc/tasks/tests.md: check all [ ] items to [x]
- Update doc/tasks/progress.md: update Tests progress and overall percentage
```

**Main Agent verification**:

- Check `doc/tasks/tests.md` — all items should be checked
- Verify ALL tests pass (exit code 0)
- If any test fails, spawn a new subagent with the specific test output and error message to fix it
- Continue to Phase 5 only if ALL tests pass

### Phase 5: Scheduler

**Action**: Spawn subagent for Scheduler module.

**Subagent prompt**:

```
Implement the Scheduler/CollectionTimer.swift file for Mac Wattage.

Requirements:
1. Properties:
   - private var timer: Timer?
   - private let interval: Int (seconds)
   - private let metrics: IOKitAdapterProtocol
   - private let estimator: PowerEstimatorProtocol
   - private let logService: PowerLogServiceProtocol
   - private let uiUpdate: @MainActor (PowerRecord) -> Void
   - private let collectQueue: DispatchQueue (label: "com.macwattage.scheduler.collect", qos: .userInitiated)

2. init(interval:metrics:estimator:logService:uiUpdate:): store all dependencies

3. start():
   - Call collect() immediately (no delay on first tick)
   - Schedule repeating Timer: Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true)
   - Timer target calls collect() on each fire

4. stop():
   - timer?.invalidate()
   - timer = nil

5. collect() (private method):
   - Dispatch to collectQueue:
     - let cpuUtil = metrics.cpuUtilization()
     - let gpuUtil = metrics.gpuUtilization()
     - let watts = estimator.estimateSystemPower(from: cpuUtil, gpuUtil: gpuUtil)
     - Create PowerRecord(id: UUID(), timestamp: Date(), watts: watts, isCharging: metrics.isCharging())
     - Task { @MainActor in try? await logService.append(record) } (async write, ignore errors)
     - DispatchQueue.main.async { uiUpdate(record) } (UI update on main thread)

After implementation:
- Verify the project compiles (build MacWattage target)
- Update doc/tasks/scheduler.md: check all [ ] items to [x]
- Update doc/tasks/progress.md: update Scheduler progress and overall percentage
```

**Main Agent verification**:

- Check `doc/tasks/scheduler.md` — all items should be checked
- Verify `Scheduler/CollectionTimer.swift` exists and compiles
- Continue to Phase 6 only if Scheduler module is complete

### Phase 6: UI Layer

**Action**: Spawn subagent for UI module.

**Subagent prompt**:

```
Implement the UI Layer for Mac Wattage. This module has 6 sub-modules.

### C5: Charts (implement first — no dependencies on other UI modules)

Create UI/Charts/SparklineView.swift:
- Input: let values: [Double] (~36 points)
- Compute max, min, range from values (min 1.0 range to avoid divide-by-zero)
- Build Path with normalized coordinates: x = index / (count - 1), y = 1.0 - normalizedY
- .stroke(Color.primary, lineWidth: 1)

Create UI/Charts/BarChartView.swift:
- Input: let data: [DailyAverage] (7 points)
- HStack with 4px spacing
- For each index: VStack with Capsule bar + day label
- Capsule height: CGFloat(data[index].averageWatts) * scale
- Day label: abbreviated day name, caption2 font, secondary color
- Frame: 80px height for the bar column

Create UI/Charts/MonthlyTotalsView.swift:
- Input: let totals: [MonthlyTotal] (up to 12 points)
- VStack with 2px spacing, leading alignment
- For each total (reversed order): HStack with month label + bar + kWh text
- Month label: 40px width, leading alignment
- Bar: Rectangle, green fill, height 14px, width proportional to totalKWh
- kWh text: caption font, secondary color, 60px width, trailing alignment

### C2: MenuBarWidgetView + MenuBarViewModel

Create UI/ViewModels/MenuBarViewModel.swift:
- @MainActor final class MenuBarViewModel: ObservableObject
- static let shared = MenuBarViewModel()
- @Published var currentWatts: Double = 0
- @Published var sparklineData: [Double] = [] (max 36 points)
- func update(with record: PowerRecord):
  - Set currentWatts = record.watts
  - Append to sparklineData, trim to 36 if needed

Create UI/MenuBarWidgetView.swift:
- @ObservedObject var viewModel = MenuBarViewModel.shared
- HStack layout: bolt icon + watts text + sparkline
- Bolt icon: Image(systemName: "bolt.fill"), size 10
- Watts text: Text("\(viewModel.currentWatts, specifier: "%.0f")W")
  - Font: system size 13, medium weight, monospaced design
- Sparkline: SparklineView(values: viewModel.sparklineData)
  - Only show if sparklineData is not empty
  - Frame: 40×14
- Empty state: when currentWatts == 0 and sparklineData is empty, show "n/a" instead of watts

### C3: PowerPopoverView + PopoverViewModel

Create UI/ViewModels/PopoverViewModel.swift:
- @MainActor final class PopoverViewModel: ObservableObject
- static let shared = PopoverViewModel()
- @Published var currentWatts: Double = 0
- @Published var sessionAverage: Double = 0
- @Published var sessionPeak: Double = 0
- @Published var dailyAverages: [DailyAverage] = []
- @Published var monthlyTotals: [MonthlyTotal] = []
- var hasData: Bool → true if dailyAverages or monthlyTotals is non-empty
- func setService(_ service: PowerLogServiceProtocol)
- func refresh(): read from service and update all @Published properties

Create UI/PowerPopoverView.swift:
- @ObservedObject var viewModel = PopoverViewModel.shared
- VStack(spacing: 16) with 4 sections separated by Dividers
- Section 1 — Current watts:
  - Large text: Text("\(viewModel.currentWatts, specifier: "%.0f")W")
  - Font: system size 32, bold weight, monospaced
  - Subtext: HStack with "Avg: XW" and "Peak: YW"
  - If !viewModel.hasData: show "Collecting data..." instead
- Section 2 — 7-day chart:
  - Header: Text("7-Day Power Consumption") with .headline
  - BarChartView(data: viewModel.dailyAverages)
  - If empty: show "No data yet" in caption
- Section 3 — Monthly totals:
  - Header: Text("Monthly Totals") with .headline
  - MonthlyTotalsView(totals: viewModel.monthlyTotals)
  - If empty: show "No data yet" in caption
- Section 4 — Settings button:
  - Button("⚙ Settings") action:
    - NSApp.activate(ignoringOtherApps: true)
    - Post .openSettings notification to open settings window
- Frame: 320 width, padding all around
- .onAppear: call viewModel.refresh()

### C4: SettingsWindowView

Create UI/SettingsWindowView.swift:
- @ObservedObject var store = Store()
- @State private var showFilePicker = false
- @State private var showClearConfirmation = false
- VStack(spacing: 20) layout, frame 420×340
- Section 1 — Collection Interval: Form with Picker("Collection Interval", selection: $store.collectionInterval)
  - Options: "Every 10 seconds" (tag 10), "Every minute" (tag 60)
  - .pickerStyle(.radioGroup)
- Section 2 — Log Directory:
  - Header: Text("Log Directory") with .headline
  - HStack with path text (caption, secondary, lineLimit 1) and "Change..." button
  - .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.folder])
  - On selection: store.logDirectory = url
- Section 3 — Auto-Launch:
  - Header: Text("Launch at Login") with .headline
  - Toggle("Automatically launch at login", isOn: $store.autoLaunchAtLogin)
- Section 4 — Data Management:
  - Header: Text("Data Management") with .headline
  - Button("Clear All Logs", role: .destructive) with .alert confirmation
  - Alert message: "This will delete all daily and monthly power consumption data. This action cannot be undone."
  - On confirm: post .clearAllLogs notification

### C1: App Entry Point

Create MacWattageApp.swift with @main:
- Add @NSApplicationDelegateAdaptor(AppDelegate.self)
- Define MenuBarExtra scene:
  - Label: MenuBarWidgetView()
  - Content: PowerPopoverView()
- Define Settings scene:
  - Content: SettingsWindowView()
- In init():
  - Call PlatformDetector.detectPlatform() and detectChipGeneration()
  - Create Store() and get logDirectory
  - Create PowerLogService(directory:)
  - Create RotationManager() and call checkAndRotate(dailyService:)
  - Create IOKitAdapter(), PowerEstimator(platform:chipGeneration:)
  - Create CollectionTimer(interval:metrics:estimator:logService:uiUpdate:)
  - Call timer.start()
  - Store timer reference in AppDelegate for lifecycle management

### C6: AppDelegate

Create AppDelegate.swift:
- NSApplicationDelegate conformance
- var collectionTimer: CollectionTimer? property
- applicationWillTerminate(_:): call collectionTimer?.stop()
- Handle .clearAllLogs notification: call powerLogService.clearAll()
- Handle .openSettings notification: order front settings window

After implementation:
- Verify the project compiles (build MacWattage target)
- Update doc/tasks/ui.md: check all [ ] items to [x]
- Update doc/tasks/progress.md: update UI Layer progress and overall percentage
```

**Main Agent verification**:

- Check `doc/tasks/ui.md` — all items should be checked
- Verify `UI/` files exist and compile
- Continue to Phase 7 only if UI module is complete

### Phase 7: Final Integration Tests

**Action**: Run ALL tests one final time.

1. Run all tests: `xcodebuild test -scheme MacWattageTests -destination 'platform=macOS,arch=arm64'`
2. If ANY test fails:
   - Spawn a new subagent with the specific test output and error message
   - Subagent should fix the failing test or code and re-run
   - Repeat until ALL tests pass
3. If ALL tests pass:
   - Update `doc/tasks/progress.md` to show 100% completion
   - Mark all task files with all items checked
   - Report final status

---

## 8. Quality Gates

Before moving from one phase to the next, the Main Agent MUST verify:

1. **Compilation**: `xcodebuild build -scheme MacWattage -destination 'platform=macOS,arch=arm64'` succeeds
2. **Task checklist**: All `[ ]` items in the current module's task file are checked to `[x]`
3. **Progress updated**: `doc/tasks/progress.md` reflects the current module's completion
4. **No warnings**: The build produces zero compiler warnings

If any quality gate fails, the Main Agent MUST spawn a fix subagent before proceeding.

---

## 9. Error Recovery Protocol

When a subagent's work fails (compilation errors, test failures, incomplete implementation):

1. Capture the full error output
2. Spawn a new subagent with:
   - The original task prompt
   - The specific error output
   - Instructions to fix the issue and re-verify
3. The fix subagent should:
   - Read the error output carefully
   - Identify the root cause
   - Fix the code
   - Re-verify compilation and tests
   - Update task files and progress
4. If the fix subagent fails again, repeat up to 3 times
5. If still failing after 3 attempts, report the error and halt

---

## 10. Final Deliverables

After all phases complete successfully:

1. **Code**: MacWattage app compiles and all tests pass
2. **Task files**: All task files in `doc/tasks/` have all items checked
3. **Progress**: `doc/tasks/progress.md` shows 100% completion
4. **Tests**: All unit tests for Metrics, Data, and Store modules pass

Report final status with:

- Total modules completed
- Total tests passed
- Any remaining issues (if any)
