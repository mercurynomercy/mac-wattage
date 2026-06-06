import Combine
import SwiftUI

/// ViewModel for the popover dashboard — aggregates session stats and chart data from PowerLogService.
@MainActor final class PopoverViewModel: ObservableObject {

    static let shared = PopoverViewModel()

    /// Most recent power reading in watts.
    var currentWatts: Double = 0

    /// Average watts over the last 1-hour rolling window.
    var sessionAverage: Double = 0

    /// Peak (max) watts over the last 1-hour window.
    var sessionPeak: Double = 0

    /// Daily average watts for the last 7 days.
    var dailyAverages: [DailyAverage] = []

    /// Monthly total kWh for the last 12 months.
    var monthlyTotals: [MonthlyTotal] = []

    /// Sparkline data points for live chart, maximum of 36 values.
    var sparklineData: [Double] = []

    /// Whether there is meaningful data to display beyond zero values.
    var hasData: Bool { !dailyAverages.isEmpty || !monthlyTotals.isEmpty }

    /// Publisher that fires whenever data is refreshed — used by SwiftUI views to force re-render.
    var onDataUpdate: AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: Notification.Name("PopoverDataUpdated"))
            .map { _ in () }
            .eraseToAnyPublisher()
    }

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
        NotificationCenter.default.post(name: Notification.Name("PopoverDataUpdated"), object: nil)
    }

    /// Append a new reading to the sparkline buffer (max 36 points).
    func updateSparkline(with record: PowerRecord) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sparklineData.append(record.watts)
            if self.sparklineData.count > 36 {
                self.sparklineData = Array(self.sparklineData.suffix(36))
            }
            NotificationCenter.default.post(name: Notification.Name("PopoverDataUpdated"), object: nil)
        }
    }

    /// Update the current watts reading.
    func updateCurrentWatts(_ watts: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentWatts = watts
            NotificationCenter.default.post(name: Notification.Name("PopoverDataUpdated"), object: nil)
        }
    }

    /// Reset all state. Called when data is cleared via notification.
    func reset() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentWatts = 0
            self.sessionAverage = 0
            self.sessionPeak = 0
            self.dailyAverages.removeAll()
            self.monthlyTotals.removeAll()
            self.sparklineData.removeAll(keepingCapacity: true)
            NotificationCenter.default.post(name: Notification.Name("PopoverDataUpdated"), object: nil)
        }
    }

    private var service: PowerLogServiceProtocol? = nil
}
