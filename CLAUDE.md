# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Behavioral guidelines + project-specific rules. These override defaults.**

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make them pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

# Constraints

- Never spawn more than 2 subagents concurrently

## Project Rules (overrides & additions above)

### Scope boundaries

- **Zero external dependencies.** No Swift Package Manager packages. Only Apple frameworks (SwiftUI, AppKit, IOKit, Metal, Foundation).
- **Minimum deployment: macOS 13 Ventura** (MenuBarExtra API availability). Don't use newer APIs without explicit permission.
- **Apple Silicon only.** No Intel/x86_64 support, no `arch -x86_64` fallbacks.

### Code style

- **Swift 6 strict concurrency.** Mark actors, Sendable types explicitly. No `@unchecked Sendable` without justification in a comment.
- **Naming:** Match the proposal's conventions (e.g., `PowerRecord`, `collectionInterval`). Use camelCase, types are PascalCase.
- **Comments:** Only where the "why" isn't obvious from code — especially for IOKit power estimation math.

### Power metrics reality check

- The proposal describes an _estimation_ strategy for power (no direct system watts API exists). Be explicit about estimated vs measured values.
- IOKit hardware sensors may not be available on all models — always have a graceful fallback. Don't crash if `IOServiceGetMatchingServices` returns empty.
- Runtime MacBook vs desktop detection (`AppleSmartBattery`) is the source of truth for what UI to show.

### Data storage

- **Plist format** (BinaryPropertyList) for the log file. Use `PropertyListEncoder`/`Decoder`.
- **Retention policy:** 30 days of raw data at default interval. Implement cleanup — never let the log grow unbounded.
- **Aggregation is computed on-demand** from raw data, not pre-aggregated into separate stores.

### UI

- Custom SwiftUI charts only — no external charting libraries.
- Menu bar item uses `MenuBarExtra` (macOS 13+). Popover is the main dashboard.
- Settings are a separate window or popover — decided per task, not assumed.

### Implementation phases

The proposal defines 5 phases (Core → Menu Bar → Popover → Settings → Polish). When the user asks to work on something, check if an earlier phase's infrastructure exists before building later-phase features.

---

## Build & Test Commands

```bash
# Run all tests (35 unit tests)
swift test

# Run a single test class (e.g., PowerEstimatorTests)
swift test --filter MacWattageTests.PowerEstimatorTests

# Run a single specific test
swift test --filter MacWattageTests.PowerEstimatorTests/test_tdp_estimation_on_m1

# Compile core library (UI files are SPM-excluded due to @main conflict)
swift build

# Open in Xcode for full IDE support and running on hardware
open MacWattage.xcodeproj
```

Tests live in `MacWattageTests/` alongside mock implementations (`Mocks.swift`). All tests are unit tests — no UI integration tests (menu bar extras can't be tested this way on CI).

### Architecture notes

- **IOKit protocol split:** `IOKitAdapter.swift` contains only the `IOKitAdapterProtocol` (no Darwin/IOKit imports, compiles in SPM). The concrete `IOKitAdapter` class lives in `IOKitImplementation.swift`, which imports Darwin and IOKit APIs (`host_statistics64` for CPU, `IOServiceMatching` for GPU/battery). This file is excluded from SPM and only compiled via the Xcode project.
- **CPU metrics:** Uses `host_statistics64(HOST_CPU_LOAD_INFO)` — available on all macOS versions without entitlements. The older `host_processor_info` was replaced because it SIGSEGVs on macOS 15+ without code-signing entitlements.
- **GPU metrics:** Currently returns `0.0` as a conservative fallback — real GPU utilization would require Metal Performance Queries, which need an active `MTLDevice` context.
- **Battery detection:** Checks for `AppleSmartBattery` via IOKit to distinguish MacBook (has battery) from desktop Macs. Returns `nil` for desktops, 100% charge and charging as defaults.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
