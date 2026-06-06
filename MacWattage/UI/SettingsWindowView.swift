import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var store = Store()

    @State private var showFilePicker: Bool = false
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            collectionIntervalSection

            Divider()

            logDirectorySection

            Divider()

            autoLaunchSection

            Divider()

            dataManagementSection
        }
        .frame(width: 420, height: 340) // Fixed window size for the settings panel.
    }

    // MARK: - Sections

    private var collectionIntervalSection: some View {
        Form {
            Picker("Collection Interval", selection: $store.collectionInterval) {
                Text("Every second").tag(1)
                Text("Every 10 seconds").tag(10)
                Text("Every minute").tag(60)
            }
            .pickerStyle(.radioGroup) // Show as a vertical group rather than segmented control.
        }
    }

    private var logDirectorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log Directory")
                .font(.headline)

            HStack {
                Text(store.logDirectory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button("Change...") { showFilePicker = true }
            }
        }
        .fileImporter( // macOS 13+ file picker restricted to folder selection.
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                store.logDirectoryPath = url.absoluteString // Persist the chosen path for next launch.
            case .failure:
                break // User cancelled or error — ignore silently.
            }
        }
    }

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
