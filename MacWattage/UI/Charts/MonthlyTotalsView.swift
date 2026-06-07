import SwiftUI

/// Horizontal bar list showing monthly total energy consumption in kWh.
/// Shows the two most recent months by default; "View more" expands to all months.
struct MonthlyTotalsView: View {
    let totals: [MonthlyTotal]

    @State private var expanded = false

    /// Newest month first.
    private var ordered: [MonthlyTotal] { totals.reversed() }

    /// Months currently visible — two most recent unless expanded.
    private var visible: [MonthlyTotal] {
        expanded ? ordered : Array(ordered.prefix(2))
    }

    /// Maximum kWh among visible rows, for proportional bar scaling.
    private var maxKWh: Double {
        visible.map(\.totalKWh).max() ?? 1.0
    }

    var body: some View {
        if totals.isEmpty || (totals.map(\.totalKWh).max() ?? 0) <= 0 {
            Text("No data yet")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(visible, id: \.id) { total in
                    HStack(spacing: 6) {
                        Text(monthLabel(forMonth: total.yearMonth))
                            .font(.caption)
                            .frame(width: 64, alignment: .leading)

                        // Bar width proportional to totalKWh relative to max, capped so the
                        // row (label + bar + value) stays within the ~288px popover content width.
                        Rectangle()
                            .fill(Color.green)
                            .frame(
                                width: max(4, CGFloat(total.totalKWh / max(maxKWh, 0.1)) * 110),
                                height: 14
                            )

                        Spacer(minLength: 4)

                        Text(String(format: "%.1f kWh", total.totalKWh))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                }

                if ordered.count > 2 {
                    Button(expanded ? "View less" : "View more") {
                        expanded.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
                }
            }
        }
    }

    private func monthLabel(forMonth yearMonth: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: yearMonth) else { return yearMonth }

        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}
