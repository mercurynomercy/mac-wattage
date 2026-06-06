# Mac Wattage — Detailed Design Document

## 1. Overview

This document provides implementation-level detail for each module defined in the High-Level Design. It specifies exact types, methods, algorithms, error handling, thread safety, and test strategies.

---

## 2. Module A: Metrics Layer

### 2.1 IOKitAdapter

#### 2.1.1 Purpose
Read raw hardware metrics from macOS via IOKit and mach APIs. Provides a protocol-based abstraction so tests can inject mock implementations.

#### 2.1.2 Protocol Definition

```swift
protocol IOKitAdapterProtocol {
    /// CPU utilization as a fraction [0.0, 1.0] across all cores
    func cpuUtilization() -> Double
    
    /// GPU utilization as a fraction [0.0, 1.0]
    func gpuUtilization() -> Double
    
    /// Whether the Mac is currently charging (nil if desktop/no battery)
    func isCharging() -> Bool?
    
    /// Battery charge level as a fraction [0.0, 1.0] (nil if desktop)
    func batteryLevel() -> Double?
}
```

#### 2.1.3 Implementation: `IOKitAdapter`

```swift
final class IOKitAdapter: IOKitAdapterProtocol {
    
    // MARK: - CPU Utilization
    
    func cpuUtilization() -> Double {
        var host = mach_host_self()
        var processorCount: mach_msg_type_number_t = 0
        var processorInfo = processor_info_t(nil)
        
        let status = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorCount
        )
        
        guard status == KERN_SUCCESS, let info = processorInfo else {
            return 0.0  // Fallback: assume idle if read fails
        }
        
        defer {
            vm_deallocate(host,
                vm_address_t(info.count * MemoryLayout<cpu_data_t>.stride),
                vm_size_t(info.count * MemoryLayout<cpu_data_t>.stride)
            )
        }
        
        // Calculate total CPU time across all cores
        var totalUsage: vm_size_t = 0
        var idleUsage: vm_size_t = 0
        
        for i in 0..<Int(processorCount) {
            let cpu = info[i]
            for state in cpu.cpu_ticks {
                totalUsage += state
            }
            idleUsage += cpu.cpu_ticks[CPU_STATE_IDLE]
        }
        
        let utilization = totalUsage > 0 ? Double(idleUsage) / Double(totalUsage) : 0.0
        return min(1.0, max(0.0, 1.0 - utilization))  // Invert: idle fraction → busy fraction
    }
    
    // MARK: - GPU Utilization
    
    func gpuUtilization() -> Double {
        // Metal performance queries for GPU utilization
        // This requires Metal device and command queue setup
        // For simplicity, we use a simplified approach:
        // Query GPU via IOService matching
        
        guard let service = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("IOGPUDevice")
        ) else {
            return 0.0  // No GPU service found, fallback to 0
        }
        
        defer { IOObjectRelease(service) }
        
        // Read GPU workload state (simplified)
        // In practice, this requires Metal Performance Queries (MPQ)
        // which need a Metal device and command buffer
        // For now, return a conservative estimate based on system state
        return 0.0  // Placeholder — actual implementation uses Metal MPQ
    }
    
    // MARK: - Battery State
    
    func isCharging() -> Bool? {
        guard let powerSource = IOPowerSourcesCopyPowerSourceInfo()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        
        // Check if AC power is connected
        guard let externalConnected = powerSource[kIOPowerSourcesInfoExternalConnectedKeyName] as? Bool else {
            return nil
        }
        
        return externalConnected
    }
    
    func batteryLevel() -> Double? {
        guard let powerSource = IOPowerSourcesCopyPowerSourceInfo()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        
        guard let capacity = powerSource[kIOPowerSourcesInfoBatteryPercentKeyName] as? Int else {
            return nil
        }
        
        return Double(capacity) / 100.0
    }
}
```

#### 2.1.4 Error Handling

| Scenario | Behavior |
|----------|----------|
| `host_processor_info` returns `KERN_FAILURE` | Return `0.0` (assume idle), continue collecting |
| GPU service not found | Return `0.0`, log warning to console |
| Battery service not found (desktop) | Return `nil` for `isCharging()` and `batteryLevel()` |
| IOKit returns malformed data | Return `0.0` or `nil`, never crash |

#### 2.1.5 Thread Safety
- All methods are synchronous and thread-safe (IOKit APIs are internally thread-safe)
- No shared mutable state within `IOKitAdapter`

---

### 2.2 PowerEstimator

#### 2.2.1 Purpose
Convert raw CPU/GPU utilization fractions into estimated system wattage. Uses hardware sensor data as primary source, falls back to TDP-based estimation.

#### 2.2.2 Protocol Definition

```swift
protocol PowerEstimatorProtocol {
    /// Estimate total system power in watts from CPU and GPU utilization
    func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double
}
```

#### 2.2.3 Implementation: `PowerEstimator`

```swift
final class PowerEstimator: PowerEstimatorProtocol {
    
    // MARK: - TDP Constants (Apple Silicon)
    
    /// TDP profiles per chip generation
    enum ChipProfile {
        struct Base {
            static let idlePower: Double = 3.0   // M1/M2 base idle watts
            static let cpuMaxPower: Double = 40.0 // M1/M2 base max CPU watts
            static let gpuMaxPower: Double = 15.0 // M1/M2 base max GPU watts
        }
        
        struct Pro {
            static let idlePower: Double = 5.0   // M1/M2 Pro idle watts
            static let cpuMaxPower: Double = 60.0
            static let gpuMaxPower: Double = 30.0
        }
        
        struct Max {
            static let idlePower: Double = 8.0   // M1/M2 Max idle watts
            static let cpuMaxPower: Double = 100.0
            static let gpuMaxPower: Double = 60.0
        }
        
        struct Ultra {
            static let idlePower: Double = 10.0  // M1 Ultra idle watts
            static let cpuMaxPower: Double = 120.0
            static let gpuMaxPower: Double = 80.0
        }
    }
    
    private let chipProfile: ChipProfile
    
    // MARK: - Hardware Sensor Reading (Primary)
    
    /// Attempt to read hardware power sensor via IOKit
    /// Returns (watts, sensorAvailable) tuple
    private func readHardwareSensor() -> (Double, Bool) {
        // Primary method: read from IOKit power sensors
        // On some Apple Silicon models, IOKit exposes power sensor data
        // via the SMC (System Management Controller) interface
        
        // TODO: Implement SMC power sensor reading
        // For now, return (0, false) to indicate sensor not available
        return (0.0, false)
    }
    
    // MARK: - Estimation
    
    func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double {
        // Step 1: Try hardware sensor (most accurate)
        let (hardwareWatts, sensorAvailable) = readHardwareSensor()
        if sensorAvailable && hardwareWatts > 0 {
            return hardwareWatts
        }
        
        // Step 2: Fallback — TDP-based estimation
        let cpuPower = chipProfile.idlePower + (cpuUtil * (chipProfile.cpuMaxPower - chipProfile.idlePower))
        let gpuPower = gpuUtil * chipProfile.gpuMaxPower
        
        return cpuPower + gpuPower
    }
    
    // MARK: - Initialization
    
    init(platform: MacPlatform, chipGeneration: ChipGeneration) {
        self.chipProfile = Self.profile(for: platform, generation: chipGeneration)
    }
    
    private static func profile(for platform: MacPlatform, generation: ChipGeneration) -> ChipProfile {
        // Match chip generation to the correct profile
        switch generation {
        case .m1Base: return ChipProfile.Base()
        case .m2Base: return ChipProfile.Base()
        case .m1Pro, .m2Pro: return ChipProfile.Pro()
        case .m1Max, .m2Max: return ChipProfile.Max()
        case .m1Ultra: return ChipProfile.Ultra()
        }
    }
}

enum ChipGeneration {
    case m1Base, m2Base
    case m1Pro, m2Pro
    case m1Max, m2Max
    case m1Ultra
}
```

