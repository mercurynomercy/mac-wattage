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
            // Scale bars so the maximum value fills ~80px height.
            let maxWatts = data.map(\.averageWatts).max() ?? 1.0
            let scale = max(maxWatts, 0.1) > 0 ? CGFloat(80.0 / max(maxWatts, 0.1)) : 0

            HStack(spacing: 4) {
                ForEach(data.indices, id: \.self) { index in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(Color.primary)
                            .frame(
                                width: 16,
                                height: max(CGFloat(data[index].averageWatts) * scale, 2)
                            )

                        Text(dayLabel(for: data[index].date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
