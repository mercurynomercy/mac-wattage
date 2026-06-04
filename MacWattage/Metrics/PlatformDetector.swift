import Foundation

/// Detects Mac platform type (laptop with battery vs desktop without).
public enum MacPlatform { case studio, laptop }

/// Apple Silicon chip generation — used for power estimation profiles.
public enum ChipGeneration { case m1Base, m2Base, m1Pro, m2Pro, m1Max, m2Max, m1Ultra }

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

        // Check Ultra first (most specific keyword match needed before Pro/Max)
        if cpuString.contains("Ultra") { return .m1Ultra }

        // Max vs Pro detection
        if cpuString.contains("Max") {
            return cpuString.range(of: "M2", options: .backwards) != nil ? .m2Max : .m1Max
        }

        if cpuString.contains("Pro") {
            return cpuString.range(of: "M2", options: .backwards) != nil ? .m2Pro : .m1Pro
        }

        // Base chips — M2 has "Apple M2" in the string, older ones have "M1"
        if cpuString.range(of: "M2", options: .backwards) != nil { return .m2Base }
        return .m1Base
    }
}
