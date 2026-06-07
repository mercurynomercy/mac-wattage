# Mac Wattage

macOS 菜单栏应用，实时追踪 MacBook / Mac Studio / Mac mini 的系统功耗。以瓦特为单位显示当前功率、会话统计和月度总耗电，全部用原生 SwiftUI 绘制，**零外部依赖**。

> **功耗读取方式：** 优先通过私有但无需 root 的 **IOReport "Energy Model"** 计数器读取**实测** SoC 功耗（CPU + GPU + ANE，与 `powermetrics` 同源），再叠加非 SoC 部分的建模偏移得到整机功耗；当 IOReport 不可用时，自动回退到基于 TDP 的估算模型。

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/language-Swift%206-orange)
![Chips](https://img.shields.io/badge/chips-M1%E2%80%93M5-purple)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 功能一览

### 菜单栏小组件
菜单栏单行显示当前功耗瓦数（圆体字），随采集周期实时刷新：

```
42W
```

### Popover 仪表板（点击菜单栏图标打开）

> 使用 `MenuBarExtra(...).menuBarExtraStyle(.window)` —— 以独立窗口（而非原生菜单）承载内容，这样自定义图表 / 渐变 / Path 绘制才能正常渲染。

| 区域 | 内容 |
|------|------|
| **顶栏** | 左上角齿轮图标打开设置，右上角电源图标退出应用 |
| **当前功耗** | 大号瓦数显示 + 基于最近 120 秒数据的平均/峰值功率 |
| **Live Power** | 基于最近 ~36 个采样点的实时面积趋势图，**基线锚定在 0W**（柱高反映绝对功率，而非区间相对值） |
| **7-Day Power Consumption (kWh)** | 最近 7 天每日 kWh 柱状图（绿色），X 轴用日期标注（如 `Jun 7`），柱顶显示当日 kWh，标题已标注单位 |
| **月度总耗电** | 过去 12 个月的 kWh 累计，绿色条形图展示 |

### 设置窗口
- **采集间隔**: 默认每 `1秒` 采样一次，用户可在设置中调整
- **日志目录**: 通过文件选择器自定义存储路径（默认 `~/Library/Application Support/Mac Wattage/`）
- **开机自启**: 开关控制登录项注册（`SMAppService.mainApp`，macOS 13+；开关状态直接读取系统注册状态，与"系统设置 → 登录项"保持同步）
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

> **IOKit 协议拆分：** `IOKitAdapter.swift` 只含纯协议（`IOKitAdapterProtocol` / `SoCPowerReaderProtocol`，无 Darwin/IOKit import，可在 SPM 下编译）；具体实现 `IOKitAdapter`（CPU/GPU 利用率）位于 `IOKitImplementation.swift`，`IOReportPowerReader`（实测功耗）位于 `IOReportPowerReader.swift`，二者导入 Darwin / IOKit，仅通过 Xcode 工程编译。

---

## 功耗读取与估算

Mac Wattage 采用**双路策略**：能拿到实测值就用实测，拿不到才回退到估算。

### A) 实测路径（首选）—— IOReport "Energy Model"

macOS 没有公开的整机瓦数 API，但 Apple Silicon 通过私有框架 **IOReport** 暴露了与 `powermetrics` 同源的、**无需 root** 的每子系统能耗计数器（`macmon` / `asitop` 即基于此）。

- 通过 `dlopen("/usr/lib/libIOReport.dylib")` + `dlsym` 在运行期解析符号（`IOReportCopyChannelsInGroup` / `IOReportCreateSubscription` / `IOReportCreateSamples` / `IOReportCreateSamplesDelta` 及通道访问器），因此**无新增依赖**，文件随 `IOKitImplementation.swift` 一并被 SPM 排除、仅 Xcode 编译。
- 订阅 **"Energy Model"** 通道组，每个采集周期采样一次累计能耗，对相邻两次取差值：`功率(W) = ΔEnergy(J) / Δt(s)`。
- 累加 CPU / GPU / ANE（及存在时的其他能耗通道），得到**实测 SoC 计算功耗**（等价于 `powermetrics` 的 "Combined Power"）。
- 任意失败（首个采样无基线、硬件不支持、符号缺失）一律返回 `nil`，自动落到下方的 TDP 估算路径。

> **注意 CF 内存语义：** `IOReportCopy*` / `IOReportCreate*` 返回 +1 所有权，用 `takeRetainedValue()`；而 `IOReportChannelGet*`（如取通道名 / 单位）返回借用引用，必须用 `takeUnretainedValue()`，否则会过度释放导致崩溃。

### 整机功耗 = 实测 SoC + 非 SoC 偏移

实测路径只覆盖 SoC 计算部分（不含屏幕 / SSD / 风扇等），因此 `PowerEstimator.wholeSystemPower(socWatts:cpuUtil:gpuUtil:)` 在实测瓦数之上叠加建模偏移，近似整机墙插功耗：

```
整机功耗 = max(0, 实测SoC) + baseConsumption + fanPower + displayPower
fanPower    = screenOff ? 0 : fanWatts × combinedLoad      // 随负载连续缩放
displayPower = (笔记本 && 屏幕开启) ? 5.0 : 0.0            // 内置屏功耗，桌面机为 0
```

> 屏幕关闭时风扇与屏幕功耗均归零。**整机数即"实测计算功耗 + 建模其余部分"**：屏幕亮度 / 外设为近似建模，并非逐项实测。

### B) 估算路径（回退）—— 基于 TDP 的连续模型

当 IOReport 不可用时，完全使用以下基于 TDP（热设计功耗）的连续估算模型。

### 1) 数据采集

每秒通过以下系统 API 读取硬件指标：

| 数据 | macOS API / Source | 说明 |
|------|-------------------|------|
| CPU 利用率 | `host_statistics64(HOST_CPU_LOAD_INFO)` | 内核返回自开机以来每个 CPU state（用户态/系统态/空闲）的累计 tick 数，取相邻两次采集差值计算忙闲比例。无需 entitlement，全 macOS 版本可用 |
| GPU 利用率 | IOKit `IOAccelerator` → `PerformanceStatistics["Device Utilization %"]` | 读取真实 GPU 占用率（与活动监视器 / iStat 同源），遍历所有 accelerator 取最大值。无可用数据时回退 0.0 |
| 充电状态 / 平台类型 | `IOServiceMatching("AppleSmartBattery")` | 有电池 → MacBook，无电池 → Mac Studio/Mini；同时返回充电状态（仅笔记本） |
| 芯片代际 | `sysctl("machdep.cpu.brand_string")` | "M1 Ultra" / "M3 Max" 等，用于选择 TDP 参数 |
| RAM 容量 | `sysctl("hw.memsize")` | 决定 Memory Coefficient |
| 风扇型号 | IOKit device tree `fan-backend-types` / `model` | none/single/dual/turbo，影响风扇功耗估算 |
| 屏幕状态 | IOKit `AppleBacklightDisplay.DisplayPowerState` | 0 = off → 强制 deep-idle，风扇功耗归零 |

### 2) 计算公式

```
combinedLoad  = 0.6 × clampedCPU + 0.4 × clampedGPU          // [0, 1]
effectiveLoad = screenOff ? 0.03 : 0.20 + 0.80 × combinedLoad // 连续，含 0.20 空闲底
fanPower      = screenOff ? 0 : fanWatts × combinedLoad        // 随负载连续缩放
watts         = SoC_TDP × effectiveLoad × memoryCoefficient + baseConsumption + fanPower
```

**关键点：** load factor 与风扇功耗均为**连续函数**（而非离散档位），因此瓦数随 CPU / GPU 负载平滑变化，不会在固定档位间"跳变"。

**利用率钳位与组合负载：** CPU/GPU 输入先 clamp 到 `[0.0, 1.0]`，再按 `60% CPU + 40% GPU` 加权（CPU 权重更高）。

**Effective Load（有效负载）：** 从空闲底 `0.20`（代表后台基础活动）线性爬升至满载 `1.0`。屏幕关闭时强制 `0.03` 深度空闲。

### 3) SoC TDP 表（满载封装功率，CPU+GPU 合计）

> Apple **从不公开官方 TDP**，下表为社区实测估算值。Ultra ≈ 2× 对应 Max（双 die 融合）。**M4 / M5 没有 Ultra 型号。**

| 芯片 | Base | Pro | Max | Ultra |
|------|:----:|:---:|:---:|:-----:|
| **M1** | 20 | 30 | 57 | 115 |
| **M2** | 20 | 35 | 61 | 120 |
| **M3** | 20 | 35 | 78 | 160 |
| **M4** | 25 | 45 | 90 | — |
| **M5**¹ | 27 | 48 | 95 | — |

*单位：瓦特 (W)。¹ M5 系列为基于 M4 约 +10% 的外推估算值，建议对照实测数据校准。*

### 4) Memory Coefficient（内存系数）

RAM 越大 → 内存控制器 / 带宽越多 → 功耗越高。覆盖 8GB 至 512GB（M3 Ultra）全部出厂配置：

| RAM | 系数 | RAM | 系数 |
|----:|:----:|----:|:----:|
| 8 GB | 1.00 | 64 GB | 1.18 |
| 16 GB | 1.05 | 96 GB | 1.24 |
| 24 GB | 1.08 | 128 GB | 1.30 |
| 32 GB | 1.10 | 192 GB | 1.40 |
| 36 GB | 1.12 | 256 GB | 1.50 |
| 48 GB | 1.15 | 512 GB | 1.70 |

> 取**不超过实际容量的最大档位**（例如 18GB 取 16GB 档）。

### 5) Base Consumption（基础功耗）— SSD + 主板最低消耗

| 平台 | 值 (W) |
|------|:------:|
| MacBook（笔记本） | 5.0 |
| Mac Studio / Mac mini（桌面） | 12.0 |

### 6) Fan Power（风扇功耗）— 随负载连续缩放

| 风扇类型 | 满载功率 (W) | 实际功耗 |
|---------|:-----------:|---------|
| none（无风扇，如 M2 Air） | 0 | 0 |
| single（单风扇） | 3.0 | `3.0 × combinedLoad` |
| dual（双风扇） | 6.0 | `6.0 × combinedLoad` |
| turbo（涡轮/液冷） | 12.0 | `12.0 × combinedLoad` |

> 屏幕关闭时风扇功耗强制归零。

### 计算示例

MacBook Pro **M1 Max**，CPU 60%、GPU 80%，32 GB RAM，双风扇：

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

> **注意：** 以上为估算值而非实测瓦数。Apple Silicon SoC 的功耗传感器不对外部应用开放，结果存在一定误差范围。

---

## 数据持久化

- **格式**: BinaryPropertyList（`PropertyListEncoder` / `Decoder`，原生高效）
- **存储位置**: 默认 `~/Library/Application Support/Mac Wattage/`，用户可在设置中更改
- **写入方式**: Journal-mode（先写临时文件再原子重命名）
- **数据轮转（按自然月）**: `RotationManager` 在 **App 启动时** 检查月份是否变化（对比 UserDefaults 中的 `lastRotationMonth`）。跨月时，将**当前月之前**的所有原始记录按 `yyyy-MM` 分组、算成月度 kWh 总计合并入 `monthly-log.plist`，再从 `daily-log.plist` 删除这些原始记录
- **原始数据保留量**: **仅当前自然月**。因此实际保留时长在 ~1–31 天间浮动（取决于今天是本月第几天）；月度总计永久保留（UI 只展示最近 12 个月）
- **秒级缓冲**: 内存中维护最近 120 条记录（约 2 分钟，1s 间隔），用于实时平均/峰值计算和 Sparkline；每 60 秒将缓冲区聚合为一条记录写入 `daily-log.plist`，保持日志精简
- **kWh 换算**: 每条聚合记录代表约 1 分钟平均瓦数，故 `kWh = Σ(watts) / 60000`

---

## 技术栈

| 类别 | 选择 |
|------|------|
| **语言** | Swift 6 (strict concurrency, Sendable / actors) |
| **UI** | SwiftUI + AppKit 集成 (MenuBarExtra `.window` 样式, macOS 13+) |
| **硬件 API** | IOReport（`Energy Model` 实测能耗，dlopen 私有框架）+ IOKit (`host_statistics64`, `IOAccelerator`, `IOServiceMatching`, device tree) + sysctl |
| **开机自启** | ServiceManagement `SMAppService`（macOS 13+） |
| **存储** | BinaryPropertyList + UserDefaults |
| **图表** | 纯 SwiftUI `Path` / `Rectangle` / `Capsule`，零第三方库 |

> **为何不用 `Canvas`？** `Canvas` 在 `MenuBarExtra` 弹窗内不渲染，因此 Sparkline 改用 `GeometryReader` + `Path` 实现。

---

## 构建与运行

### 通过 Xcode（推荐，可在真机运行）
```bash
open MacWattage.xcodeproj
```
1. 选择 **Mac Wattage** scheme
2. Build & Run (⌘R)

> UI 文件与 `IOKitImplementation.swift` 因 `@main` 冲突 / 需要 IOKit，被 SPM 排除，**只能通过 Xcode 工程编译运行完整应用**。

### 通过 build.sh（命令行快速构建）
```bash
# 一键编译并输出到 dist/，可任意目录执行：
./build.sh

# 构建产物位于 dist/MacWattage.app，可直接打开：
open dist/MacWattage.app
```

> `build.sh` 基于 Debug configuration，自动切到项目根目录并在 dist/ 不存在时创建它。构建产物位于 DerivedData，脚本自动查找并复制到 `dist/` 目录。

### 通过 Swift Package Manager（仅核心库 + 测试）
```bash
# 编译核心库（UI 文件被 SPM 排除）
swift build

# 运行全部单元测试
swift test

# 运行单个测试类
swift test --filter MacWattageTests.PowerEstimatorTests

# 运行单个用例
swift test --filter MacWattageTests.PowerEstimatorTests/testM2BaseAtIdle
```

### 最低系统要求
- **macOS**: 13 Ventura（MenuBarExtra API）
- **架构**: Apple Silicon (ARM64) only — M1 / M2 / M3 / M4 / M5，含 Pro / Max / Ultra；**不支持 Intel**

---

## 测试覆盖

```bash
swift test   # 48 tests, all passing ✅
```

| 测试模块 | 用例数 | 覆盖范围 |
|---------|:------:|---------|
| PowerEstimatorTests | 26 | TDP 估算模型（连续公式、effectiveLoad / memory coefficient / fan power）、芯片代际排序与对比、边界值钳位（负数/超1.0）、屏幕关闭强制 idle、`wholeSystemPower` 实测+偏移（base/fan/display、负值钳位、屏幕关闭） |
| PowerLogServiceTests | 14 | 追加记录、会话统计（120秒窗口）、日平均、清除全部、文件持久化、秒级缓冲 flush |
| PlatformDetectorTests | 2 | 平台检测 / 芯片识别（运行时验证） |
| RotationManagerTests | 2 | 跨月轮转触发 / 同月跳过 |
| StoreTests | 5 | UserDefaults 默认值（采集间隔默认1秒）/ 持久化读写 / LogDirectory |
| Mocks | — | MockUserDefaults、MockPowerLogService |

---

## License

MIT