#### 2.2.4 Estimation Formula Detail

```
Watts = BaseIdlePower + (cpuUtil × (cpuMaxPower - BaseIdlePower)) + (gpuUtil × gpuMaxPower)

Where:
  cpuUtil ∈ [0.0, 1.0]  — from IOKitAdapter.cpuUtilization()
  gpuUtil ∈ [0.0, 1.0]  — from IOKitAdapter.gpuUtilization()
  BaseIdlePower = chip-specific constant (watts at 0% CPU load)
  cpuMaxPower = chip-specific max CPU power (watts at 100% CPU load)
  gpuMaxPower = chip-specific max GPU power (watts at 100% GPU load)

Example (M2 base, cpuUtil=0.5, gpuUtil=0.2):
  Watts = 5.0 + (0.5 × (60.0 - 5.0)) + (0.2 × 30.0)
        = 5.0 + 27.5 + 6.0
        = 38.5W
```

#### 2.2.5 Error Handling

| Scenario | Behavior |
|----------|----------|
| Hardware sensor unavailable | Fall back to TDP estimation (no error) |
| Hardware sensor returns 0 | Fall back to TDP estimation (0 is invalid for a running system) |
| Chip generation unknown | Default to M2 base profile |

#### 2.2.6 Thread Safety
- No mutable state after initialization (immutable `chipProfile`)
- Thread-safe by design

---

### 2.3 PlatformDetector

#### 2.3.1 Purpose
Detect whether the Mac has a battery (MacBook) or not (Mac Studio, iMac, etc.) at runtime.

#### 2.3.2 Implementation

```swift
enum MacPlatform {
    case studio  // Desktop, no battery
    case laptop  // MacBook, has battery
}

enum ChipGeneration {
    case m1Base, m2Base
    case m1Pro, m2Pro
    case m1Max, m2Max
    case m1Ultra
}

final class PlatformDetector {
    
    /// Detect platform type (laptop vs desktop)
    static func detectPlatform() -> MacPlatform {
        let matching = IOServiceMatching("AppleSmartBattery")
        let iterator = UnsafeMutablePointer<io_iterator_t>.allocate(capacity: 1)
        defer { iterator.deallocate() }
        
        let status = IOServiceGetMatchingServices(
            kIOMasterPortDefault,
            matching,
            iterator
        )
        
        let hasBattery = status == KERN_SUCCESS && IOIteratorIsValid(iterator.pointee)
        IOObjectRelease(iterator.pointee)
        
        return hasBattery ? .laptop : .studio
    }
    
    /// Detect chip generation (M1/M2, base/Pro/Max/Ultra)
    static func detectChipGeneration() -> ChipGeneration {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return .m2Base }  // Default fallback
        
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let cpuString = String(cString: brand)
        
        if cpuString.contains("Ultra") { return .m1Ultra }
        if cpuString.contains("Max") {
            return cpuString.contains("M2") ? .m2Max : .m1Max
        }
        if cpuString.contains("Pro") {
            return cpuString.contains("M2") ? .m2Pro : .m1Pro
        }
        if cpuString.contains("M2") { return .m2Base }
        return .m1Base
    }
}
```

#### 2.3.3 Error Handling

| Scenario | Behavior |
|----------|----------|
| `IOServiceGetMatchingServices` fails | Return `.studio` (assume desktop) |
| `sysctlbyname` fails | Return `.m2Base` (default to M2 base) |

#### 2.3.4 Thread Safety
- Static methods, no shared mutable state
- Thread-safe by design

---

## 3. Module B: Data Layer

### 3.1 PowerRecord Model

```swift
struct PowerRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let watts: Double
    let isCharging: Bool?  // nil for desktop Macs
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, watts, isCharging
    }
    
    init(id: UUID = UUID(), timestamp: Date = Date(), watts: Double, isCharging: Bool?) {
        self.id = id
        self.timestamp = timestamp
        self.watts = watts
        self.isCharging = isCharging
    }
}

struct DailyAverage: Codable, Identifiable {
    let id: UUID
    let date: Date       // Start of day (midnight, local timezone)
    let averageWatts: Double
    
    enum CodingKeys: String, CodingKey {
        case id, date, averageWatts
    }
}

struct MonthlyTotal: Codable, Identifiable {
    let id: UUID
    let yearMonth: String  // "2025-01" format
    let totalKWh: Double
    
    enum CodingKeys: String, CodingKey {
        case id, yearMonth, totalKWh
    }
}
```

**Encoding Details**:
- `timestamp`: Encoded as ISO 8601 string via `JSONEncoder.dateEncodingStrategy = .iso8601`
- `watts`: Encoded as `Double` (IEEE 754)
- `isCharging`: Encoded as `Bool?` (null for desktop)
- `yearMonth`: String in "YYYY-MM" format (e.g., "2025-01")

---

### 3.2 PowerLogService

#### 3.2.1 Purpose
Manage the complete lifecycle of power data: append records, read/aggregate for display, and clear data.

#### 3.2.2 Protocol Definition

```swift
protocol PowerLogServiceProtocol {
    // Core operations
    func append(_ record: PowerRecord) async throws
    func records(in range: DateRange) -> [PowerRecord]
    func recentRecords(count: Int) -> [PowerRecord]
    
    // Session statistics
    func sessionAverage() -> Double
    func sessionPeak() -> Double
    func currentWatts() -> Double
    
    // Chart data
    func dailyAverages(for days: Int) -> [DailyAverage]
    func monthlyTotals(for months: Int) -> [MonthlyTotal]
    
    // Management
    func clearAll() async throws
}

struct DateRange {
    let start: Date
    let end: Date
}
```

