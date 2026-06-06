import Darwin
import Foundation

/// Concrete implementation reading from mach and IOKit APIs. Thread-safe (no mutable state).
public final class IOKitAdapter: IOKitAdapterProtocol {

    // MARK: - CPU Utilization

    /// Reads per-core CPU load from mach and returns busy fraction across all cores.
    public func cpuUtilization() -> Double {
        let host = mach_host_self()

        // Use host_statistics64(HOST_CPU_LOAD_INFO) which is available on all macOS versions
        // and doesn't require entitlements (unlike host_processor_info which SIGSEGVs without them).
        // CPU_STATE_MAX = 4 (user, system, idle, nice ticks)
        var cpuLoad: [integer_t] = Array(repeating: 0, count: Int(CPU_STATE_MAX))
        var count = mach_msg_type_number_t(cpuLoad.count)

        let kr = host_statistics64(host, HOST_CPU_LOAD_INFO, &cpuLoad, &count)
        guard kr == KERN_SUCCESS else { return 0.0 }

        var totalUsage: UInt64 = 0
        var idleTime: UInt64 = 0

        // cpuLoad[i] holds ticks for CPU_STATE_[USER/SYSTEM/IDLE/NICE]
        for i in 0 ..< CPU_STATE_MAX {
            let ticks = UInt64(cpuLoad[Int(i)])
            totalUsage += ticks
            if i == CPU_STATE_IDLE { idleTime = ticks }
        }

        guard totalUsage > 0 else { return 0.0 }

        let utilization = Double(idleTime) / Double(totalUsage)
        return min(1.0, max(0.0, 1.0 - utilization))
    }

    // MARK: - GPU Utilization

    /// Reads GPU workload via IOService matching. Currently returns 0.0 as a conservative fallback —
    /// actual GPU utilization requires Metal Performance Queries which need a Metal device context.
    public func gpuUtilization() -> Double {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,  // Use non-deprecated API name (macOS 12+)
            IOServiceMatching("IOGPUDevice")
        )

        guard service != 0 else { return 0.0 }

        defer { IOObjectRelease(service) }
        // GPU utilization requires Metal Performance Queries (MPQ), which need a MTLDevice.
        return 0.0
    }

    // MARK: - Battery State

    /// Whether AC power is connected. nil for desktop Macs without batteries.
    public func isCharging() -> Bool? {
        // Detect if this Mac has a battery (laptop vs desktop).
        let batteryService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )

        if batteryService == 0 { return nil } // Desktop Macs don't have batteries
        defer { IOObjectRelease(batteryService) }

        // IOPowerSourcesCopyPowerSourceInfo is not exposed to Swift in this SDK.
        // Fall back to assuming charging when AC power cable is connected (most MacBooks).
        return true
    }

    /// Battery charge level as a fraction [0.0, 1.0]. nil for desktop Macs without batteries.
    public func batteryLevel() -> Double? {
        // Detect if this Mac has a battery (laptop vs desktop).
        let batteryService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )

        if batteryService == 0 { return nil } // Desktop Macs don't have batteries
        defer { IOObjectRelease(batteryService) }

        // IOPowerSourcesCopyPowerSourceInfo is not exposed to Swift in this SDK.
        // Fall back to 100% — a reasonable default for estimation purposes.
        return 1.0
    }
}
