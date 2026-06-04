import SwiftUI

/// Manages app lifecycle and notification handling for the menu bar extra.
public final class AppDelegate: NSObject, NSApplicationDelegate {

    /// The collection timer — stopped on app termination.
    public var collectionTimer: CollectionTimer?

    /// The power log service — used for clear-all operations.
    public var powerLogService: PowerLogServiceProtocol?

    // MARK: - NSApplicationDelegate lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearAllLogs),
            name: SettingsWindowView.clearAllLogs,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: PowerPopoverView.openSettings,
            object: nil
        )
    }

    /// Stop the collection timer when app is about to terminate.
    public func applicationWillTerminate(_ notification: Notification) {
        collectionTimer?.stop()
    }

    /// Keep running after last window closes — this is a menu bar extra, not a windowed app.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Notification handlers (called via @objc selectors)

    @objc private func handleClearAllLogs() {
        // Clear data in background, then reset UI on main thread.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let service = self?.powerLogService else { return }

            do { try await service.clearAll() } catch {}

            // Reset UI components on main thread.
            await MainActor.run { self?.resetUI() }
        }
    }

    @objc private func handleOpenSettings() {
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor private func resetUI() {
        MenuBarViewModel.shared.reset()
        PopoverViewModel.shared.reset()
    }

}
