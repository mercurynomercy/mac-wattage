import Foundation

// Note: ChipGeneration and MacPlatform are defined in PlatformDetector.swift (canonical location).
import Foundation

/// Protocol abstraction for power estimation. Allows test doubles to inject mock values.
public protocol PowerEstimatorProtocol {
    /// Estimate total system power in watts from CPU and GPU utilization fractions.
    func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double
}

/// Chip generation-specific power constants (TDP-based estimation).
private struct ChipProfile {
    let idlePower: Double     // Watts at 0% load (base system + leakage)
    let cpuMaxPower: Double   // Max CPU power consumption at 100% load
    let gpuMaxPower: Double   // Max GPU power consumption at 100% load
}

/// Concrete TDP-based power estimator. Thread-safe (immutable after init).
public final class PowerEstimator: PowerEstimatorProtocol {

    /// Per-chip TDP constants.
    private enum Profile {
        static let base = ChipProfile(idlePower: 5.0, cpuMaxPower: 40.0, gpuMaxPower: 15.0)
        static let pro = ChipProfile(idlePower: 8.0, cpuMaxPower: 60.0, gpuMaxPower: 30.0)
        static let max = ChipProfile(idlePower: 12.0, cpuMaxPower: 100.0, gpuMaxPower: 60.0)
        static let ultra = ChipProfile(idlePower: 15.0, cpuMaxPower: 120.0, gpuMaxPower: 80.0)
    }

    private let profile: ChipProfile

    public init(platform: MacPlatform, chipGeneration: ChipGeneration) {
        self.profile = Self.profile(for: platform, generation: chipGeneration)
    }

    /// Estimate system power using TDP-based formula (hardware sensors not available on all models).
    public func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double {
        let clampedCPU = min(1.0, max(0.0, cpuUtil))
        let clampedGPU = min(1.0, max(0.0, gpuUtil))

        // Formula: idle + cpuUtil * (cpuMax - idle) + gpuUtil * gpuMax
        // This models power as a linear function of utilization from idle to max TDP.
        let cpuPower = profile.idlePower + clampedCPU * (profile.cpuMaxPower - profile.idlePower)
        let gpuPower = clampedGPU * profile.gpuMaxPower

        return cpuPower + gpuPower
    }

    private static func profile(for platform: MacPlatform, generation: ChipGeneration) -> ChipProfile {
        switch generation {
        case .m1Base, .m2Base: return Profile.base
        case .m1Pro, .m2Pro:   return Profile.pro
        case .m1Max, .m2Max:   return Profile.max
        case .m1Ultra:         return Profile.ultra
        }
    }
}
