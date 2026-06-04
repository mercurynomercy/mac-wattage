import SwiftUI

struct MenuBarWidgetView: View {
    @ObservedObject var viewModel = MenuBarViewModel.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .resizable()
                .frame(width: 10, height: 10)

            if viewModel.sparklineData.isEmpty {
                Text("n/a")
                    .font(.system(size: 13, design: .monospaced))
            } else {
                Text("\(viewModel.currentWatts, specifier: "%.0f")W")
                    .font(.system(size: 13, design: .monospaced))

                SparklineView(values: viewModel.sparklineData)
                    .frame(width: 40, height: 14)
            }
        }
    }
}

#Preview { MenuBarWidgetView() }
