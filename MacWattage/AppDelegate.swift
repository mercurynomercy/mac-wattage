import SwiftUI

/// Manages app lifecycle and notification handling for the menu bar extra.
public final class AppDelegate: NSObject, NSApplicationDelegate {

    /// The collection timer — stopped on app termination.
    public var collectionTimer: CollectionTimer?

    /// The flush timer — stopped on app termination.
    public var flushTimer: Timer?

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
    }

    /// Stop the timers when app is about to terminate.
    public func applicationWillTerminate(_ notification: Notification) {
        collectionTimer?.stop()
        flushTimer?.invalidate()
    }

    /// Keep running after last window closes — this is a menu bar extra, not a windowed app.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Notification handlers (called via @objc selectors)

    @objc private func handleClearAllLogs() {
        // Capture service before detached task (must be Sendable).
        guard let service = self.powerLogService else { return }

        // Clear data in background, then reset UI on main thread.
        Task.detached(priority: .userInitiated) { [unowned self] in
            do { try await service.clearAll() } catch {}

            // Reset UI components on main thread.
            await MainActor.run { self.resetUI() }
        }
    }

    @MainActor private func resetUI() {
        MenuBarViewModel.shared.reset()
        PopoverViewModel.shared.reset()
    }

}
