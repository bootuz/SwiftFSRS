import Foundation

/// Reschedule service for replaying review history
public struct RescheduleService<Card: FSRSCard> {
    private let fsrs: FSRS<Card>
    private let logger: (any FSRSLogger)?
    
    /// Initialize Reschedule service
    /// - Parameters:
    ///   - fsrs: FSRS instance
    ///   - logger: Optional logger for debugging and monitoring
    public init(fsrs: FSRS<Card>, logger: (any FSRSLogger)? = nil) {
        self.fsrs = fsrs
        self.logger = logger
        logger?.debug("Reschedule service initialized")
    }
    
    /// Replay a review
    /// - Parameters:
    ///   - card: Card being reviewed
    ///   - reviewed: Review date
    ///   - rating: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSError if any operation fails
    public func replay(card: Card, reviewed: Date, rating: Rating) throws -> RecordLogItem<Card> {
        return try fsrs.next(card: card, now: reviewed, grade: rating)
    }
    
    /// Handle manual rating
    /// - Parameters:
    ///   - card: Card being reviewed
    ///   - state: New state
    ///   - reviewed: Review date
    ///   - stability: Optional stability value
    ///   - difficulty: Optional difficulty value
    ///   - due: Optional due date
    /// - Returns: Record log item
    public func handleManualRating(
        card: Card,
        state: State,
        reviewed: Date,
        stability: Double? = nil,
        difficulty: Double? = nil,
        due: Date? = nil
    ) throws -> RecordLogItem<Card> {
        logger?.debug("Manual rating: state=\(state)")
        
        if state == .new {
            let log = ReviewLog(
                rating: .manual,
                state: state,
                due: due ?? reviewed,
                stability: card.stability,
                difficulty: card.difficulty,
                scheduledDays: card.scheduledDays,
                learningSteps: card.learningSteps,
                review: reviewed
            )
            
            // Direct property mutation
            var nextCard = card
            nextCard.due = reviewed
            nextCard.stability = 0
            nextCard.difficulty = 0
            nextCard.scheduledDays = 0
            nextCard.learningSteps = 0
            nextCard.reps = 0
            nextCard.lapses = 0
            nextCard.state = .new
            nextCard.lastReview = reviewed
            
            return RecordLogItem(card: nextCard, log: log)
        } else {
            guard let due = due else {
                throw FSRSError.invalidParameter("reschedule: due is required for manual rating")
            }
            
            let scheduledDays = Int(dateDiff(now: due, previous: reviewed, unit: CalculationTimeUnit.days))
            
            let log = ReviewLog(
                rating: .manual,
                state: card.state,
                due: card.lastReview ?? card.due,
                stability: card.stability,
                difficulty: card.difficulty,
                scheduledDays: card.scheduledDays,
                learningSteps: card.learningSteps,
                review: reviewed
            )
            
            // Direct property mutation
            var nextCard = card
            nextCard.state = state
            nextCard.due = due
            nextCard.lastReview = reviewed
            nextCard.stability = stability ?? card.stability
            nextCard.difficulty = difficulty ?? card.difficulty
            nextCard.scheduledDays = scheduledDays
            nextCard.reps += 1
            
            return RecordLogItem(card: nextCard, log: log)
        }
    }
    
    /// Reschedule card based on review history
    /// - Parameters:
    ///   - currentCard: Initial card state
    ///   - reviews: Review history
    /// - Returns: Array of record log items
    /// - Throws: FSRSError if any operation fails
    public func reschedule(currentCard: Card, reviews: [FSRSHistory]) throws -> [RecordLogItem<Card>] {
        logger?.debug("Starting reschedule with \(reviews.count) reviews")
        
        var collections: [RecordLogItem<Card>] = []
        
        // Create empty card from currentCard
        var curCard = currentCard
        curCard.stability = 0
        curCard.difficulty = 0
        curCard.scheduledDays = 0
        curCard.learningSteps = 0
        curCard.reps = 0
        curCard.lapses = 0
        curCard.state = .new
        curCard.lastReview = nil
        
        for (index, review) in reviews.enumerated() {
            guard let reviewDateValue = review.review else {
                continue
            }
            
            logger?.info("Processing review #\(index + 1): rating=\(review.rating?.rawValue ?? 0), date=\(reviewDateValue)")
            
            var item: RecordLogItem<Card>
            
            if review.rating == .manual {
                item = try handleManualRating(
                    card: curCard,
                    state: review.state ?? curCard.state,
                    reviewed: reviewDateValue,
                    stability: review.stability,
                    difficulty: review.difficulty,
                    due: review.due
                )
            } else if let rating = review.rating {
                item = try replay(card: curCard, reviewed: reviewDateValue, rating: rating)
            } else {
                continue
            }
            
            collections.append(item)
            curCard = item.card
        }
        
        return collections
    }
    
