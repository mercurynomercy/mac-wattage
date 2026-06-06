import SwiftUI

@main
struct MacWattageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// The collection timer — started in init, stopped by AppDelegate on termination.
    private var collectionTimer: CollectionTimer?

    /// The flush timer — fires every 60s to aggregate secondsBuffer into daily-log.
    private var flushTimer: Timer?

    /// The power log service — shared across the app.
    private var logService: PowerLogServiceProtocol?

    init() {
        let result = setupApp()
        self.collectionTimer = result.timer
        self.flushTimer = result.flushTimer
        self.logService = result.service

        // Store references for AppDelegate lifecycle management (termination, notifications).
        appDelegate.collectionTimer = result.timer
        appDelegate.flushTimer = result.flushTimer

        appDelegate.powerLogService = result.service

        // Seed initial session stats on the popover view model.
        PopoverViewModel.shared.sessionAverage = result.service.sessionAverage()
        PopoverViewModel.shared.sessionPeak = result.service.sessionPeak()

        // Seed initial data on view models (in case there's existing data in memory buffers).
        MenuBarViewModel.shared.currentWatts = result.service.currentWatts()
    }

    private func setupApp() -> (timer: CollectionTimer, flushTimer: Timer?, service: PowerLogServiceProtocol) {
        // 1. Detect full hardware profile (platform, chip, RAM, fan model, screen state).
        let hwProfile = PlatformDetector.detectHardwareProfile()

        // 2. Create app store (reads/writes UserDefaults).
        let store = Store()

        // 3. Create power log service (manages daily + monthly data files).
        let svc = PowerLogService(directory: store.logDirectory)

        // 4. Check and perform monthly data rotation if needed (non-blocking, runs on a Task).
        let rotationManager = RotationManager(userDefaults: nil)
        rotationManager.checkAndRotate(dailyService: svc)

        // 5. Create metrics pipeline (hardware reads → power estimation).
        let adapter = IOKitAdapter()

        // Create estimator with full hardware profile for accurate TDP-based estimation.
        let estimator = PowerEstimator(profile: hwProfile)

        // 6. Wire up UI update callback to shared view models.
        let menuBarVM = MenuBarViewModel.shared
        let popoverVM = PopoverViewModel.shared

        // 7. Create and start collection timer (fires immediately, then at interval).
        let timer = CollectionTimer(
            interval: store.collectionInterval,
            metrics: adapter,
            estimator: estimator,
            logService: svc,
            uiUpdate: { record in
                #if DEBUG
                NSLog("[UI callback] watts=\(record.watts) popoverSparklineCount=\(popoverVM.sparklineData.count)")
                #endif
                menuBarVM.update(with: record)
                popoverVM.updateCurrentWatts(record.watts)
                popoverVM.updateSparkline(with: record)
            }
        )

        timer.start()

        // 8. Create flush timer — fires every 60s to aggregate secondsBuffer into daily-log.
        let flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [unowned svc] _ in
            Task.detached(priority: .utility) {
                do { try await svc.flushSecondsBuffer() } catch {}
            }
        }

        // Wire up popover ViewModel to service for refresh operations.
        #if DEBUG
        NSLog("[App] Wired up popover VM, service log dir: \(store.logDirectory.path)")
        #endif
        popoverVM.setService(svc)

        return (timer, flushTimer, svc)
    }

    var body: some Scene {
        MenuBarExtra {
            PowerPopoverView()
        } label: {
            MenuBarWidgetView()
        }

        Settings {
            SettingsWindowView()
        }
    }
}
