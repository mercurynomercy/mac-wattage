import Foundation

// MARK: - Chip TDP Configuration (SoC max package power at full load)
/// Representative full-load package power (CPU+GPU) per chip generation. Apple publishes no official
/// TDP, so these are community-measured estimates. Ultra ≈ 2× the corresponding Max (two fused dies).

private enum ChipTDP {
    static let m1: Double = 20        // M1 base (~20 W)
    static let m1Pro: Double = 30     // M1 Pro (~30 W)
    static let m1Max: Double = 57     // M1 Max (~57 W)
    static let m1Ultra: Double = 115  // M1 Ultra (~110–120 W)

    static let m2: Double = 20        // M2 base (~20 W)
    static let m2Pro: Double = 35     // M2 Pro (~35 W)
    static let m2Max: Double = 61     // M2 Max (~55–68 W)
    static let m2Ultra: Double = 120  // M2 Ultra (~120 W)

    static let m3: Double = 20        // M3 base (~20 W)
    static let m3Pro: Double = 35     // M3 Pro (~35 W)
    static let m3Max: Double = 78     // M3 Max 16-core (~78 W under full load)
    static let m3Ultra: Double = 160  // M3 Ultra (~140–180 W, large die)

    static let m4: Double = 25        // M4 base (~22–28 W)
    static let m4Pro: Double = 45     // M4 Pro (~45 W)
    static let m4Max: Double = 90     // M4 Max 16-core (~90 W under full load)

    // M5 series (Base/Pro/Max only — no Ultra). Extrapolated ~10% over M4; verify against measured data.
    static let m5: Double = 27        // M5 base (estimate)
    static let m5Pro: Double = 48     // M5 Pro (estimate)
    static let m5Max: Double = 95     // M5 Max (estimate)
}

/// SoC TDP for a given chip generation. Used as the base power multiplier in the formula:
///   watts = SoC_TDP × loadFactor × memoryCoefficient + baseConsumption + fanPower
func chipTDP(for generation: ChipGeneration) -> Double {
    switch generation {
    case .m1Base, .m2Base:  return ChipTDP.m1
    case .m3Base:           return ChipTDP.m3
    case .m4Base:           return ChipTDP.m4
    case .m5Base:           return ChipTDP.m5
    case .m1Pro, .m2Pro:    return ChipTDP.m1Pro
    case .m3Pro:            return ChipTDP.m3Pro
    case .m4Pro:            return ChipTDP.m4Pro
    case .m5Pro:            return ChipTDP.m5Pro
    case .m1Max, .m2Max:    return ChipTDP.m1Max
    case .m3Max:            return ChipTDP.m3Max
    case .m4Max:            return ChipTDP.m4Max
    case .m5Max:            return ChipTDP.m5Max
    case .m1Ultra:          return ChipTDP.m1Ultra
    case .m2Ultra:          return ChipTDP.m2Ultra
    case .m3Ultra:          return ChipTDP.m3Ultra
    }
}
