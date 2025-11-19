import Foundation

/// Protocol for time providers (enables dependency injection for testing)
public protocol TimeProvider: Sendable {
    func now() -> Date
}

/// System time provider using Date()
public struct SystemTimeProvider: TimeProvider {
    public init() {}
    public func now() -> Date { Date() }
}

/// Mock time provider with fixed date (for testing)
public struct MockTimeProvider: TimeProvider {
    private let fixedDate: Date
    public init(fixedDate: Date) { self.fixedDate = fixedDate }
    public func now() -> Date { fixedDate }
}
