# Mac Wattage — High-Level Design Document

## 1. Architecture Overview

Mac Wattage is a macOS menu bar application built with SwiftUI that continuously monitors and displays system power consumption. The app runs silently in the background, collecting power data at configurable intervals and presenting it through a menu bar widget and popover dashboard.

### System Context
```
┌────────────────────────────────────────────────┐
│                  macOS System                   │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │           Mac Wattage App                 │  │
│  │                                          │  │
│  │  ┌─────────┐  ┌──────────┐  ┌────────┐  │  │
│  │  │  UI     │  │  Data    │  │ Metrics│  │  │
│  │  │ Layer   │←→│  Layer   │←→│ Layer  │  │  │
│  │  └─────────┘  └──────────┘  └────────┘  │  │
│  │       ↑              ↑              ↑    │  │
│  │  MenuBar     Power Log      IOKit /    │  │
│  │  Extra       Storage      Mach APIs    │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │         macOS Hardware                    │  │
│  │  CPU / GPU / Battery / Power Sensors     │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

---

## 2. Module Breakdown

### 2.1 Module Overview

The app is organized into three main modules with clear separation of concerns:

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

### 2.2 Module Descriptions

#### Module A: Metrics Layer (数据收集层)
**Purpose**: Raw data acquisition from macOS system APIs.
**Responsibility**: Read hardware metrics (CPU, GPU, battery state) and produce raw power values.

#### Module B: Data Layer (数据管理层)
**Purpose**: Storage, retrieval, aggregation, and rotation of power data.
**Responsibility**: Persist records to disk, compute statistics, manage data lifecycle.

#### Module C: UI Layer (用户界面层)
**Purpose**: Present data to the user through menu bar, popover, and settings.
**Responsibility**: Render current values, charts, and handle user interactions.

#### Module D: Scheduler (调度器)
**Purpose**: Orchestrate data collection timing.
**Responsibility**: Fire collection tasks at the configured interval, respect app lifecycle.

---

## 3. Module Relationships & Data Flow

### 3.1 Dependency Graph
```
UI Layer ──────┐
               │
Data Layer ←───┘
       ↑
Metrics Layer
       ↑
   macOS APIs (IOKit, mach, Metal)
```

- **UI Layer** depends on **Data Layer** for all displayed data (reads only)
- **Data Layer** depends on **Metrics Layer** to produce new records (writes)
- **Scheduler** drives **Metrics Layer** on a timer, pushes results to **Data Layer**
- **UI Layer** does NOT depend on **Metrics Layer** — all data flows through **Data Layer**

### 3.2 Data Flow Diagram
```
┌──────────┐   collects    ┌──────────────┐   writes    ┌──────────────┐
│ Scheduler│──────────────→│ Metrics Layer│────────────→│   Data Layer │
│ (Timer)  │   every N sec │ (IOKit/mach) │  PowerRecord│              │
└──────────┘               └──────────────┘             └──────┬───────┘
                                                                │
                                                                │ read / aggregate
                                                                ↓
                                                          ┌──────────────┐
                                                          │    UI Layer  │
                                                          │ (Menu/Popover│
                                                          │  / Settings) │
                                                          └──────────────┘
```

### 3.3 Module Interaction Details

#### Scheduler → Metrics Layer
- Fires a `collect()` call at configured interval
- Passes no parameters; Metrics Layer reads system state independently

#### Metrics Layer → Data Layer
- Returns a `PowerRecord` struct (timestamp + watts + optional charging state)
- Data Layer appends to in-memory buffer and persists to disk

#### Data Layer → UI Layer
- Provides computed values: `currentWatts`, `sessionAvg`, `sessionPeak`
- Provides chart data: `dailyAverages(for days: Int)`, `monthlyTotals`
- Read-only access; UI never writes data directly

---

## 4. Module Detail

### 4.1 Metrics Layer

#### 4.1.1 IOKit Adapter (`IOKitAdapter`)
**Purpose**: Bridge between macOS IOKit APIs and Swift types.

```swift
// Core protocol
protocol IOKitAdapterProtocol {
    func cpuUtilization() -> Double
    func gpuUtilization() -> Double
    func isCharging() -> Bool?
    func batteryLevel() -> Double?
}

