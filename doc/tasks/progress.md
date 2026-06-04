# Mac Wattage — Progress Tracker

## Module Status Overview

| Module | File | Overall Progress |
|--------|------|-----------------|
| Metrics Layer | [metrics.md](./metrics.md) | 17/17 tasks ✅ |
| Data Layer | [data.md](./data.md) | 25/25 tasks ✅ |
| UI Layer | [ui.md](./ui.md) | 29/29 tasks ✅ |
| Scheduler | [scheduler.md](./scheduler.md) | 5/5 tasks ✅ |
| Shared | [shared.md](./shared.md) | 2/2 tasks ✅ |
| Tests | [tests.md](./tests.md) | 13/13 tasks ✅ |

**Total**: 92 / 92 tasks complete (100%) — All modules implemented, all tests passing

---

## Module Breakdown

### Metrics Layer
- A1: IOKitAdapterProtocol + Implementation — 8/8 ✅ (cpuUtilization via host_processor_info, gpuUtilization stub, isCharging/batteryLevel with AppleSmartBattery detection)
- A2: PowerEstimatorProtocol + Implementation — 6/6 ✅ (TDP-based estimation with ChipGeneration profiles)
- A3: PlatformDetector — 3/3 ✅ (MacPlatform detection + ChipGeneration via sysctlbyname)

### Data Layer
- B1: PowerRecord Models — 4/4 ✅ (PowerRecord, DailyAverage, MonthlyTotal, DateRange with helpers)
- B2: PowerLogService — 13/13 ✅ (in-memory buffer, journal-mode writes, session stats, chart data aggregation)
- B3: RotationManager — 6/6 ✅ (month boundary detection, kWh conversion, duplicate-safe merge)
- B4: Store — 5/5 ✅ (UserDefaultsProtocol, collectionInterval/logDirectory/autoLaunchAtLogin, SMLoginItemSetEnabled)

### UI Layer
- C1: App Entry Point — 7/7 ✅ (MenuBarExtra scene, Settings scene, full wiring in init())
- C2: MenuBarWidgetView + ViewModel — 6/6 ✅ (bolt icon, watts text with monospaced font, sparkline)
- C3: PowerPopoverView + ViewModel — 12/12 ✅ (current watts, avg/peak, 7-day chart, monthly totals, settings button)
- C4: SettingsWindowView — 9/9 ✅ (collection interval picker, log directory file picker, auto-launch toggle, clear logs)
- C5: Charts — 6/6 ✅ (SparklineView normalized path, BarChartView with Capsule bars, MonthlyTotalsView horizontal bar list)
- C6: AppDelegate — 3/3 ✅ (notification handling for clearAllLogs/openSettings, lifecycle management)

### Scheduler
- D1: CollectionTimer — 5/5 ✅ (timer-driven collection, background queue, async write, main-thread UI update)

### Shared
- E1: Logger — 2/2 ✅ (warning/error with file:function:line format)

### Tests
- F1: XCTest Setup — 2/2 ✅ (Package.swift with test target, MockUserDefaults + MockPowerLogService)
- F2: PowerEstimatorTests — 6/6 ✅ (15 tests covering idle/full/half load, all chip types, ordering, clamping)
- F3: PlatformDetectorTests — 2/2 ✅ (runtime detection tests, no crash)
- F4: PowerLogServiceTests — 6/6 ✅ (12 tests covering append, session stats, daily averages, clearAll, persistence)
- F5: RotationManagerTests — 2/2 ✅ (month boundary detection, same-month skip)
- F6: StoreTests — 3/3 ✅ (defaults, persistence of interval and log directory)

---

## Build Verification

- **Xcode build**: `xcodebuild build -scheme MacWattage` — ✅ BUILD SUCCEEDED
- **Swift Package tests**: `swift test` — ✅ 35/35 passed

---

## Recommended Build Order (for reference)

1. **E (Shared)** — Logger utility, no dependencies
2. **A (Metrics Layer)** — IOKitAdapter → PowerEstimator → PlatformDetector
3. **B (Data Layer)** — Models → Service → RotationManager → Store
4. **F (Tests for A+B)** — Unit tests for Metrics and Data modules
5. **D (Scheduler)** — CollectionTimer, depends on A + B
6. **C5 (Charts)** — UI chart components, no dependencies
7. **F1-F6 (Tests for C+D)** — Tests that depend on other modules
8. **C1-C4, C6 (UI Layer)** — App entry point → widgets → popover → settings
