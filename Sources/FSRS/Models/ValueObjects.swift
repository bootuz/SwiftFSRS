import Foundation

// MARK: - Stability Value Object

/// Represents memory stability - the interval at which retrievability = 90%
/// Valid range: [S_MIN, S_MAX]
public struct Stability: Sendable, Equatable, Codable {
    public let value: Double
    
    public init(_ value: Double) throws {
        guard value >= S_MIN && value <= S_MAX else {
            throw FSRSError.invalidParameter(
                "Stability must be between \(S_MIN) and \(S_MAX), got \(value)"
            )
        }
        self.value = value
    }
    
    /// Create stability without validation (use carefully, only for constants)
    internal init(unchecked value: Double) {
        self.value = value
    }
    
    /// Initial stability for new cards
    public static let initial = Stability(unchecked: 0.0)
    
    /// Minimum allowed stability
    public static let minimum = Stability(unchecked: S_MIN)
    
    /// Maximum allowed stability
    public static let maximum = Stability(unchecked: S_MAX)
    
    /// Multiply stability by a factor
    public func multiplied(by factor: Double) throws -> Stability {
        try Stability(value * factor)
    }
    
    /// Add to stability
    public func incremented(by delta: Double) throws -> Stability {
        try Stability(value + delta)
    }
    
    /// Check if this is a new card (stability = 0)
    public var isNew: Bool {
        value == 0.0
    }
}

// MARK: - Difficulty Value Object

/// Represents card difficulty
/// Valid range: [1.0, 10.0] where higher values indicate more difficult cards
public struct Difficulty: Sendable, Equatable, Codable {
    public let value: Double
    
    public init(_ value: Double) throws {
        guard value >= DIFFICULTY_RANGE_MIN && value <= DIFFICULTY_RANGE_MAX else {
            throw FSRSError.invalidParameter(
                "Difficulty must be between \(DIFFICULTY_RANGE_MIN) and \(DIFFICULTY_RANGE_MAX), got \(value)"
            )
        }
        self.value = value
    }
    
    /// Create difficulty without validation (use carefully, only for constants)
    internal init(unchecked value: Double) {
        self.value = value
    }
    
    /// Initial difficulty for new cards
    public static let initial = Difficulty(unchecked: 0.0)
    
    /// Easiest difficulty level
    public static let easiest = Difficulty(unchecked: 1.0)
    
    /// Medium difficulty level
    public static let medium = Difficulty(unchecked: 5.0)
    
    /// Hardest difficulty level
    public static let hardest = Difficulty(unchecked: 10.0)
    
    /// Check if this is a new card (difficulty = 0)
    public var isNew: Bool {
        value == 0.0
    }
}

// MARK: - Retrievability Value Object

/// Represents the probability of successfully recalling a card
/// Valid range: [0.0, 1.0] where 1.0 means 100% recall probability
public struct Retrievability: Sendable, Equatable, Codable {
    public let value: Double
    
    public init(_ value: Double) throws {
        guard value >= 0.0 && value <= 1.0 else {
            throw FSRSError.invalidParameter(
                "Retrievability must be between 0.0 and 1.0, got \(value)"
            )
        }
        self.value = value
    }
    
    /// Create retrievability without validation (use carefully, only for constants)
    internal init(unchecked value: Double) {
        self.value = value
    }
    
    /// Zero retrievability (completely forgotten)
    public static let zero = Retrievability(unchecked: 0.0)
    
    /// Perfect retrievability
    public static let perfect = Retrievability(unchecked: 1.0)
    
    /// Target retrievability (90%)
    public static let target = Retrievability(unchecked: RETRIEVABILITY_TARGET)
    
    /// Format as percentage string
    public var percentage: String {
        String(format: "%.2f%%", value * 100)
    }
    
    /// Convert to percentage value (0-100)
    public var percentageValue: Double {
        value * 100
    }
}

// MARK: - ElapsedDays Value Object

/// Represents the number of days elapsed since last review
/// Valid range: [0.0, ∞)
public struct ElapsedDays: Sendable, Equatable, Codable {
    public let value: Double
    
    public init(_ value: Double) throws {
        guard value >= 0.0 else {
            throw FSRSError.invalidParameter(
                "ElapsedDays must be non-negative, got \(value)"
            )
        }
        self.value = value
    }
    
    /// Create elapsed days without validation (use carefully)
    internal init(unchecked value: Double) {
        self.value = value
    }
    
    /// Zero elapsed days (just reviewed)
    public static let zero = ElapsedDays(unchecked: 0.0)
    
    /// Check if this is a same-day review
    public var isSameDay: Bool {
        value == 0.0
    }
}

// MARK: - ScheduledInterval Value Object

/// Represents a scheduled interval for card review
public struct ScheduledInterval: Sendable, Equatable, Codable {
    public let days: Int
    
    public init(days: Int) throws {
        guard days >= 0 else {
            throw FSRSError.invalidParameter(
                "ScheduledInterval must be non-negative, got \(days)"
            )
        }
        self.days = days
    }
    
    /// Create from minutes
    public init(minutes: Int) throws {
        try self.init(days: minutes / MINUTES_PER_DAY)
    }
    
    /// Create interval without validation (use carefully)
    internal init(unchecked days: Int) {
        self.days = days
    }
    
    /// Zero interval (review immediately)
    public static let immediate = ScheduledInterval(unchecked: 0)
    
    /// Convert to minutes
    public var minutes: Int {
        days * MINUTES_PER_DAY
    }
    
    /// Check if this is an immediate review
    public var isImmediate: Bool {
        days == 0
    }
    
    /// Check if this is a short-term interval (less than 1 day)
    public var isShortTerm: Bool {
        days == 0
    }
}

// MARK: - MemoryState Value Object

/// Represents the complete memory state of a card
public struct MemoryState: Sendable, Equatable, Codable {
    public let stability: Stability
    public let difficulty: Difficulty
    
    public init(stability: Stability, difficulty: Difficulty) {
        self.stability = stability
        self.difficulty = difficulty
    }
    
    /// Create from raw values
    public init(stabilityValue: Double, difficultyValue: Double) throws {
        self.stability = try Stability(stabilityValue)
        self.difficulty = try Difficulty(difficultyValue)
    }
    
    /// Initial state for new cards
    public static let initial = MemoryState(
        stability: .initial,
        difficulty: .initial
    )
    
    /// Check if this represents a new card
    public var isNew: Bool {
        stability.isNew && difficulty.isNew
    }
    
    /// Create a new state with updated stability
    public func withStability(_ newStability: Stability) -> MemoryState {
        MemoryState(stability: newStability, difficulty: difficulty)
    }
    
    /// Create a new state with updated difficulty
    public func withDifficulty(_ newDifficulty: Difficulty) -> MemoryState {
        MemoryState(stability: stability, difficulty: newDifficulty)
    }
    
    /// Create a new state with both values updated
    public func with(stability newStability: Stability, difficulty newDifficulty: Difficulty) -> MemoryState {
        MemoryState(stability: newStability, difficulty: newDifficulty)
    }
}