// Concrete implementation
final class IOKitAdapter: IOKitAdapterProtocol {
    // Reads CPU stats via host_processor_info()
    // Reads GPU stats via Metal/GPU services
    // Reads battery state via IOPowerSources
}
```

#### 4.1.2 Power Estimator (`PowerEstimator`)
**Purpose**: Convert raw utilization metrics into wattage values.

```swift
protocol PowerEstimatorProtocol {
    func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double
}

final class PowerEstimator: PowerEstimatorProtocol {
    // Primary: reads hardware power sensors via IOKit (if available)
    // Fallback: CPU/GPU utilization × TDP curves
    // TDP constants per chip generation (M1/M2/Pro/Max/Ultra)
}
```

**Estimation Logic**:
```
Watts = BaseIdlePower + (cpuUtil × cpuLoadPower) + (gpuUtil × gpuLoadPower)

Where:
  BaseIdlePower  = chip-specific constant (e.g., 3.0W for M1, 5.0W for M2)
  cpuLoadPower   = chip-specific max CPU power (e.g., 40W for M1 base)
  gpuLoadPower   = chip-specific max GPU power (e.g., 15W for M1 base)
```

#### 4.1.3 Platform Detector (`PlatformDetector`)
**Purpose**: Detect hardware type at runtime to adapt behavior.

```swift
enum MacPlatform {
    case studio  // Desktop, no battery
    case laptop  // MacBook, has battery
}

final class PlatformDetector {
    static func detect() -> MacPlatform
    // Checks AppleSmartBattery service in IOKit
}
```

### 4.2 Data Layer

#### 4.2.1 Power Record Model

```swift
struct PowerRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let watts: Double
    let isCharging: Bool?  // nil for desktop Macs
}
```

#### 4.2.2 Power Log Service (`PowerLogService`)
**Purpose**: Manage the complete lifecycle of power data — read, write, aggregate, and rotate.

```swift
final class PowerLogService {
    
    // MARK: - Core Operations
    
    /// Append a new record and persist to disk
    func append(_ record: PowerRecord)
    
    /// Fetch all records within a date range
    func records(in range: DateRange) -> [PowerRecord]
    
    /// Fetch the most recent N records (for in-memory buffer)
    func recentRecords(count: Int) -> [PowerRecord]
    
    // MARK: - Session Statistics
    
    /// Compute average watts over the last 120 seconds (rolling window)
    func sessionAverage() -> Double

    /// Compute peak (max) watts over the last 120 seconds
    func sessionPeak() -> Double
    
    /// Current watts from the latest record
    func currentWatts() -> Double
    
    // MARK: - Chart Data
    
    /// Daily average watts for the last N days
    func dailyAverages(for days: Int) -> [DailyAverage]
    
    /// Monthly total kWh for the last N months
    func monthlyTotals(for months: Int) -> [MonthlyTotal]
    
    // MARK: - Data Rotation
    
    /// Summarize daily records into a monthly total and delete old daily records
    func rotateIfNeeded()
    
    // MARK: - Management
    
    /// Clear all stored data (daily and monthly)
    func clearAll()
}

struct DailyAverage: Codable {
    let date: Date      // Start of day (midnight)
    let averageWatts: Double
}

struct MonthlyTotal: Codable {
    let yearMonth: String  // "2025-01" format
    let totalKWh: Double
}
```

**Storage Schema**: Two separate plist files
```
~/Library/Application Support/Mac Wattage/
├── daily-log.plist          // [PowerRecord] — per-second samples (minute-aggregated)
└── monthly-log.plist        // [MonthlyTotal] — aggregated monthly kWh
```

**Why two files?**
- Daily log can grow to ~2,592,000 records (30 days × 86,400 per-day at 1s interval; minute-level flush keeps it to ~43,200 aggregated records)
- Monthly log stays small (~36 records for 3 years)
- Separate files enable independent rotation without touching monthly data

#### 4.2.3 Rotation Manager (`RotationManager`)
**Purpose**: Automatically summarize and purge old daily records on month boundaries.

```swift
final class RotationManager {
    
