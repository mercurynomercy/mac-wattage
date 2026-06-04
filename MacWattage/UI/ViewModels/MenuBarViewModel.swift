import SwiftUI

/// ViewModel for the menu bar extra — exposes current watts and a sparkline buffer.
@MainActor final class MenuBarViewModel: ObservableObject {

    static let shared = MenuBarViewModel()

    /// Most recent power reading in watts.
    @Published var currentWatts: Double = 0

    /// Sparkline data points, maximum of 36 values.
    @Published var sparklineData: [Double] = []

    private init() {}

    /// Update with a new power record. Sets current watts and appends to sparkline buffer (max 36 points).
    func update(with record: PowerRecord) {
        currentWatts = record.watts
        sparklineData.append(record.watts)
        if sparklineData.count > 36 {
            sparklineData = Array(sparklineData.suffix(36))
        }
    }

    /// Reset all state. Called when data is cleared.
    func reset() {
        currentWatts = 0
        sparklineData.removeAll(keepingCapacity: true)
    }
}