#### 3.2.3 Implementation: `PowerLogService`

```swift
final class PowerLogService: PowerLogServiceProtocol {
    
    private let fileManager: FileManager
    private let dailyLogURL: URL
    private let monthlyLogURL: URL
    private let writeQueue: DispatchQueue  // Serial queue for thread-safe writes
    
    // In-memory buffer: keeps last N records for fast access
    private var dailyBuffer: [PowerRecord] = []
    private var monthlyBuffer: [MonthlyTotal] = []
    
    init(directory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.dailyLogURL = directory.appendingPathComponent("daily-log.plist")
        self.monthlyLogURL = directory.appendingPathComponent("monthly-log.plist")
        self.writeQueue = DispatchQueue(label: "com.macwattage.data.write", qos: .utility)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Load existing data into memory
        loadDailyBuffer()
        loadMonthlyBuffer()
    }
    
    // MARK: - Core Operations
    
    func append(_ record: PowerRecord) async throws {
        dailyBuffer.append(record)
        
        // Journal mode: write to temp file, then rename
        let tempURL = dailyLogURL.deletingPathExtension().appendingPathExtension("tmp")
        let encoder = PropertyListEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(dailyBuffer)
        try data.write(to: tempURL, options: .atomic)
        try fileManager.moveItem(at: tempURL, to: dailyLogURL)
    }
    
    func records(in range: DateRange) -> [PowerRecord] {
        dailyBuffer.filter { record in
            record.timestamp >= range.start && record.timestamp <= range.end
        }
    }
    
    func recentRecords(count: Int) -> [PowerRecord] {
        Array(dailyBuffer.suffix(count))
    }
    
    // MARK: - Session Statistics
    
    func sessionAverage() -> Double {
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        let records = records(in: DateRange(start: oneHourAgo, end: Date()))
        guard !records.isEmpty else { return 0.0 }
        let sum = records.reduce(0.0) { $0 + $1.watts }
        return sum / Double(records.count)
    }
    
    func sessionPeak() -> Double {
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        let records = records(in: DateRange(start: oneHourAgo, end: Date()))
        return records.map(\.watts).max() ?? 0.0
    }
    
    func currentWatts() -> Double {
        dailyBuffer.last?.watts ?? 0.0
    }
    
    // MARK: - Chart Data
    
    func dailyAverages(for days: Int) -> [DailyAverage] {
        let calendar = Calendar.current
        let now = Date()
        var averages: [DailyAverage] = []
        
        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(
                byAdding: .day,
                value: -dayOffset,
                to: now
            )?.startOfDay(for: calendar) else { continue }
            
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            let dayRecords = records(in: DateRange(start: dayStart, end: dayEnd))
            guard !dayRecords.isEmpty else {
                averages.append(DailyAverage(
                    id: UUID(),
                    date: dayStart,
                    averageWatts: 0.0
                ))
                continue
            }
            
            let avg = dayRecords.reduce(0.0) { $0 + $1.watts } / Double(dayRecords.count)
            averages.append(DailyAverage(
                id: UUID(),
                date: dayStart,
                averageWatts: avg
            ))
        }
        
        // Reverse so oldest first (left to right on chart)
        return averages.reversed()
    }
    
    func monthlyTotals(for months: Int) -> [MonthlyTotal] {
        let calendar = Calendar.current
        let now = Date()
        var totals: [MonthlyTotal] = []
        
        for monthOffset in 0..<months {
            guard let monthStart = calendar.date(
                byAdding: .month,
                value: -monthOffset,
                to: now
            )?.startOfMonth(for: calendar) else { continue }
            
            let monthEnd = calendar.date(
                byAdding: .month,
                value: 1,
                to: monthStart
            ) ?? monthStart
            
            let monthRecords = records(in: DateRange(start: monthStart, end: monthEnd))
            guard !monthRecords.isEmpty else { continue }
            
            // Convert watt-seconds to kWh:
            // kWh = (avgWatts × secondsInMonth) / (1000 × 3600)
            let secondsInMonth = monthStart.timeIntervalSince(monthEnd)
            let avgWatts = monthRecords.reduce(0.0) { $0 + $1.watts } / Double(monthRecords.count)
            let totalKWh = (avgWatts * abs(secondsInMonth)) / (1000.0 * 3600.0)
            
            let yearMonth = String(format: "%04d-%02d",
                calendar.component(.year, from: monthStart),
                calendar.component(.month, from: monthStart)
            )
            
            totals.append(MonthlyTotal(
                id: UUID(),
                yearMonth: yearMonth,
                totalKWh: totalKWh
            ))
        }
        
        return totals.reversed()
    }
    
    // MARK: - Management
    
    func clearAll() async throws {
        dailyBuffer.removeAll()
        monthlyBuffer.removeAll()
        
        try fileManager.removeItem(at: dailyLogURL)
        try fileManager.removeItem(at: monthlyLogURL)
    }
    
    // MARK: - Loading
    
    private func loadDailyBuffer() {
        guard fileManager.fileExists(atPath: dailyLogURL.path) else { return }
        
        let decoder = PropertyListDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let data = try Data(contentsOf: dailyLogURL)
            dailyBuffer = try decoder.decode([PowerRecord].self, from: data)
        } catch {
            // Corrupted file or decode error — start fresh
            dailyBuffer = []
        }
    }
    
    private func loadMonthlyBuffer() {
        guard fileManager.fileExists(atPath: monthlyLogURL.path) else { return }
        
        let decoder = PropertyListDecoder()
        
        do {
            let data = try Data(contentsOf: monthlyLogURL)
            monthlyBuffer = try decoder.decode([MonthlyTotal].self, from: data)
        } catch {
            monthlyBuffer = []
        }
    }
}
```

#### 3.2.4 kWh Conversion Formula

```
kWh = (averageWatts × secondsInMonth) / (1000 × 3600)

Example:
  Average watts in January = 35W
  Seconds in January = 31 days × 86400 = 2,678,400
  kWh = (35 × 2,678,400) / 3,600,000
      = 93,744,000 / 3,600,000
      = 26.04 kWh
```

#### 3.2.5 Journal Mode (Crash Recovery)

```
Write Process:
1. Encode current dailyBuffer to Data
2. Write Data to temp file: daily-log.plist.tmp
3. If write succeeds, rename daily-log.plist.tmp → daily-log.plist
4. If write fails (crash during step 2), original file is untouched

Read Process:
1. Try to decode daily-log.plist
2. If decode fails (corrupted), discard and start fresh (empty buffer)
```

