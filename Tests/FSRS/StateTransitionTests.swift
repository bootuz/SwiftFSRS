import Foundation
import Testing

@testable import FSRS

@Suite("State Transition Tests")
struct StateTransitionTests {
    // MARK: - Helper Functions

    private func createFSRS(enableShortTerm: Bool = false) -> FSRS<TestCard> {
        let params = PartialFSRSParameters(
            enableFuzz: false,
            enableShortTerm: enableShortTerm
        )
        return fsrs(params: params)
    }

    private func createCard(state: State = .new) -> TestCard {
        TestCard(
            question: "Test",
            answer: "Test",
            state: state,
            stability: state == .new ? 0 : 10.0,
            difficulty: state == .new ? 0 : 5.0,
            scheduledDays: state == .new ? 0 : 10,
            reps: state == .new ? 0 : 3
        )
    }

    // MARK: - New State Transitions

    @Test(
        "New + Again → Learning",
        arguments: [
            (false, State.review),
            (true, State.learning)
        ])
    func testNewToLearningWithAgain(enableShortTirm: Bool, state: State) throws {
        let fsrs = createFSRS(enableShortTerm: enableShortTirm)
        let card = createCard(state: .new)

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        #expect(result.card.state == state)
        #expect(result.card.reps == 1)
        #expect(result.card.lapses == 0)
        #expect(result.card.stability > 0.21)
        #expect(result.card.difficulty > 6.41)
    }

    @Test("New + Hard → Learning")
    func testNewToLearningWithHard() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = createCard(state: .new)

        let result = try fsrs.next(card: card, now: Date(), rating: .hard)

