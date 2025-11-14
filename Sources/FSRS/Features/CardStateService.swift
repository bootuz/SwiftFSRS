import Foundation

/// Service responsible for card state manipulation operations
/// Handles rollback and forget operations
public struct CardStateService<Card: FSRSCard> {
    private let logger: (any FSRSLogger)?
    
    public init(logger: (any FSRSLogger)? = nil) {
        self.logger = logger
    }
    
    // MARK: - Rollback
    
    /// Rollback a card to its previous state before a review
    ///
    /// - Parameters:
    ///   - card: Current card state
    ///   - log: Review log to rollback
    /// - Returns: Previous card state
    /// - Throws: FSRSError if rating is manual
    public func rollback(card: Card, log: ReviewLog) throws -> Card {
        guard log.rating != .manual else {
            logger?.error("Cannot rollback manual rating")
            throw FSRSError.manualGradeNotAllowed
        }
        
        logger?.warning("Rolling back card: \(card.state) -> \(log.state), rating=\(log.rating)")
        
        let (previousDue, previousLastReview, previousLapses) = calculatePreviousState(
            card: card,
            log: log
        )
        
        var previousCard = card
        previousCard.due = previousDue
        previousCard.stability = log.stability
        previousCard.difficulty = log.difficulty
        previousCard.scheduledDays = log.scheduledDays
        previousCard.learningSteps = log.learningSteps
        previousCard.reps = max(0, card.reps - 1)
        previousCard.lapses = previousLapses
        previousCard.state = log.state
        previousCard.lastReview = previousLastReview
        
        return previousCard
    }
    
    /// Calculate the previous state values from review log
    private func calculatePreviousState(
        card: Card,
        log: ReviewLog
    ) -> (due: Date, lastReview: Date?, lapses: Int) {
        switch log.state {
        case .new:
            return (
                due: log.due,
                lastReview: nil,
                lapses: 0
            )
            
        case .learning, .relearning, .review:
            let lapseAdjustment = (log.rating == .again && log.state == .review) ? 1 : 0
            return (
                due: log.review,
                lastReview: log.due,
                lapses: max(0, card.lapses - lapseAdjustment)
            )
        }
    }
    
    // MARK: - Forget
    
    /// Forget a card (reset to new state)
    ///
    /// - Parameters:
    ///   - card: Card to forget
    ///   - now: Current time
    ///   - resetCount: Whether to reset reps and lapses counters
    /// - Returns: Record log item with forgotten card state
    public func forget(
        card: Card,
        now: Date,
        resetCount: Bool = false
    ) -> RecordLogItem<Card> {
        logger?.warning("Forgetting card: state=\(card.state), resetCount=\(resetCount)")
        
        // Calculate scheduled days based on current state
        let scheduledDays: Int
        if card.state == .new {
            scheduledDays = 0
        } else {
            scheduledDays = Int(dateDiff(
                now: now,
                previous: card.due,
                unit: CalculationTimeUnit.days
            ))
        }
        
        // Create review log for forget operation
        let forgetLog = ReviewLog(
            rating: .manual,
            state: card.state,
            due: card.due,
            stability: card.stability,
            difficulty: card.difficulty,
            scheduledDays: scheduledDays,
            learningSteps: card.learningSteps,
            review: now
        )
        
        // Reset card to new state
        var forgottenCard = card
        forgottenCard.due = now
        forgottenCard.stability = 0
        forgottenCard.difficulty = 0
        forgottenCard.scheduledDays = 0
        forgottenCard.learningSteps = 0
        forgottenCard.state = .new
        
        // Optionally reset counters
        if resetCount {
            forgottenCard.reps = 0
            forgottenCard.lapses = 0
        }
        // Note: lastReview is intentionally preserved
        
        return RecordLogItem(card: forgottenCard, log: forgetLog)
    }
}

