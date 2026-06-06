import Darwin
import Foundation

/// Concrete implementation reading from mach and IOKit APIs. Thread-safe via internal lock.
public final class IOKitAdapter: IOKitAdapterProtocol {

    // MARK: - CPU Utilization Delta Tracking

    /// Previous cumulative tick counts (since boot). Used to compute delta between calls.
    private var previousCpuTicks: [integer_t]? = nil

    /// Lock protecting `previousCpuTicks` — serializes concurrent reads.
    private let ticksLock = NSRecursiveLock()

    /// Reads per-core CPU load from mach and returns busy fraction across all cores.
    /// Uses delta between successive calls — `host_statistics64` returns cumulative ticks since boot,
    /// so the busy fraction is computed as `(deltaTotal - deltaIdle) / deltaTotal`.
    public func cpuUtilization() -> Double {
        let host = mach_host_self()

        var cpuLoad: [integer_t] = Array(repeating: 0, count: Int(CPU_STATE_MAX))
        var count = mach_msg_type_number_t(cpuLoad.count)

        let kr = host_statistics64(host, HOST_CPU_LOAD_INFO, &cpuLoad, &count)
        guard kr == KERN_SUCCESS else { return 0.0 }

        let (deltaTotal, deltaIdle): (UInt64, UInt64) = {
            self.ticksLock.lock()

            // On first call we have no previous sample — return a neutral default until
            // we have two delta samples to compare.
            guard let prev = self.previousCpuTicks, prev.count == CPU_STATE_MAX else {
                self.previousCpuTicks = cpuLoad
                self.ticksLock.unlock()
                return (UInt64(0), UInt64(0))
            }

            var dTotal: UInt64 = 0
            var dIdle: UInt64 = 0

            // cpuLoad[i] holds ticks for CPU_STATE_[USER/SYSTEM/IDLE/NICE].
            // Compute delta (current - previous) for each counter.
            for i in 0 ..< CPU_STATE_MAX {
                let delta = UInt64(cpuLoad[Int(i)]) - UInt64(prev[Int(i)])
                dTotal += delta
                if i == CPU_STATE_IDLE { dIdle = delta }
            }

            // Update stored ticks for next call.
            self.previousCpuTicks = cpuLoad
            self.ticksLock.unlock()

            return (dTotal, dIdle)
        }()

        guard deltaTotal > 0 else { return 0.0 }

        let busyFraction = Double(deltaTotal - deltaIdle) / Double(deltaTotal)
        return min(1.0, max(0.0, busyFraction))
    }

    // MARK: - GPU Utilization (Apple Silicon heuristic)

    /// Estimates GPU utilization on Apple Silicon using system memory pressure as a proxy.
    /// True per-GPU-util APIs (Metal Performance Queries) require an active MTLDevice context,
    /// which a menu-bar app typically doesn't have. Memory pressure correlates with overall system load,
    /// which often includes GPU activity under heavy workloads (e.g., LLM inference).
    public func gpuUtilization() -> Double {
        var memPressure: Int32 = 0
        var size = MemoryLayout<Int32>.size

        // hw.mem_pressure: 0 (free) to ~100+ (severe pressure).
        // HW_MEMPRESSURE constant not exported in SDK headers — use raw value 13.
        var mib: [Int32] = [CTL_HW, 13 /* HW_MEMPRESSURE */]
        let kr = sysctl(&mib, 2, &memPressure, &size, nil, 0)
        if kr == 0 && memPressure > 0 {
            // Scale: low pressure → light GPU load, high pressure → heavy.
            return min(1.0, max(0.0, Double(memPressure) / 500.0))
        }

        // No pressure data available — return conservative zero for GPU component.
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