    /// Called on app launch; checks if a month boundary has passed
    func checkAndRotate(dailyService: PowerLogService)
    
    // Rotation logic:
    // 1. Detect current month
    // 2. Find the last day of the previous month
    // 3. Compute total kWh for all records before that day
    // 4. Save as MonthlyTotal in monthly-log.plist
    // 5. Delete all records from previous months in daily-log.plist
    // 6. Keep current month's daily records for chart display
}
```

**Rotation Trigger**: On app launch + on month boundary detection.
**Example**: On June 1st, all May daily records are summarized into a monthly total and deleted.

#### 4.2.4 Store (`Store`)
**Purpose**: Persist and load configuration settings.

```swift
final class Store {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let collectionInterval = "collectionInterval"  // Int (seconds)
        static let logDirectory       = "logDirectory"        // String (path)
        static let autoLaunch         = "autoLaunchAtLogin"   // Bool
    }
    
    // MARK: - Properties
    
    var collectionInterval: Int {
        get { UserDefaults.standard.integer(forKey: Keys.collectionInterval) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.collectionInterval) }
    }
    
    var logDirectory: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: Keys.logDirectory) {
                return URL(fileURLWithPath: path)
            }
            return defaultDirectory
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: Keys.logDirectory)
        }
    }
    
    var autoLaunchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.autoLaunch) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoLaunch)
            updateLoginItems(newValue)
        }
    }
    
    // MARK: - Helpers
    
    private var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Mac Wattage")
    }
    
    private func updateLoginItems(_ enable: Bool) {
        // Uses LSSharedFileList for Login Items management
    }
}
```

### 4.3 UI Layer

#### 4.3.1 App Entry Point

```swift
@main
struct MacWattageApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar extra — no main window
        MenuBarExtra {
            PowerPopoverView()  // Popover content
        } label: {
            MenuBarWidgetView()  // Menu bar icon + current watts
        }
        
        // Separate settings window
        Settings {
            SettingsWindowView()
        }
    }
}
```

#### 4.3.2 Menu Bar Widget View (`MenuBarWidgetView`)
**Purpose**: Display current watts and sparkline in the menu bar.

```swift
struct MenuBarWidgetView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    
    var body: some View {
        HStack {
            Image(systemName: "bolt.fill")
            Text("\(viewModel.currentWatts, specifier: "%.0f")W")
            SparklineView(viewModel.sparklineData)
        }
        .font(.system(size: 13, weight: .medium))
    }
}
```

#### 4.3.3 Popover Dashboard (`PowerPopoverView`)
**Purpose**: Full dashboard with current stats, 7-day chart, and monthly totals.

```swift
struct PowerPopoverView: View {
    @ObservedObject var viewModel: PopoverViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Section 1: Current watts + session stats
            CurrentWattsSection(
                current: viewModel.currentWatts,
                average: viewModel.sessionAverage,
                peak: viewModel.sessionPeak
            )
            
            Divider()
            
            // Section 2: 7-day chart
            VStack(alignment: .leading) {
                Text("7-Day Power Consumption")
                    .font(.headline)
                BarChartView(viewModel.dailyAverages)
            }
            
            Divider()
            
            // Section 3: Monthly totals
            VStack(alignment: .leading) {
                Text("Monthly Totals")
                    .font(.headline)
                MonthlyTotalsView(viewModel.monthlyTotals)
            }
            
            Divider()
            
            // Settings link
            Button("⚙ Settings") {
                NSApp.activate(ignoringOtherApps: true)
                // Open settings window via notification or app delegate
            }
        }
        .padding()
        .frame(width: 320)
    }
}
```

#### 4.3.4 Settings Window (`SettingsWindowView`)
**Purpose**: Configure collection interval, log location, and data management.

```swift
struct SettingsWindowView: View {
    @ObservedObject var store: Store
    @State private var showFilePicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Collection interval
            Form {
                Picker("Collection Interval", selection: $store.collectionInterval) {
                    Text("Every 1 second (default)").tag(1)
                    Text("Every 5 seconds").tag(5)
                    Text("Every 10 seconds").tag(10)
                }
            }
            
