import Foundation
import Testing

@testable import FSRS

/// Integration tests for real-world FSRS usage scenarios
@Suite("Integration Tests")
struct IntegrationTests {
	// MARK: - Helper Functions

    private func createFSRS(enableFuzz: Bool = false) -> FSRS<TestCard> {
        let params = PartialFSRSParameters(
            requestRetention: 0.9,
            maximumInterval: 36_500,
            enableFuzz: enableFuzz
        )
        return fsrs(params: params, logger: ConsoleLogger())
    }

    private func createCard() -> TestCard {
        TestCard(question: "What is FSRS?", answer: "Free Spaced Repetition Scheduler")
    }

    // MARK: - Real-world Scenarios

    @Test("Consistent study schedule over multiple days")
    func testConsistentStudySchedule() throws {
        let fsrs = createFSRS()
        var card = createCard()
        var now = Date()

        // Day 1: First review
        var result = try fsrs.next(card: card, now: now, rating: .good)
        card = result.card
        #expect(card.reps == 1)

        // Day 2: Second review
        now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        result = try fsrs.next(card: card, now: now, rating: .good)
        card = result.card
        #expect(card.reps == 2)

        // Day 3+: Follow scheduled intervals
        for i in 3...7 {
            if card.scheduledDays > 0 {
                now = try #require(
                    Calendar.current.date(
                        byAdding: .day, value: Int(card.scheduledDays), to: card.lastReview ?? now))
            } else {
                now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
            }

            result = try fsrs.next(card: card, now: now, rating: .good)
            card = result.card
            #expect(card.reps == i)
        }

