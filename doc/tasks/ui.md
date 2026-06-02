# UI Layer — Task List

## C1: App Entry Point

- [ ] Create `MacWattageApp.swift` with `@main`:
  - [ ] Add `@NSApplicationDelegateAdaptor(AppDelegate.self)`
  - [ ] Define `MenuBarExtra` scene:
    - [ ] Label: `MenuBarWidgetView()`
    - [ ] Content: `PowerPopoverView()`
  - [ ] Define `Settings` scene:
    - [ ] Content: `SettingsWindowView()`
  - [ ] In `init()`:
    - [ ] Call `PlatformDetector.detectPlatform()` and `detectChipGeneration()`
    - [ ] Create `Store()` and get `logDirectory`
    - [ ] Create `PowerLogService(directory:)`
    - [ ] Create `RotationManager()` and call `checkAndRotate(dailyService:)`
    - [ ] Create `IOKitAdapter()`, `PowerEstimator(platform:chipGeneration:)`
    - [ ] Create `CollectionTimer(interval:metrics:estimator:logService:uiUpdate:)`
    - [ ] Call `timer.start()`
    - [ ] Store timer reference in AppDelegate for lifecycle management

## C2: MenuBarWidgetView + MenuBarViewModel

- [ ] Create `MenuBarViewModel` in `UI/ViewModels/MenuBarViewModel.swift`:
  - [ ] `@MainActor final class MenuBarViewModel: ObservableObject`
  - [ ] `static let shared = MenuBarViewModel()`
  - [ ] `@Published var currentWatts: Double = 0`
  - [ ] `@Published var sparklineData: [Double] = []` (max 36 points)
  - [ ] `func update(with record: PowerRecord)`:
    - [ ] Set `currentWatts = record.watts`
    - [ ] Append to sparklineData, trim to 36 if needed

- [ ] Create `MenuBarWidgetView` in `UI/MenuBarWidgetView.swift`:
  - [ ] `@ObservedObject var viewModel = MenuBarViewModel.shared`
  - [ ] HStack layout: bolt icon + watts text + sparkline
  - [ ] Bolt icon: `Image(systemName: "bolt.fill")`, size 10
  - [ ] Watts text: `Text("\(viewModel.currentWatts, specifier: "%.0f")W")`
    - [ ] Font: system size 13, medium weight, monospaced design
  - [ ] Sparkline: `SparklineView(values: viewModel.sparklineData)`
    - [ ] Only show if sparklineData is not empty
    - [ ] Frame: 40×14
  - [ ] Empty state: when currentWatts == 0 and sparklineData is empty, show "n/a" instead of watts

## C3: PowerPopoverView + PopoverViewModel

- [ ] Create `PopoverViewModel` in `UI/ViewModels/PopoverViewModel.swift`:
  - [ ] `@MainActor final class PopoverViewModel: ObservableObject`
  - [ ] `static let shared = PopoverViewModel()`
  - [ ] `@Published var currentWatts: Double = 0`
  - [ ] `@Published var sessionAverage: Double = 0`
  - [ ] `@Published var sessionPeak: Double = 0`
  - [ ] `@Published var dailyAverages: [DailyAverage] = []`
  - [ ] `@Published var monthlyTotals: [MonthlyTotal] = []`
  - [ ] `var hasData: Bool` → true if dailyAverages or monthlyTotals is non-empty
  - [ ] `func setService(_ service: PowerLogServiceProtocol)`
  - [ ] `func refresh()`: read from service and update all @Published properties

- [ ] Create `PowerPopoverView` in `UI/PowerPopoverView.swift`:
  - [ ] `@ObservedObject var viewModel = PopoverViewModel.shared`
  - [ ] VStack(spacing: 16) with 4 sections separated by Dividers
  - [ ] Section 1 — Current watts:
    - [ ] Large text: `Text("\(viewModel.currentWatts, specifier: "%.0f")W")`
    - [ ] Font: system size 32, bold weight, monospaced
    - [ ] Subtext: HStack with "Avg: XW" and "Peak: YW"
    - [ ] Font: caption, secondary color
    - [ ] If !viewModel.hasData: show "Collecting data..." instead
  - [ ] Section 2 — 7-day chart:
    - [ ] Header: `Text("7-Day Power Consumption")` with .headline
    - [ ] `BarChartView(data: viewModel.dailyAverages)`
    - [ ] If empty: show "No data yet" in caption
  - [ ] Section 3 — Monthly totals:
    - [ ] Header: `Text("Monthly Totals")` with .headline
    - [ ] `MonthlyTotalsView(totals: viewModel.monthlyTotals)`
    - [ ] If empty: show "No data yet" in caption
  - [ ] Section 4 — Settings button:
    - [ ] `Button("⚙ Settings")` action:
      - [ ] `NSApp.activate(ignoringOtherApps: true)`
      - [ ] Post `.openSettings` notification to open settings window
  - [ ] Frame: 320 width, padding all around
  - [ ] `.onAppear`: call `viewModel.refresh()`

