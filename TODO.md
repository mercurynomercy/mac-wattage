# TODO

## MacPlatform: add `.mini` and `.pro` cases

`MacPlatform` currently has only `.laptop` and `.studio`, which maps all non-laptop Macs
(Mac mini, Mac Studio, Mac Pro) to the same 12 W base consumption. The correct values are:

| Platform    | Base consumption |
|-------------|-----------------|
| Mac mini    | 8 W             |
| Mac Studio  | 12 W            |
| Mac Pro     | 20 W            |

### What needs to change

1. **`MacPlatform` enum** (`PlatformDetector.swift`) — add `.mini` and `.pro` cases.
2. **`baseConsumption` switch** (`PowerEstimator.swift`) — add cases for `.mini` (8 W) and `.pro` (20 W).
3. **IOKit detection logic** (`PlatformDetector.detectPlatform()`) — distinguish Mac mini from
   Mac Studio using a hardware identifier (e.g., `hw.model` sysctl: `"Mac14,3"` is Mac mini M2,
   `"Mac13,1"` is Mac Studio M1, `"MacPro7,1"` is Mac Pro).
4. **`PlatformDetectorTests`** — add cases for `.mini` and `.pro` in the exhaustive switch.
5. **`PowerEstimatorTests`** — update `testFanlessDeviceAtFullLoad` to use `.mini` platform
   (8 W base → 20 + 8 = 28 W at full load, no fan) once `.mini` exists.
