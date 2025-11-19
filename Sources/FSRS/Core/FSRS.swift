import Foundation

/// Main FSRS API providing card scheduling and state management
/// Generic over any type conforming to FSRSCard protocol
public struct FSRS<Card: FSRSCard> {
    // MARK: - Properties

    /// Internal algorithm implementation
    private var algorithm: FSRSAlgorithmProtocol

    /// Whether to use short-term scheduler (with learning steps)
    private let useShortTerm: Bool

    /// Optional logger for debugging and monitoring
    private let logger: (any FSRSLogger)?

    /// Service for calculating retrievability
    private let retrievabilityService: RetrievabilityService

    /// Service for card state operations (rollback, forget)
    private let cardStateService: CardStateService<Card>

    /// Factory for creating schedulers
    private let schedulerFactory: any SchedulerFactory<Card>

    // MARK: - Initialization

    /// Initialize FSRS with parameters
    /// - Parameters:
    ///   - params: Partial FSRS parameters
    ///   - randomProvider: Random provider (optional, uses system random if not provided)
    ///   - logger: Optional logger for debugging and monitoring
    ///   - logger: Optional logger for debugging and monitoring
    ///   - schedulerFactory: Optional scheduler factory (defaults to FSRSSchedulerFactory)
    public init(
        params: PartialFSRSParameters = PartialFSRSParameters(),
        randomProvider: RandomProvider? = nil,
        logger: (any FSRSLogger)? = nil,
        schedulerFactory: (any SchedulerFactory<Card>)? = nil
    ) {
        let finalParams = FSRSParametersGenerator.generate(from: params)
        self.useShortTerm = finalParams.enableShortTerm
        self.logger = logger
        self.algorithm = FSRSAlgorithm(
            params: params,
            randomProvider: randomProvider,
            logger: logger
        )

        self.retrievabilityService = RetrievabilityService(
            algorithm: algorithm,
            logger: logger
        )
        self.cardStateService = CardStateService<Card>(logger: logger)
        self.schedulerFactory = schedulerFactory ?? FSRSSchedulerFactory<Card>()

        logger?.debug("FSRS initialized: useShortTerm=\(useShortTerm)")
    }

    // MARK: - Algorithm Access

    /// Access to algorithm parameters (read-only after initialization)
    ///
    /// Parameters cannot be mutated after FSRS is initialized because:
    /// - The interval modifier is precomputed during initialization
    /// - Calculator instances are created with the initial parameters
    ///
    /// If you need different parameters, create a new FSRS instance.
    public var parameters: FSRSParameters {
        get {
            algorithm.parameters
        }
        set {
            algorithm.parameters = newValue
        }
    }

    /// Forgetting curve calculation
    public func forgettingCurve(_ elapsedDays: Double, _ stability: Double) -> Double {
        return algorithm.forgettingCurve(elapsedDays, stability)
    }

    // MARK: - Core Scheduling Methods

    /// Preview all rating scenarios
    /// Shows what would happen with each possible rating (Again, Hard, Good, Easy)
    ///
    /// - Parameters:
    ///   - card: Card to process
    ///   - now: Current time
    /// - Returns: Record log with all rating scenarios
    /// - Throws: FSRSError if any operation fails
    public func `repeat`(card: Card, now: Date) throws -> RecordLog<Card> {
        logger?.debug("Previewing all ratings: state=\(card.state), useShortTerm=\(useShortTerm)")

        let scheduler = schedulerFactory.makeScheduler(
            card: card,
            now: now,
            algorithm: algorithm,
            useShortTerm: useShortTerm,
            logger: logger
        )
        return try scheduler.preview()
    }

    /// Get next state for specific grade
    ///
    /// - Parameters:
    ///   - card: Card to process
    ///   - now: Current time
    ///   - grade: Grade rating (Again, Hard, Good, or Easy)
    /// - Returns: Record log item with next card state
    /// - Throws: FSRSError if any operation fails
    public func next(card: Card, now: Date, grade: Rating) throws -> RecordLogItem<Card> {
        logger?.debug("Processing next: grade=\(grade), state=\(card.state)")

        guard grade != .manual else {
            logger?.error("Manual grade not allowed for scheduling")
            throw FSRSError.manualGradeNotAllowed
        }

        let scheduler = schedulerFactory.makeScheduler(
            card: card,
            now: now,
            algorithm: algorithm,
            useShortTerm: useShortTerm,
            logger: logger
        )
        return try scheduler.review(grade: grade)
    }

