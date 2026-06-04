# Scheduler — Task List

## D1: CollectionTimer

- [x] Create `CollectionTimer` in `Scheduler/CollectionTimer.swift`:
  - [x] Properties:
    - [x] `private var timer: Timer?`
    - [x] `private let interval: Int` (seconds)
    - [x] `private let metrics: IOKitAdapterProtocol`
    - [x] `private let estimator: PowerEstimatorProtocol`
    - [x] `private let logService: PowerLogServiceProtocol`
    - [x] `private let uiUpdate: @MainActor (PowerRecord) -> Void`
    - [x] `private let collectQueue: DispatchQueue` (label: "com.macwattage.scheduler.collect", qos: .userInitiated)
  - [x] `init(interval:metrics:estimator:logService:uiUpdate:)`: store all dependencies
  - [x] `start()`:
    - [x] Call `collect()` immediately (no delay on first tick)
    - [x] Schedule repeating Timer: `Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true)`
    - [x] Timer target calls `collect()` on each fire (via weak TimerTarget to avoid retain cycles)
  - [x] `stop()`:
    - [x] `timer?.invalidate()`
    - [x] `timer = nil` (also clears timerTarget weak reference)
  - [x] `collect()` / `doCollect()`:
    - [x] Dispatch to `collectQueue`:
      - [x] Read CPU and GPU utilization from metrics adapter (returns 0.0 on failure)
      - [x] Estimate watts using power estimator with clamped utilization values
      - [x] Create `PowerRecord` (isCharging from metrics adapter — nil for desktop)
      - [x] `Task { try? await logService.append(record) }` (async write, ignore errors)
      - [x] `DispatchQueue.main.async { uiUpdate(record) }` (UI update on main thread)

## Dependencies Between Subtasks

```
D1 (CollectionTimer) → A1 (IOKitAdapter), A2 (PowerEstimator), B2 (PowerLogService)
```
