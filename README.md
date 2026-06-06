# Mac Wattage

macOS 菜单栏应用，实时追踪 MacBook / Mac Studio 的系统功耗。以瓦特为单位显示当前功率、会话统计和月度总耗电，全部用原生 SwiftUI 绘制，零外部依赖。

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/language-Swift%206-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 功能一览

### 菜单栏小组件
实时显示当前功耗，附带 Sparkline 迷你趋势图：

```
⚡ 42W ▁▂▃█▅▄
```

### Popover 仪表板（点击菜单栏图标打开）
| 区域 | 内容 |
|------|------|
| **当前功耗** | 大号瓦数显示 + 基于最近 120 秒数据的平均/峰值功率 |
| **Sparkline** | 基于最近 120 秒记录的迷你趋势图 (~120 个数据点) |
| **7天图表** | 每日平均功耗柱状图（最近 7 天的 kWh 总计） |
| **月度总耗电** | 过去 6 个月的 kWh 累计，绿色条形图展示 |
| **设置入口** | 一键打开独立设置窗口 |

### 设置窗口
- **采集间隔**: 默认每 `1秒` 采样一次，用户可在设置中调整
- **日志目录**: 通过文件选择器自定义存储路径（默认 `~/Library/Application Support/Mac Wattage/`）
- **开机自启**: 开关控制登录项注册（SMLoginItemSetEnabled）
- **清除数据**: 一键清空所有日志

---

## 架构概览

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
│  IOKitAdapter (CPU/GPU util)                │
│  PowerEstimator (TDP-based wattage model)   │
│  PlatformDetector (MacBook vs Studio)       │
├─────────────────────────────────────────────┤
│            Data Layer                       │
│  PowerLogService (journal-mode plist I/O)   │
│  RotationManager (monthly archive rotation) │
│  Store (UserDefaults settings persistence)  │
└─────────────────────────────────────────────┘
```

### 功耗估算策略
macOS 不提供直接的系统总瓦数 API，Mac Wattage 采用**基于 TDP 的估算模型**:

```
estimatedWatts = idlePower + cpuUtil × (cpuMaxTDP - idlePower) + gpuUtil × gpuMaxGPU
```

各芯片代际的参数：

| 芯片 | Idle (W) | CPU Max (W) | GPU Max (W) |
|------|-----------|-------------|-------------|
| M1/M2 Base | 5 | 40 | 15 |
| Pro | 8 | 60 | 30 |
| Max | 12 | 100 | 60 |
| Ultra | 15 | 120 | 80 |

平台检测通过 `IOServiceGetMatchingServices("AppleSmartBattery")` 区分 Mac Studio（无电池）和 MacBook。

---

## 数据持久化

- **格式**: BinaryPropertyList（原生高效）
- **存储位置**: 默认 `~/Library/Application Support/Mac Wattage/`，用户可在设置中更改
- **写入方式**: Journal-mode（先写临时文件再原子重命名）
- **数据轮转**: 跨月时自动将旧月份记录归档为月度 kWh 总览，仅保留当月原始数据
- **秒级缓冲**: 内存中维护最近 120 条记录（约 2 分钟，1s 间隔），用于实时平均/峰值计算和 Sparkline 图表；每 60 秒将缓冲区内数据聚合为一条记录写入日志，保持 `daily-log.plist` 精简

---

## 技术栈

| 类别 | 选择 |
|------|------|
| **语言** | Swift 6+ (strict concurrency, Sendable / actors) |
| **UI** | SwiftUI + AppKit 集成 (MenuBarExtra, macOS 13+) |
| **硬件 API** | IOKit (`host_processor_info`, `IOServiceMatching`) |
| **存储** | BinaryPropertyList + UserDefaults |
| **图表** | 纯 SwiftUI Path / Rectangle，零第三方库 |

---

## 构建与运行

### 通过 Swift Package Manager
```bash
# 编译并运行测试
swift test

# 构建应用（需要 Xcode toolchain）
swift build
```

### 通过 Xcode
1. `open MacWattage.xcodeproj`
2. 选择 **Mac Wattage** scheme
3. Build & Run (⌘R)

### 最低系统要求
- **macOS**: 13 Ventura（MenuBarExtra API）
- **架构**: Apple Silicon (ARM64) — M1 / M2 系列，含 Pro/Max/Ultra
- **存储**: 每秒钟采集一次，每秒级缓冲（120条）用于实时指标；每分钟聚合写入日志文件

---

## 测试覆盖

```bash
swift test   # 37 tests, all passing ✅
```

| 测试模块 | 文件数 | 用例数 | 覆盖范围 |
|---------|--------|--------|---------|
| PowerEstimatorTests | 1 | 15 | TDP估算模型、芯片代际排序、边界值钳位 |
| PowerLogServiceTests | 1 | 14 | 追加记录、会话统计（基于120秒窗口）、日平均、清除全部、文件持久化、秒级缓冲 flush |
| PlatformDetectorTests | 1 | 2 | 平台检测 / 芯片识别（运行时验证） |
| RotationManagerTests | 1 | 2 | 跨月轮转触发 / 同月跳过 |
| StoreTests | 1 | 5 | UserDefaults 默认值（采集间隔默认为1秒）/ 持久化读写 / LogDirectory |
| Mocks | 1 | — | MockUserDefaults、MockPowerLogService |

---

## 实现阶段（历史）

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 — Core Data Collection | IOKit、CPU/GPU采集、Plist写入 | ✅ 完成 |
| Phase 2 — Menu Bar Widget | 菜单栏图标 + Sparkline | ✅ 完成 |
| Phase 3 — Popover Dashboard | 仪表板 + 7天/月度图表 | ✅ 完成 |
| Phase 4 — Settings & Data Management | 采集间隔、日志目录、清除数据 | ✅ 完成 |
| Phase 5 — Platform Adaptation & Polish | Mac Studio vs MacBook自适应、充电状态显示 | ✅ 完成 |

**92/92 子任务全部实现。** — 详见 `doc/tasks/progress.md`

---

## License

MIT
