import Foundation

// MARK: - Load Factor Configuration (by utilization level)

/// Discrete load factors for the estimation formula.
/// Mapped from CPU/GPU utilization thresholds:
///   idle (screen off)  < 0.15 → 0.03
///   light              < 0.40 → 0.25
///   medium             < 0.70 → 0.55
///   heavy              < 1.00 → 0.85
///   full               ≥ 1.00 → 1.00
private let LOAD_FACTORS: [Double] = [0.03, 0.25, 0.55, 0.85, 1.0]

func loadFactor(for cpuUtil: Double) -> Double {
    let u = max(0.0, min(1.0, cpuUtil))
    if u < 0.15 { return LOAD_FACTORS[0] } // idle (screen off)
    if u < 0.40 { return LOAD_FACTORS[1] } // light
    if u < 0.70 { return LOAD_FACTORS[2] } // medium
    if u < 1.00 { return LOAD_FACTORS[3] } // heavy
    return LOAD_FACTORS[4]                  // full load (1.0)
}

// MARK: - Memory Coefficients by RAM Size

private let MEMORY_COEFFICIENTS: [(ramGB: Int, coefficient: Double)] = [
    (8, 1.0),
    (16, 1.05),
    (24, 1.10),
    (32, 1.10),
    (48, 1.18),
    (64, 1.18),
    (96, 1.28),
    (128, 1.28),
    (192, 1.40),
    (256, 1.40),
]

private func memoryCoefficient(for ramBytes: Int64) -> Double {
    let ramGB = ramBytes / (1024 * 1024 * 1024)
    // Find the largest entry ≤ ramGB (conservative — don't over-estimate memory)
    var result = 1.0 // default for very small RAM (≤8 GB) or unknown
    for entry in MEMORY_COEFFICIENTS {
        if ramGB >= entry.ramGB { result = entry.coefficient } else { break }
    }
    return result
}

// MARK: - Base Consumption by Device Type

/// Minimum system power (SSD + motherboard) when SoC is at zero load.
private let BASE_CONSUMPTION: [MacPlatform: Double] = [.laptop: 5.0, .studio: 12.0]

// MARK: - Fan Power by Device Type and Model

/// Estimated fan power draw. Apple Silicon Macs without fans return 0.
private let FAN_POWER: [MacPlatform: Double] = [.laptop: 3.0, .studio: 6.0]

// MARK: - Chip TDP Configuration (SoC max power at full load)
/// Representative TDP per chip generation. Uses mid-to-upper range of published specs.

private enum ChipTDP {
    static let m1: Double = 20       // M1 base (Air/Pro13": 15–20 W)
    static let m1Pro: Double = 30     // M1 Pro (8-core: 24–30 W)
    static let m1Max: Double = 56     // M1 Max (mid-range of 50–60 W)
    static let m1Ultra: Double = 95   // M1 Ultra (mid-range of 90–100 W)

    static let m2: Double = 20        // M2 base (18–22 W)
    static let m2Pro: Double = 35     // M2 Pro (mid of 28–40 W)
    static let m2Max: Double = 61     // M2 Max (mid of 55–68 W)
    static let m2Ultra: Double = 103  // M2 Ultra (mid of 95–110 W)

    static let m3: Double = 20        // M3 base (18–22 W)
    static let m3Pro: Double = 35     // M3 Pro (mid of 28–40 W)
    static let m3Max: Double = 57     // M3 Max (mid of 45–65 W)
    static let m3Ultra: Double = 109  // M3 Ultra (mid of 100–120 W)

    static let m4: Double = 25        // M4 base (Mac mini/iPad Pro: 20–28 W)
    static let m4Pro: Double = 39     // M4 Pro (mid of 35–48 W)
    static let m4Max: Double = 62     // M4 Max (mid of 55–75 W)
}

/// SoC TDP for a given chip generation. Used as the base power multiplier in the formula:
///   watts = SoC_TDP × loadFactor × memoryCoefficient + baseConsumption + fanPower
func chipTDP(for generation: ChipGeneration) -> Double {
    switch generation {
    case .m1Base,  .m2Base:     return ChipTDP.m1
    case .m1Pro,   .m2Pro:      return ChipTDP.m1Pro
    case .m1Max,   .m2Max:      return ChipTDP.m1Max
    case .m1Ultra:              return ChipTDP.m1Ultra
    }
}
