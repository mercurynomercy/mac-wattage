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

                    // Use percentage-based scaling so small variations (e.g. 22–23W)
                    // remain visually meaningful even when absolute differences are tiny.
                    let maxVal = values.max() ?? 0.0
                    let minVal = values.min() ?? 0.0

                    for (index, value) in values.enumerated() {
                        // Normalize x across [0, 1] then scale to chart width (40px).
                        let x = Double(index) / Double(count - 1) * 40.0
                        // Normalize y using percentage of actual range, inverted (SwiftUI Y goes down),
                        // and scaled to chart height (~20px). Clamp to [0, 1] so identical values
                        // still render at the midpoint rather than clipping to an edge.
                        let actualRange = maxVal - minVal
                        let normalizedY: Double = actualRange > 0 ? (value - minVal) / actualRange : 0.5
                        let clampedY = max(0.0, min(normalizedY, 1.0))
                        let y = (1.0 - clampedY) * 20.0

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.black, lineWidth: 1.5)
            }
        }
    }
}
