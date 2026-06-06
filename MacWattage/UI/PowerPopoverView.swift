import SwiftUI

struct PowerPopoverView: View {
    @ObservedObject var viewModel = PopoverViewModel.shared

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
        .onAppear { viewModel.refresh() } // Reload aggregated data when popover opens.
    }

    // MARK: - Sections

    private var currentWattsSection: some View {
        VStack(spacing: 4) {
            if viewModel.hasData {
                Text("\(viewModel.currentWatts, specifier: "%.0f")W")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)

                Text("Avg: \(viewModel.sessionAverage, specifier: "%.0f")W · Peak: \(viewModel.sessionPeak, specifier: "%.0f")W")
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

            if viewModel.sparklineData.count < 2 {
                Text("Collecting data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                SparklineView(values: viewModel.sparklineData)
                    .frame(height: 60)
            }
        }
    }

    private var sevenDayChartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("7-Day Power Consumption")
                .font(.headline)

            if viewModel.dailyAverages.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                BarChartView(data: viewModel.dailyAverages)
                    .frame(height: 80)
            }
        }
    }

    private var monthlyTotalsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monthly Totals")
                .font(.headline)

            if viewModel.monthlyTotals.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                MonthlyTotalsView(totals: viewModel.monthlyTotals)
                    .frame(maxHeight: 168) // ~12 rows × (14px + 2px spacing).
            }
        }
    }

    private var settingsButton: some View {
        Button("Settings") {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: PowerPopoverView.openSettings, object: nil) // Signal to the app delegate that settings should open.
        }
    }

    // MARK: - Notification names

    static let openSettings = Notification.Name("openSettings")
}
