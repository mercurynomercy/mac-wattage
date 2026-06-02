# Scheduler — Task List

## D1: CollectionTimer

- [ ] Create `CollectionTimer` in `Scheduler/CollectionTimer.swift`:
  - [ ] Properties:
    - [ ] `private var timer: Timer?`
    - [ ] `private let interval: Int` (seconds)
    - [ ] `private let metrics: IOKitAdapterProtocol`
    - [ ] `private let estimator: PowerEstimatorProtocol`
    - [ ] `private let logService: PowerLogServiceProtocol`
    - [ ] `private let uiUpdate: @MainActor (PowerRecord) -> Void`
    - [ ] `private let collectQueue: DispatchQueue` (label: "com.macwattage.scheduler.collect", qos: .userInitiated)
  - [ ] `init(interval:metrics:estimator:logService:uiUpdate:)`: store all dependencies
  - [ ] `start()`:
    - [ ] Call `collect()` immediately (no delay on first tick)
    - [ ] Schedule repeating Timer: `Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true)`
    - [ ] Timer target calls `collect()` on each fire
  - [ ] `stop()`:
    - [ ] `timer?.invalidate()`
    - [ ] `timer = nil`
  - [ ] `collect()` (private method):
    - [ ] Dispatch to `collectQueue`:
      - [ ] `let cpuUtil = metrics.cpuUtilization()`
      - [ ] `let gpuUtil = metrics.gpuUtilization()`
      - [ ] `let watts = estimator.estimateSystemPower(from: cpuUtil, gpuUtil: gpuUtil)`
      - [ ] Create `PowerRecord(id: UUID(), timestamp: Date(), watts: watts, isCharging: metrics.isCharging())`
      - [ ] `Task { @MainActor in try? await logService.append(record) }` (async write, ignore errors)
      - [ ] `DispatchQueue.main.async { uiUpdate(record) }` (UI update on main thread)

## Dependencies Between Subtasks

```
D1 (CollectionTimer) → A1 (IOKitAdapter), A2 (PowerEstimator), B2 (PowerLogService)
```
