import Foundation

// Note: ChipGeneration, MacPlatform, FanModel, HardwareProfile are defined in PlatformDetector.swift.
import Foundation

/// Protocol abstraction for power estimation. Allows test doubles to inject mock values.
public protocol PowerEstimatorProtocol {
    /// Estimate total system power in watts from CPU and GPU utilization fractions.
    func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double
}

/// TDP-based power estimator using the formula:
///   watts = SoC_TDP × loadFactor × memoryCoefficient + baseConsumption + fanPower
///
/// Thread-safe (immutable after init).
public final class PowerEstimator: PowerEstimatorProtocol {

    private let profile: HardwareProfile

    public init(profile: HardwareProfile) {
        self.profile = profile
    }

    /// Estimate system power using the TDP-based estimation formula.
    public func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double {
        // Clamp inputs to [0, 1].
        let clampedCPU = min(1.0, max(0.0, cpuUtil))
        let clampedGPU = min(1.0, max(0.0, gpuUtil))

        // Combined load signal: CPU primary, GPU secondary (50/50 blend).
        let combinedLoad = 0.6 * clampedCPU + 0.4 * clampedGPU

        // Discrete load factor based on combined utilization level:
        //   idle (screen off)  < 0.15 → 0.03
        //   light              < 0.40 → 0.25
        //   medium             < 0.70 → 0.55
        //   heavy              < 1.00 → 0.85
        //   full               ≥ 1.00 → 1.00
        let loadFactor: Double = {
            if combinedLoad < 0.15 { return 0.03 } // idle (screen off)
            if combinedLoad < 0.40 { return 0.25 } // light
            if combinedLoad < 0.70 { return 0.55 } // medium
            if combinedLoad < 1.00 { return 0.85 } // heavy
            return 1.0                            // full load (overridden by screenOff)
        }()

        // If screen is off, force idle load factor regardless of CPU/GPU.
        let effectiveLoad = profile.screenOff ? 0.03 : loadFactor

        // Memory coefficient based on total physical RAM (bandwidth → power).
        let memoryCoefficient = memCoefficient(for: profile.ramSizeBytes)

        // Base consumption (SSD + motherboard idle power).
        let baseConsumption: Double = {
            switch profile.platform {
            case .laptop: return 5.0
            case .studio: return 12.0
            }
        }()

        // Fan power draw (only active under load).
        let fanPower: Double = {
            // Fans are negligible at idle/light loads.
            if effectiveLoad < 0.3 { return 0.0 }
            switch profile.fanModel {
            case .none:    return 0.0
            case .single:  return 3.0 * effectiveLoad // scales with load
            case .dual:    return 6.0 * effectiveLoad
            case .turbo:   return 12.0 * effectiveLoad
            }
        }()

        // Final formula: SoC_TDP × loadFactor × memoryCoefficient + baseConsumption + fanPower
        let socTDP = chipTDP(for: profile.chipGeneration)
        return socTDP * effectiveLoad * memoryCoefficient + baseConsumption + fanPower
    }

    /// Compute combined load factor from utilization inputs (for tests that need it).
    internal func computeLoadFactor(from cpuUtil: Double, gpuUtil: Double) -> (loadFactor: Double, effectiveLoad: Double) {
        let clampedCPU = min(1.0, max(0.0, cpuUtil))
        let clampedGPU = min(1.0, max(0.0, gpuUtil))
        let combinedLoad = 0.6 * clampedCPU + 0.4 * clampedGPU

        let loadFactor: Double = {
            if combinedLoad < 0.15 { return 0.03 }
            if combinedLoad < 0.40 { return 0.25 }
            if combinedLoad < 0.70 { return 0.55 }
            if combinedLoad < 1.00 { return 0.85 }
            return 1.0
        }()

        let effectiveLoad = profile.screenOff ? 0.03 : loadFactor
        return (loadFactor, effectiveLoad)
    }

    /// Convenience for tests: returns the memory coefficient.
    internal func getMemoryCoefficient() -> Double {
        memCoefficient(for: profile.ramSizeBytes)
    }

    /// Convenience for tests: returns the SoC TDP.
    internal func getSoCTDP() -> Double {
        chipTDP(for: profile.chipGeneration)
    }
}

// MARK: - Private helpers (imported from PowerConfig.swift)

private func memCoefficient(for ramBytes: Int64) -> Double {
    let ramGB = ramBytes / (1024 * 1024 * 1024)
    let entries: [(ramGB: Int, coefficient: Double)] = [
        (8, 1.0), (16, 1.05), (32, 1.10),
        (64, 1.18), (128, 1.28), (192, 1.40),
    ]
    var result = 1.0
    for entry in entries {
        if ramGB >= entry.ramGB { result = entry.coefficient } else { break }
    }
    return result
}
