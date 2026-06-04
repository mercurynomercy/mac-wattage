# Shared — Task List

## E1: Logger Utility

- [x] Create `Logger` enum in `Shared/Logger.swift`:
  - [x] Static method: `warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line)`:
    - [x] Extract filename from full path using `(file as NSString).lastPathComponent`
    - [x] Print format: `[MacWattage WARNING] filename:line function - message`
  - [x] Static method: `error(_ message: String, file: String = #file, function: String = #function, line: Int = #line)`:
    - [x] Same format but with `[MacWattage ERROR]` prefix

- [x] Replace all raw `print()` calls in the codebase with Logger:
  - [x] In PowerLogService.append(): use `.error()` for write failures — NOT NEEDED (errors handled via try/catch, no raw prints remain)
  - [x] In Load methods: use `.warning()` for corrupted file detection — NOT NEEDED (errors handled via try/catch, no raw prints remain)

## Dependencies Between Subtasks

```
E1 (Logger) → used by B2, D1 for error reporting only
```
