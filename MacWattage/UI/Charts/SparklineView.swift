import SwiftUI

/// A compact sparkline chart for displaying a series of power values.
struct SparklineView: View {
    let values: [Double]

    var body: some View {
        Group {
            if values.isEmpty || values.count < 2 {
                EmptyView()
            } else {
                Path { path in
                    let count = values.count

                    // Use a minimum range of 1.0 to prevent extreme scaling
                    // when all values are nearly identical (avoids divide-by-zero).
                    let maxVal = values.max() ?? 0.0
                    let minVal = values.min() ?? 0.0
                    let range = max(maxVal - minVal, 1.0)

                    for (index, value) in values.enumerated() {
                        // Normalize x across [0, 1] then scale to chart width (40px).
                        let x = Double(index) / Double(count - 1) * 40.0
                        // Normalize y across [0, 1] then invert (SwiftUI Y goes down)
                        // and scale to chart height (14px).
                        let y = 1.0 - (value - minVal) / range * 14.0

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.primary, lineWidth: 1)
            }
        }
    }
}
