//
//  FSRSLogger.swift
//  FSRS
//
//  Created by Astemir Boziev on 05.11.25.
//

import Foundation

/// Log level for FSRS logging system
///
/// Defines the severity of log messages, from informational to error.
/// Levels are ordered by severity: info < debug < warning < error
public enum FSRSLogLevel: Int, Codable, CustomStringConvertible, Sendable {
    /// Informational messages about normal operations
    case info
    /// Detailed diagnostic information for debugging
    case debug
    /// Warning messages about potential issues
    case warning
    /// Error messages about failures or critical issues
    case error

    public var description: String {
        switch self {
        case .info:
            return "info"
        case .debug:
            return "debug"
        case .warning:
            return "warning"
        case .error:
            return "error"
        }
    }
}

/// A structured log message containing metadata about the log event
///
/// Captures all relevant information about a log event including:
/// - The severity level
/// - The source location (file, function, line)
/// - The timestamp
/// - The subsystem that generated the log
public struct FSRSLogMessage: Codable, CustomStringConvertible, Sendable {
    /// The subsystem that generated this log message
    public let system: String
    /// The severity level of this log message
    public let level: FSRSLogLevel
    /// The actual log message content
    public let message: String
    /// The file identifier where the log was generated
    public let fileID: String
    /// The function name where the log was generated
    public let function: String
    /// The line number where the log was generated
    public let line: UInt
    /// The timestamp when the log was generated (seconds since epoch)
    public let timestamp: TimeInterval

    /// Creates a new log message with the specified parameters
    ///
    /// - Parameters:
    ///   - system: The subsystem generating the log
    ///   - level: The severity level
    ///   - message: The log message content
    ///   - fileID: The source file identifier
    ///   - function: The function name
    ///   - line: The line number
    ///   - timestamp: The timestamp (seconds since epoch)
    @usableFromInline
    init(
        system: String,
        level: FSRSLogLevel,
        message: String,
        fileID: String,
        function: String,
        line: UInt,
        timestamp: TimeInterval,
    ) {
        self.system = system
        self.level = level
        self.message = message
        self.fileID = fileID
        self.function = function
        self.line = line
        self.timestamp = timestamp
    }

    /// Formatted string representation of the log message
    ///
    /// Format: `{ISO8601_date} [{level}] [{system}] [{file}.{function}:{line}] {message}`
    ///
    /// Example: `2025-11-20T10:30:45Z [debug] [FSRS] [BaseScheduler.init:83] Scheduler initialized`
    public var description: String {
        let date = Date(timeIntervalSince1970: timestamp).iso8601String
        let file = fileID.split(separator: ".", maxSplits: 1).first.map(String.init) ?? fileID
        let description = "\(date) [\(level)] [\(system)] [\(file).\(function):\(line)] \(message)"

        return description
    }
}

/// Protocol for logging FSRS operations
///
/// Implement this protocol to provide custom logging behavior for the FSRS system.
/// The protocol includes convenience methods for different log levels (info, debug, warning, error)
/// that automatically capture source location information.
///
/// Example implementation:
/// ```swift
/// struct ConsoleLogger: FSRSLogger {
///     func log(message: FSRSLogMessage) {
///         print(message.description)
///     }
/// }
/// ```
public protocol FSRSLogger: Sendable {
    /// Log a message
    ///
    /// - Parameter message: The structured log message to record
    func log(message: FSRSLogMessage)
}

/// Default implementations providing convenience logging methods
public extension FSRSLogger {
    /// Log a message at the specified level
    ///
    /// This is the base method that all convenience methods (info, debug, warning, error) use.
    /// Source location information is automatically captured from the call site.
    ///
    /// - Parameters:
    ///   - level: The severity level
    ///   - message: The message to log (evaluated lazily via autoclosure)
    ///   - fileID: The source file (automatically captured)
    ///   - function: The function name (automatically captured)
    ///   - line: The line number (automatically captured)
    @inlinable
    func log(
        _ level: FSRSLogLevel,
        message: @autoclosure () -> String,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
    ) {
        let system = "\(fileID)".split(separator: "/").first ?? ""

        log(
            message: FSRSLogMessage(
                system: "\(system)",
                level: level,
                message: message(),
                fileID: "\(fileID)",
                function: "\(function)",
                line: line,
                timestamp: Date().timeIntervalSince1970
            )
        )
    }

