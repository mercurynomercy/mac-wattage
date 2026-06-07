# Mac Wattage

A macOS menu bar app that tracks real-time system power consumption on MacBook / Mac Studio / Mac mini. It shows current wattage, session statistics, and monthly total energy — all drawn with native SwiftUI and **zero external dependencies**.

> 中文文档见 [README-zh.md](README-zh.md)。

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/language-Swift%206-orange)
![Chips](https://img.shields.io/badge/chips-M1%E2%80%93M5-purple)
![License](https://img.shields.io/badge/license-MIT-green)

> **How power is read:** Mac Wattage prefers **measured** SoC power from the private but no-root **IOReport "Energy Model"** counters (the same data `powermetrics` reports — CPU + GPU + ANE), then adds a modeled non-SoC offset to approximate whole-system power. When IOReport is unavailable, it automatically falls back to a TDP-based estimation model.

---

## Features

### Menu bar widget
A single-line wattage value (rounded font) in the menu bar, refreshed every collection cycle:

```
42W
```

### Popover dashboard (click the menu bar item)

> Built with `MenuBarExtra(...).menuBarExtraStyle(.window)` — content is hosted in a standalone window (not a native menu) so custom charts / gradients / Path drawing render correctly.

| Area | Content |
|------|---------|
| **Top bar** | Gear icon (top-left) opens Settings; power icon (top-right) quits the app |
| **Current power** | Large wattage readout + average / peak power over the last 120 seconds |
| **Live Power** | Real-time area chart of the last ~36 samples, **baseline anchored at 0 W** (bar height reflects absolute power, not min-to-max range) |
| **7-Day Power Consumption (kWh)** | Per-day kWh bar chart (green), X axis labeled by date (e.g. `Jun 7`), per-bar daily kWh on top, unit shown in the title |
| **Monthly Totals** | Cumulative kWh over the last 12 months as green bars |

### Settings window
- **Collection interval**: samples every `1 s` by default; adjustable in settings
- **Log directory**: customizable storage path via a file picker (default `~/Library/Application Support/Mac Wattage/`)
- **Launch at login**: registers the login item via `SMAppService.mainApp` (macOS 13+); the toggle reflects the live system registration state, staying in sync with *System Settings → Login Items*
- **Clear data**: wipes all logs in one click

---

## Architecture

```
┌─────────────────────────────────────────────┐
│              UI Layer (SwiftUI)             │
│  MenuBarWidgetView · PowerPopoverView       │
│  SettingsWindowView   Charts (Sparkline,    │
│                       BarChart, Monthly)    │
├─────────────────────────────────────────────┤
│           Scheduler (Timer-driven)          │
│  CollectionTimer ─→ collect() every N sec   │
├─────────────────────────────────────────────┤
│            Metrics Layer                    │
│  IOReportPowerReader (measured SoC power)   │
│  IOKitAdapter (CPU/GPU util)                │
│  PowerEstimator (measured+offset / TDP fb)  │
│  PlatformDetector (MacBook vs Studio, chip) │
├─────────────────────────────────────────────┤
│            Data Layer                       │
│  PowerLogService (journal-mode plist I/O)   │
│  RotationManager (monthly archive rotation) │
│  Store (UserDefaults settings persistence)  │
└─────────────────────────────────────────────┘
```

> **IOKit protocol split:** `IOKitAdapter.swift` holds only the pure protocols (`IOKitAdapterProtocol` / `SoCPowerReaderProtocol`, no Darwin/IOKit imports, compiles under SPM). The concrete `IOKitAdapter` (CPU/GPU utilization) lives in `IOKitImplementation.swift`, and `IOReportPowerReader` (measured power) in `IOReportPowerReader.swift`; both import Darwin / IOKit and are compiled only via the Xcode project.

---

## Power reading & estimation

Mac Wattage uses a **two-path strategy**: use the measured value when available, fall back to estimation when not.

### A) Measured path (preferred) — IOReport "Energy Model"

macOS exposes no public whole-machine wattage API, but Apple Silicon surfaces the same per-subsystem energy counters as `powermetrics` through the private **IOReport** framework — **without root** (this is what `macmon` / `asitop` use).

- Symbols are resolved at runtime via `dlopen("/usr/lib/libIOReport.dylib")` + `dlsym` (`IOReportCopyChannelsInGroup` / `IOReportCreateSubscription` / `IOReportCreateSamples` / `IOReportCreateSamplesDelta` and the channel accessors), so there are **no new dependencies**; the file is excluded from SPM (Xcode-only) alongside `IOKitImplementation.swift`.
- It subscribes to the **"Energy Model"** channel group, samples cumulative energy each cycle, and takes the delta between two samples: `power(W) = ΔEnergy(J) / Δt(s)`.
- Summing CPU / GPU / ANE (and any other energy channels present) yields the **measured SoC compute power** (equivalent to `powermetrics`' "Combined Power").
- Any failure (no baseline on the first sample, unsupported hardware, missing symbols) returns `nil`, automatically falling through to the TDP estimate below.

> **CF memory semantics:** `IOReportCopy*` / `IOReportCreate*` return +1 ownership — use `takeRetainedValue()`. The `IOReportChannelGet*` accessors (e.g. channel name / unit) return *borrowed* references and **must** use `takeUnretainedValue()`, otherwise an over-release crashes the app.

### Whole-system power = measured SoC + non-SoC offset

The measured path only covers the SoC compute portion (no display / SSD / fans), so `PowerEstimator.wholeSystemPower(socWatts:cpuUtil:gpuUtil:)` layers a modeled offset on top of the measured watts to approximate wall-socket draw:

```
whole-system = max(0, measuredSoC) + baseConsumption + fanPower + displayPower
fanPower     = screenOff ? 0 : fanWatts × combinedLoad      // scales continuously with load
displayPower = (laptop && screenOn) ? 5.0 : 0.0            // built-in panel; 0 on desktops
```

> Display and fan contributions drop to zero when the screen is off. The total is **"measured compute + modeled rest"**: display brightness and peripherals are approximated, not measured per-component.

### B) Estimation path (fallback) — continuous TDP model

When IOReport is unavailable, the app uses the following TDP-based (thermal design power) continuous model entirely.

### 1) Data collection

Hardware metrics are read each second via these system APIs:

| Data | macOS API / Source | Notes |
|------|-------------------|-------|
| CPU utilization | `host_statistics64(HOST_CPU_LOAD_INFO)` | Kernel returns cumulative ticks per CPU state (user/system/idle) since boot; busy ratio is computed from the delta between two reads. No entitlement, available on all macOS versions |
| GPU utilization | IOKit `IOAccelerator` → `PerformanceStatistics["Device Utilization %"]` | Real GPU usage (same source as Activity Monitor / iStat), max across all accelerators. Falls back to 0.0 when unavailable |
| Charging state / platform | `IOServiceMatching("AppleSmartBattery")` | Has battery → MacBook, none → Mac Studio/Mini; also returns charging state (laptops only) |
| Chip generation | `sysctl("machdep.cpu.brand_string")` | "M1 Ultra" / "M3 Max" etc., selects the TDP parameters |
| RAM size | `sysctl("hw.memsize")` | Determines the memory coefficient |
| Fan model | IOKit device tree `fan-backend-types` / `model` | none/single/dual/turbo, affects fan power estimate |
| Screen state | IOKit `AppleBacklightDisplay.DisplayPowerState` | 0 = off → forces deep-idle, fan power to zero |

### 2) Formula

```
combinedLoad  = 0.6 × clampedCPU + 0.4 × clampedGPU          // [0, 1]
effectiveLoad = screenOff ? 0.03 : 0.20 + 0.80 × combinedLoad // continuous, with a 0.20 idle floor
fanPower      = screenOff ? 0 : fanWatts × combinedLoad        // scales continuously with load
watts         = SoC_TDP × effectiveLoad × memoryCoefficient + baseConsumption + fanPower
```

**Key point:** both the load factor and fan power are **continuous functions** (not discrete steps), so wattage tracks CPU / GPU load smoothly without snapping between levels.

**Clamping & combined load:** CPU/GPU inputs are first clamped to `[0.0, 1.0]`, then weighted `60% CPU + 40% GPU` (CPU weighted higher).

**Effective load:** ramps linearly from a `0.20` idle floor (background baseline activity) up to `1.0` at full load. Screen off forces `0.03` deep idle.

### 3) SoC TDP table (full-load package power, CPU+GPU combined)

> Apple **never publishes official TDP** — these are community-measured estimates. Ultra ≈ 2× the corresponding Max (two fused dies). **M4 / M5 have no Ultra model.**

| Chip | Base | Pro | Max | Ultra |
|------|:----:|:---:|:---:|:-----:|
| **M1** | 20 | 30 | 57 | 115 |
| **M2** | 20 | 35 | 61 | 120 |
| **M3** | 20 | 35 | 78 | 160 |
| **M4** | 25 | 45 | 90 | — |
| **M5**¹ | 27 | 48 | 95 | — |

*Units: watts (W). ¹ M5 values are extrapolated ~+10% over M4; calibrate against measured data.*

### 4) Memory coefficient

More RAM → more memory controllers / bandwidth → higher power. Covers every factory config from 8GB to 512GB (M3 Ultra):

| RAM | Coeff | RAM | Coeff |
|----:|:----:|----:|:----:|
| 8 GB | 1.00 | 64 GB | 1.18 |
| 16 GB | 1.05 | 96 GB | 1.24 |
| 24 GB | 1.08 | 128 GB | 1.30 |
| 32 GB | 1.10 | 192 GB | 1.40 |
| 36 GB | 1.12 | 256 GB | 1.50 |
| 48 GB | 1.15 | 512 GB | 1.70 |

> Takes the **largest tier not exceeding the actual capacity** (e.g. 18GB uses the 16GB tier).

### 5) Base consumption — SSD + logic-board floor

| Platform | Value (W) |
|----------|:---------:|
| MacBook (laptop) | 5.0 |
| Mac Studio / Mac mini (desktop) | 12.0 |

### 6) Fan power — scales continuously with load

| Fan type | Full-load (W) | Actual draw |
|----------|:-------------:|-------------|
| none (fanless, e.g. M2 Air) | 0 | 0 |
| single | 3.0 | `3.0 × combinedLoad` |
| dual | 6.0 | `6.0 × combinedLoad` |
| turbo (turbo/liquid) | 12.0 | `12.0 × combinedLoad` |

> Fan power is forced to zero when the screen is off.

### Worked example (estimation path)

MacBook Pro **M1 Max**, CPU 60%, GPU 80%, 32 GB RAM, dual fans:

```
clampedCPU    = 0.60
clampedGPU    = 0.80
combinedLoad  = 0.6 × 0.60 + 0.4 × 0.80 = 0.68
effectiveLoad = 0.20 + 0.80 × 0.68      = 0.744
memoryCoeff   = 1.10                     // 32 GB
fanPower      = 6.0 × 0.68               = 4.08

watts = 57 × 0.744 × 1.10 + 5.0 (laptop) + 4.08
      = 46.65 + 5.0 + 4.08
      ≈ 55.7W
```

> **Note:** this is an *estimate*, not a measurement. Use it when the IOReport measured path is unavailable.

---

## Data persistence

- **Format**: BinaryPropertyList (`PropertyListEncoder` / `Decoder`, native and efficient)
- **Location**: default `~/Library/Application Support/Mac Wattage/`, changeable in settings
- **Write strategy**: journal-mode (write to a temp file, then atomic rename)
- **Monthly rotation**: `RotationManager` checks at **app launch** whether the month has changed (against `lastRotationMonth` in UserDefaults). On a month boundary it groups all records **before the current month** by `yyyy-MM`, folds them into monthly kWh totals in `monthly-log.plist`, then deletes those raw records from `daily-log.plist`
- **Raw retention**: **current calendar month only** — so actual retention floats between ~1–31 days (depending on the day of month). Monthly totals are kept indefinitely (UI shows the last 12 months)
- **Seconds buffer**: an in-memory rolling window of the last 120 records (~2 min at 1s interval) drives live average/peak and the sparkline; every 60 s it is aggregated into a single record written to `daily-log.plist`, keeping the log compact
- **kWh conversion**: each aggregated record represents ~1 minute of average watts, so `kWh = Σ(watts) / 60000`

---

## Tech stack

| Category | Choice |
|----------|--------|
| **Language** | Swift 6 (strict concurrency, Sendable / actors) |
| **UI** | SwiftUI + AppKit integration (MenuBarExtra `.window` style, macOS 13+) |
| **Hardware APIs** | IOReport (`Energy Model` measured energy, dlopen private framework) + IOKit (`host_statistics64`, `IOAccelerator`, `IOServiceMatching`, device tree) + sysctl |
| **Launch at login** | ServiceManagement `SMAppService` (macOS 13+) |
| **Storage** | BinaryPropertyList + UserDefaults |
| **Charts** | Pure SwiftUI `Path` / `Rectangle` / `Capsule`, no third-party libraries |

> **Why not `Canvas`?** `Canvas` doesn't render inside a `MenuBarExtra` popover, so the sparkline uses `GeometryReader` + `Path` instead.

---

## Build & run

### Via Xcode (recommended, runs on real hardware)
```bash
open MacWattage.xcodeproj
```
1. Select the **Mac Wattage** scheme
2. Build & Run (⌘R)

> UI files plus `IOKitImplementation.swift` / `IOReportPowerReader.swift` are excluded from SPM (`@main` conflict / need IOKit), so the **full app only builds & runs via the Xcode project**.

### Via build.sh (quick command-line build)
```bash
# Compile and output to dist/, runnable from any directory:
./build.sh

# The build product is at dist/MacWattage.app:
open dist/MacWattage.app
```

> `build.sh` uses the Debug configuration, switches to the project root, and creates dist/ if missing. It locates the product in DerivedData and copies it to `dist/`.

### Via Swift Package Manager (core library + tests only)
```bash
# Compile the core library (UI files are SPM-excluded)
swift build

# Run all unit tests
swift test

# Run a single test class
swift test --filter MacWattageTests.PowerEstimatorTests

# Run a single case
swift test --filter MacWattageTests.PowerEstimatorTests/testM2BaseAtIdle
```

### Minimum requirements
- **macOS**: 13 Ventura (MenuBarExtra API)
- **Architecture**: Apple Silicon (ARM64) only — M1 / M2 / M3 / M4 / M5, including Pro / Max / Ultra; **no Intel support**

---

## Test coverage

```bash
swift test   # 48 tests, all passing ✅
```

| Test module | Cases | Coverage |
|-------------|:-----:|----------|
| PowerEstimatorTests | 26 | TDP model (continuous formula, effectiveLoad / memory coefficient / fan power), chip-generation ordering & comparison, boundary clamping (negative / >1.0), screen-off forced idle, `wholeSystemPower` measured+offset (base/fan/display, negative clamping, screen off) |
| PowerLogServiceTests | 14 | Appending records, session stats (120s window), daily averages, clear-all, file persistence, seconds-buffer flush |
| PlatformDetectorTests | 2 | Platform detection / chip identification (runtime checks) |
| RotationManagerTests | 2 | Cross-month rotation trigger / same-month skip |
| StoreTests | 5 | UserDefaults defaults (interval defaults to 1s) / persistence read-write / LogDirectory |
| Mocks | — | MockUserDefaults, MockPowerLogService |

---

## License

MIT
