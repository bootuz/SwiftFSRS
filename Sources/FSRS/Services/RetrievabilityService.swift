import Foundation

/// Service responsible for calculating card retrievability
/// Retrievability represents the probability of successfully recalling a card
public struct RetrievabilityService {
    private let algorithm: any FSRSAlgorithmProtocol
    private let logger: (any FSRSLogger)?
    
    /// Initialize retrievability service
    /// - Parameters:
    ///   - algorithm: FSRS algorithm instance
    ///   - logger: Optional logger for debugging
    public init(
        algorithm: any FSRSAlgorithmProtocol,
        logger: (any FSRSLogger)? = nil
    ) {
        self.algorithm = algorithm
        self.logger = logger
    }
    
    // MARK: - Public API
    
    /// Get retrievability as a numeric value (0.0 to 1.0)
    ///
    /// - Parameters:
    ///   - card: Card to calculate retrievability for
    ///   - now: Current time (defaults to now)
    /// - Returns: Retrievability value between 0.0 and 1.0
    public func getRetrievabilityValue<Card: FSRSCard>(card: Card, now: Date? = nil) -> Double {
        let currentTime = now ?? Date()
        
        // New cards have zero retrievability
        guard card.state != .new else {
            logger?.info("Retrievability for new card: 0.0")
            return 0.0
        }
        
        // Cards without a last review have zero retrievability
        guard let lastReview = card.lastReview else {
            logger?.info("Retrievability for card without last review: 0.0")
            return 0.0
        }
        
        // Calculate elapsed days and retrievability
        let elapsedDays = max(
            dateDiff(now: currentTime, previous: lastReview, unit: CalculationTimeUnit.days),
            0.0
        )
        
        let retrievability = algorithm.forgettingCurve(elapsedDays, card.stability)
        
        logger?.info("""
            Retrievability calculated: \
            state=\(card.state), \
            elapsed=\(elapsedDays)d, \
            stability=\(card.stability) -> \
            retrievability=\(retrievability)
            """)
        
        return retrievability
    }
    
    /// Get retrievability formatted as a percentage string
    ///
    /// - Parameters:
    ///   - card: Card to calculate retrievability for
    ///   - now: Current time (defaults to now)
    /// - Returns: Retrievability formatted as percentage (e.g., "85.00%")
    public func getRetrievabilityFormatted<Card: FSRSCard>(
        card: Card,
        now: Date? = nil
    ) -> String {
        let value = getRetrievabilityValue(card: card, now: now)
        return String(format: "%.2f%%", value * 100)
    }
}