    // MARK: - Retrievability Methods

    /// Get retrievability of card as percentage string
    /// - Parameters:
    ///   - card: Card to process
    ///   - now: Optional current time (defaults to now)
    /// - Returns: Retrievability formatted as percentage (e.g., "85.00%")
    public func getRetrievability(card: Card, now: Date? = nil) -> String {
        retrievabilityService.getRetrievabilityFormatted(card: card, now: now)
    }

    /// Get retrievability of card as numeric value
    /// - Parameters:
    ///   - card: Card to process
    ///   - now: Optional current time (defaults to now)
    /// - Returns: Retrievability as Double (0.0 to 1.0)
    public func getRetrievabilityValue(card: Card, now: Date? = nil) -> Double {
        retrievabilityService.getRetrievabilityValue(card: card, now: now)
    }

    // MARK: - Card State Operations

    /// Rollback card to previous state
    /// - Parameters:
    ///   - card: Current card state
    ///   - log: Review log to rollback
    /// - Returns: Previous card state
    /// - Throws: FSRSError if rating is manual
    public func rollback(card: Card, log: ReviewLog) throws -> Card {
        try cardStateService.rollback(card: card, log: log)
    }

    /// Forget a card (reset to new state)
    /// - Parameters:
    ///   - card: Card to forget
    ///   - now: Current time
    ///   - resetCount: Whether to reset reps and lapses
    /// - Returns: Record log item
    public func forget(card: Card, now: Date, resetCount: Bool = false) -> RecordLogItem<Card> {
        cardStateService.forget(card: card, now: now, resetCount: resetCount)
    }

    /// Reschedule card based on review history
    /// - Parameters:
    ///   - currentCard: Current card state
    ///   - reviews: Review history
    ///   - options: Reschedule options
    /// - Returns: Reschedule result
    /// - Throws: FSRSError if any operation fails
    public func reschedule(
        currentCard: Card,
        reviews: [FSRSHistory],
        options: RescheduleOptions<Card> = RescheduleOptions<Card>()
    ) throws -> RescheduleResult<Card> {
        logger?.debug("Rescheduling card with \(reviews.count) reviews")

        var filteredReviews = reviews

        // Sort reviews if needed
        if let orderBy = options.reviewsOrderBy {
            filteredReviews.sort(by: orderBy)
        }

        // Skip manual reviews if requested
        if options.skipManual {
            filteredReviews = filteredReviews.filter { $0.rating != .manual }
        }

        let rescheduleService = RescheduleService<Card>(fsrs: self, logger: logger)

        // Use firstCard or create empty from currentCard
        var emptyCard = currentCard
        emptyCard.due = currentCard.due
        emptyCard.stability = 0
        emptyCard.difficulty = 0
        emptyCard.scheduledDays = 0
        emptyCard.learningSteps = 0
        emptyCard.reps = 0
        emptyCard.lapses = 0
        emptyCard.state = .new
        emptyCard.lastReview = nil

        let collections = try rescheduleService.reschedule(
            currentCard: options.firstCard ?? emptyCard,
            reviews: filteredReviews
        )

        let nowDate = options.now ?? Date()

        let manualItem = try rescheduleService.calculateManualRecord(
            currentCard: currentCard,
            now: nowDate,
            recordLogItem: collections.last,
            updateMemory: options.updateMemoryState
        )

        var resultCollections = collections
        if let handler = options.recordLogHandler {
            resultCollections = collections.map { handler($0) }
        }

        var resultManualItem: RecordLogItem<Card>? = manualItem
        if let handler = options.recordLogItemHandler, let manualItem = manualItem {
            resultManualItem = handler(manualItem)
        }

        return RescheduleResult<Card>(
            collections: resultCollections,
            rescheduleItem: resultManualItem
        )
    }
}
