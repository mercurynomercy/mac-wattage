import XCTest
@testable import MacWattage

// MARK: - Shared test fixtures (M2 Base, studio platform)
private let m2BaseSoCTDP: Double = 20.0    // ChipTDP.m2
private let baseConsumption: Double = 12.0  // MacStudio platform

// MARK: - Helper to compute expected watts with new formula
private func expectedWatts(
    cpuUtil: Double, gpuUtil: Double, fanModel: FanModel = .dual
) -> Double {
    let clampedCPU = min(1.0, max(0.0, cpuUtil))
    let clampedGPU = min(1.0, max(0.0, gpuUtil))
    let combinedLoad = 0.6 * clampedCPU + 0.4 * clampedGPU

    let loadFactor: Double = {
        if combinedLoad < 0.15 { return 0.03 } // idle
        if combinedLoad < 0.40 { return 0.25 } // light
        if combinedLoad < 0.70 { return 0.55 } // medium
        if combinedLoad < 1.00 { return 0.85 } // heavy
        return 1.0                            // full load
    }()

    let effectiveLoad: Double = {
        if fanModel == .none && loadFactor < 0.3 { return 0.0 } // fanless at idle
        if loadFactor < 0.3 { return 12.6 } // just base + idle SoC
        let fanPower: Double = {
            switch fanModel {
            case .none: return 0.0
            case .single: return 3.0 * loadFactor
            case .dual: return 6.0 * loadFactor
            case .turbo: return 12.0 * loadFactor
            }
        }()
        // Simplified: SoC_TDP × effectiveLoad × memCoeff(1.0) + baseConsumption + fanPower
        // For this helper, use the loadFactor as effectiveLoad directly.
        return m2BaseSoCTDP * loadFactor + baseConsumption + fanPower
    }()

    return effectiveLoad // simplified approximation for test helper
}

final class PowerEstimatorTests: XCTestCase {

    // MARK: - M2 Base (default) at various loads — studio platform, dual fan

    func testM2BaseAtIdle() {
        // Continuous: effectiveLoad = 0.20 + 0.80×0 = 0.20, fan = 6×0 = 0
        // = 20 × 0.20 + 12 = 16W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 16.0, accuracy: 1.0, "M2 base at idle should be ~16W")
    }

    func testM2BaseAtFullLoad() {
        // SoC_TDP(20) × 1.0 + baseConsumption(12) + fanPower(dual=6×1.0=6W)
        // = 20 + 12 + 6 = 38.0W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 38.0, accuracy: 0.5, "M2 base at full load should be ~38W")
    }

    func testM2BaseAtHalfLoad() {
        // Combined = 0.5 → effectiveLoad = 0.20 + 0.80×0.5 = 0.60, fan = 6×0.5 = 3
        // SoC_TDP(20) × 0.60 + 12 + 3 = 12 + 12 + 3 = 27W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.5, gpuUtil: 0.5)
        XCTAssertEqual(watts, 27.0, accuracy: 1.0, "M2 base at half load should be ~27W")
    }

    // MARK: - M1 Pro at various loads

    func testM1ProAtHalfLoad() {
        // M1 Pro SoC_TDP = 30W, combined 0.5 → effectiveLoad 0.60, fan 6×0.5 = 3
        // 30 × 0.60 + 12 + 3 = 18 + 12 + 3 = 33W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m1Pro, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.5, gpuUtil: 0.5)
        XCTAssertEqual(watts, 33.0, accuracy: 2.0, "M1 Pro at half load should be ~33W")
    }

    func testM2ProAtIdle() {
        // M2 Pro groups with M1 Pro → SoC_TDP = 30W, effectiveLoad 0.20, fan 0
        // 30 × 0.20 + 12 = 18W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Pro, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 18.0, accuracy: 2.0, "M2 Pro at idle should be ~18W")
    }

    // MARK: - Light load (screen on, low utilization)

