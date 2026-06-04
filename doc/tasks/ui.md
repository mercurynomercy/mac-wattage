# UI Layer — Task List

## C1: App Entry Point

- [x] Create `MacWattageApp.swift` with @main:
  - [x] Add `@NSApplicationDelegateAdaptor(AppDelegate.self)`
  - [x] Define MenuBarExtra scene:
    - [x] Label: `MenuBarWidgetView()` (custom SwiftUI view for menu bar icon)
    - [x] Content: `PowerPopoverView()` (popover dashboard)
  - [x] Define Settings scene:
    - [x] Content: `SettingsWindowView()` (dedicated settings window)
  - [x] In init():
    - [x] Call `PlatformDetector.detectPlatform()` and `detectChipGeneration()` (side-effect for estimator profile)
    - [x] Create `Store()` and get `logDirectory` (reads UserDefaults for user config)
    - [x] Create `PowerLogService(directory:)` (loads existing data into memory buffers)
    - [x] Create `RotationManager()` and call `checkAndRotate(dailyService:)` (non-blocking)
    - [x] Create `IOKitAdapter()` and `PowerEstimator(platform:chipGeneration:)` (metrics pipeline)
    - [x] Wire up UI update callback to shared view models (`MenuBarViewModel`, `PopoverViewModel`)
    - [x] Create and start `CollectionTimer` (fires immediately, then at configured interval)
    - [x] Store timer reference in AppDelegate for lifecycle management

## C2: MenuBarWidgetView + MenuBarViewModel

- [x] Create `MenuBarViewModel` in `UI/ViewModels/MenuBarViewModel.swift`:
  - [x] `@MainActor final class MenuBarViewModel: ObservableObject`
  - [x] `static let shared = MenuBarViewModel()` (singleton)
  - [x] `@Published var currentWatts: Double = 0` (most recent power reading)
  - [x] `@Published var sparklineData: [Double] = []` (max 36 points)
  - [x] `func update(with record: PowerRecord)`: sets currentWatts, appends to sparklineData (trims to 36)
- [x] Create `MenuBarWidgetView` in `UI/MenuBarWidgetView.swift`:
  - [x] `@ObservedObject var viewModel = MenuBarViewModel.shared`
  - [x] HStack layout: bolt icon + watts text ± sparkline (4px spacing)
  - [x] Bolt icon: `Image(systemName: "bolt.fill")`, size 10×10
  - [x] Watts text: `Text("\(viewModel.currentWatts, specifier: "%.0f")W")`
    - [x] Font: system size 13, monospaced design (medium weight)
  - [x] Sparkline: `SparklineView(values: viewModel.sparklineData)` only when data not empty
    - [x] Frame: 40×14
  - [x] Empty state: when sparklineData is empty, show "n/a" instead of watts

## C3: PowerPopoverView + PopoverViewModel

- [x] Create `PopoverViewModel` in `UI/ViewModels/PopoverViewModel.swift`:
  - [x] `@MainActor final class PopoverViewModel: ObservableObject`
  - [x] `static let shared = PopoverViewModel()` (singleton)
  - [x] `@Published var currentWatts: Double = 0` (most recent reading)
  - [x] `@Published var sessionAverage: Double = 0` (1-hour rolling window average)
  - [x] `@Published var sessionPeak: Double = 0` (1-hour rolling window peak)
  - [x] `@Published var dailyAverages: [DailyAverage] = []` (last 7 days)
  - [x] `@Published var monthlyTotals: [MonthlyTotal] = []` (last 12 months)
  - [x] `var hasData: Bool → true if dailyAverages or monthlyTotals is non-empty`
  - [x] `func setService(_ service: PowerLogServiceProtocol)` (injected at startup)
  - [x] `func refresh()`: reads from service and updates all @Published properties
- [x] Create `PowerPopoverView` in `UI/PowerPopoverView.swift`:
  - [x] `@ObservedObject var viewModel = PopoverViewModel.shared`
  - [x] VStack(spacing: 16) with 4 sections separated by Dividers
  - [x] Section 1 — Current watts:
    - [x] Large text: `Text("\(viewModel.currentWatts, specifier: "%.0f")W")`
    - [x] Font: system size 32, bold weight, monospaced design
    - [x] Subtext: HStack with "Avg: XW" and "Peak: YW" (caption, secondary)
    - [x] If !viewModel.hasData: show "Collecting data..." instead of watts
  - [x] Section 2 — 7-day chart:
    - [x] Header: `Text("7-Day Power Consumption")` with .headline
    - [x] BarChartView(data: viewModel.dailyAverages) (Capsule bars with day labels)
    - [x] If empty: show "No data yet" in caption/secondary color
  - [x] Section 3 — Monthly totals:
    - [x] Header: `Text("Monthly Totals")` with .headline
    - [x] MonthlyTotalsView(totals: viewModel.monthlyTotals) (horizontal green bars with kWh labels)
    - [x] If empty: show "No data yet" in caption/secondary color
  - [x] Section 4 — Settings button:
    - [x] `Button("Settings")` action posts `.openSettings` notification (via NotificationCenter)
  - [x] Frame: 320 width, padding all around
  - [x] `.onAppear`: call `viewModel.refresh()` (loads aggregated data from service)

