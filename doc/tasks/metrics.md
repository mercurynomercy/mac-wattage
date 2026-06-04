# Metrics Layer — Task List

## A1: IOKitAdapterProtocol + Implementation

- [x] Define `IOKitAdapterProtocol` in `Metrics/IOKitAdapter.swift`:
  - [x] `func cpuUtilization() -> Double` — CPU usage fraction [0.0, 1.0]
  - [x] `func gpuUtilization() -> Double` — GPU usage fraction [0.0, 1.0]
  - [x] `func isCharging() -> Bool?` — nil for desktop Macs
  - [x] `func batteryLevel() -> Double?` — nil for desktop, fraction [0.0, 1.0]
- [x] Implement `IOKitAdapter` concrete class:
  - [x] `cpuUtilization()`: use `host_processor_info()` with `PROCESSOR_CPU_LOAD_INFO`
    - Calculate total vs idle time across all cores
    - Return `1.0 - (idle / total)` clamped to [0.0, 1.0]
    - Return `0.0` if mach call fails (never throw)
  - [x] `gpuUtilization()`: use IOService matching for GPU device (returns 0.0 as conservative fallback)
    - Return `0.0` if GPU service not found (fallback)
  - [x] `isCharging()`: detect AppleSmartBattery, return true if present (nil for desktop)
  - [x] `batteryLevel()`: detect AppleSmartBattery, return nil for desktop

## A2: PowerEstimatorProtocol + Implementation

- [x] Define `PowerEstimatorProtocol` in `Metrics/PowerEstimator.swift`:
  - [x] `func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double`
- [x] Define `ChipGeneration` enum (m1Base, m2Base, m1Pro, m2Pro, m1Max, m2Max, m1Ultra)
- [x] Define chip profiles with per-chip constants:
  - Base: idle=5W, cpuMax=40W, gpuMax=15W
  - Pro: idle=8W, cpuMax=60W, gpuMax=30W
  - Max: idle=12W, cpuMax=100W, gpuMax=60W
  - Ultra: idle=15W, cpuMax=120W, gpuMax=80W
- [x] Implement TDP-based estimation (fallback):
  - Formula: `idlePower + cpuUtil × (cpuMaxPower - idlePower) + gpuUtil × gpuMaxPower`
- [x] Implement chip profile selection based on `ChipGeneration`

## A3: PlatformDetector

- [x] Define `MacPlatform` enum (`.studio`, `.laptop`)
- [x] Implement `detectPlatform()`:
  - Use `IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))`
  - Return `.laptop` if battery service found, `.studio` otherwise
- [x] Implement `detectChipGeneration()`:
  - Use `sysctlbyname("machdep.cpu.brand_string")` to read CPU string
  - Parse for "Ultra", "Max", "Pro" keywords and M1/M2 prefix
  - Default to `.m2Base` if detection fails

## Dependencies Between Subtasks

```
A1 (IOKitAdapter) ← A3 (PlatformDetector for chip gen in estimator)
A2 (PowerEstimator) ← A1, A3 both needed for full pipeline
```
