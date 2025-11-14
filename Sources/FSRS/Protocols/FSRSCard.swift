import Foundation

/// Protocol for cards compatible with FSRS scheduling algorithm
///
/// Implement this protocol with your own card type to integrate FSRS scheduling.
/// Your type can include any additional properties (question, answer, id, etc.)
///
/// Example:
/// ```swift
/// struct Flashcard: FSRSCard {
///     let id: UUID
///     var question: String
///     var answer: String
///     
///     // FSRS-required properties
///     var due: Date
///     var state: State
///     // ... other FSRS properties
/// }
/// ```
public protocol FSRSCard: Sendable {
    /// Date when the card is due for review
    var due: Date { get set }
    
    /// Current learning state of the card (New, Learning, Review, Relearning)
    var state: State { get set }
    
    /// Date of the last review (nil for new cards)
    var lastReview: Date? { get set }
    
    /// Memory stability (interval when retrievability = 90%)
    var stability: Double { get set }
    
    /// Difficulty level (1-10, higher = more difficult)
    var difficulty: Double { get set }
    
    /// Number of days scheduled until next review
    var scheduledDays: Int { get set }
    
    /// Current step in learning/relearning stages
    var learningSteps: Int { get set }
    
    /// Total number of times the card has been reviewed
    var reps: Int { get set }
    
    /// Number of times the card was forgotten or answered incorrectly
    var lapses: Int { get set }
}

