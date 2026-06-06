import Foundation

/// Lightweight UserDefaults protocol for dependency injection in tests.
public protocol UserDefaultsProtocol: AnyObject {
    func integer(forKey key: String, defaultValue: Int) -> Int
    var boolForKey: (String) -> Bool { get }
    func string(forKey key: String) -> String?
    func setAny(_ value: Any?, forKey key: String)
    func object(forKey key: String) -> Any?
}

/// Application store backed by UserDefaults. Manages collection interval, log directory path, and login items toggle.
public final class Store: ObservableObject {

    private let defaults: UserDefaultsProtocol?
    /// Direct reference to standard defaults, captured once before any property access.
    private let std: UserDefaults

    /// Collection interval in seconds (default 1).
    public var collectionInterval: Int {
        get { readInt(forKey: StoreKey.collectionInterval, defaultValue: 1) }
        set { write(newValue, forKey: StoreKey.collectionInterval) }
    }

    /// Log storage directory path (default ~/Library/Application Support/Mac Wattage).
    public var logDirectoryPath: String? {
        get { readString(forKey: StoreKey.logDirectoryPath) }
        set { write(newValue, forKey: StoreKey.logDirectoryPath) }
    }

    /// Computed log directory URL. Returns the user-configured path or the default Application Support location.
    public var logDirectory: URL {
        if let path = logDirectoryPath, let url = URL(string: path) { return url }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Mac Wattage") ?? URL(fileURLWithPath: "/tmp/MacWattage")
    }

    /// Auto-launch at login toggle (default false). On set, updates the system login item list.
    public var autoLaunchAtLogin: Bool {
        get { readBool(forKey: StoreKey.autoLaunchAtLogin) }
        set { write(newValue, forKey: StoreKey.autoLaunchAtLogin); updateLoginItems(newValue) }
    }

    /// Creates a store backed by the given UserDefaults. Pass nil to use standard defaults directly.
    public init(defaults: UserDefaultsProtocol? = nil) {
        self.defaults = defaults
        // Capture standard once, before any property access triggers recursive loops.
        self.std = UserDefaults.standard
    }

    // MARK: - Internal access helpers

    private func readInt(forKey key: String, defaultValue: Int) -> Int {
        if let d = defaults { return readInt(from: d, key: key, defaultValue: defaultValue) }
        // Direct calls on captured std — no protocol dispatch.
        if let obj = std.object(forKey: key), let v = obj as? Int { return v }
        return defaultValue
    }

    private func readInt(from d: UserDefaultsProtocol, key: String, defaultValue: Int) -> Int {
        if let obj = d.object(forKey: key), let v = obj as? Int { return v }
        // Fallback to captured std for default value.
        if let obj = std.object(forKey: key), let v = obj as? Int { return v }
        return defaultValue
    }

    private func readString(forKey key: String) -> String? {
        if let d = defaults { return d.string(forKey: key) }
        return std.string(forKey: key)
    }

    private func readBool(forKey key: String) -> Bool {
        if let d = defaults { return d.boolForKey(key) }
        return std.bool(forKey: key)
    }

    private func write(_ value: Any?, forKey key: String) {
        if let d = defaults {
            // Use native Foundation setters — no extension dispatch.
            switch value {
            case let v as Bool:             d.setAny(v, forKey: key)
            case let v as Int:              d.setAny(v, forKey: key)
            case let v as Double:           d.setAny(v, forKey: key)
            case let v as String?:         d.setAny(v, forKey: key)
            case let v as URL:             d.setAny(v.absoluteString, forKey: key)
            case let v as Data?:           d.setAny(v, forKey: key)
            default:                       d.setAny(value, forKey: key)
            }
        } else {
            // Direct calls on captured std — no extension dispatch.
            switch value {
            case let v as Bool:             std.set(v, forKey: key)
            case let v as Int:              std.set(v, forKey: key)
            case let v as Double:           std.set(v, forKey: key)
            case let v as String?:         std.set(v, forKey: key)
            case let v as URL:             std.set(v.absoluteString, forKey: key)
            case let v as Data?:           std.set(v, forKey: key)
            default:                       std.set(value, forKey: key)
            }
        }
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
        std.removeObject(forKey: StoreKey.collectionInterval)
        std.removeObject(forKey: StoreKey.logDirectoryPath)
        autoLaunchAtLogin = false
    }

    deinit {
        // No cleanup needed — UserDefaults persists across sessions.
    }
}
