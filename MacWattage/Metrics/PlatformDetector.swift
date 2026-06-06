import CoreFoundation
import Darwin
import Foundation

/// Detects Mac platform type (laptop with battery vs desktop without).
public enum MacPlatform { case studio, laptop }

/// Fan model type — used for estimating fan power draw.
public enum FanModel { case none, single, dual, turbo }

/// Apple Silicon chip generation — used for power estimation profiles.
public enum ChipGeneration {
    case m1Base, m2Base, m3Base, m4Base
    case m1Pro,  m2Pro,  m3Pro,  m4Pro
    case m1Max,  m2Max,  m3Max,  m4Max
    case m1Ultra, m2Ultra, m3Ultra
}

/// Runtime hardware detection. Uses IOKit and sysctl — never throws, always returns a valid value.
public enum PlatformDetector {

    /// Detect whether the Mac has a battery (MacBook) or not (desktop).
    public static func detectPlatform() -> MacPlatform {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0

        let status = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard status == KERN_SUCCESS && iterator != 0 else {
            return .studio  // No battery service found → desktop
        }

        defer { IOObjectRelease(iterator) }
        guard IOIteratorIsValid(iterator) != 0 else { return .studio }

        // If AppleSmartBattery service exists, it's a laptop
        _ = IOIteratorNext(iterator) != 0
        return .laptop
    }

    /// Detect chip generation by reading the CPU brand string via sysctl.
    public static func detectChipGeneration() -> ChipGeneration {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0 else {
            return .m2Base  // Default fallback
        }

        var brand = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0) == 0 else {
            return .m2Base
        }

        let cpuString = String(cString: brand)

        // Check Ultra first (must match before Pro/Max substrings)
        if cpuString.contains("Ultra") {
            if cpuString.contains("M3") { return .m3Ultra }
            if cpuString.contains("M2") { return .m2Ultra }
            return .m1Ultra
        }

        if cpuString.contains("Max") {
            if cpuString.contains("M4") { return .m4Max }
            if cpuString.contains("M3") { return .m3Max }
            if cpuString.contains("M2") { return .m2Max }
            return .m1Max
        }

        if cpuString.contains("Pro") {
            if cpuString.contains("M4") { return .m4Pro }
            if cpuString.contains("M3") { return .m3Pro }
            if cpuString.contains("M2") { return .m2Pro }
            return .m1Pro
        }

        if cpuString.contains("M4") { return .m4Base }
        if cpuString.contains("M3") { return .m3Base }
        if cpuString.contains("M2") { return .m2Base }
        return .m1Base
    }

    // MARK: - Additional Hardware Detection

    /// Detect total RAM size in bytes via sysctl(hw.memsize).
    public static func detectRAMSize() -> Int64 {
        var size: Int64 = 0
        let result = sysctlbyname("hw.memsize", &size, nil, nil, 0)
        guard result == 0 else { return 8 * 1024 * 1024 * 1024 } // fallback: 8 GB
        return size
    }

    /// Detect fan model type by reading device tree properties.
    public static func detectFanModel() -> FanModel {
        let root = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/")
        guard root != 0 else {
            return .single // conservative default for unknown hardware
        }
        defer { IOObjectRelease(root) }

        // Read "fan-backend-types" property — a CFArray of fan type strings.
        guard let fansProp = IORegistryEntryCreateCFProperty(root, "fan-backend-types" as CFString, nil, 0) else {
            // Fallback: detect via model identifier string.
            return fanModelFromModelIdentifier()
        }

        let fansArray = (fansProp as! CFArray) as [CFTypeRef]
        let count = fansArray.count
        if count == 0 { return .none }
        if count == 1 { return .single }

        // Check for turbo/liquid cooling fans (higher power draw).
        let fanStrings = fansArray.compactMap { $0 as? String }
        for name in fanStrings where name.contains("turbo") || name.lowercased().contains("liquid") {
            return .turbo
        }

        // 2+ fans, none turbo — dual fan.
        return count >= 2 ? .dual : .single
    }

    /// Fallback fan model detection via IOPlatformExpert device tree "model" property.
    private static func fanModelFromModelIdentifier() -> FanModel {
        let root = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/")
        guard root != 0 else {
            return .single // conservative default for unknown hardware
        }
        defer { IOObjectRelease(root) }

        guard let modelCF = IORegistryEntryCreateCFProperty(root, "model" as CFString, nil, 0) else {
            return .single // fallback default
        }
        let modelString = (modelCF.takeRetainedValue() as! CFString) as String

        let model = modelString.lowercased()

        // Known fanless Macs (Apple Silicon base models with passive cooling).
        let fanlessModels: [String] = ["mac14,7", "mac14,8"] // M2 Mac mini
        if fanlessModels.contains(model) { return .none }

        // Known single-fan Macs.
        let singleFanModels: [String] = ["MacBookAir10,1", "mac14,2"] // M2 Air, M2 mini
        if singleFanModels.contains(model) { return .single }

        // Default: dual fan for Pro/Max/Ultra class machines.
        return .dual
    }

    /// Detect whether the display backlight is off (screen sleeping).
    public static func isScreenOff() -> Bool {
        let matching = IOServiceMatching("AppleBacklightDisplay")
        var iterator: io_iterator_t = 0

        let status = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard status == KERN_SUCCESS && iterator != 0 else {
            return false // unknown display state — assume screen is on (conservative for power)
        }

        defer { IOObjectRelease(iterator) }
        guard IOIteratorIsValid(iterator) != 0 else { return false }

        // Found a backlight display — check its power state.
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return false }

        // Check "DisplayPowerState" property (0 = off, 1+ = on).
        let powerValue: Int32? = IORegistryEntryCreateCFProperty(service, "DisplayPowerState" as CFString, nil, 0)
            .map { $0.takeRetainedValue() as! Int32 }
        IOObjectRelease(service)
        return powerValue == 0
    }

    /// Combined hardware profile — all detected attributes in one struct.
    public static func detectHardwareProfile() -> HardwareProfile {
        let platform = detectPlatform()
        let chipGen = detectChipGeneration()
        let ramSize = detectRAMSize()
        let fanModel = detectFanModel()

        return HardwareProfile(
            platform: platform,
            chipGeneration: chipGen,
            ramSizeBytes: ramSize,
            fanModel: fanModel,
            screenOff: isScreenOff()
        )
    }
}

/// Combined hardware profile — result of all platform detection queries.
public struct HardwareProfile {
    public let platform: MacPlatform
    public let chipGeneration: ChipGeneration
    /// Total physical RAM in bytes (e.g. 8 GB = 8_589_934_592).
    public let ramSizeBytes: Int64
    /// Fan model type for power estimation.
    public let fanModel: FanModel
    /// Whether the display is currently off (screen sleep).
    public let screenOff: Bool

    /// Convenience getter for platform label used in UI.
    public var isStudio: Bool { platform == .studio }

    /// Convenience getter for RAM in GB (rounded up).
    public var ramGB: Int {
        Int((ramSizeBytes + 1024 * 1024 * 1024 - 1) / (1024 * 1024 * 1024))
    }
}

