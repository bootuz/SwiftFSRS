import FSRS
import Foundation

/// Realistic flashcard implementation showing how to integrate FSRS with your own data
///
/// This example demonstrates:
/// - Combining business data (question, answer, id) with FSRS scheduling
/// - Conforming to FSRSCard protocol with just 9 properties
///
/// Your flashcard keeps all its data while FSRS manages the scheduling!
public struct Flashcard: FSRSCard, Identifiable, Codable {
    // ========================================
    // YOUR flashcard content (business data)
    // ========================================

    /// Unique identifier for the flashcard
    public let id: UUID

    /// Front of the card - the question or prompt
    public var question: String

    /// Back of the card - the answer or content
    public var answer: String

    /// Which deck this card belongs to
    public var deck: String

    /// Tags for organization and filtering
    public var tags: [String]

    /// Additional notes or context
    public var notes: String

    /// When this card was first created
    public let createdAt: Date

    /// Last time the card content was edited
    public var updatedAt: Date

    // ========================================
    // FSRS scheduling properties (required)
    // ========================================

    /// When the card is due for review
    public var due: Date

    /// Current learning state (New, Learning, Review, Relearning)
    public var state: State

    /// When the card was last reviewed (nil for new cards)
    public var lastReview: Date?

    /// Memory stability (interval when retrievability = 90%)
    public var stability: Double

    /// Difficulty level (1-10, higher = more difficult)
    public var difficulty: Double

    /// Days scheduled until next review
    public var scheduledDays: Int

    /// Current step in learning/relearning stages
    public var learningSteps: Int

    /// Total number of reviews
    public var reps: Int

    /// Number of times forgotten or answered incorrectly
    public var lapses: Int

    // ========================================
    // Initialization
    // ========================================

    public init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        deck: String = "Default",
        tags: [String] = [],
        notes: String = ""
    ) {
        // Your flashcard data
        self.id = id
        self.question = question
        self.answer = answer
        self.deck = deck
        self.tags = tags
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()

        // FSRS scheduling defaults (new card)
        self.due = Date()
        self.state = .new
        self.lastReview = nil
        self.stability = 0
        self.difficulty = 0
        self.scheduledDays = 0
        self.learningSteps = 0
        self.reps = 0
        self.lapses = 0
    }
}

// ========================================
// Usage Example
// ========================================

// Create FSRS scheduler for your Flashcard type
let fsrs = FSRS<Flashcard>()

// Create a flashcard with YOUR data
var card = Flashcard(
    question: "What is the capital of France?",
    answer: "Paris",
    deck: "Geography",
    tags: ["Europe", "Capitals", "Cities"]
)

// Preview all possible scheduling outcomes
let scheduling = try fsrs.repeat(card: card, now: Date())

print("If you rate it 'Again':", scheduling[.again]!.card.due)
print("If you rate it 'Hard':", scheduling[.hard]!.card.due)
print("If you rate it 'Good':", scheduling[.good]!.card.due)
print("If you rate it 'Easy':", scheduling[.easy]!.card.due)

card = scheduling[.good]!.card

// Card has BOTH your data AND FSRS scheduling:
print("Question: \(card.question)")  // "What is the capital of France?"
print("Answer: \(card.answer)")  // "Paris"
print("Deck: \(card.deck)")  // "Geography"
print("Tags: \(card.tags)")  // ["Europe", "Capitals", "Cities"]
print("Next review: \(card.due)")  // Calculated by FSRS
print("Difficulty: \(card.difficulty)")  // Calculated by FSRS
print("Reviews: \(card.reps)")  // 1

// Save to database, JSON, UserDefaults, etc.
let jsonData = try JSONEncoder().encode(card)
try jsonData.write(to: fileURL)

// Load and continue scheduling
let loaded = try JSONDecoder().decode(Flashcard.self, from: jsonData)
let nextReview = try fsrs.next(card: loaded, now: Date(), rating: .good)
