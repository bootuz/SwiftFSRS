# FSRS Logging System

The FSRS Swift implementation includes a comprehensive logging system for debugging, monitoring, and performance analysis.

## Table of Contents

- [Overview](#overview)
- [Log Levels](#log-levels)
- [Logger Protocol](#logger-protocol)
- [Where Logs Are Generated](#where-logs-are-generated)
- [Usage Examples](#usage-examples)
- [Performance Considerations](#performance-considerations)

## Overview

The logging system is designed to be:
- **Optional**: Zero overhead when not used
- **Flexible**: Easy to implement custom loggers
- **Comprehensive**: Covers all major operations
- **Type-safe**: Uses Swift's type system for safety
- **Sendable**: Safe for concurrent use

## Log Levels

Four log levels are available, from most to least info:

| Level | Purpose | Example Use Cases |
|-------|---------|-------------------|
| `info` | Detailed calculations and intermediate values | Forgetting curve calculations, fuzzing details, interval constraints |
| `debug` | Entry/exit of methods, state transitions | Scheduler initialization, card state changes, algorithm decisions |
| `warning` | Recoverable issues, special operations | Rollbacks, forgetting cards, parameter adjustments |
| `error` | Invalid inputs, failures | Invalid grades, memory state errors, failed operations |

## Logger Protocol

Implement the `FSRSLogger` protocol to create a custom logger:

```swift
public protocol FSRSLogger: Sendable {
    func log(message: FSRSLogMessage)
}
```

### FSRSLogMessage

Each log message contains:
- `system`: The system/module generating the log
- `level`: The log level (info, debug, warning, error)
- `message`: The log message text
- `fileID`: Source file identifier
- `function`: Function name
- `line`: Line number
- `timestamp`: Unix timestamp

### Convenience Methods

The protocol extension provides convenience methods:

```swift
logger.info("Detailed information")
logger.debug("Debug information")
logger.warning("Warning message")
logger.error("Error message")
```

## Where Logs Are Generated

### 1. FSRS.swift - Main API

**Debug Level:**
- `init`: "FSRS initialized: useShortTerm={bool}"
- `repeat`: "Previewing all ratings: state={state}, useShortTerm={bool}"
- `next`: "Processing next: grade={grade}, state={state}"
- `reschedule`: "Rescheduling card with {count} reviews"
- Strategy setters: "Setting custom {type} strategy"
- `clearAllStrategies`: "Clearing all custom strategies"

**info Level:**
- `getRetrievabilityValue`: "Retrievability: state={state}, t={t}, s={s} -> r={r}"

**Warning Level:**
- `rollback`: "Rolling back: state={current} -> {previous}, rating={rating}"
- `forget`: "Forgetting card: state={state}, resetCount={bool}"

**Error Level:**
- `next`: "Invalid manual grade" (when grade is manual)
- `rollback`: "Cannot rollback manual rating"

### 2. FSRSAlgorithm.swift - Core Algorithm

**Debug Level:**
- `init`: "Algorithm initialized: requestRetention={r}, maximumInterval={i}, enableFuzz={bool}, enableShortTerm={bool}"
- `nextState`: "New card state: s={s}, d={d}, grade={g}"
- `nextState`: "State transition: s={old_s} -> s'={new_s}, d={old_d} -> d'={new_d}, grade={g}, t={t}"
- `nextInterval`: "Next interval: s={s}, elapsed={elapsed} -> interval={interval}"

**info Level:**
- `forgettingCurve`: "Forgetting curve: t={t}, s={s} -> r={r}"
- `nextState`: "Manual rating: no state change"
- `applyFuzz`: "Fuzz skipped: interval={interval}, enableFuzz={bool}"
- `applyFuzz`: "Fuzz applied: {old} -> {new}, range=[{min}, {max}], factor={factor}"

**Error Level:**
- `init`: "Failed to calculate interval modifier: {error}"
- `nextState`: "Invalid delta t: {t}"
- `nextState`: "Invalid grade: {g}"
- `nextState`: "Invalid grade for new card: {g}"
- `nextState`: "Invalid memory state: d={d}, s={s}"

### 3. BasicScheduler.swift & LongTermScheduler.swift

**Debug Level:**
- `init`: "{Type}Scheduler initialized: state={state}, elapsedDays={days}"
- `newState`: "New card scheduling: grade={grade}"
- `newState`: "New card result: state={state}, scheduledDays={days}, learningSteps={steps}" (BasicScheduler)
- `newState`: "New card result: scheduledDays={days}, stability={s}" (LongTermScheduler)
- `learningState`: "Learning state: grade={grade}, currentState={state}" (BasicScheduler)
- `learningState`: "Learning result: state={state}, learningSteps={steps}" (BasicScheduler)
- `reviewState`: "Review scheduling: grade={grade}, retrievability={r}"
- `reviewState`: "Review result: scheduledDays={days}, lapses={lapses}"

**info Level:**
- `nextDS`: "DS calculation ({grade}): s={old_s} -> {new_s}, d={old_d} -> {new_d}"
- `nextInterval`: "Interval constraints: again={a}, hard={h}, good={g}, easy={e}" (LongTermScheduler)
- `nextInterval`: "Interval constraints: hard={h}, good={g}, easy={e}" (BasicScheduler)

### 4. Reschedule.swift

**Debug Level:**
- `init`: "Reschedule service initialized"
- `reschedule`: "Starting reschedule with {count} reviews"
- `handleManualRating`: "Manual rating: state={state}, elapsedDays={days}"
- `calculateManualRecord`: "Calculating manual record: no changes needed"
- `calculateManualRecord`: "Calculating manual record: scheduledDays={days}, updateMemory={bool}"

**info Level:**
- `reschedule` (in loop): "Processing review #{n}: rating={rating}, date={date}"

## Usage Examples

### Basic Console Logger

```swift
struct ConsoleLogger: FSRSLogger {
    func log(message: FSRSLogMessage) {
        print(message.description)
    }
}

let logger = ConsoleLogger()
let fsrs = FSRS<MyCard>(logger: logger)
```

### Filtered Logger (Warnings and Errors Only)

```swift
struct FilteredLogger: FSRSLogger {
    let minimumLevel: FSRSLogLevel
    
    func log(message: FSRSLogMessage) {
        if message.level.rawValue >= minimumLevel.rawValue {
            print(message.description)
        }
    }
}

let logger = FilteredLogger(minimumLevel: .warning)
let fsrs = FSRS<MyCard>(logger: logger)
```

### File Logger

```swift
struct FileLogger: FSRSLogger {
    let fileURL: URL
    
    func log(message: FSRSLogMessage) {
        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
            return
        }
        defer { try? fileHandle.close() }
        
        fileHandle.seekToEndOfFile()
        if let data = (message.description + "\n").data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

let logURL = URL(fileURLWithPath: "/path/to/fsrs.log")
let logger = FileLogger(fileURL: logURL)
let fsrs = FSRS<MyCard>(logger: logger)
```

### OSLog Integration (iOS/macOS)

```swift
import os.log

struct OSLogger: FSRSLogger {
    private let log = OSLog(subsystem: "com.yourapp.fsrs", category: "algorithm")
    
    func log(message: FSRSLogMessage) {
        let type: OSLogType
        switch message.level {
        case .info: type = .debug
        case .debug: type = .info
        case .warning: type = .error
        case .error: type = .fault
        }
        
        os_log("%{public}@", log: log, type: type, message.description)
    }
}

let logger = OSLogger()
let fsrs = FSRS<MyCard>(logger: logger)
```

## Performance Considerations

### Zero Overhead When Not Used

When no logger is provided, there is **zero performance overhead**:

```swift
// No logger = no performance impact
let fsrs = FSRS<MyCard>()
```

### Lazy Evaluation with @autoclosure

All logging methods use `@autoclosure`, meaning messages are only evaluated if a logger is present:

```swift
// This string interpolation only happens if logger exists
logger?.debug("State: \(expensive_calculation())")
```

### Recommended Log Levels by Frequency

For hot paths (frequently called code):
- Use `info` or `debug` levels
- These are typically filtered out in production

For exceptional cases:
- Use `warning` or `error` levels
- These should be rare and always important

### Memory Considerations

Log messages are created on-demand and not retained by the FSRS system. The logger implementation controls memory usage:

```swift
// Good: Immediate output, no retention
struct ImmediateLogger: FSRSLogger {
    func log(message: FSRSLogMessage) {
        print(message.description)
    }
}

// Caution: Retains all messages in memory
class BufferedLogger: FSRSLogger {
    var messages: [FSRSLogMessage] = []
    
    func log(message: FSRSLogMessage) {
        messages.append(message) // Grows unbounded!
    }
}
```

## Integration Patterns

### Development vs Production

```swift
#if DEBUG
let logger = ConsoleLogger()
#else
let logger: FSRSLogger? = nil // No logging in production
#endif

let fsrs = FSRS<MyCard>(logger: logger)
```

### Conditional Logging

```swift
struct ConditionalLogger: FSRSLogger {
    let enabled: Bool
    
    func log(message: FSRSLogMessage) {
        guard enabled else { return }
        print(message.description)
    }
}

let logger = ConditionalLogger(enabled: UserDefaults.standard.bool(forKey: "enableLogging"))
let fsrs = FSRS<MyCard>(logger: logger)
```

### Multiple Loggers (Composite Pattern)

```swift
struct CompositeLogger: FSRSLogger {
    let loggers: [FSRSLogger]
    
    func log(message: FSRSLogMessage) {
        for logger in loggers {
            logger.log(message: message)
        }
    }
}

let logger = CompositeLogger(loggers: [
    ConsoleLogger(),
    FileLogger(fileURL: logURL),
    OSLogger()
])

let fsrs = FSRS<MyCard>(logger: logger)
```

## Log Message Format

The default format is:

```
{iso8601_date} [{level}] [{system}] [{file}.{function}:{line}] {message}
```

Example:
```
2025-11-05T10:30:45.123Z [debug] [FSRS] [FSRS.next:110] Processing next: grade=good, state=new
```

## Best Practices

1. **Development**: Use info or debug logging to understand algorithm behavior
2. **Production**: Use warning/error levels only, or disable logging entirely
3. **Testing**: Implement a test logger to verify expected operations
4. **Performance Analysis**: Create custom loggers to track timing and frequency
5. **Debugging**: Use file logging to capture issues that are hard to reproduce

## Additional Resources

- See `Examples/LoggerExample.swift` for complete working examples
- See `FSRSLogger.swift` for the protocol definition and convenience methods
- See individual source files for specific log locations and messages

