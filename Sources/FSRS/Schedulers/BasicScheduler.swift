import Foundation

/// Basic scheduler with learning steps support
/// Cards progress through learning steps before advancing to review state
public final class BasicScheduler<Card: FSRSCard>: BaseScheduler<Card> {
    // Learning steps strategy
    private let learningStepsStrategy: LearningStepsStrategy

    public init(
        card: Card,
        now: Date,
        algorithm: any FSRSAlgorithmProtocol,
        learningStepsStrategy: LearningStepsStrategy? = nil,
        logger: (any FSRSLogger)? = nil
    ) {
        // Use provided or default learning steps strategy
        self.learningStepsStrategy = learningStepsStrategy ?? basicLearningStepsStrategy
        super.init(card: card, now: now, algorithm: algorithm, logger: logger)
    }

    // MARK: - New Card Scheduling

    override public func scheduleNewCard(rating: Rating) throws -> RecordLogItem<Card> {
        logger?.debug("Basic new card: rating=\(rating)")

        // Calculate next memory state
        let nextState = try calculateNextMemoryState(
            elapsedDays: elapsedDaysValue,
            rating: rating,
            retrievability: nil
        )

        // Apply state to card
        var nextCard = currentCard
        nextCard.stability = nextState.stability.value
        nextCard.difficulty = nextState.difficulty.value

        // Apply learning steps
        try applyLearningSteps(to: &nextCard, rating: rating, targetState: .learning)

        logger?.debug("New card result: state=\(nextCard.state), learningSteps=\(nextCard.learningSteps)")
        return RecordLogItem(card: nextCard, log: buildLog(rating: rating))
    }

    // MARK: - Learning/Relearning Scheduling

    override public func scheduleLearningCard(rating: Rating) throws -> RecordLogItem<Card> {
        logger?.debug("Basic learning: rating=\(rating), currentState=\(lastCard.state)")

        // Calculate next memory state
        let nextState = try calculateNextMemoryState(
            elapsedDays: elapsedDaysValue,
            rating: rating,
            retrievability: nil
        )

        // Apply state to card
        var nextCard = currentCard
        nextCard.stability = nextState.stability.value
        nextCard.difficulty = nextState.difficulty.value

        // Apply learning steps (preserving Learning or Relearning state)
        try applyLearningSteps(to: &nextCard, rating: rating, targetState: lastCard.state)

        logger?.debug("Learning result: state=\(nextCard.state), learningSteps=\(nextCard.learningSteps)")
        return RecordLogItem(card: nextCard, log: buildLog(rating: rating))
    }

