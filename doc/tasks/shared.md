# Shared — Task List

## E1: Logger Utility

- [ ] Create `Logger` enum in `Shared/Logger.swift`:
  - [ ] Static method: `warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line)`:
    - [ ] Extract filename from full path using `(file as NSString).lastPathComponent`
    - [ ] Print format: `[MacWattage WARNING] filename:line function - message`
  - [ ] Static method: `error(_ message: String, file: String = #file, function: String = #function, line: Int = #line)`:
    - [ ] Same format but with `[MacWattage ERROR]` prefix

- [ ] Replace all raw `print()` calls in the codebase with Logger:
  - [ ] In PowerLogService.append(): use `.error()` for write failures
  - [ ] In Load methods: use `.warning()` for corrupted file detection

## Dependencies Between Subtasks

```
E1 (Logger) → used by B2, D1 for error reporting only
```