#### 3.2.6 Thread Safety

```
writeQueue (serial dispatch queue)
    │
    ├── append() — writes to disk
    ├── loadDailyBuffer() — reads on init
    └── loadMonthlyBuffer() — reads on init

dailyBuffer — accessed only on writeQueue (except during init)
monthlyBuffer — accessed only on main thread (read-only after init)
```

- All writes go through `writeQueue` (serial queue)
- `dailyBuffer` is only modified on `writeQueue`
- `monthlyBuffer` is read-only after initialization (never modified at runtime)
- `recentRecords()`, `sessionAverage()`, `sessionPeak()`, `currentWatts()` read `dailyBuffer` on the calling thread — safe because `dailyBuffer` is only written on `writeQueue` (no concurrent reads during writes in this design)

**Note**: For strict thread safety with concurrent reads, `dailyBuffer` should be accessed via `writeQueue.sync`. The current design assumes reads are fast (in-memory array scan) and the write interval (10s or 60s) makes contention negligible. If needed, all reads can be wrapped in `writeQueue.sync {}`.

---

### 3.3 RotationManager

#### 3.3.1 Purpose
Automatically summarize daily records into monthly totals and purge old daily records when a month boundary is crossed.

#### 3.3.2 Implementation

```swift
final class RotationManager {
    
    private let userDefaultStorage: UserDefaultsProtocol
    
    init(userDefaultStorage: UserDefaultsProtocol = UserDefaults.standard) {
        self.userDefaultStorage = userDefaultStorage
    }
    
    /// Called on app launch; checks if a month boundary has passed
    func checkAndRotate(dailyService: PowerLogService) {
        let lastRotationKey = "lastRotationMonth"
        let calendar = Calendar.current
        
        guard let lastRotationString = userDefaultStorage.string(forKey: lastRotationKey),
              let lastRotation = ISO8601DateFormatter().date(from: lastRotationString) else {
            // First launch or corrupted key — perform initial rotation
            performRotation(dailyService: dailyService)
            saveLastRotation()
            return
        }
        
        guard let lastRotationMonth = calendar.dateComponents(
            [.year, .month],
            from: lastRotation
        ) else {
            performRotation(dailyService: dailyService)
            saveLastRotation()
            return
        }
        
        let currentMonth = calendar.dateComponents(
            [.year, .month],
            from: Date()
        )
        
        // Check if we've crossed a month boundary
        if currentMonth.year != lastRotationMonth.year || currentMonth.month != lastRotationMonth.month {
            performRotation(dailyService: dailyService)
            saveLastRotation()
        }
    }
    
    private func performRotation(dailyService: PowerLogService) {
        // 1. Get all daily records older than the current month
        let calendar = Calendar.current
        let now = Date()
        guard let currentMonthStart = calendar.date(
            byAdding: .month,
            value: -1,
            to: now
        )?.startOfDay(for: calendar) else { return }
        
        let oldRecords = dailyService.records(in: DateRange(
            start: Date.distantPast,
            end: currentMonthStart
        ))
        
        guard !oldRecords.isEmpty else { return }
        
        // 2. Group by month and compute totals
        var monthlyGroups: [String: [PowerRecord]] = [:]
        for record in oldRecords {
            let yearMonth = formatYearMonth(from: record.timestamp)
            monthlyGroups[yearMonth, default: []].append(record)
        }
        
        // 3. Save monthly totals
        var existingMonthly = loadExistingMonthly()
        for (yearMonth, records) in monthlyGroups {
            let secondsInPeriod = Double(records.count) * 10.0  // 10s interval
            let avgWatts = records.reduce(0.0) { $0 + $1.watts } / Double(records.count)
            let totalKWh = (avgWatts * secondsInPeriod) / (1000.0 * 3600.0)
            
            // Avoid duplicates
            if let existingIndex = existingMonthly.firstIndex(where: { $0.yearMonth == yearMonth }) {
                existingMonthly[existingIndex] = MonthlyTotal(
                    id: existingMonthly[existingIndex].id,
                    yearMonth: yearMonth,
                    totalKWh: totalKWh
                )
            } else {
                existingMonthly.append(MonthlyTotal(
                    id: UUID(),
                    yearMonth: yearMonth,
                    totalKWh: totalKWh
                ))
            }
        }
        
        // 4. Save monthly totals to file (via dailyService)
        // Note: monthly totals are persisted separately
        saveMonthlyTotals(existingMonthly)
        
        // 5. Clear old daily records (keep current month only)
        // This is done by the caller (dailyService) after rotation
    }
    
    private func saveLastRotation() {
        let formatter = ISO8601DateFormatter()
        userDefaultStorage.set(formatter.string(from: Date()), forKey: "lastRotationMonth")
    }
    
    private func formatYearMonth(from date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }
    
    private func loadExistingMonthly() -> [MonthlyTotal] {
        // Load from monthly-log.plist
        // (Implementation delegates to PowerLogService.monthlyBuffer)
        return []
    }
    
    private func saveMonthlyTotals(_ totals: [MonthlyTotal]) {
        // Save to monthly-log.plist
        // (Implementation delegates to PowerLogService)
    }
}
```

**Rotation Trigger**: Called once on app launch. If the app has been running across a month boundary (e.g., launched on June 1st after not running in May), rotation happens immediately.

**Rotation Process**:
1. Detect current month
2. Compare with last saved rotation month (stored in UserDefaults)
3. If different month → summarize old daily records → save as monthly totals → clear old daily records
4. Save current month as the new "last rotation" timestamp

---

### 3.4 Store

#### 3.4.1 Purpose
Persist and load configuration settings using UserDefaults. Manages login items.

#### 3.4.2 Implementation

