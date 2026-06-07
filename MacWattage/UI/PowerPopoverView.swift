import SwiftUI

struct PowerPopoverView: View {
    // @State guarantees re-renders — @ObservedObject is unreliable inside MenuBarExtra content views.
    @State private var currentWatts: Double = 0
    @State private var sessionAverage: Double = 0
    @State private var sessionPeak: Double = 0
    @State private var dailyAverages: [DailyAverage] = []
    @State private var monthlyTotals: [MonthlyTotal] = []
    @State private var sparklineData: [Double] = []

    private var hasData: Bool { !dailyAverages.isEmpty || !monthlyTotals.isEmpty }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            currentWattsSection
            liveChartSection
            Divider()
            sevenDayChartSection
            Divider()
            monthlyTotalsSection
            Divider()
            settingsButton
        }
        .frame(width: 320)
        .padding()
        .onAppear { sync() }
        .onReceive(timer) { _ in sync() }
    }

    // MARK: - Sections

    private var currentWattsSection: some View {
        VStack(spacing: 4) {
            if hasData {
                Text("\(currentWatts, specifier: "%.0f")W")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)

                Text("Avg: \(sessionAverage, specifier: "%.1f")W · Peak: \(sessionPeak, specifier: "%.1f")W")
                    .foregroundColor(.black)
                    .font(.caption)
            } else {
                Text("Collecting data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var liveChartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Live Power")
                .font(.headline)

            if sparklineData.count < 2 {
                Text("Collecting data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                SparklineView(values: sparklineData)
                    .frame(height: 60)
            }
        }
    }

    private var sevenDayChartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("7-Day Power Consumption")
                .font(.headline)

            if dailyAverages.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                BarChartView(data: dailyAverages)
                    .frame(height: 100)
            }
        }
    }

    private var monthlyTotalsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monthly Totals")
                .font(.headline)

            if monthlyTotals.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                MonthlyTotalsView(totals: monthlyTotals)
                    .frame(maxHeight: 168) // ~12 rows × (14px + 2px spacing).
            }
        }
    }

    private var settingsButton: some View {
        Button("Settings") {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: PowerPopoverView.openSettings, object: nil)
        }
    }

    // MARK: - Data sync

    private func sync() {
        let vm = PopoverViewModel.shared
        vm.refresh()
        currentWatts = vm.currentWatts
        sessionAverage = vm.sessionAverage
        sessionPeak = vm.sessionPeak
        dailyAverages = vm.dailyAverages
        monthlyTotals = vm.monthlyTotals
        sparklineData = vm.sparklineData
    }

    // MARK: - Notification names

    static let openSettings = Notification.Name("openSettings")
}
