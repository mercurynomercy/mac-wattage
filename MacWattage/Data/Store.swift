import Foundation

/// Lightweight UserDefaults protocol for dependency injection. Extends the real UserDefaults to conform.
public protocol UserDefaultsProtocol: AnyObject {
    func integer(forKey key: String, defaultValue: Int) -> Int
    var boolForKey: (String) -> Bool { get }
    func string(forKey key: String) -> String?
    func setAny(_ value: Any?, forKey key: String)  // Avoids collision with Foundation's native set methods
    func object(forKey key: String) -> Any?
}

/// Extension makes real UserDefaults conform to our protocol.
extension UserDefaults: UserDefaultsProtocol {

    /// Convenience wrapper with default value for integer retrieval.
    public func integer(forKey key: String, defaultValue: Int) -> Int {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.integer(forKey: key)
    }

    /// Convenience wrapper for bool retrieval.
    public var boolForKey: (String) -> Bool {
        return { key in UserDefaults.standard.bool(forKey: key) }
    }

    /// Set any Codable-compatible value. Routes to the appropriate native UserDefaults method for each type.
    public func setAny(_ value: Any?, forKey key: String) {
        switch value {
        case let v as Bool?:            UserDefaults.standard.set(v, forKey: key)  // Optional — routes to native Bool? setter
        case let v as Int?:             UserDefaults.standard.set(v, forKey: key)  // Optional — routes to native Int? setter
        case let v as Double?:          UserDefaults.standard.set(v, forKey: key)  // Optional — routes to native Double? setter
        case let v as String?:          UserDefaults.standard.set(v, forKey: key)  // Optional — routes to native String? setter
        case let v as URL?:             UserDefaults.standard.set(v?.absoluteString, forKey: key)  // Optional — routes to native String? setter
        case let v as Data?:            UserDefaults.standard.set(v, forKey: key)  // Optional — routes to native Data? setter
        default:                        UserDefaults.standard.set(value, forKey: key)  // NSKeyedArchiver-compatible types
        }
    }

    /// Convenience wrapper for generic object retrieval.
    public func object(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: key)  // Direct call to avoid protocol witness table recursion.
    }

    /// Convenience wrapper for retrieving URL values from stored strings.
    public func url(forKey key: String) -> URL? {
        guard let str = UserDefaults.standard.string(forKey: key) else { return nil }
        return URL(string: str)
    }

    /// Remove a key from UserDefaults.
    public func removeObject(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)  // Direct call to avoid protocol witness table recursion.
    }

}

/// Application store backed by UserDefaults. Manages collection interval, log directory path, and login items toggle.
public final class Store: ObservableObject {

    private let defaults: UserDefaultsProtocol

    /// Collection interval in seconds (default 10).
    public var collectionInterval: Int {
        get { defaults.integer(forKey: StoreKey.collectionInterval, defaultValue: 10) }
        set { defaults.setAny(newValue, forKey: StoreKey.collectionInterval) }
    }

    /// Log storage directory path (default ~/Library/Application Support/Mac Wattage).
    public var logDirectoryPath: String? {
        get { defaults.string(forKey: StoreKey.logDirectoryPath) }
        set { defaults.setAny(newValue, forKey: StoreKey.logDirectoryPath) }
    }

    /// Computed log directory URL. Returns the user-configured path or the default Application Support location.
    public var logDirectory: URL {
        if let path = logDirectoryPath, let url = URL(string: path) { return url }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Mac Wattage") ?? URL(fileURLWithPath: "/tmp/MacWattage")
    }

    /// Auto-launch at login toggle (default false). On set, updates the system login item list.
    public var autoLaunchAtLogin: Bool {
        get { defaults.boolForKey(StoreKey.autoLaunchAtLogin) }
        set {
            defaults.setAny(newValue, forKey: StoreKey.autoLaunchAtLogin)
            updateLoginItems(newValue)
        }
    }

    /// Creates a store backed by the given UserDefaults. Pass nil to use standard defaults.
    public init(defaults: UserDefaultsProtocol? = nil) {
        self.defaults = defaults ?? (UserDefaults.standard as UserDefaultsProtocol)
    }

    // MARK: - Login Items

    /// Add or remove this app from the user's login items using SMLoginItemSetEnabled.
    private func updateLoginItems(_ enable: Bool) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        // SMLoginItemSetEnabled requires the login item bundle ID.
        let loginItemID = "\(bundleID).helper"

        // Call SMLoginItemSetEnabled via dlopen/dlsym since the symbol may not be in this SDK.
        let handle = dlopen(nil, RTLD_LAZY)  // Use main program's symbol table
        if let sym = dlsym(handle, "SMLoginItemSetEnabled") {
            typealias FuncType = @convention(c) (CFString, Bool) -> Bool
            let fn = unsafeBitCast(sym, to: FuncType.self)
            _ = fn(loginItemID as CFString, enable)
        } else {
            // SMLoginItemSetEnabled not available on this system.
        }
    }

    /// Clear all stored data (collection interval, log directory, login items).
    public func reset() {
        defaults.setAny(nil, forKey: StoreKey.collectionInterval)
        defaults.setAny(nil, forKey: StoreKey.logDirectoryPath)
        autoLaunchAtLogin = false
    }

    deinit {
        // No cleanup needed — UserDefaults persists across sessions.
    }
}