    /// Log an informational message
    ///
    /// Use for normal operational messages that highlight the progress of the application.
    ///
    /// - Parameters:
    ///   - message: The message to log (evaluated lazily)
    ///   - fileID: The source file (automatically captured)
    ///   - function: The function name (automatically captured)
    ///   - line: The line number (automatically captured)
    @inlinable
    func info(
        _ message: @autoclosure () -> String,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
    ) {
        log(
            .info,
            message: message(),
            fileID: fileID,
            function: function,
            line: line,
        )
    }

    /// Log a debug message
    ///
    /// Use for detailed diagnostic information useful during development and debugging.
    /// These messages typically include variable values, state transitions, and execution flow.
    ///
    /// - Parameters:
    ///   - message: The message to log (evaluated lazily)
    ///   - fileID: The source file (automatically captured)
    ///   - function: The function name (automatically captured)
    ///   - line: The line number (automatically captured)
    @inlinable
    func debug(
        _ message: @autoclosure () -> String,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
    ) {
        log(
            .debug,
            message: message(),
            fileID: fileID,
            function: function,
            line: line,
        )
    }

    /// Log a warning message
    ///
    /// Use for potentially harmful situations that don't prevent the application from continuing
    /// but may indicate problems or unexpected conditions.
    ///
    /// - Parameters:
    ///   - message: The message to log (evaluated lazily)
    ///   - fileID: The source file (automatically captured)
    ///   - function: The function name (automatically captured)
    ///   - line: The line number (automatically captured)
    @inlinable
    func warning(
        _ message: @autoclosure () -> String,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
    ) {
        log(
            .warning,
            message: message(),
            fileID: fileID,
            function: function,
            line: line,
        )
    }

    /// Log an error message
    ///
    /// Use for error events that might still allow the application to continue running,
    /// but represent failures or critical issues that need attention.
    ///
    /// - Parameters:
    ///   - message: The message to log (evaluated lazily)
    ///   - fileID: The source file (automatically captured)
    ///   - function: The function name (automatically captured)
    ///   - line: The line number (automatically captured)
    @inlinable
    func error(
        _ message: @autoclosure () -> String,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
    ) {
        log(
            .error,
            message: message(),
            fileID: fileID,
            function: function,
            line: line,
        )
    }
}

/// Trace an async operation's execution
///
/// Logs "begin" when the operation starts, "end" when it completes successfully,
/// and "error: {error}" if it throws. This is useful for tracking the lifecycle
/// of async operations during debugging.
///
/// - Parameters:
///   - logger: Optional logger to use (if nil, no logging occurs)
///   - operation: The async operation to trace
///   - isolation: Actor isolation context (automatically captured in Swift 6.0+)
///   - fileID: The source file (automatically captured)
///   - function: The function name (automatically captured)
///   - line: The line number (automatically captured)
/// - Returns: The result of the operation
/// - Throws: Rethrows any error from the operation
///
/// Example:
/// ```swift
/// let result = await trace(using: logger) {
///     try await someAsyncOperation()
/// }
/// ```
#if compiler(>=6.0)
    @inlinable
    @discardableResult
    package func trace<R: Sendable>(
        using logger: (any FSRSLogger)?,
        _ operation: () async throws -> R,
        isolation _: isolated (any Actor)? = #isolation,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) async rethrows -> R {
        logger?.debug("begin", fileID: fileID, function: function, line: line)
        defer { logger?.debug("end", fileID: fileID, function: function, line: line) }

        do {
            return try await operation()
        } catch {
            logger?.debug("error: \(error)", fileID: fileID, function: function, line: line)
            throw error
        }
    }

/// Trace an async operation's execution (Swift <6.0 version)
///
/// This version uses `@_unsafeInheritExecutor` for pre-Swift 6.0 compatibility.
/// See the Swift 6.0+ version documentation for details.
#else
    @_unsafeInheritExecutor
    @inlinable
    @discardableResult
    package func trace<R: Sendable>(
        using logger: (any FSRSLogger)?,
        _ operation: () async throws -> R,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) async rethrows -> R {
        logger?.debug("begin", fileID: fileID, function: function, line: line)
        defer { logger?.debug("end", fileID: fileID, function: function, line: line) }

        do {
            return try await operation()
        } catch {
            logger?.debug("error: \(error)", fileID: fileID, function: function, line: line)
            throw error
        }
    }
#endif
