import XCTest
@testable import MacWattage

final class PowerEstimatorTests: XCTestCase {

    // MARK: - M2 Base (default) at various loads

    func testM2BaseAtIdle() {
        // idle: 5W, cpuMax: 40W, gpuMax: 15W
        // Formula: idle + cpuUtil*(cpuMax-idle) + gpuUtil*gpuMax
        // = 5 + 0*(40-5) + 0*15 = 5W
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m2Base)
        let watts = estimator.estimateSystemPower(from: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 5.0, accuracy: 0.1, "M2 base at idle should be ~5W")
    }

    func testM2BaseAtFullLoad() {
        // = 5 + 1.0*(40-5) + 1.0*15 = 5 + 35 + 15 = 55W
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m2Base)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 55.0, accuracy: 0.1, "M2 base at full load should be ~55W")
    }

    func testM2BaseAtHalfLoad() {
        // = 5 + 0.5*(40-5) + 0.5*15 = 5 + 17.5 + 7.5 = 30W
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m2Base)
        let watts = estimator.estimateSystemPower(from: 0.5, gpuUtil: 0.5)
        XCTAssertEqual(watts, 30.0, accuracy: 0.1, "M2 base at half load should be ~30W")
    }

    // MARK: - M1 Pro at various loads

    func testM1ProAtHalfLoad() {
        // Pro: idle=8, cpuMax=60, gpuMax=30
        // = 8 + 0.5*(60-8) + 0.5*30 = 8 + 26 + 15 = 49W
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m1Pro)
        let watts = estimator.estimateSystemPower(from: 0.5, gpuUtil: 0.5)
        XCTAssertEqual(watts, 49.0, accuracy: 0.1, "M1 Pro at half load should be ~49W")
    }

    func testM2ProAtIdle() {
        // Pro: idle=8W at 0% load
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m2Pro)
        let watts = estimator.estimateSystemPower(from: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 8.0, accuracy: 0.1, "M2 Pro at idle should be ~8W")
    }

    // MARK: - Max and Ultra chips

    func testM1MaxAtFullLoad() {
        // Max: idle=12, cpuMax=100, gpuMax=60
        // = 12 + 1.0*(100-12) + 1.0*60 = 12 + 88 + 60 = 160W
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m1Max)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 160.0, accuracy: 0.1, "M1 Max at full load should be ~160W")
    }

    func testM2MaxAtHalfLoad() {
        // Max: idle=12, cpuMax=100, gpuMax=60
        // = 12 + 0.5*(100-12) + 0.5*60 = 12 + 44 + 30 = 86W
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m2Max)
        let watts = estimator.estimateSystemPower(from: 0.5, gpuUtil: 0.5)
        XCTAssertEqual(watts, 86.0, accuracy: 0.1, "M2 Max at half load should be ~86W")
    }

    func testM1UltraAtFullLoad() {
        // Ultra: idle=15, cpuMax=120, gpuMax=80
        // = 15 + 1.0*(120-15) + 1.0*80 = 15 + 105 + 80 = 200W
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m1Ultra)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertEqual(watts, 200.0, accuracy: 0.1, "M1 Ultra at full load should be ~200W")
    }

    // MARK: - Ordering check

    func testUltraMaxPowerGreaterThanBase() {
        let ultra = PowerEstimator(platform: .studio, chipGeneration: .m1Ultra)
        let base = PowerEstimator(platform: .studio, chipGeneration: .m1Base)
        let ultraWatts = ultra.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        let baseWatts = base.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        XCTAssertGreaterThan(ultraWatts, baseWatts, "Ultra max power should exceed Base max power")
    }

    // MARK: - Different chips produce different results

    func testDifferentChipsProduceDifferentResults() {
        let base = PowerEstimator(platform: .studio, chipGeneration: .m2Base)
        let pro = PowerEstimator(platform: .studio, chipGeneration: .m2Pro)
        let max = PowerEstimator(platform: .studio, chipGeneration: .m2Max)
        let ultra = PowerEstimator(platform: .studio, chipGeneration: .m1Ultra)

        let watts = base.estimateSystemPower(from: 0.7, gpuUtil: 0.3)
        let proWatts = pro.estimateSystemPower(from: 0.7, gpuUtil: 0.3)
        let maxWatts = max.estimateSystemPower(from: 0.7, gpuUtil: 0.3)
        let ultraWatts = ultra.estimateSystemPower(from: 0.7, gpuUtil: 0.3)

        // All should be different at same utilization
        XCTAssertNotEqual(watts, proWatts)
        XCTAssertNotEqual(proWatts, maxWatts)
        XCTAssertNotEqual(maxWatts, ultraWatts)

        // And ordered correctly: base < pro < max < ultra
        XCTAssertLessThan(watts, proWatts)
        XCTAssertLessThan(proWatts, maxWatts)
        XCTAssertLessThan(maxWatts, ultraWatts)
    }

    // MARK: - Utilization clamping

    func testClampsNegativeUtilization() {
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m2Base)
        let watts = estimator.estimateSystemPower(from: -0.5, gpuUtil: 1.0)
        // Should clamp cpu to 0.0: = 5 + 0*(40-5) + 1*15 = 20W
        XCTAssertEqual(watts, 20.0, accuracy: 0.1)
    }

    func testClampsOverOneUtilization() {
        let estimator = PowerEstimator(platform: .studio, chipGeneration: .m2Base)
        let watts = estimator.estimateSystemPower(from: 1.5, gpuUtil: -0.3)
        // Should clamp cpu to 1.0 and gpu to 0.0: = 5 + 35*1.0 + 0 = 40W
        XCTAssertEqual(watts, 40.0, accuracy: 0.1)
    }

    // MARK: - Platform detection affects profile for base chips (m1Base vs m2Base same)

    func testSameProfileForM1AndM2Base() {
        let m1 = PowerEstimator(platform: .studio, chipGeneration: .m1Base)
        let m2 = PowerEstimator(platform: .studio, chipGeneration: .m2Base)
        XCTAssertEqual(
            m1.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            m2.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            accuracy: 0.1,
            "M1 base and M2 base should produce identical results"
        )
    }

    func testSameProfileForM1AndM2Pro() {
        let m1 = PowerEstimator(platform: .studio, chipGeneration: .m1Pro)
        let m2 = PowerEstimator(platform: .studio, chipGeneration: .m2Pro)
        XCTAssertEqual(
            m1.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            m2.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            accuracy: 0.1,
            "M1 Pro and M2 Pro should produce identical results"
        )
    }

    func testSameProfileForM1AndM2Max() {
        let m1 = PowerEstimator(platform: .studio, chipGeneration: .m1Max)
        let m2 = PowerEstimator(platform: .studio, chipGeneration: .m2Max)
        XCTAssertEqual(
            m1.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            m2.estimateSystemPower(from: 0.5, gpuUtil: 0.3),
            accuracy: 0.1,
            "M1 Max and M2 Max should produce identical results"
        )
    }

}
