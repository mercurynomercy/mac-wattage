import SwiftUI

struct PowerPopoverView: View {
    // @State guarantees re-renders — @ObservedObject is unreliable inside MenuBarExtra content views.
    @State private var currentWatts: Double = 0
    @State private var sessionAverage: Double = 0
    @State private var sessionPeak: Double = 0
    @State private var dailyAverages: [DailyAverage] = []
    @State private var monthlyTotals: [MonthlyTotal] = []
    @State private var sparklineData: [Double] = []
    @State private var deviceLabel: String = ""

    private var hasData: Bool { !dailyAverages.isEmpty || !monthlyTotals.isEmpty }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            topBar

            currentWattsSection
            liveChartSection
            Divider()
            sevenDayChartSection
            Divider()
            monthlyTotalsSection
        }
        .frame(width: 320)
        .padding()
        .onAppear { sync() }
        .onReceive(timer) { _ in sync() }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            settingsButton  // gear icon, top-left

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .help("Quit")
        }
    }

    private var currentWattsSection: some View {
        VStack(spacing: 2) {
            if hasData {
                Text("\(currentWatts, specifier: "%.0f")W")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            } else {
                Text("Collecting data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !deviceLabel.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "apple.logo")
                    Text(deviceLabel)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if hasData {
                Text("Avg: \(sessionAverage, specifier: "%.1f")W · Peak: \(sessionPeak, specifier: "%.1f")W")
                    .foregroundColor(.primary)
                    .font(.caption)
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
            Text("7-Day Power Consumption (kWh)")
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
            }
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        // macOS 14+ requires SettingsLink to open the Settings scene; the old
        // showSettingsWindow: selector now throws. macOS 13 falls back to the selector.
        let icon = Image(systemName: "gearshape.fill")
        Group {
            if #available(macOS 14, *) {
                SettingsLink { icon }
            } else {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                } label: { icon }
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .help("Settings")
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
        deviceLabel = vm.deviceLabel
    }
}
