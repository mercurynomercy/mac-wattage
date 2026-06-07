import SwiftUI

/// Horizontal bar list showing monthly total energy consumption in kWh.
struct MonthlyTotalsView: View {
    let totals: [MonthlyTotal]

    /// Maximum kWh value for proportional bar scaling.
    private var maxKWh: Double {
        totals.map(\.totalKWh).max() ?? 1.0
    }

    var body: some View {
        if totals.isEmpty || maxKWh <= 0 {
            Text("No data yet")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(totals.reversed()), id: \.id) { total in
                    HStack(spacing: 6) {
                        Text(monthLabel(forMonth: total.yearMonth))
                            .font(.caption)
                            .frame(width: 36, alignment: .leading)

                        // Bar width proportional to totalKWh relative to max, capped so the
                        // row (label + bar + value) stays within the ~288px popover content width.
                        Rectangle()
                            .fill(Color.green)
                            .frame(
                                width: max(4, CGFloat(total.totalKWh / max(maxKWh, 0.1)) * 130),
                                height: 14
                            )

                        Spacer(minLength: 4)

                        Text(String(format: "%.1f kWh", total.totalKWh))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                }
            }
        }
    }

    private func monthLabel(forMonth yearMonth: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: yearMonth) else { return yearMonth }

        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}