            // Log directory
            VStack(alignment: .leading) {
                Text("Log Directory")
                Button("Change...") { showFilePicker = true }
                    .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.folder]) { result in
                        // Update store.logDirectory
                    }
                Text(store.logDirectory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Auto-launch toggle
            Toggle("Launch at login", isOn: $store.autoLaunchAtLogin)
            
            // Clear data
            Button("Clear All Logs", role: .destructive) {
                // Confirm dialog → call powerLogService.clearAll()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
```

#### 4.3.5 ViewModels

```swift
// Menu bar view model — updated on each collection cycle
@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var currentWatts: Double = 0
    @Published var sparklineData: [Double] = []  // Last ~120 records (~2-minute rolling window)
}

// Popover view model — computed on demand from data layer
@MainActor
final class PopoverViewModel: ObservableObject {
    @Published var currentWatts: Double = 0
    @Published var sessionAverage: Double = 0
    @Published var sessionPeak: Double = 0
    @Published var dailyAverages: [DailyAverage] = []
    @Published var monthlyTotals: [MonthlyTotal] = []
    
    func refresh() {
        // Read from PowerLogService and update @Published properties
    }
}
```

### 4.4 Scheduler

#### 4.4.1 Collection Timer (`CollectionTimer`)
**Purpose**: Trigger data collection at the configured interval.

```swift
final class CollectionTimer {
    
    private var timer: Timer?
    private let interval: Int  // seconds
    private let metrics: IOKitAdapterProtocol
    private let estimator: PowerEstimatorProtocol
    private let logService: PowerLogService
    private let uiUpdate: @MainActor (PowerRecord) -> Void
    
    init(
        interval: Int,
        metrics: IOKitAdapterProtocol,
        estimator: PowerEstimatorProtocol,
        logService: PowerLogService,
        uiUpdate: @escaping @MainActor (PowerRecord) -> Void
    ) {
        self.interval = interval
        self.metrics = metrics
        self.estimator = estimator
        self.logService = logService
        self.uiUpdate = uiUpdate
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true) { [weak self] _ in
            self?.collect()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func collect() {
        let cpuUtil = metrics.cpuUtilization()
        let gpuUtil = metrics.gpuUtilization()
        let watts = estimator.estimateSystemPower(from: cpuUtil, gpuUtil: gpuUtil)
        
        let record = PowerRecord(
            id: UUID(),
            timestamp: Date(),
            watts: watts,
            isCharging: metrics.isCharging()
        )
        
        logService.append(record)
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.uiUpdate(record)
        }
    }
}
```

---

## 5. App Lifecycle & Threading Model

### 5.1 Lifecycle
```
App Launch
    │
    ├── PlatformDetector.detect()
    ├── Store.load()
    ├── RotationManager.checkAndRotate()
    ├── CollectionTimer.start()
    └── MenuBarExtra appears
         │
         └── Collects data every N seconds forever
              │
              └── App Quit (user quits or system shutdown)
                   CollectionTimer.stop()
                   PowerLogService.flush()
```

### 5.2 Threading Model
```
Main Thread (UI)
    │
    ├── MenuBarWidgetView rendering
    ├── PopoverViewModel refresh
    ├── SettingsWindowView interactions
    └── ← receives PowerRecord updates (async from background)
         │
Background Thread
    │
    └── CollectionTimer fires on Timer
         │
         ├── IOKit reads (synchronous, fast)
         └── Power estimation (synchronous, fast)
              │
              └── PowerLogService.append()
                   │
                   └── File I/O (dispatched to background queue)
```

- **Collection** runs on a background thread (Timer target)
- **File I/O** runs on a dedicated background queue (not main thread)
- **UI updates** are dispatched to the main thread via `@MainActor` / `DispatchQueue.main`
- **No data races**: PowerLogService uses a serial queue for all writes

---

## 6. Chart Rendering (Custom SwiftUI)

### 6.1 Sparkline View (Menu Bar)
```swift
struct SparklineView: View {
    let values: [Double]  // ~120 records (~2 minutes at 1s interval)
    
    var body: some View {
        Path { path in
            let max = values.max() ?? 1
            let min = values.min() ?? 0
            let range = max - min > 0 ? max - min : 1
            
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) / CGFloat(values.count - 1)
                let normalizedY = (value - min) / range
                let point = CGPoint(x: x, y: 1.0 - normalizedY)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(Color.primary, lineWidth: 1)
    }
}
```

### 6.2 Bar Chart View (7-Day)
```swift
struct BarChartView: View {
    let data: [DailyAverage]  // 7 points
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(data.indices, id: \.self) { index in
                VStack {
                    Capsule()
                        .fill(Color.blue)
                        .frame(height: CGFloat(data[index].averageWatts) * scale)
                    Text(dayLabel(for: index))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
            }
        }
    }
}
```

### 6.3 Monthly Totals View
```swift
struct MonthlyTotalsView: View {
    let totals: [MonthlyTotal]  // Up to 6 months (past 6)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(totals.reversed(), id: \.yearMonth) { total in
                HStack {
                    Text(monthLabel(from: total.yearMonth))
                        .frame(width: 40, alignment: .leading)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: CGFloat(total.totalKWh) * scale, height: 14)
                    Text("\(total.totalKWh, specifier: "%.1f")kWh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }
}
```

---

## 7. File Structure

```
MacWattage/
├── MacWattageApp.swift              // @main entry point, MenuBarExtra & Settings scene
├── AppDelegate.swift                 // NSApplicationDelegate (login items, lifecycle)
│
├── Metrics/
│   ├── IOKitAdapter.swift           // Protocol + implementation for hardware reads
│   ├── PowerEstimator.swift         // Utilization → watts conversion
│   └── PlatformDetector.swift       // MacBook vs desktop detection
│
├── Data/
│   ├── PowerRecord.swift            // Codable model
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
└── Scheduler/
    └── CollectionTimer.swift         // Timer-driven collection loop
```

---

## 8. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Data format | Binary plist | Native macOS, compact, fast I/O, no external deps |
| Storage layout | Two files (daily + monthly) | Independent rotation; daily log is large, monthly is small |
| Chart rendering | Custom SwiftUI paths | Zero dependencies; charts are simple enough to build |
| Settings UI | Dedicated NSWindow | Full-featured panel with file picker, toggles, destructive actions |
| Session stats | 120-second rolling window (last 120 records) | Reflects recent load without being stale; matches Sparkline chart window |
| Power estimation | Hardware sensors primary, TDP fallback | Accurate when available, functional on all Apple Silicon |
| Data rotation | Automatic on month boundary | Keeps daily log manageable; preserves monthly history |
| Threading | Background collection, main-thread UI | Prevents UI freeze; @MainActor ensures thread safety |
| Login items | User-controlled toggle | Respects user preference; not forced |
| Minimum macOS | 13 Ventura | Required for MenuBarExtra API |

---

## 9. Open Questions for Implementation

These items need decisions before code generation:

1. **Menu bar icon**: Should the app use a single icon with a dynamic text overlay (e.g., "⚡ 42W"), or an image-based icon that changes color based on power level?

2. **Dark/Light mode**: Should the menu bar widget text color adapt to system appearance, or use a fixed color for readability?

3. **Empty state**: What should the popover show on first launch before any data is collected? (e.g., "Collecting data..." placeholder)

4. **Error handling**: If IOKit fails (e.g., permissions denied), should the app:
   - Show an error in the popover?
   - Silently fall back to estimation?
   - Disable itself and show a warning?

5. **Data integrity**: If the app crashes mid-write, should the plist include a checksum or journal mode to detect corruption?