    /// Calculate manual record for rescheduling
    /// - Parameters:
    ///   - currentCard: Current card state
    ///   - now: Current time
    ///   - recordLogItem: Optional last record log item
    ///   - updateMemory: Whether to update memory state
    /// - Returns: Manual record log item or nil
    /// - Throws: FSRSError if any operation fails
    public func calculateManualRecord(
        currentCard: Card,
        now: Date,
        recordLogItem: RecordLogItem<Card>?,
        updateMemory: Bool
    ) throws -> RecordLogItem<Card>? {
        guard let recordLogItem = recordLogItem else {
            return nil
        }
        
        let rescheduleCard = recordLogItem.card
        
        // If cards are the same, return nil
        if currentCard.due.timeIntervalSince1970 == rescheduleCard.due.timeIntervalSince1970 {
            logger?.debug("Calculating manual record: no changes needed")
            return nil
        }
        
        var updatedCard = currentCard
        updatedCard.scheduledDays = Int(dateDiff(
            now: rescheduleCard.due,
            previous: currentCard.due,
            unit: CalculationTimeUnit.days
        ))
        
        logger?.debug("Calculating manual record: scheduledDays=\(updatedCard.scheduledDays), updateMemory=\(updateMemory)")
        
        return try handleManualRating(
            card: updatedCard,
            state: rescheduleCard.state,
            reviewed: now,
            stability: updateMemory ? rescheduleCard.stability : nil,
            difficulty: updateMemory ? rescheduleCard.difficulty : nil,
            due: rescheduleCard.due
        )
    }
}

// MARK: - Reschedule Models

/// Reschedule options configuration
public struct RescheduleOptions<Card: FSRSCard> {
    /// Optional handler to transform each record log item
    public var recordLogHandler: ((RecordLogItem<Card>) -> RecordLogItem<Card>)?
    
    /// Optional handler to transform the final manual item
    public var recordLogItemHandler: ((RecordLogItem<Card>) -> RecordLogItem<Card>)?
    
    /// Optional custom sort order for reviews
    public var reviewsOrderBy: ((FSRSHistory, FSRSHistory) -> Bool)?
    
    /// Whether to skip manual reviews (default: true)
    public var skipManual: Bool = true
    
    /// Whether to update memory state (stability/difficulty) (default: false)
    public var updateMemoryState: Bool = false
    
    /// Current time (defaults to now)
    public var now: Date?
    
    /// Optional starting card state (defaults to empty card)
    public var firstCard: Card?
    
    public init(
        recordLogHandler: ((RecordLogItem<Card>) -> RecordLogItem<Card>)? = nil,
        recordLogItemHandler: ((RecordLogItem<Card>) -> RecordLogItem<Card>)? = nil,
        reviewsOrderBy: ((FSRSHistory, FSRSHistory) -> Bool)? = nil,
        skipManual: Bool = true,
        updateMemoryState: Bool = false,
        now: Date? = nil,
        firstCard: Card? = nil
    ) {
        self.recordLogHandler = recordLogHandler
        self.recordLogItemHandler = recordLogItemHandler
        self.reviewsOrderBy = reviewsOrderBy
        self.skipManual = skipManual
        self.updateMemoryState = updateMemoryState
        self.now = now
        self.firstCard = firstCard
    }
}

/// Reschedule result containing replay history and final state
public struct RescheduleResult<Card: FSRSCard> {
    /// Collection of all record log items from replaying history
    public var collections: [RecordLogItem<Card>]
    
    /// Optional manual reschedule item for current state
    public var rescheduleItem: RecordLogItem<Card>?
    
    public init(
        collections: [RecordLogItem<Card>],
        rescheduleItem: RecordLogItem<Card>?
    ) {
        self.collections = collections
        self.rescheduleItem = rescheduleItem
    }
}
