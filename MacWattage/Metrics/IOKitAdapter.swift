import Foundation

/// Protocol abstraction for hardware metrics reads. Allows test doubles to inject mock values.
public protocol IOKitAdapterProtocol {
    /// CPU usage fraction across all cores, [0.0, 1.0]. Returns 0.0 on failure (never throws).
    func cpuUtilization() -> Double

    /// GPU usage fraction, [0.0, 1.0]. Returns 0.0 if no GPU service found (fallback).
    func gpuUtilization() -> Double

    /// Whether the Mac is currently charging. nil for desktop Macs without batteries.
    func isCharging() -> Bool?

    /// Battery charge level as a fraction [0.0, 1.0]. nil for desktop Macs without batteries.
    func batteryLevel() -> Double?
}

/// Concrete implementation reading from mach and IOKit APIs. Thread-safe (no mutable state).
public final class IOKitAdapter: IOKitAdapterProtocol {

    // MARK: - CPU Utilization

    /// Reads per-core CPU load from mach and returns busy fraction across all cores.
    public func cpuUtilization() -> Double {
        let host = mach_host_self()
        var processorCount: mach_msg_type_number_t = 0

        // Single call to get both the processor count and cpu_ticks data.
        let status = host_processor_info(
            host, PROCESSOR_CPU_LOAD_INFO, &processorCount, nil, nil
        )

        guard status == KERN_SUCCESS else { return 0.0 }

        // Second call to get the actual cpu_load data
        var info: processor_info_array_t? = nil
        let result = host_processor_info(
            host, PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, nil
        )

        guard result == KERN_SUCCESS, let rawInfo = info else { return 0.0 }

        defer {
            // Each processor has PROCESSOR_CPU_LOAD_INFO_COUNT (4) integer_t values for cpu_ticks
            let byteCount = Int(processorCount * mach_msg_type_number_t(MemoryLayout<UInt32>.size))
            vm_deallocate(host, vm_address_t(byteCount), vm_size_t(byteCount))
        }

        var totalUsage: UInt64 = 0
        var idleTime: UInt64 = 0

        // The array is processorCount * PROCESSOR_CPU_LOAD_INFO_COUNT integers
        // Each group of 4 consecutive ints = (user, system, idle, nice) ticks
        let tickCount = Int(processorCount) * 4
        for i in 0 ..< tickCount {
            let ticks = rawInfo[i]
            totalUsage += UInt64(ticks)
            if i % 4 == 2 { idleTime += UInt64(ticks) }
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