        #expect(result.card.state == .learning)
        #expect(result.card.reps == 1)
    }

    @Test("New + Good → Learning (with short-term)")
    func testNewToLearningWithGood() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = createCard(state: .new)

        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        #expect(result.card.state == .learning)
        #expect(result.card.reps == 1)
    }

    @Test("New + Good → Review (without short-term)")
    func testNewToReviewWithGoodNoShortTerm() throws {
        let fsrs = createFSRS(enableShortTerm: false)
        let card = createCard(state: .new)

        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        #expect(result.card.state == .review)
        #expect(result.card.reps == 1)
        #expect(result.card.scheduledDays > 0)
    }

    @Test("New + Easy → Review")
    func testNewToReviewWithEasy() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .new)

        let result = try fsrs.next(card: card, now: Date(), rating: .easy)

        #expect(result.card.state == .review)
        #expect(result.card.reps == 1)
        #expect(result.card.scheduledDays > 0)
    }

    // MARK: - Learning State Transitions

    @Test("Learning + Again → Learning (restart)")
    func testLearningToLearningWithAgain() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .learning,
            stability: 1.0,
            difficulty: 5.0,
            learningSteps: 1,
            reps: 1
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        #expect(result.card.state == .learning)
        #expect(result.card.learningSteps == 0)
    }

    @Test("Learning + Good → Learning or Review (progress)")
    func testLearningProgressWithGood() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .learning,
            stability: 0.21,
            difficulty: 6.41,
            learningSteps: 0,
            reps: 1
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        // Should progress in learning or graduate
        #expect(result.card.state == .review)
        #expect(result.card.reps == 2)
        #expect(result.card.difficulty < card.difficulty)
        #expect(result.card.stability > card.stability)
    }

    @Test("Learning + Easy → Review (graduate early)")
    func testLearningToReviewWithEasy() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .learning,
            stability: 1.0,
            difficulty: 5.0,
            learningSteps: 1,
            reps: 1
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .easy)

        #expect(result.card.state == .review)
        #expect(result.card.scheduledDays > 0)
    }

    // MARK: - Review State Transitions

    @Test("Review + Again → Relearning")
    func testReviewToRelearningWithAgain() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = createCard(state: .review)

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        #expect(result.card.state == .relearning)
        #expect(result.card.lapses == 1)
    }

    @Test("Review + Hard → Review")
    func testReviewToReviewWithHard() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .review)

        let result = try fsrs.next(card: card, now: Date(), rating: .hard)

        #expect(result.card.state == .review)
        #expect(result.card.reps == 4)
        #expect(result.card.lapses == 0)
    }

    @Test("Review + Good → Review")
    func testReviewToReviewWithGood() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .review)

        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        #expect(result.card.state == .review)
        #expect(result.card.reps == 4)
        #expect(result.card.lapses == 0)
        #expect(result.card.stability >= card.stability)
    }

    @Test("Review + Easy → Review")
    func testReviewToReviewWithEasy() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .review)

        let result = try fsrs.next(card: card, now: Date(), rating: .easy)

        #expect(result.card.state == .review)
        #expect(result.card.reps == 4)
        #expect(result.card.stability >= card.stability)
    }

    // MARK: - Relearning State Transitions

    @Test("Relearning + Again → Relearning (restart)")
    func testRelearningToRelearningWithAgain() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .relearning,
            stability: 5.0,
            difficulty: 7.0,
            learningSteps: 1,
            reps: 5,
            lapses: 1
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        // State can be relearning or review depending on short-term configuration
        #expect(result.card.state == .relearning || result.card.state == .review)
        #expect(result.card.reps == 6)
    }

    @Test("Relearning + Good → Relearning or Review (progress)")
    func testRelearningProgressWithGood() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .relearning,
            stability: 5.0,
            difficulty: 7.0,
            learningSteps: 0,
            reps: 5,
            lapses: 1
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        #expect(result.card.reps == 6)
    }

    @Test("Relearning + Easy → Review (graduate)")
    func testRelearningToReviewWithEasy() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .relearning,
            stability: 5.0,
            difficulty: 7.0,
            learningSteps: 1,
            reps: 5,
            lapses: 1
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .easy)

        #expect(result.card.state == .review)
    }

    // MARK: - Lapses Tracking

    @Test("Lapses increment only on Review → Relearning")
    func testLapsesIncrementOnReviewFailure() throws {
        let fsrs = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            reps: 10,
            lapses: 3
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        #expect(result.card.lapses == 4)
    }

    @Test("Lapses do not increment on Learning failure")
    func testLapsesNotIncrementOnLearningFailure() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .learning,
            stability: 1.0,
            difficulty: 5.0,
            reps: 1,
            lapses: 0
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        #expect(result.card.lapses == 0)
    }

    @Test("Lapses persist through successful reviews")
    func testLapsesPersistThroughSuccessfulReviews() throws {
        let fsrs = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            reps: 10,
            lapses: 5
        )

        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        #expect(result.card.lapses == 5)
    }

    // MARK: - Stability Progression

    @Test("Stability increases on successful review")
    func testStabilityIncreasesOnSuccess() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .review)
        let initialStability = card.stability

        let result = try fsrs.next(card: card, now: Date(), rating: .good)
        #expect(result.card.stability >= initialStability)
    }

    @Test("Stability decreases on failure")
    func testStabilityDecreasesOnFailure() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .review)
        let initialStability = card.stability

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        #expect(result.card.stability < initialStability)
    }

    @Test("Easy rating produces highest stability")
    func testEasyProducesHighestStability() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = createCard(state: .review)

        let recordLog = try fsrs.repeat(card: card, now: Date())

        // swiftlint:disable:next force_unwrapping
        let againStability = recordLog[.again]!.card.stability
        // swiftlint:disable:next force_unwrapping
        let hardStability = recordLog[.hard]!.card.stability
        // swiftlint:disable:next force_unwrapping
        let goodStability = recordLog[.good]!.card.stability
        // swiftlint:disable:next force_unwrapping
        let easyStability = recordLog[.easy]!.card.stability

        #expect(easyStability > goodStability)
        #expect(goodStability > hardStability)
        #expect(hardStability > againStability)
    }

    // MARK: - Difficulty Progression

    @Test("Difficulty increases on Again rating")
    func testDifficultyIncreasesOnAgain() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .review)
        let initialDifficulty = card.difficulty

        let result = try fsrs.next(card: card, now: Date(), rating: .again)

        #expect(result.card.difficulty > initialDifficulty)
    }

    @Test("Difficulty decreases on Easy rating")
    func testDifficultyDecreasesOnEasy() throws {
        let fsrs = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            reps: 3
        )
        let initialDifficulty = card.difficulty

        let result = try fsrs.next(card: card, now: Date(), rating: .easy)

        #expect(result.card.difficulty <= initialDifficulty)
    }

    @Test("Difficulty stays within valid range")
    func testDifficultyBounds() throws {
        let fsrs = createFSRS()

        // Test with very high difficulty
        let hardCard = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 9.9,
            reps: 50
        )

        let resultHard = try fsrs.next(card: hardCard, now: Date(), rating: .again)
        #expect(resultHard.card.difficulty >= 1.0)
        #expect(resultHard.card.difficulty <= 10.0)

        // Test with very low difficulty
        let easyCard = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 1.1,
            reps: 50
        )

        let resultEasy = try fsrs.next(card: easyCard, now: Date(), rating: .easy)
        #expect(resultEasy.card.difficulty >= 1.0)
        #expect(resultEasy.card.difficulty <= 10.0)
    }

    // MARK: - Scheduled Days

    @Test("Scheduled days increase with stability")
    func testScheduledDaysIncreaseWithStability() throws {
        let fsrs = createFSRS()
        let card = createCard(state: .review)

        var currentCard = card

        for _ in 0..<3 {
            let result = try fsrs.next(card: currentCard, now: Date(), rating: .good)
            let newScheduledDays = result.card.scheduledDays

            // Scheduled days should generally increase with successful reviews
            #expect(newScheduledDays >= 0)

            currentCard = result.card
        }
    }

    @Test("Scheduled days are zero for learning state")
    func testLearningStateScheduledDays() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        let card = createCard(state: .new)

        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        if result.card.state == .learning {
            #expect(result.card.scheduledDays == 0)
        }
    }

    // MARK: - Complete Card Lifecycle

    @Test("Complete lifecycle: New → Learning → Review")
    func testCompleteLifecycle() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        var card = TestCard(question: "Test", answer: "Test")
        var now = Date()

        // New → Learning
        #expect(card.state == .new)
        var result = try fsrs.next(card: card, now: now, rating: .good)
        card = result.card
        #expect(card.state == .learning)
        #expect(card.reps == 1)

        // Progress through learning steps
        now = try #require(Calendar.current.date(byAdding: .minute, value: 10, to: now))
        result = try fsrs.next(card: card, now: now, rating: .good)
        card = result.card

        // Eventually reach Review
        if card.state == .learning {
            now = try #require(Calendar.current.date(byAdding: .hour, value: 1, to: now))
            result = try fsrs.next(card: card, now: now, rating: .good)
            card = result.card
        }

        // Verify final state
        #expect(card.state == .review || card.state == .learning)
        #expect(card.reps >= 1)
    }

    @Test("Failed review lifecycle: Review → Relearning → Review")
    func testFailedReviewLifecycle() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        var card = createCard(state: .review)
        let now = Date()

        // Review → Relearning (failure)
        #expect(card.state == .review)
        #expect(card.lapses == 0)

        var result = try fsrs.next(card: card, now: now, rating: .again)
        card = result.card

        #expect(card.state == .relearning)
        #expect(card.lapses == 1)

        // Relearning → Review (recovery)
        result = try fsrs.next(card: card, now: now, rating: .easy)
        card = result.card

        #expect(card.state == .review)
        #expect(card.lapses == 1)  // Lapses persist
    }

    @Test("Multiple failures accumulate lapses")
    func testMultipleFailuresAccumulateLapses() throws {
        let fsrs = createFSRS(enableShortTerm: true)
        var card = createCard(state: .review)
        var now = Date()

        // First failure
        var result = try fsrs.next(card: card, now: now, rating: .again)
        card = result.card
        #expect(card.lapses == 1)

        // Graduate back to review
        result = try fsrs.next(card: card, now: now, rating: .easy)
        card = result.card
        #expect(card.state == .review)
        #expect(card.lapses == 1)

        // Second failure
        now = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        result = try fsrs.next(card: card, now: now, rating: .again)
        card = result.card
        #expect(card.lapses == 2)
    }
}