    // MARK: - Review Card Scheduling
    // swiftlint:disable:next function_body_length
    override public func scheduleReviewCard(rating: Rating) throws -> RecordLogItem<Card> {
        logger?.debug("Basic review: rating=\(rating)")

        // Calculate retrievability
        let currentStability = try Stability(currentCard.stability)
        let retrievability = try stabilityCalculator.forgettingCurve(
            elapsedDays: elapsedDaysValue,
            stability: currentStability
        )

        logger?.debug("Review retrievability: \(retrievability.value)")

        // For "Again", enter relearning with learning steps
        if rating == .again {
            let nextState = try calculateNextMemoryState(
                elapsedDays: elapsedDaysValue,
                rating: .again,
                retrievability: retrievability
            )

            var nextCard = currentCard
            nextCard.stability = nextState.stability.value
            nextCard.difficulty = nextState.difficulty.value
            nextCard.lapses += 1

            try applyLearningSteps(to: &nextCard, rating: .again, targetState: .relearning)

            return RecordLogItem(card: nextCard, log: buildLog(rating: .again))
        }

        // For Hard, Good, Easy - calculate intervals and apply constraints
        let hardState = try calculateNextMemoryState(
            elapsedDays: elapsedDaysValue,
            rating: .hard,
            retrievability: retrievability
        )
        let goodState = try calculateNextMemoryState(
            elapsedDays: elapsedDaysValue,
            rating: .good,
            retrievability: retrievability
        )
        let easyState = try calculateNextMemoryState(
            elapsedDays: elapsedDaysValue,
            rating: .easy,
            retrievability: retrievability
        )

        let intervalModifier = algorithm.intervalModifier

        let hardInterval = intervalCalculator.calculateScheduledInterval(
            stability: hardState.stability,
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )
        let goodInterval = intervalCalculator.calculateScheduledInterval(
            stability: goodState.stability,
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )
        let easyInterval = intervalCalculator.calculateScheduledInterval(
            stability: easyState.stability,
            elapsedDays: elapsedDaysValue,
            intervalModifier: intervalModifier
        )

        // Apply interval constraints
        let constrained = IntervalConstraintApplier.applyReviewCardConstraints(
            hard: hardInterval,
            good: goodInterval,
            easy: easyInterval
        )

        // Select and prepare the card based on rating
        var nextCard = currentCard
        switch rating {
        case .hard:
            nextCard.stability = hardState.stability.value
            nextCard.difficulty = hardState.difficulty.value
            nextCard.scheduledDays = constrained.hard
        case .good:
            nextCard.stability = goodState.stability.value
            nextCard.difficulty = goodState.difficulty.value
            nextCard.scheduledDays = constrained.good
        case .easy:
            nextCard.stability = easyState.stability.value
            nextCard.difficulty = easyState.difficulty.value
            nextCard.scheduledDays = constrained.easy
        default:
            throw FSRSError.invalidGrade("Unexpected rating in review: \(rating)")
        }

        nextCard.due = dateScheduler(
            now: reviewTime,
            offset: Double(nextCard.scheduledDays),
            isDay: true
        )
        nextCard.state = .review
        nextCard.learningSteps = 0

        logger?.debug("Review result: scheduledDays=\(nextCard.scheduledDays)")
        return RecordLogItem(card: nextCard, log: buildLog(rating: rating))
    }

    // MARK: - Learning Steps Logic

    /// Get learning info for a rating
    private func getLearningInfo(card: Card, rating: Rating) -> (scheduledMinutes: Int, nextSteps: Int) {
        let parameters = algorithm.parameters
        let cardLearningSteps = card.learningSteps

        // Determine which step to use based on state and rating
        let effectiveStep = (currentCard.state == .learning && rating != .again && rating != .hard)
            ? cardLearningSteps + 1
            : cardLearningSteps

        let stepsStrategy = learningStepsStrategy(
            parameters,
            card.state,
            effectiveStep
        )

        let scheduledMinutes = max(0, stepsStrategy[rating]?.scheduledMinutes ?? 0)
        let nextSteps = max(0, stepsStrategy[rating]?.nextStep ?? 0)

        return (scheduledMinutes: scheduledMinutes, nextSteps: nextSteps)
    }

    /// Apply learning steps to card
    private func applyLearningSteps(
        to card: inout Card,
        rating: Rating,
        targetState: State
    ) throws {
        let (scheduledMinutes, nextSteps) = getLearningInfo(card: currentCard, rating: rating)

        // Short-term interval (less than 1 day)
        if scheduledMinutes > 0 && scheduledMinutes < MINUTES_PER_DAY {
            card.learningSteps = nextSteps
            card.scheduledDays = 0
            card.state = targetState
            card.due = dateScheduler(
                now: reviewTime,
                offset: Double(scheduledMinutes),
                isDay: false
            )
            logger?.debug("Applied learning step: \(scheduledMinutes) minutes")
        }
        // Long interval (>= 1 day) but still counted as a step
        else if scheduledMinutes >= MINUTES_PER_DAY {
            card.learningSteps = nextSteps
            card.state = .review
            card.due = dateScheduler(
                now: reviewTime,
                offset: Double(scheduledMinutes),
                isDay: false
            )
            card.scheduledDays = scheduledMinutes / MINUTES_PER_DAY
            logger?.debug("Applied long learning step: \(scheduledMinutes) minutes = \(card.scheduledDays) days")
        }
        // No more learning steps - graduate to review
        else {
            card.learningSteps = 0
            card.state = .review

            let intervalModifier = algorithm.intervalModifier
            // At this point, card.stability should be valid (set by calculateNextMemoryState)
            // But we need to handle the case where it might still be 0.0
            let stability = try Stability(card.stability)
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
            logger?.debug("Graduated to review: \(interval) days")
        }
    }
}
