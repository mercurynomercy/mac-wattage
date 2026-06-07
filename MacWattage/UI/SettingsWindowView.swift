import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var store = Store()

    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            autoLaunchSection

            Divider()

            dataManagementSection
        }
        .frame(width: 420, height: 180) // Fixed window size for the settings panel.
    }

    // MARK: - Sections

    private var autoLaunchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Launch at Login")
                .font(.headline)

            Toggle("Automatically launch at login", isOn: $store.autoLaunchAtLogin)
        }
    }

    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Management")
                .font(.headline)

            Button("Clear All Logs", role: .destructive) {
                showClearConfirmation = true // Ask for confirmation before deleting all stored data.
            }
        }
        .alert("Confirm Clear All Logs", isPresented: $showClearConfirmation) {
            Button("Delete Everything", role: .destructive) {
                NotificationCenter.default.post(name: SettingsWindowView.clearAllLogs, object: nil) // Signal the data layer to purge logs.
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all daily and monthly power consumption data. This action cannot be undone.")
        }
    }

    // MARK: - Notification names

    static let clearAllLogs = Notification.Name("clearAllLogs")
}
