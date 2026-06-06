import Foundation

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
    case .m1Base, .m2Base:  return ChipTDP.m1
    case .m3Base:           return ChipTDP.m3
    case .m4Base:           return ChipTDP.m4
    case .m1Pro, .m2Pro:    return ChipTDP.m1Pro
    case .m3Pro:            return ChipTDP.m3Pro
    case .m4Pro:            return ChipTDP.m4Pro
    case .m1Max, .m2Max:    return ChipTDP.m1Max
    case .m3Max:            return ChipTDP.m3Max
    case .m4Max:            return ChipTDP.m4Max
    case .m1Ultra:          return ChipTDP.m1Ultra
    case .m2Ultra:          return ChipTDP.m2Ultra
    case .m3Ultra:          return ChipTDP.m3Ultra
    }
}
