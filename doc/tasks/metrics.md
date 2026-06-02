# Metrics Layer — Task List

## A1: IOKitAdapterProtocol + Implementation

- [ ] Define `IOKitAdapterProtocol` in `Metrics/IOKitAdapter.swift`:
  - [ ] `func cpuUtilization() -> Double` — CPU usage fraction [0.0, 1.0]
  - [ ] `func gpuUtilization() -> Double` — GPU usage fraction [0.0, 1.0]
  - [ ] `func isCharging() -> Bool?` — nil for desktop Macs
  - [ ] `func batteryLevel() -> Double?` — nil for desktop, fraction [0.0, 1.0]
- [ ] Implement `IOKitAdapter` concrete class:
  - [ ] `cpuUtilization()`: use `host_processor_info()` with `PROCESSOR_CPU_LOAD_INFO`
    - Calculate total vs idle time across all cores
    - Return `1.0 - (idle / total)` clamped to [0.0, 1.0]
    - Return `0.0` if mach call fails (never throw)
  - [ ] `gpuUtilization()`: use Metal Performance Queries or IOService matching
    - Return `0.0` if GPU service not found (fallback)
  - [ ] `isCharging()`: use `IOPowerSourcesCopyPowerSourceInfo()`
    - Read `kIOPowerSourcesInfoExternalConnectedKeyName`
    - Return nil if power source info unavailable
  - [ ] `batteryLevel()`: use `IOPowerSourcesCopyPowerSourceInfo()`
    - Read `kIOPowerSourcesInfoBatteryPercentKeyName` and divide by 100
    - Return nil if unavailable

## A2: PowerEstimatorProtocol + Implementation

- [ ] Define `PowerEstimatorProtocol` in `Metrics/PowerEstimator.swift`:
  - [ ] `func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double`
- [ ] Define `ChipGeneration` enum (m1Base, m2Base, m1Pro, m2Pro, m1Max, m2Max, m1Ultra)
- [ ] Define `ChipProfile` struct with per-chip constants:
  - Base: idle=3W, cpuMax=40W, gpuMax=15W
  - Pro: idle=5W, cpuMax=60W, gpuMax=30W
  - Max: idle=8W, cpuMax=100W, gpuMax=60W
  - Ultra: idle=10W, cpuMax=120W, gpuMax=80W
- [ ] Implement hardware sensor reading path (primary):
  - Read from IOKit power sensors via SMC interface
  - Return `(watts: Double, sensorAvailable: Bool)` tuple
- [ ] Implement TDP-based estimation (fallback):
  - Formula: `idlePower + cpuUtil × (cpuMaxPower - idlePower) + gpuUtil × gpuMaxPower`
- [ ] Implement chip profile selection based on `ChipGeneration`
- [ ] Default to M2 base if chip detection fails

## A3: PlatformDetector

- [ ] Define `MacPlatform` enum (`.studio`, `.laptop`)
- [ ] Implement `detectPlatform()`:
  - Use `IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))`
  - Return `.laptop` if battery service found, `.studio` otherwise
- [ ] Implement `detectChipGeneration()`:
  - Use `sysctlbyname("machdep.cpu.brand_string")` to read CPU string
  - Parse for "Ultra", "Max", "Pro" keywords and M1/M2 prefix
  - Default to `.m2Base` if detection fails

## Dependencies Between Subtasks

```
A1 (IOKitAdapter) ← A3 (PlatformDetector for chip gen in estimator)
A2 (PowerEstimator) ← A1, A3 both needed for full pipeline
```