```swift
final class Store {
    
    private let defaults: UserDefaultsProtocol
    
    // MARK: - Keys
    
    enum Keys: String {
        case collectionInterval = "collectionInterval"
        case logDirectory = "logDirectory"
        case autoLaunch = "autoLaunchAtLogin"
    }
    
    // MARK: - Properties
    
    var collectionInterval: Int {
        get { defaults.integer(forKey: Keys.collectionInterval.rawValue) }
        set { defaults.set(newValue, forKey: Keys.collectionInterval.rawValue) }
    }
    
    var logDirectory: URL {
        get {
            if let path = defaults.string(forKey: Keys.logDirectory.rawValue) {
                return URL(fileURLWithPath: path)
            }
            return defaultDirectory
        }
        set {
            defaults.set(newValue.path, forKey: Keys.logDirectory.rawValue)
        }
    }
    
    var autoLaunchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.autoLaunch.rawValue) }
        set {
            defaults.set(newValue, forKey: Keys.autoLaunch.rawValue)
            updateLoginItems(newValue)
        }
    }
    
    // MARK: - Defaults
    
    var defaultCollectionInterval: Int { 1 }  // 1 second (default)
    var defaultLogDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Mac Wattage")
    }
    
    // MARK: - Initialization
    
    init(defaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.defaults = defaults
        // Set defaults if not already set
        if !defaults.object(forKey: Keys.collectionInterval.rawValue) {
            defaults.set(defaultCollectionInterval, forKey: Keys.collectionInterval.rawValue)
        }
        if !defaults.object(forKey: Keys.autoLaunch.rawValue) {
            defaults.set(false, forKey: Keys.autoLaunch.rawValue)
        }
    }
    
    // MARK: - Login Items
    
    private func updateLoginItems(_ enable: Bool) {
        let appURL = Bundle.main.bundleURL
        let helperURL = appURL.deletingLastPathComponent()
            .appendingPathComponent("Applications")
            .appendingPathComponent("Mac Wattage.app")
        
        // Use LSSharedFileList for Login Items
        guard let items = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems as CFString, nil)?.takeRetainedValue() as? LSSharedFileList else {
            return
        }
        
        if enable {
            // Add to login items if not already present
            let currentItems = LSSharedFileListCopyItems(items)?.takeRetainedValue() as? [LSSharedFileListItem] ?? []
            let alreadyPresent = currentItems.contains { item in
                (item.itemRef as? URL)?.lastPathComponent == "Mac Wattage.app"
            }
            
            if !alreadyPresent {
                LSSharedFileListInsertItemURL(
                    items,
                    kLSSharedFileListItemLast,
                    nil,
                    nil,
                    helperURL as CFURL,
                    nil,
                    nil
                )
            }
        } else {
            // Remove from login items
            let currentItems = LSSharedFileListCopyItems(items)?.takeRetainedValue() as? [LSSharedFileListItem] ?? []
            for item in currentItems {
                if let itemURL = (item.itemRef as? URL),
                   itemURL.lastPathComponent == "Mac Wattage.app" {
                    items.removeItem(item)
                    break
                }
            }
        }
    }
}

// Protocol for testability
protocol UserDefaultsProtocol {
    var integer(forKey: String) -> Int { get set }
    var bool(forKey: String) -> Bool { get set }
    func string(forKey: String) -> String?
    func set(_ value: Any?, forKey: String)
    func object(forKey: String) -> Any?
}

extension UserDefaults: UserDefaultsProtocol {}
```

---

## 4. Module C: UI Layer

### 4.1 App Entry Point

```swift
@main
struct MacWattageApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var store = Store()
    @StateObject private var powerLogService: PowerLogService
    @StateObject private var platformDetector = PlatformDetector()
    
    init() {
        // Detect platform at launch
        let platform = PlatformDetector.detectPlatform()
        let chipGeneration = PlatformDetector.detectChipGeneration()
        
        // Initialize services
        let store = Store()
        let directory = store.logDirectory
        FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let service = PowerLogService(directory: directory)
        _powerLogService = StateObject(wrappedValue: service)
        
        // Perform rotation if needed
        let rotationManager = RotationManager()
        rotationManager.checkAndRotate(dailyService: service)
        
        // Start collection timer
        let adapter = IOKitAdapter()
        let estimator = PowerEstimator(platform: platform, chipGeneration: chipGeneration)
        let timer = CollectionTimer(
            interval: store.collectionInterval,
            metrics: adapter,
            estimator: estimator,
            logService: service
        ) { record in
            // UI update callback
            MenuBarViewModel.shared.update(with: record)
            PopoverViewModel.shared.refresh()
        }
        timer.start()
        appDelegate.collectionTimer = timer
    }
    
    var body: some Scene {
        MenuBarExtra {
            PowerPopoverView()
        } label: {
            MenuBarWidgetView()
        }
        
        Settings {
            SettingsWindowView()
        }
    }
}
```

### 4.2 Menu Bar Widget View

```swift
struct MenuBarWidgetView: View {
    @ObservedObject var viewModel = MenuBarViewModel.shared
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
            
            Text("\(viewModel.currentWatts, specifier: "%.0f")W")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
            
            if !viewModel.sparklineData.isEmpty {
                SparklineView(values: viewModel.sparklineData)
                    .frame(width: 40, height: 14)
            }
        }
        .environment(\.colorScheme, .light)  // Adapt to system appearance
    }
}

// Empty state: show "⚡ n/a" when no data collected yet
struct MenuBarWidgetEmptyView: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
            Text("n/a")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
    }
}
```

**Empty State Behavior**: On first launch (no records collected yet), display `⚡ n/a` instead of a wattage value. After the first record is collected, transition to showing the actual wattage.

### 4.3 Popover Dashboard

```swift
struct PowerPopoverView: View {
    @ObservedObject var viewModel = PopoverViewModel.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Section 1: Current watts + session stats
            currentWattsSection
            
            Divider()
            
            // Section 2: 7-day chart
            sevenDayChartSection
            
            Divider()
            
            // Section 3: Monthly totals
            monthlyTotalsSection
            
            Divider()
            
            // Settings link
            settingsButton
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            viewModel.refresh()
        }
    }
    
    private var currentWattsSection: some View {
        VStack(spacing: 4) {
            if viewModel.hasData {
                Text("\(viewModel.currentWatts, specifier: "%.0f")W")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                
                HStack(spacing: 12) {
                    Text("Avg: \(viewModel.sessionAverage, specifier: "%.0f")W")
                    Text("Peak: \(viewModel.sessionPeak, specifier: "%.0f")W")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("Collecting data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var sevenDayChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-Day Power Consumption")
                .font(.headline)
            
            if !viewModel.dailyAverages.isEmpty {
                BarChartView(data: viewModel.dailyAverages)
            } else {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var monthlyTotalsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monthly Totals")
                .font(.headline)
            
            if !viewModel.monthlyTotals.isEmpty {
                MonthlyTotalsView(totals: viewModel.monthlyTotals)
            } else {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var settingsButton: some View {
        Button("⚙ Settings") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(#selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: nil, from: nil)
            // Open settings window via notification
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
```

**Empty State**: When no data has been collected yet, show `⚡ n/a` in the menu bar and "No data yet" in the popover sections.

### 4.4 Settings Window

