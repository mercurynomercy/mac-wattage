import Combine
import SwiftUI

/// ViewModel for the popover dashboard — aggregates session stats and chart data from PowerLogService.
@MainActor final class PopoverViewModel: ObservableObject {

    static let shared = PopoverViewModel()

    /// Most recent power reading in watts.
    @Published var currentWatts: Double = 0

    /// Average watts over the last 1-hour rolling window.
    @Published var sessionAverage: Double = 0

    /// Peak (max) watts over the last 1-hour window.
    @Published var sessionPeak: Double = 0

    /// Daily average watts for the last 7 days.
    @Published var dailyAverages: [DailyAverage] = []

    /// Monthly total kWh for the last 12 months.
    @Published var monthlyTotals: [MonthlyTotal] = []

    /// Sparkline data points for live chart, maximum of 36 values.
    @Published var sparklineData: [Double] = []

    /// Static device label (chip + RAM), e.g. "M4 Max · 128GB". Set once at startup.
    var deviceLabel: String = ""

    /// Whether there is meaningful data to display beyond zero values.
    var hasData: Bool { !dailyAverages.isEmpty || !monthlyTotals.isEmpty }

    private init() {}

    /// Inject the power log service for data reads. Called once at app startup.
    func setService(_ service: PowerLogServiceProtocol) {
        self.service = service
    }

    /// Refresh all properties from the log service. Called on popover appear and periodically.
    func refresh() {
        guard let service = self.service else {
            #if DEBUG
            NSLog("[PopoverViewModel] refresh() SKIPPED — no service set")
            #endif
            return
        }

        currentWatts = service.currentWatts()
        sessionAverage = service.sessionAverage()
        sessionPeak = service.sessionPeak()
        dailyAverages = service.dailyAverages(for: 7)
        monthlyTotals = service.monthlyTotals(for: 12)
        // Seed sparklineData from the live buffer only when it would add more data than we
        // already have — prevents a post-flush secondsBuffer (1–2 items) from overwriting
        // the 36-item history that updateSparkline accumulated.
        let fresh = service.sparklineWatts(count: 36)
        if fresh.count > sparklineData.count { sparklineData = fresh }
    }

    /// Append a new reading to the sparkline buffer (max 36 points).
    func updateSparkline(with record: PowerRecord) {
        sparklineData.append(record.watts)
        if sparklineData.count > 36 {
            sparklineData = Array(sparklineData.suffix(36))
        }
    }

    /// Update the current watts reading.
    func updateCurrentWatts(_ watts: Double) {
        currentWatts = watts
    }

    /// Reset all state. Called when data is cleared via notification.
    func reset() {
        currentWatts = 0
        sessionAverage = 0
        sessionPeak = 0
        dailyAverages.removeAll()
        monthlyTotals.removeAll()
        sparklineData.removeAll(keepingCapacity: true)
    }

    private var service: PowerLogServiceProtocol? = nil
}