        // Verify progression
        #expect(card.state == .review)
        #expect(card.stability > 0)
        #expect(card.scheduledDays > 0)
    }

    @Test("Student struggles with difficult card")
    func testDifficultCardScenario() throws {
        let fsrs = createFSRS()
        var card = createCard()
        var now = Date()

        // Multiple failed attempts
        for _ in 0..<3 {
            var result = try fsrs.next(card: card, now: now, rating: .again)
            card = result.card

            // Try again after some time
            now = try #require(Calendar.current.date(byAdding: .hour, value: 1, to: now))
            result = try fsrs.next(card: card, now: now, rating: .hard)
            card = result.card

            now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        }

        // Eventually, difficulty should be high
        #expect(card.difficulty > 5.0)
        #expect(card.reps >= 6)
    }

    @Test("Student masters easy card quickly")
    func testEasyCardScenario() throws {
        let fsrs = createFSRS()
        var card = createCard()
        var now = Date()

        // Consistently rate as easy
        for _ in 0..<5 {
            let result = try fsrs.next(card: card, now: now, rating: .easy)
            card = result.card

            if card.scheduledDays > 0 {
                now = try #require(
                    Calendar.current.date(byAdding: .day, value: Int(card.scheduledDays), to: now))
            } else {
                now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
            }
        }

        // Card should have low difficulty and high stability
        #expect(card.difficulty < 3.0)
        #expect(card.stability > 10.0)
        #expect(card.scheduledDays > 7)
    }

    @Test("Forgetting and relearning cycle")
    func testForgettingAndRelearning() throws {
        let fsrs = createFSRS()
        var card = createCard()
        var now = Date()

        // Learn the card
        var result = try fsrs.next(card: card, now: now, rating: .good)
        card = result.card

        // Graduate to review
        now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        result = try fsrs.next(card: card, now: now, rating: .easy)
        card = result.card
        #expect(card.state == .review)

        // Forget the card
        now = try #require(Calendar.current.date(byAdding: .day, value: 30, to: now))
        result = try fsrs.next(card: card, now: now, rating: .again)
        card = result.card
        #expect(card.state == .relearning || card.state == .review)
        #expect(card.lapses >= 1)

        // Relearn successfully
        result = try fsrs.next(card: card, now: now, rating: .good)
        card = result.card

        // Verify recovery
        #expect(card.reps > 2)
    }

    @Test("Long-term retention scenario (1 year)")
    func testLongTermRetention() throws {
        let fsrs = createFSRS()
        var card = createCard()
        var now = Date()

        // Simulate studying over a year with good performance
        var totalDays = 0

        while totalDays < 365 && card.reps < 20 {
            let result = try fsrs.next(card: card, now: now, rating: .good)
            card = result.card

            let daysToAdd = max(1, card.scheduledDays)
            now = try #require(Calendar.current.date(byAdding: .day, value: daysToAdd, to: now))
            totalDays += daysToAdd
        }

        // After a year of consistent study, card should be mature
        #expect(card.stability > 30.0)
        #expect(card.scheduledDays > 30)
    }

    @Test("Cramming vs spaced repetition")
    func testCrammingVsSpacedRepetition() throws {
        let fsrs = createFSRS()

        // Cramming: Review many times in one day
        var cramCard = createCard()
        let cramDate = Date()
        for _ in 1...10 {
            let result = try fsrs.next(card: cramCard, now: cramDate, rating: .good)
            cramCard = result.card
        }

        // Spaced: Review over multiple days
        var spacedCard = createCard()
        var spacedDate = Date()
        for _ in 1...10 {
            let result = try fsrs.next(card: spacedCard, now: spacedDate, rating: .good)
            spacedCard = result.card

            if spacedCard.scheduledDays > 0 {
                spacedDate = try #require(
                    Calendar.current.date(
                        byAdding: .day, value: Int(spacedCard.scheduledDays), to: spacedDate))
            } else {
                spacedDate = try #require(
                    Calendar.current.date(byAdding: .day, value: 1, to: spacedDate))
            }
        }

        // Spaced repetition should result in better retention
        #expect(spacedCard.stability >= cramCard.stability)
    }

    // MARK: - Batch Operations

    @Test("Review multiple cards in session")
    func testBatchReviewSession() throws {
        let fsrs = createFSRS()
        let now = Date()

        var cards = [
            TestCard(question: "Q1", answer: "A1"),
            TestCard(question: "Q2", answer: "A2"),
            TestCard(question: "Q3", answer: "A3"),
            TestCard(question: "Q4", answer: "A4"),
            TestCard(question: "Q5", answer: "A5")
        ]

        let grades: [Rating] = [.easy, .good, .hard, .good, .easy]

        // Review all cards
        for i in 0..<cards.count {
            let result = try fsrs.next(card: cards[i], now: now, rating: grades[i])
            cards[i] = result.card
        }

        // Verify all cards were updated
        for card in cards {
            #expect(card.reps == 1)
            #expect(card.stability > 0)
        }
    }

    @Test("Preview all cards before review")
    func testPreviewAllCardsBeforeReview() throws {
        let fsrs = createFSRS()
        let now = Date()

        let cards = [
            TestCard(question: "Q1", answer: "A1"),
            TestCard(question: "Q2", answer: "A2"),
            TestCard(question: "Q3", answer: "A3")
        ]

        // Preview each card
        var previews: [RecordLog<TestCard>] = []
        for card in cards {
            let preview = try fsrs.repeat(card: card, now: now)
            previews.append(preview)
        }

        // Each preview should have 4 options
        for preview in previews {
            #expect(preview.count == 4)
        }
    }

    // MARK: - Undo/Redo Scenarios

    @Test("Undo review with rollback")
    func testUndoReview() throws {
        let fsrs = createFSRS()
        let originalCard = createCard()
        let now = Date()

        // Perform review
        let result = try fsrs.next(card: originalCard, now: now, rating: .hard)
        let updatedCard = result.card

        #expect(updatedCard.reps == 1)
        #expect(updatedCard.stability > 0)

        // Undo review
        let rolledBackCard = try fsrs.rollback(card: updatedCard, log: result.log)

        #expect(rolledBackCard.state == originalCard.state)
        #expect(rolledBackCard.reps == originalCard.reps)
        #expect(rolledBackCard.stability == originalCard.stability)
    }

    @Test("Multiple undo operations")
    func testMultipleUndoOperations() throws {
        let fsrs = createFSRS()
        var card = createCard()
        var now = Date()
        var logs: [ReviewLog] = []
        var cardStates: [TestCard] = [card]

        // Perform multiple reviews
        for _ in 0..<5 {
            let result = try fsrs.next(card: card, now: now, rating: .good)
            logs.append(result.log)
            card = result.card
            cardStates.append(card)

            now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        }

        #expect(card.reps == 5)

        // Undo all reviews in reverse order
        for i in stride(from: logs.count - 1, through: 0, by: -1) {
            card = try fsrs.rollback(card: card, log: logs[i])
            #expect(card.reps == i)
        }

        #expect(card.reps == 0)
        #expect(card.state == .new)
    }

    // MARK: - Data Migration/Import Scenarios

    @Test("Import existing card with history")
    func testImportExistingCard() throws {
        let fsrs = createFSRS()
        let now = Date()

        // Create a card as if it was imported from another system
        let importedCard = TestCard(
            question: "Imported Q",
            answer: "Imported A",
            due: try #require(Calendar.current.date(byAdding: .day, value: -5, to: now)),
            state: .review,
            lastReview: Calendar.current.date(byAdding: .day, value: -15, to: now),
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 5,
            lapses: 1
        )

        // Continue using the card
        let result = try fsrs.next(card: importedCard, now: now, rating: .good)

        #expect(result.card.reps == 6)
        #expect(result.card.stability >= importedCard.stability)
    }

    @Test("Reset card completely with forget")
    func testResetCardCompletely() throws {
        let fsrs = createFSRS()
        let now = Date()

        // Create a mature card
        let matureCard = TestCard(
            question: "Mature Q",
            answer: "Mature A",
            state: .review,
            stability: 100.0,
            difficulty: 2.0,
            scheduledDays: 90,
            reps: 50,
            lapses: 2
        )

        // Reset the card
        let result = fsrs.forget(card: matureCard, now: now, resetCount: true)

        #expect(result.card.state == .new)
        #expect(result.card.stability == 0)
        #expect(result.card.difficulty == 0)
        #expect(result.card.reps == 0)
        #expect(result.card.lapses == 0)
    }

    // MARK: - Edge Cases and Error Handling

    @Test("Review card with future due date")
    func testFutureDueDateReview() throws {
        let fsrs = createFSRS()
        let now = Date()
        let futureDate = try #require(Calendar.current.date(byAdding: .day, value: 10, to: now))

        let card = TestCard(
            question: "Test",
            answer: "Test",
            due: futureDate,
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 15,
            reps: 3
        )

        // Should still allow review
        let result = try fsrs.next(card: card, now: now, rating: .good)
        #expect(result.card.reps == 4)
    }

    @Test("Review card with very old due date")
    func testVeryOldDueDateReview() throws {
        let fsrs = createFSRS()
        let now = Date()
        let oldDate = try #require(Calendar.current.date(byAdding: .day, value: -365, to: now))

        let card = TestCard(
            question: "Test",
            answer: "Test",
            due: oldDate,
            state: .review,
            lastReview: Calendar.current.date(byAdding: .day, value: -375, to: now),
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 3
        )

        // Should handle very overdue cards
        let result = try fsrs.next(card: card, now: now, rating: .again)
        #expect(result.card.lapses == 1)
    }

    @Test("Concurrent reviews of same card (copy)")
    func testConcurrentReviews() throws {
        let fsrs = createFSRS()
        let originalCard = createCard()
        let now = Date()

        // Simulate two different review paths
        let result1 = try fsrs.next(card: originalCard, now: now, rating: .good)
        let result2 = try fsrs.next(card: originalCard, now: now, rating: .easy)

        // Both should be valid but different
        #expect(result1.card.reps == 1)
        #expect(result2.card.reps == 1)
        #expect(result1.card.stability != result2.card.stability)
    }

    // MARK: - Retrievability Over Time

    @Test("Monitor retrievability over time")
    func testRetrievabilityOverTime() throws {
        let fsrs = createFSRS()
        let baseDate = Date()

        // Create a reviewed card
        var card = createCard()
        let result = try fsrs.next(card: card, now: baseDate, rating: .good)
        card = result.card

        // Skip to review state
        let result2 = try fsrs.next(card: card, now: baseDate, rating: .easy)
        card = result2.card

        var previousRetrievability = 1.0

        // Check retrievability over next 30 days
        for days in 1...30 {
            let checkDate = try #require(
                Calendar.current.date(byAdding: .day, value: days, to: baseDate))
            let retrievability = fsrs.getRetrievabilityValue(card: card, now: checkDate)

            // Should decrease over time
            #expect(retrievability <= previousRetrievability)
            #expect(retrievability >= 0)
            #expect(retrievability <= 1)

            previousRetrievability = retrievability
        }
    }

    @Test("Optimal review timing based on retrievability")
    func testOptimalReviewTiming() throws {
        let fsrs = createFSRS()
        var card = createCard()
        let now = Date()

        // Review to get to review state
        var result = try fsrs.next(card: card, now: now, rating: .good)
        card = result.card

        result = try fsrs.next(card: card, now: now, rating: .easy)
        card = result.card

        guard card.state == .review else { return }

        // Check retrievability at scheduled due date
        let dueDate = card.due
        let retrievabilityAtDue = fsrs.getRetrievabilityValue(card: card, now: dueDate)

        // Should be close to request retention (0.9)
        #expect(retrievabilityAtDue >= 0.8)
        #expect(retrievabilityAtDue <= 1.0)
    }

    // MARK: - Custom Properties Preservation

    @Test("Custom card properties survive full lifecycle")
    func testCustomPropertiesPreservation() throws {
        let fsrs = createFSRS()
        var card = TestCard(
            question: "Custom Q",
            answer: "Custom A",
            tags: ["important", "history"],
            notes: "Study this carefully"
        )
        var now = Date()

        // Multiple reviews
        for _ in 0..<5 {
            let result = try fsrs.next(card: card, now: now, rating: .good)
            card = result.card

            // Verify custom properties
            #expect(card.question == "Custom Q")
            #expect(card.answer == "Custom A")
            #expect(card.tags == ["important", "history"])
            #expect(card.notes == "Study this carefully")

            now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        }
    }

    // MARK: - Stress Tests

    @Test("Handle large number of reviews")
    func testLargeNumberOfReviews() throws {
        let fsrs = createFSRS()
        var card = createCard()
        var now = Date()

        // Perform many reviews
        for i in 1...100 {
            let rating: Rating = i % 4 == 0 ? .again : .good
            let result = try fsrs.next(card: card, now: now, rating: rating)
            card = result.card

            now = try #require(Calendar.current.date(byAdding: .hour, value: 1, to: now))
        }

        // Card should still be in valid state
        #expect(card.difficulty >= 1.0)
        #expect(card.difficulty <= 10.0)
        #expect(card.stability > 0)
    }

    @Test("Rapid successive reviews")
    func testRapidSuccessiveReviews() throws {
        let fsrs = createFSRS()
        var card = createCard()
        let now = Date()

        // Review multiple times at the exact same time
        for _ in 0..<10 {
            let result = try fsrs.next(card: card, now: now, rating: .good)
            card = result.card
        }

        #expect(card.reps == 10)
    }
}
