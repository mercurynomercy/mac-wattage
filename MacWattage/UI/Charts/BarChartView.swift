import SwiftUI

/// Horizontal bar chart showing daily average power consumption.
struct BarChartView: View {
    let data: [DailyAverage]

    var body: some View {
        if data.isEmpty {
            Text("No data yet")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            // Scale bars by kWh so the maximum value fills ~60px height (leaving room for labels).
            let maxKWh = data.map(\.totalKWh).max() ?? 0.1
            let scale = CGFloat(60.0 / max(maxKWh, 0.001))

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data.indices, id: \.self) { index in
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", data[index].totalKWh))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)

                        Capsule()
                            .fill(Color.green)
                            .frame(
                                width: 14,
                                height: max(CGFloat(data[index].totalKWh) * scale, 2)
                            )

                        Text(dayLabel(for: data[index].date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
