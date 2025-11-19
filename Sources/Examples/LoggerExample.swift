import Foundation
import FSRS

// MARK: - Example Logger Implementations

/// Simple console logger that prints all messages
struct ConsoleLogger: FSRSLogger {
    func log(message: FSRSLogMessage) {
        print(message.description)
    }
}

/// Filtered logger that only logs specific levels
struct FilteredLogger: FSRSLogger {
    let minimumLevel: FSRSLogLevel
    
    init(minimumLevel: FSRSLogLevel = .debug) {
        self.minimumLevel = minimumLevel
    }
    
    func log(message: FSRSLogMessage) {
        // Only log if message level is >= minimum level
        if message.level.rawValue >= minimumLevel.rawValue {
            print(message.description)
        }
    }
}

/// File logger that writes to a log file
struct FileLogger: FSRSLogger {
    let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }
    
    func log(message: FSRSLogMessage) {
        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
            return
        }
        
        defer {
            try? fileHandle.close()
        }
        
        fileHandle.seekToEndOfFile()
        if let data = (message.description + "\n").data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

/// Custom logger with colored output (for terminal)
struct ColoredConsoleLogger: FSRSLogger {
    func log(message: FSRSLogMessage) {
        let colorCode: String
        let resetCode = "\u{001B}[0m"
        
        switch message.level {
        case .info:
            colorCode = "\u{001B}[37m" // White
        case .debug:
            colorCode = "\u{001B}[36m" // Cyan
        case .warning:
            colorCode = "\u{001B}[33m" // Yellow
        case .error:
            colorCode = "\u{001B}[31m" // Red
        }
        
        print("\(colorCode)\(message.description)\(resetCode)")
    }
}

// MARK: - Usage Examples

/// Example 1: Basic usage with console logger
func exampleBasicLogging() {
    let logger = ConsoleLogger()
    let fsrs = FSRS<MyCard>(logger: logger)
    
    // All operations will now be logged
    let card = MyCard()
    do {
        let result = try fsrs.next(card: card, now: Date(), grade: .good)
        print("Next due: \(result.card.due)")
    } catch {
        print("Error: \(error)")
    }
}

/// Example 2: Filtered logging (errors and warnings only)
func exampleFilteredLogging() {
    let logger = FilteredLogger(minimumLevel: .warning)
    let fsrs = FSRS<MyCard>(logger: logger)
    
    // Only warnings and errors will be logged
    let card = MyCard()
    do {
        _ = try fsrs.forget(card: card, now: Date()) // This will log a warning
    } catch {
        print("Error: \(error)")
    }
}

/// Example 3: File logging for debugging
func exampleFileLogging() {
    let logFileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("fsrs_debug.log")
    
    let logger = FileLogger(fileURL: logFileURL)
    let fsrs = FSRS<MyCard>(logger: logger)
    
    // All logs will be written to file
    let card = MyCard()
    do {
        let recordLog = try fsrs.repeat(card: card, now: Date())
        print("Logged \(recordLog.count) scenarios to \(logFileURL.path)")
    } catch {
        print("Error: \(error)")
    }
}

/// Example 4: Multiple loggers using a composite pattern
struct CompositeLogger: FSRSLogger {
    let loggers: [FSRSLogger]
    
    init(_ loggers: FSRSLogger...) {
        self.loggers = loggers
    }
    
    func log(message: FSRSLogMessage) {
        for logger in loggers {
            logger.log(message: message)
        }
    }
}

func exampleCompositeLogging() {
    let consoleLogger = ConsoleLogger()
    let fileLogger = FileLogger(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("fsrs.log"))
    
    let compositeLogger = CompositeLogger(consoleLogger, fileLogger)
    let fsrs = FSRS<MyCard>(logger: compositeLogger)
    
    // Logs will go to both console and file
    let card = MyCard()
    do {
        _ = try fsrs.next(card: card, now: Date(), grade: .good)
    } catch {
        print("Error: \(error)")
    }
}

