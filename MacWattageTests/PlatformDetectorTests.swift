import XCTest
@testable import MacWattage

final class PlatformDetectorTests: XCTestCase {

    func testDetectPlatformReturnsValidValue() {
        // detectPlatform reads AppleSmartBattery IOKit service.
        // On a MacBook it returns .laptop, on desktop (Mac Studio) it returns .studio.
        // We just verify the method doesn't crash and returns a valid enum case.
        let platform = PlatformDetector.detectPlatform()
        switch platform {
        case .studio, .laptop:
            break // Valid enum cases
        }
    }

    func testDetectChipGenerationReturnsValidValue() {
        // detectChipGeneration reads machdep.cpu.brand_string via sysctlbyname.
        // We verify it doesn't crash and returns a valid ChipGeneration case.
        let chip = PlatformDetector.detectChipGeneration()
        switch chip {
        case .m1Base, .m2Base, .m3Base, .m4Base, .m5Base,
             .m1Pro,  .m2Pro,  .m3Pro,  .m4Pro,  .m5Pro,
             .m1Max,  .m2Max,  .m3Max,  .m4Max,  .m5Max,
             .m1Ultra, .m2Ultra, .m3Ultra:
            break // Valid enum cases
        }
    }

}
