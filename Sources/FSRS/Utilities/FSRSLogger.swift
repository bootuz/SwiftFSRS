//
//  FSRSLogger.swift
//  FSRS
//
//  Created by Astemir Boziev on 05.11.25.
//


import Foundation

public enum FSRSLogLevel: Int, Codable, CustomStringConvertible, Sendable {
    case info
    case debug
    case warning
    case error
    
    public var description: String {
        switch self {
        case .info: "info"
        case .debug: "debug"
        case .warning: "warning"
        case .error: "error"
        }
    }
}

public struct FSRSLogMessage: Codable, CustomStringConvertible, Sendable {
    public let system: String
    public let level: FSRSLogLevel
    public let message: String
    public let fileID: String
    public let function: String
    public let line: UInt
    public let timestamp: TimeInterval
    
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
    
    public var description: String {
        let date = Date(timeIntervalSince1970: timestamp).iso8601String
        let file = fileID.split(separator: ".", maxSplits: 1).first.map(String.init) ?? fileID
        let description = "\(date) [\(level)] [\(system)] [\(file).\(function):\(line)] \(message)"
        
        return description
    }
}

public protocol FSRSLogger: Sendable {
    func log(message: FSRSLogMessage)
}

extension FSRSLogger {
    @inlinable
    public func log(
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
    
    @inlinable
    public func info(
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
    
    @inlinable
    public func debug(
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
    
    @inlinable
    public func warning(
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
    
    @inlinable
    public func error(
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