/// Example 5: Async logging with structured output
actor AsyncLogger: FSRSLogger {
    private var messages: [FSRSLogMessage] = []
    
    nonisolated func log(message: FSRSLogMessage) {
        Task {
            await addMessage(message)
        }
    }
    
    private func addMessage(_ message: FSRSLogMessage) {
        messages.append(message)
        
        // Process in batches
        if messages.count >= 100 {
            flush()
        }
    }
    
    private func flush() {
        for message in messages {
            print(message.description)
        }
        messages.removeAll()
    }
    
    func getMessages() -> [FSRSLogMessage] {
        messages
    }
}

// MARK: - Example Card Implementation

struct MyCard: FSRSCard {
    var due = Date()
    var stability: Double = 0
    var difficulty: Double = 0
    var scheduledDays: Int = 0
    var learningSteps: Int = 0
    var reps: Int = 0
    var lapses: Int = 0
    var state: State = .new
    var lastReview: Date?
}

// MARK: - Log Analysis Example

/// Example of analyzing logs for debugging
func exampleLogAnalysis() {
    let logger = ConsoleLogger()
    let fsrs = FSRS<MyCard>(logger: logger)
    
    var card = MyCard()
    
    // Simulate multiple reviews
    let ratings: [Rating] = [.good, .good, .again, .hard, .good]
    
    for rating in ratings {
        do {
            let result = try fsrs.next(card: card, now: Date(), grade: rating)
            card = result.card
            
            // You'll see detailed logs showing:
            // - State transitions
            // - Stability and difficulty changes
            // - Interval calculations
            // - Fuzzing applied (if enabled)
            
        } catch {
            print("Error: \(error)")
        }
        
        // Sleep briefly to separate operations in logs
        Thread.sleep(forTimeInterval: 0.1)
    }
}

// MARK: - Performance Monitoring Example

/// Logger that tracks performance metrics
class PerformanceLogger: FSRSLogger {
    private var operationCounts: [String: Int] = [:]
    private var startTimes: [String: Date] = [:]
    
    func log(message: FSRSLogMessage) {
        let operation = message.function
        
        if message.message.contains("begin") {
            startTimes[operation] = Date()
        } else if message.message.contains("end") {
            if let startTime = startTimes[operation] {
                let duration = Date().timeIntervalSince(startTime)
                print("⏱️ \(operation) took \(String(format: "%.3f", duration))s")
                startTimes.removeValue(forKey: operation)
            }
            
            operationCounts[operation, default: 0] += 1
        }
        
        // Also print the actual log
        print(message.description)
    }
    
    func printStatistics() {
        print("\n📊 Performance Statistics:")
        for (operation, count) in operationCounts.sorted(by: { $0.key < $1.key }) {
            print("  \(operation): \(count) calls")
        }
    }
}

func examplePerformanceMonitoring() {
    let logger = PerformanceLogger()
    let fsrs = FSRS<MyCard>(logger: logger)
    
    var card = MyCard()
    
    // Run multiple operations
    for _ in 0..<10 {
        do {
            let result = try fsrs.next(card: card, now: Date(), grade: .good)
            card = result.card
        } catch {
            print("Error: \(error)")
        }
    }
    
    logger.printStatistics()
}

// MARK: - Main Example Runner

func runAllExamples() {
    print("=== Example 1: Basic Logging ===")
    exampleBasicLogging()
    
    print("\n=== Example 2: Filtered Logging ===")
    exampleFilteredLogging()
    
    print("\n=== Example 3: File Logging ===")
    exampleFileLogging()
    
    print("\n=== Example 4: Composite Logging ===")
    exampleCompositeLogging()
    
    print("\n=== Example 5: Log Analysis ===")
    exampleLogAnalysis()
    
    print("\n=== Example 6: Performance Monitoring ===")
    examplePerformanceMonitoring()
}