## C4: SettingsWindowView

- [ ] Create `SettingsWindowView` in `UI/SettingsWindowView.swift`:
  - [ ] `@ObservedObject var store = Store()`
  - [ ] `@State private var showFilePicker = false`
  - [ ] `@State private var showClearConfirmation = false`
  - [ ] VStack(spacing: 20) layout, frame 420×340

- [ ] Section 1 — Collection Interval:
  - [ ] `Form` container with `Picker("Collection Interval", selection: $store.collectionInterval)`
  - [ ] Options: "Every 10 seconds" (tag 10), "Every minute" (tag 60)
  - [ ] `.pickerStyle(.radioGroup)`

- [ ] Section 2 — Log Directory:
  - [ ] Header: `Text("Log Directory")` with .headline
  - [ ] HStack with path text (caption, secondary, lineLimit 1) and "Change..." button
  - [ ] `.fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.folder])`
  - [ ] On selection: `store.logDirectory = url`

- [ ] Section 3 — Auto-Launch:
  - [ ] Header: `Text("Launch at Login")` with .headline
  - [ ] `Toggle("Automatically launch at login", isOn: $store.autoLaunchAtLogin)`

- [ ] Section 4 — Data Management:
  - [ ] Header: `Text("Data Management")` with .headline
  - [ ] `Button("Clear All Logs", role: .destructive)` with `.alert` confirmation
  - [ ] Alert message: "This will delete all daily and monthly power consumption data. This action cannot be undone."
  - [ ] On confirm: post `.clearAllLogs` notification

- [ ] Notification handling in App entry point:
  - [ ] Observe `.clearAllLogs` → call `powerLogService.clearAll()`
  - [ ] Observe `.openSettings` → activate settings window

## C5: Charts

- [ ] Create `SparklineView` in `UI/Charts/SparklineView.swift`:
  - [ ] Input: `let values: [Double]` (~36 points)
  - [ ] Compute max, min, range from values (min 1.0 range to avoid divide-by-zero)
  - [ ] Build `Path` with normalized coordinates:
    - [ ] x = index / (count - 1)
    - [ ] y = 1.0 - normalizedY
  - [ ] `.stroke(Color.primary, lineWidth: 1)`

- [ ] Create `BarChartView` in `UI/Charts/BarChartView.swift`:
  - [ ] Input: `let data: [DailyAverage]` (7 points)
  - [ ] HStack with 4px spacing
  - [ ] For each index: VStack with Capsule bar + day label
  - [ ] Capsule height: `CGFloat(data[index].averageWatts) * scale`
  - [ ] Day label: abbreviated day name, caption2 font, secondary color
  - [ ] Frame: 80px height for the bar column

- [ ] Create `MonthlyTotalsView` in `UI/Charts/MonthlyTotalsView.swift`:
  - [ ] Input: `let totals: [MonthlyTotal]` (up to 12 points)
  - [ ] VStack with 2px spacing, leading alignment
  - [ ] For each total (reversed order): HStack with month label + bar + kWh text
  - [ ] Month label: 40px width, leading alignment
  - [ ] Bar: Rectangle, green fill, height 14px, width proportional to totalKWh
  - [ ] kWh text: caption font, secondary color, 60px width, trailing alignment

## C6: AppDelegate

- [ ] Create `AppDelegate.swift`:
  - [ ] `NSApplicationDelegate` conformance
  - [ ] `var collectionTimer: CollectionTimer?` property
  - [ ] `applicationWillTerminate(_:)`: call `collectionTimer?.stop()`
  - [ ] Handle `.clearAllLogs` notification: call `powerLogService.clearAll()`
  - [ ] Handle `.openSettings` notification: order front settings window

## Dependencies Between Subtasks

```
C2 (MenuBarWidget) → C5 (SparklineView)
C3 (Popover) → C5 (BarChartView, MonthlyTotalsView)
C4 (Settings) → B4 (Store) for settings persistence
C1 (App Entry) → C2, C3, C4, C6 all wired together
C6 (AppDelegate) → C1 stores timer reference
```