## C4: SettingsWindowView

- [x] Create `SettingsWindowView` in `UI/SettingsWindowView.swift`:
  - [x] `@ObservedObject var store = Store()` (reads/writes UserDefaults)
  - [x] `@State private var showFilePicker = false` (for log directory selection)
  - [x] `@State private var showClearConfirmation = false` (for destructive action)
  - [x] VStack(spacing: 20) layout, frame 420×340 (fixed window size for settings panel)

- [x] Section 1 — Collection Interval:
  - [x] Form container with `Picker("Collection Interval", selection: $store.collectionInterval)`
  - [x] Options: "Every 10 seconds" (tag 10), "Every minute" (tag 60)
  - [x] `.pickerStyle(.radioGroup)` (vertical radio group layout)

- [x] Section 2 — Log Directory:
  - [x] Header: `Text("Log Directory")` with .headline
  - [x] HStack with path text (caption, secondary, lineLimit 1) and "Change..." button
  - [x] `.fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.folder])` (macOS 13+ folder picker)
  - [x] On selection: `store.logDirectoryPath = url.absoluteString` (persist for next launch)

- [x] Section 3 — Auto-Launch:
  - [x] Header: `Text("Launch at Login")` with .headline
  - [x] Toggle("Automatically launch at login", isOn: $store.autoLaunchAtLogin)
    - On set, calls `updateLoginItems(_:)` via SMLoginItemSetEnabled (via dlopen/dlsym)

- [x] Section 4 — Data Management:
  - [x] Header: `Text("Data Management")` with .headline
  - [x] Button("Clear All Logs", role: .destructive) with `.alert` confirmation dialog
  - [x] Alert message: "This will delete all daily and monthly power consumption data. This action cannot be undone."
  - [x] On confirm: post `.clearAllLogs` notification (handled by AppDelegate)

## C5: Charts

- [x] Create `SparklineView` in `UI/Charts/SparklineView.swift`:
  - [x] Input: `let values: [Double]` (~36 points)
  - [x] Compute max, min, range from values (min 1.0 range to avoid divide-by-zero)
  - [x] Build Path with normalized coordinates: x=index/(count-1)*40, y=1.0-normalizedY*14
  - [x] `.stroke(Color.primary, lineWidth: 1)` (monochrome line)
- [x] Create `BarChartView` in `UI/Charts/BarChartView.swift`:
  - [x] Input: `let data: [DailyAverage]` (7 points)
  - [x] HStack with 4px spacing, scale bars so max fills ~80px height
  - [x] For each index: VStack with Capsule bar + day label (Abbreviated EEE format)
  - [x] Day label: caption2 font, secondary color
- [x] Create `MonthlyTotalsView` in `UI/Charts/MonthlyTotalsView.swift`:
  - [x] Input: `let totals: [MonthlyTotal]` (up to ~12 points)
  - [x] VStack with 2px spacing, leading alignment (reversed order — oldest first)
  - [x] For each total: HStack with month label + green bar + kWh text
  - [x] Month label: caption font, 40px width (MMM format)
  - [x] Bar: Rectangle, green fill, height 14px, width proportional to totalKWh (max ~200px)
  - [x] kWh text: caption font, secondary color, ~60px width

## C6: AppDelegate

- [x] Create `AppDelegate.swift`:
  - [x] `NSObject` + `NSApplicationDelegate` conformance
  - [x] Properties: `collectionTimer: CollectionTimer?`, `powerLogService: PowerLogServiceProtocol?`
  - [x] `applicationDidFinishLaunching(_:)`: register for `.clearAllLogs` and `.openSettings` notifications
  - [x] `applicationWillTerminate(_:)`: call `collectionTimer?.stop()` (graceful shutdown)
  - [x] `applicationShouldTerminateAfterLastWindowClosed(_:)`: return false (menu bar app stays running)
  - [x] `handleClearAllLogs()`: async clear service in background, then reset UI on main thread
  - [x] `handleOpenSettings()`: activate app via NSApp.activate(ignoringOtherApps:)

## Dependencies Between Subtasks

```
C2 (MenuBarWidget) → C5 (SparklineView)
C3 (Popover) → C5 (BarChartView, MonthlyTotalsView)
C4 (Settings) → B4 (Store) for settings persistence + notification posting
C1 (App Entry) → C2, C3, C4, C6 all wired together
C6 (AppDelegate) → C1 stores timer reference for lifecycle management
```
