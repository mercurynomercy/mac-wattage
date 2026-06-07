import Foundation

/// Repeating timer that collects hardware metrics, estimates power consumption, and logs the result.
/// Thread-safe: metric reads happen on a background queue; UI updates are dispatched to the main thread.
public final class CollectionTimer {

    private var timer: Timer?
    /// Serial background queue for hardware metric reads — keeps IOKit calls off the main thread.
    private let collectQueue: DispatchQueue

    /// Collection interval in seconds (read from settings).
    private let interval: Int
    /// Hardware metrics reader — CPU/GPU utilization and battery state.
    private let metrics: IOKitAdapterProtocol
    /// TDP-based power estimator — translates utilization fractions to watts.
    private let estimator: PowerEstimatorProtocol
    /// Measured SoC power source (IOReport). nil → always fall back to the estimate.
    private let powerReader: SoCPowerReaderProtocol?
    /// Persistent log service — writes records to disk.
    private let logService: PowerLogServiceProtocol

    /// UI update callback, invoked on the main thread with each new record.
    private let uiUpdate: @MainActor (PowerRecord) -> Void

    /// Weak-reference wrapper so the timer selector can reach this instance without a retain cycle.
    private class TimerTarget: NSObject {
        weak var owner: CollectionTimer?

        @objc func collect() { owner?.doCollect() }
    }

    private var timerTarget: TimerTarget?

    // MARK: - Init / Lifecycle

    public init(
        interval: Int,
        metrics: IOKitAdapterProtocol,
        estimator: PowerEstimatorProtocol,
        powerReader: SoCPowerReaderProtocol?,
        logService: PowerLogServiceProtocol,
        uiUpdate: @escaping @MainActor (PowerRecord) -> Void
    ) {
        self.interval = interval
        self.metrics = metrics
        self.estimator = estimator
        self.powerReader = powerReader
        self.logService = logService
        self.uiUpdate = uiUpdate

        // Serial queue for metric reads — ordered, non-concurrent IOKit calls.
        self.collectQueue = DispatchQueue(
            label: "com.macwattage.scheduler.collect", qos: .userInitiated)

        self.timerTarget = TimerTarget()
    }

    /// Start collection: read immediately, then repeat at the configured interval.
    public func start() {
        // Collect right away so there's no gap before the first data point.
        collect()

        timerTarget?.owner = self

        // Timer fires on the main run loop; work is dispatched to collectQueue.
        // Uses timerTarget (not self) as target to avoid a retain cycle.
        timer = Timer.scheduledTimer(
            timeInterval: Double(interval), target: timerTarget!, selector: #selector(TimerTarget.collect), userInfo: nil, repeats: true)

        NSLog("[CollectionTimer] Timer started with interval=%ds, timer=%@", interval, String(describing: timer))
    }

    /// Stop collection and invalidate the timer. The instance can be restarted with `start()`.
    public func stop() {
        timer?.invalidate()
        timer = nil
        timerTarget?.owner = nil
    }

    // MARK: - Collection

    private func doCollect() {
        NSLog("[CollectionTimer] doCollect firing")
        collectQueue.async { [weak self] in
            guard let self else { return }

            // Read hardware metrics (non-blocking — returns 0.0 on failure).
            let cpuUtil = self.metrics.cpuUtilization()
            let gpuUtil = self.metrics.gpuUtilization()

            // Prefer measured SoC power (IOReport) + modeled non-SoC offset for whole-system
            // wall power; fall back to the pure TDP estimate when no measurement is available.
            let watts: Double
            if let socWatts = self.powerReader?.socPowerWatts() {
                watts = self.estimator.wholeSystemPower(socWatts: socWatts, cpuUtil: cpuUtil, gpuUtil: gpuUtil)
            } else {
                watts = self.estimator.estimateSystemPower(from: cpuUtil, gpuUtil: gpuUtil)
            }

            // Charging state is nil for desktop Macs without batteries.
            let isCharging = self.metrics.isCharging()

            // Build the record — id and timestamp are auto-generated defaults.
            let record = PowerRecord(watts: watts, isCharging: isCharging)

            // Feed the in-memory live buffer only. The 60s flush timer aggregates these
            // per-second samples into one daily-log record per minute — writing every
            // sample to disk here would inflate kWh ~60x and rewrite the whole log each second.
            Task { await self.logService.recordSample(record) }

            // Push to UI on the main thread.
            DispatchQueue.main.async { [uiUpdate] in
                uiUpdate(record)
            }
        }
    }

    // MARK: - Internal for testing / direct invocation (called by timer)

    /// Dispatch a single collection cycle to the background queue.
    private func collect() { doCollect() }
}
