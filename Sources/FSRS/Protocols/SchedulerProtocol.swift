import Foundation

/// Scheduler protocol for FSRS card scheduling
public protocol SchedulerProtocol<Card> {
    /// The card type this scheduler works with
    associatedtype Card: FSRSCard

    /// Last card state (before review)
    var last: Card { get }

    /// Current card state (after initialization)
    var current: Card { get set }

    /// Review time
    var reviewTime: Date { get }

    /// Elapsed days since last review
    var elapsedDays: Double { get }

    /// FSRS algorithm instance
    var algorithm: any FSRSAlgorithmProtocol { get }

    /// Handle new state
    /// - Parameter rating: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSError if any operation fails
    func newState(rating: Rating) throws -> RecordLogItem<Card>

    /// Handle learning/relearning state
    /// - Parameter rating: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSError if any operation fails
    func learningState(rating: Rating) throws -> RecordLogItem<Card>

    /// Handle review state
    /// - Parameter rating: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSError if any operation fails
    func reviewState(rating: Rating) throws -> RecordLogItem<Card>

    /// Build review log
    /// - Parameter rating: Rating
    /// - Returns: Review log
    func buildLog(rating: Rating) -> ReviewLog
}

/// Default implementations for SchedulerProtocol
extension SchedulerProtocol {
    /// Check if rating is valid
    /// - Parameter rating: Grade to check
    /// - Throws: FSRSError if rating is invalid
    public func checkGrade(_ rating: Rating) throws {
        guard (1...4).contains(rating.rawValue) else {
            throw FSRSError.invalidGrade("Invalid rating: \(rating)")
        }
    }

    /// Preview all rating scenarios
    /// - Returns: Record log with all grades
    /// - Throws: FSRSError if any operation fails
    public func preview() throws -> RecordLog<Card> {
        [
            .again: try review(rating: .again),
            .hard: try review(rating: .hard),
            .good: try review(rating: .good),
            .easy: try review(rating: .easy)
        ] as RecordLog<Card>
    }

    /// Review with specific rating
    /// - Parameter rating: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSError if any operation fails
    public func review(rating: Rating) throws -> RecordLogItem<Card> {
        try checkGrade(rating)

        switch last.state {
        case .new:
            return try newState(rating: rating)
        case .learning, .relearning:
            return try learningState(rating: rating)
        case .review:
            return try reviewState(rating: rating)
        }
    }

    /// Build review log - default implementation
    /// - Parameter rating: Rating
    /// - Returns: Review log
    public func buildLog(rating: Rating) -> ReviewLog {
        ReviewLog(
            rating: rating,
            state: current.state,
            due: last.lastReview ?? last.due,
            stability: current.stability,
            difficulty: current.difficulty,
            scheduledDays: current.scheduledDays,
            learningSteps: current.learningSteps,
            review: reviewTime
        )
    }
}
