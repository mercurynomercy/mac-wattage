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

        // Combined load signal: CPU primary (0.6), GPU secondary (0.4).
        let combinedLoad = 0.6 * clampedCPU + 0.4 * clampedGPU

        // Continuous effective load: a 0.20 idle floor (baseline SoC activity even when "idle")
        // ramping linearly to 1.0 at full load. Screen off forces a deep-idle 0.03.
        // Continuous (not bucketed) so wattage tracks load smoothly instead of snapping between levels.
        let effectiveLoad = profile.screenOff ? 0.03 : 0.20 + 0.80 * combinedLoad

        // Memory coefficient based on total physical RAM (bandwidth → power).
        let memoryCoefficient = memCoefficient(for: profile.ramSizeBytes)

        // Base consumption (SSD + motherboard idle power).
        let baseConsumption: Double = {
            switch profile.platform {
            case .laptop: return 5.0
            case .studio: return 12.0
            }
        }()

        // Fan power draw scales continuously with load (zero at idle, max at full load).
        let fanWatts: Double = {
            switch profile.fanModel {
            case .none:    return 0.0
            case .single:  return 3.0
            case .dual:    return 6.0
            case .turbo:   return 12.0
            }
        }()
        let fanPower = profile.screenOff ? 0.0 : fanWatts * combinedLoad

        // Final formula: SoC_TDP × effectiveLoad × memoryCoefficient + baseConsumption + fanPower
        let socTDP = chipTDP(for: profile.chipGeneration)
        return socTDP * effectiveLoad * memoryCoefficient + baseConsumption + fanPower
    }

    /// Compute combined load factor from utilization inputs (for tests that need it).
    internal func computeLoadFactor(from cpuUtil: Double, gpuUtil: Double) -> (loadFactor: Double, effectiveLoad: Double) {
        let clampedCPU = min(1.0, max(0.0, cpuUtil))
        let clampedGPU = min(1.0, max(0.0, gpuUtil))
        let combinedLoad = 0.6 * clampedCPU + 0.4 * clampedGPU
        let effectiveLoad = profile.screenOff ? 0.03 : 0.20 + 0.80 * combinedLoad
        return (effectiveLoad, effectiveLoad)
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
    // Power scales with RAM (more memory controllers / bandwidth → more power).
    // Covers all shipping Apple Silicon configs from 8 GB up to 512 GB (M3 Ultra).
    let entries: [(ramGB: Int, coefficient: Double)] = [
        (8, 1.00), (16, 1.05), (24, 1.08), (32, 1.10), (36, 1.12), (48, 1.15),
        (64, 1.18), (96, 1.24), (128, 1.30), (192, 1.40), (256, 1.50), (512, 1.70),
    ]
    var result = 1.0
    for entry in entries {
        if ramGB >= entry.ramGB { result = entry.coefficient } else { break }
    }
    return result
}
