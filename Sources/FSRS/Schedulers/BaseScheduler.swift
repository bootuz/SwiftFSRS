import Foundation

/// Base scheduler containing common logic for all scheduler types
/// Subclasses implement mode-specific behavior (e.g., learning steps vs direct review)
open class BaseScheduler<Card: FSRSCard>: SchedulerProtocol {
    // MARK: - Properties
    
    /// Last card state (before review)
    public let lastCard: Card
    
    /// Current card state (after initialization, with updated reps)
    public var currentCard: Card
    
    /// Time of review
    public let reviewTime: Date
    
    /// Days elapsed since last review (value object)
    internal let elapsedDaysValue: ElapsedDays
    
    /// FSRS algorithm instance
    public let algorithm: any FSRSAlgorithmProtocol
    
    /// Logger for debugging
    internal let logger: (any FSRSLogger)?
    
    /// Calculator for stability operations
    internal let stabilityCalculator: StabilityCalculator
    
    /// Calculator for difficulty operations
    internal let difficultyCalculator: DifficultyCalculator
    
    /// Calculator for interval operations
    internal let intervalCalculator: IntervalCalculator
    
    // MARK: - Initialization
    
    public init(
        card: Card,
        now: Date,
        algorithm: any FSRSAlgorithmProtocol,
        logger: (any FSRSLogger)? = nil
    ) {
        self.lastCard = card
        self.reviewTime = now
        self.algorithm = algorithm
        self.logger = logger
        
        // Calculate elapsed days
        let intervalDays: Double
        if card.state != .new, let lastReview = card.lastReview {
            intervalDays = Double(dateDiffInDays(last: lastReview, current: now))
        } else {
            intervalDays = 0
        }
        self.elapsedDaysValue = (try? ElapsedDays(intervalDays)) ?? .zero
        
        // Initialize calculators
        self.stabilityCalculator = StabilityCalculator(
            parameters: algorithm.parameters,
            logger: logger
        )
        self.difficultyCalculator = DifficultyCalculator(
            parameters: algorithm.parameters,
            logger: logger
        )
        self.intervalCalculator = IntervalCalculator(
            parameters: algorithm.parameters,
            randomProvider: algorithm.randomProvider,
            logger: logger
        )
        
        // Update current card with review info
        var updatedCurrent = card
        updatedCurrent.lastReview = now
        updatedCurrent.reps += 1
        self.currentCard = updatedCurrent
        
        logger?.debug("""
            Scheduler initialized: \
            type=\(type(of: self)), \
            state=\(card.state), \
            elapsed=\(intervalDays)d
            """)
    }
    
    // MARK: - Common Methods
    
    /// Calculate next memory state (difficulty and stability) for a rating
    ///
    /// - Parameters:
    ///   - elapsedDays: Days elapsed since last review
    ///   - grade: Rating given
    ///   - retrievability: Optional retrievability (calculated if nil)
    /// - Returns: Next memory state
    /// - Throws: FSRSError if calculation fails
    internal func calculateNextMemoryState(
        elapsedDays elapsedDaysParam: ElapsedDays,
        grade: Rating,
        retrievability: Retrievability? = nil
    ) throws -> MemoryState {
        // Check if card is new BEFORE trying to create value objects
        // New cards have stability=0.0 and difficulty=0.0, which fail validation
        let isNewCard = currentCard.stability == 0.0 && currentCard.difficulty == 0.0
        
        if isNewCard {
            let initialStability = try stabilityCalculator.initStability(for: grade)
            let initialDifficulty = try difficultyCalculator.initDifficulty(for: grade)
            
            logger?.debug("""
                New card state: \
                stability=\(initialStability.value), \
                difficulty=\(initialDifficulty.value), \
                grade=\(grade)
                """)
            
            return MemoryState(
                stability: initialStability,
                difficulty: initialDifficulty
            )
        }
        
        // Card is not new, so we can safely create value objects
        let currentStability = try Stability(currentCard.stability)
        let currentDifficulty = try Difficulty(currentCard.difficulty)
        
        // Calculate or use provided retrievability
        let actualRetrievability: Retrievability
        if let provided = retrievability {
            actualRetrievability = provided
        } else {
            actualRetrievability = try stabilityCalculator.forgettingCurve(
                elapsedDays: elapsedDaysParam,
                stability: currentStability
            )
        }
        
        // Calculate next difficulty
        let nextDifficulty = try difficultyCalculator.nextDifficulty(
            current: currentDifficulty,
            grade: grade
        )
        
        // Calculate next stability based on grade
        let nextStability: Stability
        if grade == .again {
            // For "Again", use forget stability
            nextStability = try stabilityCalculator.nextForgetStability(
                difficulty: currentDifficulty,
                stability: currentStability,
                retrievability: actualRetrievability
            )
        } else {
            // For other grades, use recall stability
            nextStability = try stabilityCalculator.nextRecallStability(
                difficulty: currentDifficulty,
                stability: currentStability,
                retrievability: actualRetrievability,
                grade: grade
            )
        }
        
        logger?.debug("""
            State transition: \
            s=\(currentStability.value) -> \(nextStability.value), \
            d=\(currentDifficulty.value) -> \(nextDifficulty.value), \
            grade=\(grade)
            """)
        
        return MemoryState(stability: nextStability, difficulty: nextDifficulty)
    }
    
    /// Schedule a card with direct interval (no learning steps)
    ///
    /// - Parameters:
    ///   - card: Card to schedule
    ///   - stability: Stability to use for interval calculation
    ///   - intervalModifier: Interval modifier from algorithm
    internal func scheduleWithInterval(
        card: inout Card,
        stability: Stability,
        intervalModifier: Double
    ) {
        let interval = intervalCalculator.calculateScheduledInterval(
            stability: stability,
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )
        
        card.scheduledDays = interval
        card.due = dateScheduler(
            now: reviewTime,
            offset: Double(interval),
            isDay: true
        )
        card.state = .review
        card.learningSteps = 0
        
        logger?.debug("Scheduled with interval: \(interval) days")
    }
    
    // MARK: - Template Methods (Override in Subclasses)
    
    /// Schedule a new card
    /// Must be overridden by subclasses
    open func scheduleNewCard(grade: Rating) throws -> RecordLogItem<Card> {
        fatalError("Must override scheduleNewCard in subclass")
    }
    
    /// Schedule a learning/relearning card
    /// Must be overridden by subclasses
    open func scheduleLearningCard(grade: Rating) throws -> RecordLogItem<Card> {
        fatalError("Must override scheduleLearningCard in subclass")
    }
    
    /// Schedule a review card
    /// Must be overridden by subclasses
    open func scheduleReviewCard(grade: Rating) throws -> RecordLogItem<Card> {
        fatalError("Must override scheduleReviewCard in subclass")
    }
}

// MARK: - SchedulerProtocol Implementation

extension BaseScheduler {
    public var last: Card { lastCard }
    public var current: Card {
        get { currentCard }
        set { currentCard = newValue }
    }
    
    // Protocol requires Double, but we use ElapsedDays value object internally
    public var elapsedDays: Double {
        elapsedDaysValue.value
    }
    
    public func newState(grade: Rating) throws -> RecordLogItem<Card> {
        try scheduleNewCard(grade: grade)
    }
    
    public func learningState(grade: Rating) throws -> RecordLogItem<Card> {
        try scheduleLearningCard(grade: grade)
    }
    
    public func reviewState(grade: Rating) throws -> RecordLogItem<Card> {
        try scheduleReviewCard(grade: grade)
    }
}