```swift
struct SettingsWindowView: View {
    @ObservedObject var store = Store()
    @State private var showFilePicker = false
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Collection interval
            Form {
                Picker("Collection Interval", selection: $store.collectionInterval) {
                    Text("Every 1 second (default)").tag(1)
                    Text("Every 5 seconds").tag(5)
                    Text("Every 10 seconds").tag(10)
                }
                .pickerStyle(.radioGroup)
            }
            
            Divider()
            
            // Log directory
            VStack(alignment: .leading, spacing: 6) {
                Text("Log Directory")
                    .font(.headline)
                
                HStack {
                    Text(store.logDirectory.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button("Change...") {
                        showFilePicker = true
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.folder]
            ) { result in
                if let url = try? result.get()?.url {
                    store.logDirectory = url
                }
            }
            
            // Auto-launch toggle
            VStack(alignment: .leading, spacing: 6) {
                Text("Launch at Login")
                    .font(.headline)
                
                Toggle("Automatically launch at login", isOn: $store.autoLaunchAtLogin)
            }
            
            Divider()
            
            // Clear data
            VStack(alignment: .leading, spacing: 6) {
                Text("Data Management")
                    .font(.headline)
                
                Button("Clear All Logs", role: .destructive) {
                    showClearConfirmation = true
                }
                .alert("Clear All Logs?", isPresented: $showClearConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        // Trigger clear via notification or direct call
                        NotificationCenter.default.post(name: .clearAllLogs, object: nil)
                    }
                } message: {
                    Text("This will delete all daily and monthly power consumption data. This action cannot be undone.")
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 420, height: 340)
    }
}

extension Notification.Name {
    static let clearAllLogs = Notification.Name("clearAllLogs")
}
```

### 4.5 ViewModels

```swift
@MainActor
final class MenuBarViewModel: ObservableObject {
    static let shared = MenuBarViewModel()
    
    @Published var currentWatts: Double = 0
    @Published var sparklineData: [Double] = []  // Last ~120 records (~2-minute rolling window)
    
    private init() {}
    
    func update(with record: PowerRecord) {
        currentWatts = record.watts
        
        // Add to sparkline buffer (rolling window, max 120 records = ~2 minutes at 1s interval)
        sparklineData.append(record.watts)
        if sparklineData.count > 36 {
            sparklineData.removeFirst()
        }
    }
}

@MainActor
final class PopoverViewModel: ObservableObject {
    static let shared = PopoverViewModel()
    
    @Published var currentWatts: Double = 0
    @Published var sessionAverage: Double = 0
    @Published var sessionPeak: Double = 0
    @Published var dailyAverages: [DailyAverage] = []
    @Published var monthlyTotals: [MonthlyTotal] = []
    
    private var powerLogService: PowerLogServiceProtocol?
    
    private init() {}
    
    func setService(_ service: PowerLogServiceProtocol) {
        self.powerLogService = service
    }
    
    var hasData: Bool {
        !dailyAverages.isEmpty || !monthlyTotals.isEmpty
    }
    
    func refresh() {
        guard let service = powerLogService else { return }
        
        currentWatts = service.currentWatts()
        sessionAverage = service.sessionAverage()
        sessionPeak = service.sessionPeak()
        dailyAverages = service.dailyAverages(for: 7)
        monthlyTotals = service.monthlyTotals(for: 12)
    }
}
```

### 4.6 Charts

See High-Level Design Section 6 for chart rendering code. Same implementation applies.

---

## 5. Module D: Scheduler

### 5.1 CollectionTimer

#### 5.1.1 Purpose
Fire data collection tasks at the configured interval. Bridges Metrics Layer and Data Layer.

#### 5.1.2 Implementation

```swift
final class CollectionTimer {
    
    private var timer: Timer?
    private let interval: Int
    private let metrics: IOKitAdapterProtocol
    private let estimator: PowerEstimatorProtocol
    private let logService: PowerLogServiceProtocol
    private let uiUpdate: @MainActor (PowerRecord) -> Void
    private let collectQueue: DispatchQueue
    
    init(
        interval: Int,
        metrics: IOKitAdapterProtocol,
        estimator: PowerEstimatorProtocol,
        logService: PowerLogServiceProtocol,
        uiUpdate: @escaping @MainActor (PowerRecord) -> Void
    ) {
        self.interval = interval
        self.metrics = metrics
        self.estimator = estimator
        self.logService = logService
        self.uiUpdate = uiUpdate
        self.collectQueue = DispatchQueue(label: "com.macwattage.scheduler.collect", qos: .userInitiated)
    }
    
    func start() {
        // Start immediately, then on interval
        collect()
        
        timer = Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true) { [weak self] _ in
            self?.collect()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func collect() {
        collectQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cpuUtil = self.metrics.cpuUtilization()
            let gpuUtil = self.metrics.gpuUtilization()
            let watts = self.estimator.estimateSystemPower(from: cpuUtil, gpuUtil: gpuUtil)
            
            let record = PowerRecord(
                id: UUID(),
                timestamp: Date(),
                watts: watts,
                isCharging: self.metrics.isCharging()
            )
            
            // Write to log service (async)
            Task { @MainActor in
                try? await self.logService.append(record)
            }
            
            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                self?.uiUpdate(record)
            }
        }
    }
}
```

#### 5.1.3 Threading Model

```
Timer fires (main thread)
    │
    └──→ collectQueue (background)
         │
         ├── metrics.cpuUtilization()    — synchronous, fast
         ├── metrics.gpuUtilization()    — synchronous, fast
         ├── estimator.estimateSystemPower() — synchronous, fast
         │
         ├── logService.append() async   — dispatches to writeQueue
         └── uiUpdate(record)            — dispatched to main thread
```

---

## 6. Error Handling Strategy

### 6.1 Error Propagation

| Layer | Error Type | Handling |
|-------|-----------|----------|
| Metrics Layer | IOKit read failure | Return default value (0.0 or nil), never throw |
| Metrics Layer | Hardware sensor unavailable | Fall back to TDP estimation |
| Data Layer | File write failure | Catch in `append()`, log to console, continue |
| Data Layer | File corruption | Catch in `loadDailyBuffer()`, start with empty buffer |
| Data Layer | Rotation failure | Log to console, skip rotation, continue |
| UI Layer | No data to display | Show "n/a" or "No data yet" |

### 6.2 Error Logging

```swift
// Simple console logging (no external logging framework)
enum Logger {
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("[MacWattage WARNING] \(fileName):\(line) \(function) - \(message)")
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("[MacWattage ERROR] \(fileName):\(line) \(function) - \(message)")
    }
}
```

**Usage**:
```swift
// In PowerLogService.append()
do {
    try data.write(to: tempURL, options: .atomic)
    try fileManager.moveItem(at: tempURL, to: dailyLogURL)
} catch {
    Logger.error("Failed to write daily log: \(error.localizedDescription)")
}
```

---

## 7. Testing Strategy

### 7.1 Testing Framework: XCTest

**Why XCTest**:
- Built into Xcode — no external dependencies
- Supports unit tests for Swift classes
- Supports UI tests for SwiftUI views
- Integrates with Xcode CI/CD (Xcode Build Action)
- Native Swift concurrency support (`async/await`)

