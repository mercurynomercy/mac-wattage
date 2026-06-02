# Mac Wattage — Requirements Proposal

## 1. Overview

**Mac Wattage** is a macOS menu bar app that tracks system power consumption in real time. It displays current wattage, session statistics, and historical charts — all accessible from the menu bar popover. The app supports both Mac Studio (desktop, no battery) and MacBook models with battery, adapting the display accordingly.

---

## 2. Key Features

### Menu Bar Widget
- **Current watts** — prominently displayed (e.g., "42W")
- **Session stats** — average and peak wattage since login or app launch
- **Sparkline chart** — small visual trend of recent power consumption

### Popover Dashboard (click menu bar item to open)
1. **Current watts** — large display with session avg/peak below it
2. **7-day chart** — daily average power consumption bar/sparkline chart (30 data points)
3. **Monthly totals** — simple 12-month bar chart showing total kWh per month (e.g., "Jan: 30kWh")

### Data Collection
- **Default frequency**: every 10 seconds
- **Configurable**: user can change collection interval to per-minute via settings

### Platform Support
| Feature | Mac Studio (Desktop) | MacBook |
|---------|---------------------|---------|
| System power (watts) | Yes | Yes |
| Charging/discharging rate | N/A | Included in system power display |

---

## 3. Tech Stack

| Category | Choice |
|----------|--------|
| Language | Swift 6.0+ (with strict concurrency) |
| UI Framework | SwiftUI + AppKit integration where needed |
| Menu Bar Integration | `MenuBarExtra` (macOS 13+) |
| Data Storage | File-based log + `UserDefaults` for settings |
| Chart Rendering | Custom SwiftUI (no external charting library) |
| Build Tool | Xcode (native Swift project template) |

**Zero external dependencies.** No Node.js, Python, or other runtime requirements.

---

## 4. UI Design

### Menu Bar Item
```
[⚡ 42W]   ← current watts with small sparkline trail behind it
```

### Popover Layout (click to open)
```
┌───────────────────────────────┐
│                               │
│         42W                   │  ← large current watts display
│     Avg: 38W · Peak: 65W      │  ← session statistics
│                               │
├───────────────────────────────┤
│ 7-Day Power Consumption       │  ← daily average chart (bars)
│ [▮][▮▮][▮ ][▮▮▮]...          │
│                               │
├───────────────────────────────┤
│ Monthly Totals                │  ← monthly bar chart (12 months)
│ Jan: 30kWh                    │
│ Feb: 28kWh                    │
│ ...                           │
│                               │
├───────────────────────────────┤
│ ⚙ Settings                    │  ← link to settings window / popover
└───────────────────────────────┘
```

### Settings (separate window or settings popover)
- Collection interval: 10s / per minute toggle
- Log file location picker (default to `~/Library/Application Support/Mac Wattage/`)
- Clear all logs button

---

## 5. Data Storage & Format

### Log File
- **Format**: `BinaryPropertyList (.plist)` — most efficient native macOS format, compact and fast to read/write
- **Schema**: Array of timestamped records:

```swift
struct PowerRecord: Codable {
    let timestamp: Date        // ISO 8601
    let watts: Double          // system power in watts
    #if canImport(Battery) || hasBattery
    let isCharging: Bool       // MacBook only (auto-detected at runtime)
    #endif
}

// Stored as: [PowerRecord] in a single plist file
```

### Storage Location
- **Default**: `~/Library/Application Support/Mac Wattage/power-log.plist`
- **User configurable**: user can choose any directory via file picker in settings

### Settings (UserDefaults)
- `collectionInterval`: 10 or 60 seconds
- `logFilePath`: user-defined path string

### Data Retention & Cleanup
- App retains up to **30 days** of 10-second interval data (~25,920 records)
- App retains full **6 months** of monthly aggregated data (12 bars/month × ~3 years = 36 records)
- **Clear all logs** button in settings wipes the log file

### Data Aggregation Strategy
| View | Granularity | Points | Storage Method |
|------|------------|--------|----------------|
| Menu bar sparkline | 10-second samples | ~36 (last 6 min) | In-memory ring buffer |
| Session stats | All samples since login/launch | Variable | Computed on demand (avg, max) |
| 7-day chart | Daily averages of raw data | ~30 daily points (one per day) | Computed from raw data at render time (no separate storage) |
| Monthly totals | Per-month kWh sum | Up to 12 bars (most recent) | Computed from raw data at render time, cached in memory |

> **Note**: Monthly totals are computed on-demand from the raw log file and cached in memory. No separate aggregation table is stored — this avoids data duplication while keeping rendering fast (monthly computation happens once per view open).

---

## 6. Power Metrics API Strategy

### Apple Silicon (M-series, including Mac Studio)
macOS does not expose a direct "system total watts" API. The approach:

1. **Estimate system power from utilization**
   - Use `IOPowerSourcesCopyPowerSourceInfo()` and IOKit to read available hardware power sensors (on models that expose them)
   - On Apple Silicon, derive estimates from:
     - CPU utilization (`host_processor_info` / `mach_host_vm_statistics`) × known Apple Silicon TDP curves
     - GPU utilization (Metal performance queries or `IOServiceGetMatchingServices` for GPU power)
     - Base system idle power (known constant per chip generation: ~3W M1, ~5W M2, etc.)

2. **Fallback estimation** (if hardware sensors unavailable)
   - CPU power = `cpuUsage * cpuMaxTDP + idlePower`
     - M1/M2 base: ~3-5W idle, up to 40-60W under load
     - M1/M2 Pro/Max/Ultra: ~5-8W idle, up to 60-120W under load
   - GPU power estimate from Metal/GPU utilization queries

3. **Runtime detection** (Mac Studio vs MacBook)
   - Check `IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleSmartBattery"))`
   - If a battery service exists → MacBook mode (show charging/discharging)
   - Otherwise → Mac Studio/Desktop mode

### Key APIs Used (all Apple-provided, no third-party)
| API | Purpose |
|-----|---------|
| `IOPowerSources.h` (IOKit) | Battery info, power source state |
| `host_processor_info()` (mach) | CPU utilization stats |
| Metal Performance Queries | GPU utilization |
| `ProcessInfo` (Foundation) | General system state |

---

## 7. Implementation Phases

### Phase 1 — Core Data Collection
- IOKit integration for hardware power sensors (best-effort)
- CPU utilization reading via mach APIs
- GPU utilization estimation framework
- Power record creation and plist file I/O

### Phase 2 — Menu Bar Widget
- `MenuBarExtra` setup with macOS minimum target (macOS 13 Ventura)
- Current watts display + sparkline rendering in SwiftUI
- Session avg/peak computation

### Phase 3 — Popover Dashboard
- Power consumption popover with all three sections: current watts, 7-day chart, monthly totals
- Custom SwiftUI bar/sparkline charts (no external libraries)

### Phase 4 — Settings & Data Management
- Collection interval toggle in settings (10s / per minute)
- File picker for log location configuration
- Clear all logs functionality

### Phase 5 — Platform Adaptation & Polish
- Auto-detect MacBook vs desktop and show/hide battery-related info accordingly
- Charging/discharging rate display for MacBooks
- App icon, menu bar icons (light & dark mode)

---

## 8. Minimum System Requirements
- **macOS**: 13 Ventura (for `MenuBarExtra` API)
- **Architecture**: Apple Silicon only (M1/M2 series, including Pro/Max/Ultra)
- **Storage**: ~50MB max for 30 days of log data (at default collection interval)
