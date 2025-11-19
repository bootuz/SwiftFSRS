import Foundation

/// Represents a review log entry for a card
public struct ReviewLog: Codable, Equatable, Sendable {
    /// Rating given during the review
    public var rating: Rating
    
    /// State of the card during the review
    public var state: State
    
    /// Date of the last scheduling before this review
    public var due: Date
    
    /// Stability of the card before the review
    public var stability: Double
    
    /// Difficulty of the card before the review
    public var difficulty: Double
    
    /// Number of days until the next review
    public var scheduledDays: Int
    
    /// Current step during (re)learning stages
    public var learningSteps: Int
    
    /// Date of the review
    public var review: Date
    
    public init(
        rating: Rating,
        state: State,
        due: Date,
        stability: Double,
        difficulty: Double,
        scheduledDays: Int,
        learningSteps: Int,
        review: Date
    ) {
        self.rating = rating
        self.state = state
        self.due = due
        self.stability = stability
        self.difficulty = difficulty
        self.scheduledDays = scheduledDays
        self.learningSteps = learningSteps
        self.review = review
    }
}

/// Record log item containing card and review log
/// Generic over Card type to preserve user's Card type
public struct RecordLogItem<Card: FSRSCard>: Sendable {
    public let card: Card
    public let log: ReviewLog
    
    public init(card: Card, log: ReviewLog) {
        self.card = card
        self.log = log
    }
}

/// Record log containing all rating scenarios
/// Generic over Card type to preserve user's Card type
public typealias RecordLog<Card: FSRSCard> = [Rating: RecordLogItem<Card>]


/// FSRS state (difficulty and stability)
public struct FSRSState: Codable, Equatable, Sendable {
    public var stability: Double
    public var difficulty: Double
    
    public init(stability: Double, difficulty: Double) {
        self.stability = stability
        self.difficulty = difficulty
    }
    
    /// Check if this represents a new card (both values are 0)
    public var isNew: Bool {
        stability == 0.0 && difficulty == 0.0
    }
    
    /// Create from value objects
    public init(from memoryState: MemoryState) {
        self.stability = memoryState.stability.value
        self.difficulty = memoryState.difficulty.value
    }
    
    /// Convert to value objects (throws if values are invalid)
    public func toMemoryState() throws -> MemoryState {
        try MemoryState(
            stability: Stability(stability),
            difficulty: Difficulty(difficulty)
        )
    }
    
    /// Create a new state with updated stability
    public func withStability(_ newStability: Double) -> FSRSState {
        FSRSState(stability: newStability, difficulty: difficulty)
    }
    
    /// Create a new state with updated difficulty
    public func withDifficulty(_ newDifficulty: Double) -> FSRSState {
        FSRSState(stability: stability, difficulty: newDifficulty)
    }
}

/// FSRS review entry for history
public struct FSRSReview: Codable, Sendable {
    /// Rating (0-4: Manual, Again, Hard, Good, Easy)
    public var rating: Rating
    
    /// Number of days that passed (delta_t)
    public var deltaT: Int
    
    public init(rating: Rating, deltaT: Int) {
        self.rating = rating
        self.deltaT = deltaT
    }
}

/// FSRS history entry for rescheduling
public struct FSRSHistory: Codable, Sendable {
    public var rating: Rating?
    public var review: Date?
    public var due: Date?
    public var state: State?
    public var stability: Double?
    public var difficulty: Double?
    public var scheduledDays: Int?
    public var learningSteps: Int?
    
    public init(
        rating: Rating? = nil,
        review: Date? = nil,
        due: Date? = nil,
        state: State? = nil,
        stability: Double? = nil,
        difficulty: Double? = nil,
        scheduledDays: Int? = nil,
        learningSteps: Int? = nil
    ) {
        self.rating = rating
        self.review = review
        self.due = due
        self.state = state
        self.stability = stability
        self.difficulty = difficulty
        self.scheduledDays = scheduledDays
        self.learningSteps = learningSteps
    }
}