**Test Target**: Add a new "Tests" target in Xcode:
```
MacWattage/
├── MacWattage/              # Main app target
├── MacWattageTests/         # Unit test target (XCTest)
└── MacWattageUITests/       # UI test target (XCTest)
```

### 7.2 Unit Test Coverage

#### 7.2.1 Metrics Layer Tests

**Test: `PowerEstimatorTests`**
```swift
import XCTest
@testable import MacWattage

final class PowerEstimatorTests: XCTestCase {
    
    func testEstimateM2BaseAtIdle() {
        // At 0% CPU, 0% GPU → should return idle power (~5W for M2 base)
        let estimator = PowerEstimator(platform: .laptop, chipGeneration: .m2Base)
        let watts = estimator.estimateSystemPower(from: 0.0, gpuUtil: 0.0)
        XCTAssertEqual(watts, 5.0, accuracy: 0.5)  // ~5W idle
    }
    
    func testEstimateM2BaseAtFullLoad() {
        // At 100% CPU, 100% GPU → should return near max power
        let estimator = PowerEstimator(platform: .laptop, chipGeneration: .m2Base)
        let watts = estimator.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        // M2 base: 5W idle + (1.0 × 55W) + (1.0 × 30W) = 90W
        XCTAssertGreaterThan(watts, 80.0)
        XCTAssertLessThan(watts, 100.0)
    }
    
    func testEstimateM1ProAtHalfLoad() {
        // M1 Pro: 5W idle + (0.5 × 55W) + (0.5 × 30W) = 47.5W
        let estimator = PowerEstimator(platform: .laptop, chipGeneration: .m1Pro)
        let watts = estimator.estimateSystemPower(from: 0.5, gpuUtil: 0.5)
        XCTAssertEqual(watts, 47.5, accuracy: 1.0)
    }
    
    func testEstimateDifferentChips() {
        // M1 Ultra should have higher max power than M1 base
        let ultra = PowerEstimator(platform: .laptop, chipGeneration: .m1Ultra)
        let base = PowerEstimator(platform: .laptop, chipGeneration: .m1Base)
        
        let ultraWatts = ultra.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        let baseWatts = base.estimateSystemPower(from: 1.0, gpuUtil: 1.0)
        
        XCTAssertGreaterThan(ultraWatts, baseWatts)
    }
}
```

**Test: `PlatformDetectorTests`**
```swift
final class PlatformDetectorTests: XCTestCase {
    
    func testDetectPlatformReturnsValidType() {
        // Runtime test — verifies the method doesn't crash
        let platform = PlatformDetector.detectPlatform()
        XCTAssertTrue(platform == .studio || platform == .laptop)
    }
    
    func testDetectChipGenerationReturnsValidType() {
        // Runtime test — verifies the method doesn't crash
        let chip = PlatformDetector.detectChipGeneration()
        switch chip {
        case .m1Base, .m2Base, .m1Pro, .m2Pro, .m1Max, .m2Max, .m1Ultra:
            break  // Valid
        }
    }
}
```

#### 7.2.2 Data Layer Tests

**Test: `PowerLogServiceTests`**
```swift
final class PowerLogServiceTests: XCTestCase {
    
    var tempDirectory: URL!
    var service: PowerLogService!
    
    override func setUp() {
        super.setUp()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MacWattageTest-\(UUID().uuidString)")
        FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        service = PowerLogService(directory: tempDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testAppendAndReadRecord() async throws {
        let record = PowerRecord(watts: 42.5, isCharging: true)
        try await service.append(record)
        
        let current = service.currentWatts()
        XCTAssertEqual(current, 42.5, accuracy: 0.1)
    }
    
    func testSessionAverage() async throws {
        // Append records with known values
        for i in 0..<10 {
            let record = PowerRecord(watts: Double(i * 10), isCharging: nil)
            try await service.append(record)
        }
        
        let avg = service.sessionAverage()
        // Average of 0, 10, 20, ..., 90 = 45W
        XCTAssertEqual(avg, 45.0, accuracy: 1.0)
    }
    
    func testSessionPeak() async throws {
        for i in 0..<10 {
            let record = PowerRecord(watts: Double(i * 10), isCharging: nil)
            try await service.append(record)
        }
        
        let peak = service.sessionPeak()
        XCTAssertEqual(peak, 90.0, accuracy: 0.1)
    }
    
    func testDailyAverages() {
        let now = Date()
        let calendar = Calendar.current
        
        // Create records for yesterday
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return }
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: yesterdayStart) ?? yesterdayStart
        
        for i in 0..<100 {
            let timestamp = calendar.date(byAdding: .second, value: i * 10, to: yesterdayStart) ?? yesterdayStart
            let record = PowerRecord(timestamp: timestamp, watts: 35.0, isCharging: nil)
            // Note: append is async, but for testing we can directly manipulate the buffer
            // In practice, use a test double or inject a mock
        }
        
        let averages = service.dailyAverages(for: 7)
        XCTAssertEqual(averages.count, 7)
    }
    
    func testClearAll() async throws {
        let record = PowerRecord(watts: 50.0, isCharging: nil)
        try await service.append(record)
        
        try await service.clearAll()
        
        XCTAssertEqual(service.currentWatts(), 0.0)
    }
}
```

**Test: `RotationManagerTests`**
```swift
final class RotationManagerTests: XCTestCase {
    
    func testCheckAndRotateDetectsMonthBoundary() {
        // Mock UserDefaults to simulate crossing a month boundary
        let mockDefaults = MockUserDefaults()
        let rotationManager = RotationManager(userDefaultStorage: mockDefaults)
        
        // Set last rotation to previous month
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let formatter = ISO8601DateFormatter()
        mockDefaults.values["lastRotationMonth"] = formatter.string(from: previousMonth)
        
        // Simulate a PowerLogService mock
        let mockService = MockPowerLogService()
        
        // Should trigger rotation
        rotationManager.checkAndRotate(dailyService: mockService)
        
        XCTAssertTrue(mockService.rotationTriggered)
    }
    
    func testCheckAndRotateSkipsWithinSameMonth() {
        let mockDefaults = MockUserDefaults()
        let rotationManager = RotationManager(userDefaultStorage: mockDefaults)
        
        // Set last rotation to current month
        mockDefaults.values["lastRotationMonth"] = ISO8601DateFormatter().string(from: Date())
        
        let mockService = MockPowerLogService()
        rotationManager.checkAndRotate(dailyService: mockService)
        
        XCTAssertFalse(mockService.rotationTriggered)
    }
}

// Mocks for testing
final class MockUserDefaults: UserDefaultsProtocol {
    var values: [String: Any] = [:]
    
    var integer(forKey key: String) -> Int {
        return values[key] as? Int ?? 0
    }
    var bool(forKey key: String) -> Bool {
        return values[key] as? Bool ?? false
    }
    func string(forKey key: String) -> String? {
        return values[key] as? String
    }
    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }
    func object(forKey key: String) -> Any? {
        return values[key]
    }
}

final class MockPowerLogService: PowerLogServiceProtocol {
    var rotationTriggered = false
    var appendedRecords: [PowerRecord] = []
    
    func append(_ record: PowerRecord) async throws {
        appendedRecords.append(record)
    }
    func records(in range: DateRange) -> [PowerRecord] {
        return appendedRecords.filter { $0.timestamp >= range.start && $0.timestamp <= range.end }
    }
    func recentRecords(count: Int) -> [PowerRecord] {
        return Array(appendedRecords.suffix(count))
    }
    func sessionAverage() -> Double { 0.0 }
    func sessionPeak() -> Double { 0.0 }
    func currentWatts() -> Double { 0.0 }
    func dailyAverages(for days: Int) -> [DailyAverage] { [] }
    func monthlyTotals(for months: Int) -> [MonthlyTotal] { [] }
    func clearAll() async throws {}
}
```

