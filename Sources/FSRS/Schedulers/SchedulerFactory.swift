import Foundation

/// Factory for creating schedulers
/// Allows decoupling FSRS from specific scheduler implementations
public protocol SchedulerFactory<Card> {
    /// The card type this factory works with
    associatedtype Card: FSRSCard

    /// Create a scheduler instance
    /// - Parameters:
    ///   - card: Card to schedule
    ///   - now: Current time
    ///   - algorithm: FSRS algorithm instance
    ///   - useShortTerm: Whether to use short-term scheduler
    ///   - logger: Optional logger
    /// - Returns: Configured scheduler
    func makeScheduler(
        card: Card,
        now: Date,
        algorithm: any FSRSAlgorithmProtocol,
        useShortTerm: Bool,
        logger: (any FSRSLogger)?
    ) -> any SchedulerProtocol<Card>
}

/// Default FSRS scheduler factory
public struct FSRSSchedulerFactory<Card: FSRSCard>: SchedulerFactory {
    public init() {}

    public func makeScheduler(
        card: Card,
        now: Date,
        algorithm: any FSRSAlgorithmProtocol,
        useShortTerm: Bool,
        logger: (any FSRSLogger)?
    ) -> any SchedulerProtocol<Card> {
        if useShortTerm {
            return BasicScheduler(
                card: card,
                now: now,
                algorithm: algorithm,
                logger: logger
            )
        } else {
            return LongTermScheduler(
                card: card,
                now: now,
                algorithm: algorithm,
                logger: logger
            )
        }
    }
}
