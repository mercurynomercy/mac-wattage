# Mac Wattage — Progress Tracker

## Module Status Overview

| Module | File | Overall Progress |
|--------|------|-----------------|
| Metrics Layer | [metrics.md](./metrics.md) | 0/17 tasks |
| Data Layer | [data.md](./data.md) | 0/25 tasks |
| UI Layer | [ui.md](./ui.md) | 0/29 tasks |
| Scheduler | [scheduler.md](./scheduler.md) | 0/5 tasks |
| Shared | [shared.md](./shared.md) | 0/2 tasks |
| Tests | [tests.md](./tests.md) | 0/13 tasks |

**Total**: 0 / 91 tasks complete (0%)

---

## Module Breakdown

### Metrics Layer — [metrics.md](./metrics.md)
- A1: IOKitAdapterProtocol + Implementation — 0/8 tasks
- A2: PowerEstimatorProtocol + Implementation — 0/6 tasks  
- A3: PlatformDetector — 0/3 tasks

### Data Layer — [data.md](./data.md)
- B1: PowerRecord Models + Supporting Types — 0/4 tasks
- B2: PowerLogServiceProtocol + Implementation — 0/13 tasks
- B3: RotationManager — 0/6 tasks
- B4: Store — 0/5 tasks

### UI Layer — [ui.md](./ui.md)
- C1: App Entry Point — 0/7 tasks
- C2: MenuBarWidgetView + ViewModel — 0/6 tasks
- C3: PowerPopoverView + ViewModel — 0/12 tasks
- C4: SettingsWindowView — 0/9 tasks
- C5: Charts (Sparkline, BarChart, MonthlyTotals) — 0/6 tasks
- C6: AppDelegate — 0/3 tasks

### Scheduler — [scheduler.md](./scheduler.md)
- D1: CollectionTimer — 0/5 tasks

### Shared — [shared.md](./shared.md)
- E1: Logger Utility — 0/2 tasks

### Tests — [tests.md](./tests.md)
- F1: XCTest Target Setup — 0/2 tasks
- F2: PowerEstimatorTests — 0/6 tasks
- F3: PlatformDetectorTests — 0/2 tasks
- F4: PowerLogServiceTests — 0/6 tasks
- F5: RotationManagerTests — 0/2 tasks
- F6: StoreTests — 0/3 tasks

---

## Recommended Build Order

Build modules in dependency order to ensure each module can be tested independently:

1. **E (Shared)** — Logger utility, no dependencies
2. **A (Metrics Layer)** — IOKitAdapter → PowerEstimator → PlatformDetector
3. **B (Data Layer)** — Models → Service → RotationManager → Store  
4. **F (Tests for A+B)** — Unit tests for Metrics and Data modules
5. **D (Scheduler)** — CollectionTimer, depends on A + B
6. **C5 (Charts)** — UI chart components, no dependencies
7. **F1-F6 (Tests for C+D)** — Tests that depend on other modules
8. **C1-C4, C6 (UI Layer)** — App entry point → widgets → popover → settings

Each module can be tested in isolation once its dependencies are complete.
UI modules should be manually verified visually after all tasks pass.
