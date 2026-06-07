import SwiftUI

struct MenuBarWidgetView: View {
    @ObservedObject var viewModel = MenuBarViewModel.shared

    var body: some View {
        if viewModel.sparklineData.isEmpty {
            Text("--W")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        } else {
            Text("\(viewModel.currentWatts, specifier: "%.0f")W")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
    }
}

#Preview { MenuBarWidgetView() }