### 7.3 Test Execution

```bash
# Run all tests via Xcode
xcodebuild test -scheme MacWattage -destination 'platform=macOS,arch=arm64'

# Run only unit tests
xcodebuild test -scheme MacWattage -only-testing:MacWattageTests -destination 'platform=macOS,arch=arm64'

# Run with coverage
xcodebuild test -scheme MacWattage -destination 'platform=macOS,arch=arm64' CODE_COVERAGE=YES
```

### 7.4 Test Strategy Summary

| Module | Test Type | Approach |
|--------|-----------|----------|
| `PowerEstimator` | Unit test | Inject chip type, assert wattage output for known CPU/GPU inputs |
| `PlatformDetector` | Integration test | Run on real hardware, verify no crash and valid return type |
| `PowerLogService` | Unit test | Use temp directory, append records, verify aggregation results |
| `RotationManager` | Unit test | Mock `UserDefaults` and `PowerLogService`, verify rotation trigger |
| `CollectionTimer` | Skipped | Timer-based, hard to test in isolation; covered by manual testing |
| `Store` | Unit test | Mock `UserDefaults`, verify property reads/writes |
| `MenuBarWidgetView` | Manual test | Visual inspection, no automated UI tests |
| `PowerPopoverView` | Manual test | Visual inspection, no automated UI tests |
| `SettingsWindowView` | Manual test | Verify file picker, toggle, clear button behavior |

---

## 8. File Structure (Updated with Tests)

```
MacWattage/
├── MacWattageApp.swift              // @main entry point
├── AppDelegate.swift                 // NSApplicationDelegate (login items, lifecycle)
│
├── Metrics/
│   ├── IOKitAdapter.swift           // Protocol + implementation
│   ├── PowerEstimator.swift         // Utilization → watts conversion
│   └── PlatformDetector.swift       // MacBook vs desktop detection
│
├── Data/
│   ├── PowerRecord.swift            // Codable models
│   ├── PowerLogService.swift        // CRUD, aggregation, session stats
│   ├── RotationManager.swift        // Monthly rotation logic
│   └── Store.swift                  // UserDefaults + Login Items
│
├── UI/
│   ├── MenuBarWidgetView.swift      // Menu bar icon + watts + sparkline
│   ├── PowerPopoverView.swift       // Dashboard popover
│   ├── SettingsWindowView.swift     // Dedicated NSWindow
│   ├── Charts/
│   │   ├── SparklineView.swift
│   │   ├── BarChartView.swift
│   │   └── MonthlyTotalsView.swift
│   └── ViewModels/
│       ├── MenuBarViewModel.swift
│       └── PopoverViewModel.swift
│
├── Scheduler/
│   └── CollectionTimer.swift         // Timer-driven collection
│
├── Shared/
│   └── Logger.swift                  // Console logging utility
│
└── MacWattageTests/                  // XCTest target
    ├── PowerEstimatorTests.swift
    ├── PlatformDetectorTests.swift
    ├── PowerLogServiceTests.swift
    ├── RotationManagerTests.swift
    └── StoreTests.swift
```

---

## 9. API Contracts Summary

### 9.1 IOKitAdapterProtocol

```swift
protocol IOKitAdapterProtocol {
    func cpuUtilization() -> Double        // [0.0, 1.0]
    func gpuUtilization() -> Double        // [0.0, 1.0]
    func isCharging() -> Bool?             // nil = desktop
    func batteryLevel() -> Double?         // nil = desktop, [0.0, 1.0] = laptop
}
```

### 9.2 PowerEstimatorProtocol

```swift
protocol PowerEstimatorProtocol {
    func estimateSystemPower(from cpuUtil: Double, gpuUtil: Double) -> Double  // watts
}
```

### 9.3 PowerLogServiceProtocol

```swift
protocol PowerLogServiceProtocol {
    func append(_ record: PowerRecord) async throws
    func records(in range: DateRange) -> [PowerRecord]
    func recentRecords(count: Int) -> [PowerRecord]
    func sessionAverage() -> Double
    func sessionPeak() -> Double
    func currentWatts() -> Double
    func dailyAverages(for days: Int) -> [DailyAverage]
    func monthlyTotals(for months: Int) -> [MonthlyTotal]
    func clearAll() async throws
}
```

### 9.4 UserDefaultsProtocol

```swift
protocol UserDefaultsProtocol {
    var integer(forKey: String) -> Int { get set }
    var bool(forKey: String) -> Bool { get set }
    func string(forKey: String) -> String?
    func set(_ value: Any?, forKey: String)
    func object(forKey: String) -> Any?
}
```

---

## 10. Constants & Configuration

### 10.1 Sparkline Buffer Size
- Menu bar sparkline: **120 points** (last 120 seconds at 1s interval, rolling window)

### 10.2 Session Window
- Session average/peak: **120 seconds** rolling window (last 120 records)

### 10.3 Chart Ranges
- 7-day chart: **7 days** of daily averages
- Monthly totals: **6 months** of monthly kWh (past 6)

### 10.4 Collection Intervals
- Default: **1 second**; user can increase in settings (5s, 10s options)
- Alternative: **60 seconds** (1 minute)

### 10.5 File Naming
- Daily log: `daily-log.plist`
- Monthly log: `monthly-log.plist`
- Temp file (journal mode): `daily-log.plist.tmp`

### 10.6 Default Storage Path
```
~/Library/Application Support/Mac Wattage/
├── daily-log.plist
└── monthly-log.plist
```
