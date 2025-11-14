import Foundation

/// Scheduler protocol for FSRS card scheduling
public protocol SchedulerProtocol {
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
    /// - Parameter grade: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSAlgorithmError if any operation fails
    func newState(grade: Rating) throws -> RecordLogItem<Card>
    
    /// Handle learning/relearning state
    /// - Parameter grade: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSAlgorithmError if any operation fails
    func learningState(grade: Rating) throws -> RecordLogItem<Card>
    
    /// Handle review state
    /// - Parameter grade: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSAlgorithmError if any operation fails
    func reviewState(grade: Rating) throws -> RecordLogItem<Card>
    
    /// Build review log
    /// - Parameter rating: Rating
    /// - Returns: Review log
    func buildLog(rating: Rating) -> ReviewLog
}

/// Default implementations for SchedulerProtocol
public extension SchedulerProtocol {
    /// Check if grade is valid
    /// - Parameter grade: Grade to check
    /// - Throws: FSRSError if grade is invalid
    func checkGrade(_ grade: Rating) throws {
        guard (1...4).contains(grade.rawValue) else {
            throw FSRSError.invalidGrade("Invalid grade: \(grade)")
        }
    }
    
    /// Preview all rating scenarios
    /// - Returns: Record log with all grades
    /// - Throws: FSRSAlgorithmError if any operation fails
    func preview() throws -> RecordLog<Card> {
        return [
            .again: try review(grade: .again),
            .hard: try review(grade: .hard),
            .good: try review(grade: .good),
            .easy: try review(grade: .easy)
        ] as RecordLog<Card>
    }
    
    /// Review with specific grade
    /// - Parameter grade: Grade rating
    /// - Returns: Record log item
    /// - Throws: FSRSAlgorithmError if any operation fails
    func review(grade: Rating) throws -> RecordLogItem<Card> {
        try checkGrade(grade)
        
        switch last.state {
        case .new:
            return try newState(grade: grade)
        case .learning, .relearning:
            return try learningState(grade: grade)
        case .review:
            return try reviewState(grade: grade)
        }
    }
    
    /// Build review log - default implementation
    /// - Parameter rating: Rating
    /// - Returns: Review log
    func buildLog(rating: Rating) -> ReviewLog {
        return ReviewLog(
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