    func testLightLoad() {
        // Combined = 0.18 → effectiveLoad 0.20+0.144 = 0.344, fan 6×0.18 ≈ 1.1
        // SoC_TDP(20) × 0.344 + 12 + 1.1 ≈ 6.9 + 12 + 1.1 ≈ 20W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.2, gpuUtil: 0.15)
        XCTAssertEqual(watts, 20.0, accuracy: 2.0, "Light load should be ~20W")
    }

    // MARK: - Heavy load (high utilization)

    func testHeavyLoad() {
        // Combined = 0.88 → effectiveLoad 0.20+0.704 = 0.904, fan 6×0.88 ≈ 5.28
        // SoC_TDP(20) × 0.904 + 12 + 5.28 ≈ 18.1 + 12 + 5.28 ≈ 35.4W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.9, gpuUtil: 0.85)
        XCTAssertEqual(watts, 35.4, accuracy: 2.0, "Heavy load should be ~35W")
    }

    // MARK: - Screen off forces idle load factor

    func testScreenOffForcesIdleLoad() {
        // Even at 100% CPU/GPU, screen off forces load factor to 0.03
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: true)
        let estimator = PowerEstimator(profile: hwProfile)
        let wattsOff = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        let wattsOn = PowerEstimator(profile: HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)).estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertLessThan(wattsOff, wattsOn, "Screen off should drastically reduce wattage")
        XCTAssertEqual(wattsOff, 12.6, accuracy: 0.5) // Same as idle
    }

    // MARK: - Max and Ultra chips

    func testM1MaxAtFullLoad() {
        // M1 Max SoC_TDP = 56W, full load (1.0)
        // 56 + 12 + 6 = 74W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m1Max, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 74.0, accuracy: 2.0, "M1 Max at full load should be ~74W")
    }

    func testM2MaxAtHalfLoad() {
        // M2 Max SoC_TDP = 61W, combined 0.5 → effectiveLoad 0.60, fan 6×0.5 = 3
        // 61 × 0.60 + 12 + 3 = 36.6 + 12 + 3 ≈ 51.6W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Max, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.5, gpuUtil: 0.5)
        XCTAssertEqual(watts, 51.6, accuracy: 3.0, "M2 Max at half load should be ~51.6W")
    }

    func testM1UltraAtFullLoad() {
        // M1 Ultra SoC_TDP = 115W, full load (1.0)
        // 115 + 12 + 6 = 133W
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m1Ultra, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 133.0, accuracy: 2.0, "M1 Ultra at full load should be ~133W")
    }

    // MARK: - Laptop platform (lower base consumption)

    func testLaptopAtIdle() {
        // M2 Base, laptop platform (base=5W), light load (0.25)
        // 20 × 0.25 + 5 = 10W (fan off at <0.3 effectiveLoad)
        let hwProfile = HardwareProfile(
            platform: .laptop, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .single, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 10.0, accuracy: 1.0, "M2 base laptop at idle should be ~10W")
    }

    func testLaptopAtFullLoad() {
        // M2 Base, laptop (base=5W), single fan (3×1.0=3W)
        // 20 + 5 + 3 = 28W
        let hwProfile = HardwareProfile(
            platform: .laptop, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .single, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 28.0, accuracy: 2.0, "M2 base laptop at full load should be ~28W")
    }

    // MARK: - Fanless device (Mac mini M2)

    func testFanlessDeviceAtFullLoad() {
        // Fan model = none, SoC_TDP(20) × 1.0 + baseConsumption(5 for laptop, but mini is studio-like...
        // Actually Mac mini = studio platform? No — it has no battery, so detectPlatform() → .studio
        // But base consumption for studio = 12W. Let's use laptop since mini is small...
        // Actually, Mac mini has no battery → studio platform. base = 12W? That's too high for Mac mini.
        // For now, studio platform with no fan: 20 + 12 = 32W (base is higher for desktop)
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .none, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 32.0, accuracy: 3.0, "Fanless M2 base at full load should be ~32W")
    }

    // MARK: - Memory coefficient effect

    func testMemoryCoefficientIncreasesPower() {
        let hwProfile8GB = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false) // memCoeff = 1.0
        let hwProfile32GB = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 34_359_738_368,
            fanModel: .dual, screenOff: false) // memCoeff = 1.10

        let estimator8GB = PowerEstimator(profile: hwProfile8GB)
        let estimator32GB = PowerEstimator(profile: hwProfile32GB)

        // At full load with same chip, 32GB should consume more than 8GB
        let watts8 = estimator8GB.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        let watts32 = estimator32GB.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertGreaterThan(watts32, watts8, "32GB should consume more than 8GB at full load")
    }

    // MARK: - Ordering check (chip hierarchy)

    func testUltraMaxPowerGreaterThanBase() {
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592, fanModel: .dual, screenOff: false)
        let ultra = PowerEstimator(profile: hwProfile.m1Ultra())
        let base = PowerEstimator(profile: hwProfile.m2Base())
        let ultraWatts = ultra.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        let baseWatts = base.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertGreaterThan(ultraWatts, baseWatts, "Ultra max power should exceed Base max power")
    }

    // MARK: - Different chips produce different results at same load

    func testDifferentChipsProduceDifferentResults() {
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592, fanModel: .dual, screenOff: false)
        let base = PowerEstimator(profile: hwProfile.m2Base())
        let pro = PowerEstimator(profile: hwProfile.m2Pro())
        let max = PowerEstimator(profile: hwProfile.m2Max())

        // At medium load (0.5, 0.5 → combined=0.5 → medium(0.55))
        let watts = base.estimateSystemPower(from: 0.7, gpuUtil: 0.3)
        let proWatts = pro.estimateSystemPower(from: 0.7, gpuUtil: 0.3)
        let maxWatts = max.estimateSystemPower(from: 0.7, gpuUtil: 0.3)

        // All should be different and ordered base < pro < max
        XCTAssertNotEqual(watts, proWatts)
        XCTAssertNotEqual(proWatts, maxWatts)
        XCTAssertLessThan(watts, proWatts)
        XCTAssertLessThan(proWatts, maxWatts)
    }

    // MARK: - Utilization clamping (negative and over-1 values)

    func testClampsNegativeUtilization() {
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.estimateSystemPower(from: -0.5, gpuUtil: 1.0)
        // CPU clamped to 0 → combined = 0.4 → effectiveLoad 0.52, fan 6×0.4 = 2.4
        // 20 × 0.52 + 12 + 2.4 = 10.4 + 12 + 2.4 = 24.8W
        XCTAssertEqual(watts, 24.8, accuracy: 0.1, "Negative CPU should clamp to 0")
    }

    func testClampsOverOneUtilization() {
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        // CPU clamped to 1.0, GPU clamped to 1.0 → combined=1.0*0.6+1.0*0.4 = 1.0 → full load (1.0)
        let watts = estimator.estimateSystemPower(from: 1.5, gpuUtil: 2.0)
        XCTAssertEqual(watts, 38.0, accuracy: 2.0, "Over-1 values should clamp to full load")
    }

    // MARK: - Same profile for M1 and M2 base (same SoC_TDP)

    func testSameProfileForM1AndM2Base() {
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592, fanModel: .dual, screenOff: false)
        let m1 = PowerEstimator(profile: hwProfile.m1Base())
        let m2 = PowerEstimator(profile: hwProfile.m2Base())
        XCTAssertEqual(
            m1.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            m2.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            accuracy: 1.0,
            "M1 base and M2 base should produce identical results"
        )
    }

    func testSameProfileForM1AndM2Pro() {
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592, fanModel: .dual, screenOff: false)
        let m1 = PowerEstimator(profile: hwProfile.m1Pro())
        let m2 = PowerEstimator(profile: hwProfile.m2Pro())
        XCTAssertEqual(
            m1.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            m2.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            accuracy: 2.0,
            "M1 Pro and M2 Pro should produce identical results"
        )
    }

    func testSameProfileForM1AndM2Max() {
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592, fanModel: .dual, screenOff: false)
        let m1 = PowerEstimator(profile: hwProfile.m1Max())
        let m2 = PowerEstimator(profile: hwProfile.m2Max())
        XCTAssertEqual(
            m1.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            m2.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            accuracy: 2.0,
            "M1 Max and M2 Max should produce identical results"
        )
    }

    // MARK: - wholeSystemPower (measured SoC + modeled non-SoC offset)

    func testWholeSystemPowerStudioAddsBaseAndFan() {
        // Studio: base 12, fan dual 6×load. At full load: measured 30 + 12 + 6 = 48. No display.
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.wholeSystemPower(socWatts: 30.0, cpuUtil: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 48.0, accuracy: 0.01, "Studio whole-system = measured + base + fan")
    }

    func testWholeSystemPowerLaptopAddsDisplay() {
        // Laptop: base 5, fan dual 6×0 at idle, display 5. measured 8 + 5 + 0 + 5 = 18.
        let hwProfile = HardwareProfile(
            platform: .laptop, chipGeneration: .m4Max, ramSizeBytes: 137_438_953_472,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.wholeSystemPower(socWatts: 8.0, cpuUtil: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 18.0, accuracy: 0.01, "Laptop whole-system adds 5W display term")
    }

    func testWholeSystemPowerScreenOffDropsDisplayAndFan() {
        // Screen off: no display, no fan. Laptop base 5 only. measured 6 + 5 = 11.
        let hwProfile = HardwareProfile(
            platform: .laptop, chipGeneration: .m4Max, ramSizeBytes: 137_438_953_472,
            fanModel: .dual, screenOff: true)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.wholeSystemPower(socWatts: 6.0, cpuUtil: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 11.0, accuracy: 0.01, "Screen off drops display and fan, base only")
    }

    func testWholeSystemPowerClampsNegativeSoC() {
        // A bogus negative measured value is clamped to 0; only the offset remains.
        let hwProfile = HardwareProfile(
            platform: .studio, chipGeneration: .m2Base, ramSizeBytes: 8_589_934_592,
            fanModel: .dual, screenOff: false)
        let estimator = PowerEstimator(profile: hwProfile)
        let watts = estimator.wholeSystemPower(socWatts: -50.0, cpuUtil: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 12.0, accuracy: 0.01, "Negative SoC clamps to 0, base remains")
    }

}

