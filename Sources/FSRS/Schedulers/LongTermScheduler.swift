import Foundation

/// Long-term scheduler without learning steps
/// Cards go directly to review state with calculated intervals
public final class LongTermScheduler<Card: FSRSCard>: BaseScheduler<Card> {
    
    // MARK: - New Card Scheduling
    
    public override func scheduleNewCard(grade: Rating) throws -> RecordLogItem<Card> {
        logger?.debug("Long-term new card: grade=\(grade)")
        
        // Calculate next states for all grades
        let nextStates = try calculateAllGradeStates(
            elapsedDays: .zero,
            retrievability: nil
        )
        
        // Apply intervals and constraints
        var cardAgain = try createCardWithState(nextStates.again)
        var cardHard = try createCardWithState(nextStates.hard)
        var cardGood = try createCardWithState(nextStates.good)
        var cardEasy = try createCardWithState(nextStates.easy)
        
        try applyIntervalsToNewCard(
            cardAgain: &cardAgain,
            cardHard: &cardHard,
            cardGood: &cardGood,
            cardEasy: &cardEasy
        )
        
        // Select card based on actual grade
        let selectedCard = try selectCard(
            grade: grade,
            again: cardAgain,
            hard: cardHard,
            good: cardGood,
            easy: cardEasy
        )
        
        logger?.debug("New card result: scheduledDays=\(selectedCard.scheduledDays)")
        return RecordLogItem(card: selectedCard, log: buildLog(rating: grade))
    }
    
    // MARK: - Learning/Relearning Scheduling
    
    public override func scheduleLearningCard(grade: Rating) throws -> RecordLogItem<Card> {
        // In long-term mode, learning state is treated same as review
        logger?.debug("Long-term learning: treating as review, grade=\(grade)")
        return try scheduleReviewCard(grade: grade)
    }
    
    // MARK: - Review Card Scheduling
    
    public override func scheduleReviewCard(grade: Rating) throws -> RecordLogItem<Card> {
        logger?.debug("Long-term review: grade=\(grade)")
        
        // Calculate retrievability
        let currentStability = try Stability(currentCard.stability)
        let retrievability = try stabilityCalculator.forgettingCurve(
            elapsedDays: elapsedDaysValue,
            stability: currentStability
        )
        
        logger?.debug("Review retrievability: \(retrievability.value)")
        
        // Calculate next states for all grades
        let nextStates = try calculateAllGradeStates(
            elapsedDays: elapsedDaysValue,
            retrievability: retrievability
        )
        
        // Apply intervals and constraints
        var cardAgain = try createCardWithState(nextStates.again)
        var cardHard = try createCardWithState(nextStates.hard)
        var cardGood = try createCardWithState(nextStates.good)
        var cardEasy = try createCardWithState(nextStates.easy)
        
        try applyIntervalsToReviewCard(
            cardAgain: &cardAgain,
            cardHard: &cardHard,
            cardGood: &cardGood,
            cardEasy: &cardEasy
        )
        
        // Increment lapses for Again
        cardAgain.lapses += 1
        
        // Select card based on actual grade
        let selectedCard = try selectCard(
            grade: grade,
            again: cardAgain,
            hard: cardHard,
            good: cardGood,
            easy: cardEasy
        )
        
        logger?.debug("Review result: scheduledDays=\(selectedCard.scheduledDays)")
        return RecordLogItem(card: selectedCard, log: buildLog(rating: grade))
    }
    
    // MARK: - Helper Methods
    
    private struct AllGradeStates {
        let again: MemoryState
        let hard: MemoryState
        let good: MemoryState
        let easy: MemoryState
    }
    
    private func calculateAllGradeStates(
        elapsedDays: ElapsedDays,
        retrievability: Retrievability?
    ) throws -> AllGradeStates {
        AllGradeStates(
            again: try calculateNextMemoryState(
                elapsedDays: elapsedDays,
                grade: .again,
                retrievability: retrievability
            ),
            hard: try calculateNextMemoryState(
                elapsedDays: elapsedDays,
                grade: .hard,
                retrievability: retrievability
            ),
            good: try calculateNextMemoryState(
                elapsedDays: elapsedDays,
                grade: .good,
                retrievability: retrievability
            ),
            easy: try calculateNextMemoryState(
                elapsedDays: elapsedDays,
                grade: .easy,
                retrievability: retrievability
            )
        )
    }
    
    private func createCardWithState(_ state: MemoryState) throws -> Card {
        var card = currentCard
        card.stability = state.stability.value
        card.difficulty = state.difficulty.value
        return card
    }
    
    private func applyIntervalsToNewCard(
        cardAgain: inout Card,
        cardHard: inout Card,
        cardGood: inout Card,
        cardEasy: inout Card
    ) throws {
        let intervalModifier = algorithm.intervalModifier
        
        // Calculate base intervals
        // At this point, stability should be valid (set by calculateNextMemoryState)
        let againInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardAgain.stability),
            elapsedDays: .zero,
            intervalModifier: intervalModifier
        )
        let hardInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardHard.stability),
            elapsedDays: .zero,
            intervalModifier: intervalModifier
        )
        let goodInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardGood.stability),
            elapsedDays: .zero,
            intervalModifier: intervalModifier
        )
        let easyInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardEasy.stability),
            elapsedDays: .zero,
            intervalModifier: intervalModifier
        )
        
        // Apply constraints
        let constrained = IntervalConstraintApplier.applyNewCardConstraints(
            again: againInterval,
            hard: hardInterval,
            good: goodInterval,
            easy: easyInterval
        )
        
        // Set intervals and dates
        setIntervalAndDue(card: &cardAgain, interval: constrained.again)
        setIntervalAndDue(card: &cardHard, interval: constrained.hard)
        setIntervalAndDue(card: &cardGood, interval: constrained.good)
        setIntervalAndDue(card: &cardEasy, interval: constrained.easy)
    }
    
    private func applyIntervalsToReviewCard(
        cardAgain: inout Card,
        cardHard: inout Card,
        cardGood: inout Card,
        cardEasy: inout Card
    ) throws {
        let intervalModifier = algorithm.intervalModifier
        
        // Calculate base intervals
        // At this point, stability should be valid (set by calculateNextMemoryState)
        let againInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardAgain.stability),
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )
        let hardInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardHard.stability),
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )
        let goodInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardGood.stability),
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )
        let easyInterval = intervalCalculator.calculateScheduledInterval(
            stability: try Stability(cardEasy.stability),
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )
        
        // Apply constraints (no constraint on again for review cards)
        let constrained = IntervalConstraintApplier.applyReviewCardConstraints(
            hard: hardInterval,
            good: goodInterval,
            easy: easyInterval
        )
        
        // Set intervals and dates
        setIntervalAndDue(card: &cardAgain, interval: againInterval)
        setIntervalAndDue(card: &cardHard, interval: constrained.hard)
        setIntervalAndDue(card: &cardGood, interval: constrained.good)
        setIntervalAndDue(card: &cardEasy, interval: constrained.easy)
    }
    
    private func setIntervalAndDue(card: inout Card, interval: Int) {
        card.scheduledDays = interval
        card.due = dateScheduler(now: reviewTime, offset: Double(interval), isDay: true)
        card.state = .review
        card.learningSteps = 0
    }
    
    private func selectCard(
        grade: Rating,
        again: Card,
        hard: Card,
        good: Card,
        easy: Card
    ) throws -> Card {
        switch grade {
        case .again: return again
        case .hard: return hard
        case .good: return good
        case .easy: return easy
        case .manual: throw FSRSError.manualGradeNotAllowed
        }
    }
}

