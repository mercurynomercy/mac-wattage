import SwiftUI

/// A compact area sparkline chart for displaying a series of power values.
/// Uses SwiftUI `Path` shapes (not `Canvas`) — `Canvas` fails to render inside MenuBarExtra popovers.
struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Filled area gradient.
            areaPath(w: w, h: h)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.45), .blue.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Stroke line on top.
            linePath(w: w, h: h)
                .stroke(Color.blue, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func yFor(_ v: Double, h: Double) -> Double {
        let maxVal = values.max() ?? 0
        let minVal = values.min() ?? 0
        let range = maxVal - minVal
        let norm: Double = range > 0 ? (v - minVal) / range : 0.5
        return (1.0 - max(0, min(norm, 1))) * h
    }

    private func point(_ i: Int, _ v: Double, w: Double, h: Double) -> CGPoint {
        let count = values.count
        let x = count > 1 ? Double(i) / Double(count - 1) * w : 0
        return CGPoint(x: x, y: yFor(v, h: h))
    }

    private func linePath(w: Double, h: Double) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        for (i, v) in values.enumerated() {
            let pt = point(i, v, w: w, h: h)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    private func areaPath(w: Double, h: Double) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        path.move(to: CGPoint(x: 0, y: h))
        for (i, v) in values.enumerated() {
            path.addLine(to: point(i, v, w: w, h: h))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}