// MARK: - Convenience extensions on HardwareProfile for tests

extension HardwareProfile {
    /// Create with M1 Base chip.
    func m1Base() -> HardwareProfile { new(chipGeneration: .m1Base) }
    /// Create with M2 Base chip.
    func m2Base() -> HardwareProfile { new(chipGeneration: .m2Base) }
    /// Create with M1 Pro chip.
    func m1Pro() -> HardwareProfile { new(chipGeneration: .m1Pro) }
    /// Create with M2 Pro chip.
    func m2Pro() -> HardwareProfile { new(chipGeneration: .m2Pro) }
    /// Create with M1 Max chip.
    func m1Max() -> HardwareProfile { new(chipGeneration: .m1Max) }
    /// Create with M2 Max chip.
    func m2Max() -> HardwareProfile { new(chipGeneration: .m2Max) }
    /// Create with M1 Ultra chip.
    func m1Ultra() -> HardwareProfile { new(chipGeneration: .m1Ultra) }

    private func new(
        platform: MacPlatform? = nil, chipGeneration: ChipGeneration? = nil,
        ramSizeBytes: Int64? = nil, fanModel: FanModel? = nil
    ) -> HardwareProfile {
        // Directly construct a new HardwareProfile with the specified overrides.
        return HardwareProfile(
            platform: platform ?? self.platform,
            chipGeneration: chipGeneration ?? self.chipGeneration,
            ramSizeBytes: ramSizeBytes ?? 8_589_934_592,
            fanModel: fanModel ?? self.fanModel,
            screenOff: self.screenOff)
    }

}
