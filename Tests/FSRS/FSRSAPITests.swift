import Testing
import Foundation
@testable import FSRS

@Suite("FSRS API Tests")
struct FSRSAPITests {
    
    private func createFSRS(enableFuzz: Bool = false, enableShortTerm: Bool = true) -> FSRS<TestCard> {
        let params = PartialFSRSParameters(
            requestRetention: 0.9,
            maximumInterval: 36500,
            enableFuzz: enableFuzz,
            enableShortTerm: enableShortTerm
        )
        return fsrs(params: params, logger: ConsoleLogger())
    }
    
    private func createCard() -> TestCard {
        return TestCard(question: "What is FSRS?", answer: "Free Spaced Repetition Scheduler")
    }
    
    private func createReviewCard() -> TestCard {
        return TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 5
        )
    }
        
    @Test("Create empty card with default values")
    func testCreateEmptyCard() {
        let card = createCard()
        
        #expect(card.state == .new)
        #expect(card.stability == 0)
        #expect(card.difficulty == 0)
        #expect(card.reps == 0)
        #expect(card.lapses == 0)
        #expect(card.learningSteps == 0)
        #expect(card.scheduledDays == 0)
        #expect(card.lastReview == nil)
    }
    
    // MARK: - Repeat (Preview) Tests
    
    @Test("Repeat shows all 4 rating options for new card")
    func testRepeatNewCard() throws {
        let f = createFSRS()
        let card = createCard()
        let now = Date()
        
        let recordLog = try f.repeat(card: card, now: now)
        
        // Should contain all 4 grades
        #expect(recordLog.count == 4)
        #expect(recordLog[.again] != nil)
        #expect(recordLog[.hard] != nil)
        #expect(recordLog[.good] != nil)
        #expect(recordLog[.easy] != nil)
    }
    
    @Test("Repeat sets lastReview to current time")
    func testRepeatSetsLastReview() throws {
        let f = createFSRS()
        let card = createCard()
        let now = Date()
        
        let recordLog = try f.repeat(card: card, now: now)
        
        #expect(recordLog[.again]?.card.lastReview == now)
        #expect(recordLog[.hard]?.card.lastReview == now)
        #expect(recordLog[.good]?.card.lastReview == now)
        #expect(recordLog[.easy]?.card.lastReview == now)
    }
    
    @Test("Repeat calculates different stability for each rating")
    func testRepeatCalculatesStability() throws {
        let f = createFSRS()
        let card = createCard()
        
        let recordLog = try f.repeat(card: card, now: Date())
        
        let againStability = recordLog[.again]!.card.stability
        let hardStability = recordLog[.hard]!.card.stability
        let goodStability = recordLog[.good]!.card.stability
        let easyStability = recordLog[.easy]!.card.stability
        
        // Stability should increase: again < hard < good < easy
        #expect(againStability < hardStability)
        #expect(hardStability < goodStability)
        #expect(goodStability < easyStability)
        #expect(againStability > 0)
    }
    
    @Test("Repeat calculates different difficulty for each rating")
    func testRepeatCalculatesDifficulty() throws {
        let f = createFSRS()
        let card = createCard()
        
        let recordLog = try f.repeat(card: card, now: Date())
        
        let againDifficulty = recordLog[.again]!.card.difficulty
        let hardDifficulty = recordLog[.hard]!.card.difficulty
        let goodDifficulty = recordLog[.good]!.card.difficulty
        let easyDifficulty = recordLog[.easy]!.card.difficulty
        
        // Difficulty should decrease: again > hard > good > easy
        #expect(againDifficulty > hardDifficulty)
        #expect(hardDifficulty > goodDifficulty)
        #expect(goodDifficulty > easyDifficulty)
        #expect(easyDifficulty >= 1.0)
    }
    
    @Test("Repeat increments reps counter")
    func testRepeatIncrementsReps() throws {
        let f = createFSRS()
        let card = createCard()
        
        let recordLog = try f.repeat(card: card, now: Date())
        
        #expect(recordLog[.again]?.card.reps == 1)
        #expect(recordLog[.hard]?.card.reps == 1)
        #expect(recordLog[.good]?.card.reps == 1)
        #expect(recordLog[.easy]?.card.reps == 1)
    }
    
    @Test("Repeat preserves custom card properties")
    func testRepeatPreservesCustomProperties() throws {
        let f = createFSRS()
        let card = TestCard(
            question: "Custom Question",
            answer: "Custom Answer",
            tags: ["tag1", "tag2"],
            notes: "Important note"
        )
        
        let recordLog = try f.repeat(card: card, now: Date())
        
        #expect(recordLog[.good]?.card.question == "Custom Question")
        #expect(recordLog[.good]?.card.answer == "Custom Answer")
        #expect(recordLog[.good]?.card.tags == ["tag1", "tag2"])
        #expect(recordLog[.good]?.card.notes == "Important note")
    }
    
    // MARK: - Next (Single Rating) Tests
    
    @Test("Next returns card for specific rating")
    func testNextWithSpecificRating() throws {
        let f = createFSRS()
        let card = createCard()
        let now = Date()
        
        let result = try f.next(card: card, now: now, grade: .good)
        
        #expect(result.card.state != .new)
        #expect(result.card.lastReview == now)
        #expect(result.card.reps == 1)
        #expect(result.log.rating == .good)
    }
    
    @Test("Next throws error for manual rating")
    func testNextRejectsManualRating() throws {
        let f = createFSRS()
        let card = createCard()
        
        #expect(throws: FSRSError.self) {
            _ = try f.next(card: card, now: Date(), grade: .manual)
        }
    }
    
    @Test("Next with Again rating creates learning state")
    func testNextAgainCreatesLearningState() throws {
        let f = createFSRS()
        let card = createCard()
        
        let result = try f.next(card: card, now: Date(), grade: .again)
        
        #expect(result.card.state == .learning)
    }
    
    @Test("Next with Easy rating creates review state")
    func testNextEasyCreatesReviewState() throws {
        let f = createFSRS()
        let card = createCard()
        
        let result = try f.next(card: card, now: Date(), grade: .easy)
        
        #expect(result.card.state == .review)
        #expect(result.card.scheduledDays > 0)
    }
    
    // MARK: - State Transition Tests
    
    @Test("New card transitions to Learning state with Again/Hard/Good")
    func testNewToLearningTransition() throws {
        let f = createFSRS(enableShortTerm: true)
        let card = createCard()
        
        let againResult = try f.next(card: card, now: Date(), grade: .again)
        let hardResult = try f.next(card: card, now: Date(), grade: .hard)
        let goodResult = try f.next(card: card, now: Date(), grade: .good)
        
        #expect(againResult.card.state == .learning)
        #expect(hardResult.card.state == .learning)
        #expect(goodResult.card.state == .learning)
    }
    
    @Test("New card transitions to Review state with Easy")
    func testNewToReviewTransition() throws {
        let f = createFSRS()
        let card = createCard()
        
        let result = try f.next(card: card, now: Date(), grade: .easy)
        
        #expect(result.card.state == .review)
    }
    
    @Test("Review card transitions to Relearning on Again")
    func testReviewToRelearningTransition() throws {
        let f = createFSRS(enableShortTerm: true)
        let card = createReviewCard()
        
        let result = try f.next(card: card, now: Date(), grade: .again)
        
        #expect(result.card.state == .relearning)
        #expect(result.card.lapses == 1)
    }
    
    @Test("Multiple reviews increment reps and update state")
    func testMultipleReviews() throws {
        let f = createFSRS()
        var card = createCard()
        var now = Date()
        
        // First review
        var result = try f.next(card: card, now: now, grade: .good)
        card = result.card
        #expect(card.reps == 1)
        
        // Second review
        now = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        result = try f.next(card: card, now: now, grade: .good)
        card = result.card
        #expect(card.reps == 2)
        
        // Third review
        now = Calendar.current.date(byAdding: .day, value: Int(card.scheduledDays), to: now)!
        result = try f.next(card: card, now: now, grade: .good)
        card = result.card
        #expect(card.reps == 3)
    }
    
    // MARK: - Retrievability Tests
    
    @Test("Retrievability returns formatted percentage string")
    func testGetRetrievabilityFormat() throws {
        let f = createFSRS()
        let card = createReviewCard()
        
        let retrievability = f.getRetrievability(card: card)
        
        // Should be formatted as percentage
        #expect(retrievability.contains("%"))
        #expect(retrievability.count > 0)
    }
    
    @Test("Retrievability value is between 0 and 1 for review cards")
    func testGetRetrievabilityValue() {
        let f = createFSRS()
        let card = createReviewCard()
        
        let value = f.getRetrievabilityValue(card: card)
        
        #expect(value >= 0.0)
        #expect(value <= 1.0)
    }
    
    @Test("New card has zero retrievability")
    func testNewCardRetrievability() {
        let f = createFSRS()
        let card = createCard()
        
        let value = f.getRetrievabilityValue(card: card)
        
        #expect(value == 0.0)
    }
    
    @Test("Retrievability decreases over time")
    func testRetrievabilityDecreases() {
        let f = createFSRS()
        let baseDate = Date()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            lastReview: baseDate,
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 1
        )
        
        let now1 = Calendar.current.date(byAdding: .day, value: 1, to: baseDate)!
        let r1 = f.getRetrievabilityValue(card: card, now: now1)
        
        let now2 = Calendar.current.date(byAdding: .day, value: 5, to: baseDate)!
        let r2 = f.getRetrievabilityValue(card: card, now: now2)
        
        let now3 = Calendar.current.date(byAdding: .day, value: 10, to: baseDate)!
        let r3 = f.getRetrievabilityValue(card: card, now: now3)
        
        // Retrievability should decrease over time
        #expect(r1 > r2)
        #expect(r2 > r3)
    }
    
    // MARK: - Rollback Tests
    
    @Test("Rollback restores previous card state")
    func testRollback() throws {
        let f = createFSRS()
        let originalCard = createCard()
        
        // Perform a review
        let result = try f.next(card: originalCard, now: Date(), grade: .good)
        let updatedCard = result.card
        let log = result.log
        
        // Rollback
        let rolledBackCard = try f.rollback(card: updatedCard, log: log)
        
        #expect(rolledBackCard.state == originalCard.state)
        #expect(rolledBackCard.reps == originalCard.reps)
        #expect(rolledBackCard.stability == originalCard.stability)
        #expect(rolledBackCard.difficulty == originalCard.difficulty)
    }
    
    @Test("Rollback throws error for manual rating")
    func testRollbackRejectsManualRating() throws {
        let f = createFSRS()
        let card = createReviewCard()
        
        let log = ReviewLog(
            rating: .manual,
            state: .review,
            due: card.due,
            stability: card.stability,
            difficulty: card.difficulty,
            scheduledDays: 0,
            learningSteps: 0,
            review: Date()
        )
        
        #expect(throws: FSRSError.self) {
            _ = try f.rollback(card: card, log: log)
        }
    }
    
    @Test("Rollback decrements lapses when appropriate")
    func testRollbackDecrementsLapses() throws {
        let f = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 5,
            lapses: 2
        )
        
        // Review with Again (increases lapses)
        let result = try f.next(card: card, now: Date(), grade: .again)
        #expect(result.card.lapses == 3)
        
        // Rollback should restore original lapses
        let rolledBack = try f.rollback(card: result.card, log: result.log)
        #expect(rolledBack.lapses == 2)
    }
    
    // MARK: - Forget Tests
    
    @Test("Forget resets card to new state")
    func testForgetCard() {
        let f = createFSRS()
        let card = createReviewCard()
        let now = Date()
        
        let result = f.forget(card: card, now: now)
        
        #expect(result.card.state == .new)
        #expect(result.card.stability == 0)
        #expect(result.card.difficulty == 0)
        #expect(result.card.scheduledDays == 0)
        #expect(result.card.learningSteps == 0)
        #expect(result.card.due == now)
    }
    
    @Test("Forget with resetCount resets reps and lapses")
    func testForgetWithResetCount() {
        let f = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            reps: 10,
            lapses: 3
        )
        
        let result = f.forget(card: card, now: Date(), resetCount: true)
        
        #expect(result.card.reps == 0)
        #expect(result.card.lapses == 0)
    }
    
    @Test("Forget without resetCount preserves reps and lapses")
    func testForgetPreservesCount() {
        let f = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 5.0,
            reps: 10,
            lapses: 3
        )
        
        let result = f.forget(card: card, now: Date(), resetCount: false)
        
        #expect(result.card.reps == 10)
        #expect(result.card.lapses == 3)
    }
    
    @Test("Forget creates manual rating log")
    func testForgetCreatesManualLog() {
        let f = createFSRS()
        let card = createReviewCard()
        
        let result = f.forget(card: card, now: Date())
        
        #expect(result.log.rating == .manual)
    }
    
    // MARK: - Forgetting Curve Tests
    
    @Test("Forgetting curve returns value between 0 and 1")
    func testForgettingCurveRange() {
        let f = createFSRS()
        
        let result1 = f.forgettingCurve(0, 10.0)
        let result2 = f.forgettingCurve(5, 10.0)
        let result3 = f.forgettingCurve(100, 10.0)
        
        #expect(result1 >= 0 && result1 <= 1)
        #expect(result2 >= 0 && result2 <= 1)
        #expect(result3 >= 0 && result3 <= 1)
    }
    
    @Test("Forgetting curve starts at approximately 0.9")
    func testForgettingCurveStartsHigh() {
        let f = createFSRS()
        
        // At elapsed=0, retrievability should be close to 0.9 (request retention)
        let result = f.forgettingCurve(0, 10.0)
        
        #expect(result > 0.85)
        #expect(result <= 1.0)
    }
    
    @Test("Forgetting curve decreases with elapsed days")
    func testForgettingCurveDecreases() {
        let f = createFSRS()
        let stability = 10.0
        
        let r1 = f.forgettingCurve(1, stability)
        let r2 = f.forgettingCurve(5, stability)
        let r3 = f.forgettingCurve(10, stability)
        let r4 = f.forgettingCurve(20, stability)
        
        #expect(r1 > r2)
        #expect(r2 > r3)
        #expect(r3 > r4)
    }
    
    // MARK: - Parameter Tests
    
    @Test("FSRS uses custom parameters")
    func testCustomParameters() {
        let customParams = PartialFSRSParameters(
            requestRetention: 0.85,
            maximumInterval: 365,
            enableFuzz: false
        )
        let f: FSRS<TestCard> = fsrs(params: customParams)
        
        #expect(f.parameters.requestRetention == 0.85)
        #expect(f.parameters.maximumInterval == 365)
        #expect(f.parameters.enableFuzz == false)
    }
    
    @Test("FSRS uses default parameters when not specified")
    func testDefaultParameters() {
        let f: FSRS<TestCard> = fsrs()
        
        #expect(f.parameters.requestRetention > 0)
        #expect(f.parameters.maximumInterval > 0)
        #expect(f.parameters.w.count == 21) // FSRS-6 has 21 parameters
    }
    
    @Test("Parameters can be updated after initialization")
    func testUpdateParameters() {
        var f = createFSRS()
        var params = f.parameters
        params.requestRetention = 0.95
        f.parameters = params
        
        #expect(f.parameters.requestRetention == 0.95)
    }
    
    // MARK: - Reschedule Tests
    
    @Test("Reschedule with empty history returns current card")
    func testRescheduleEmptyHistory() throws {
        let f = createFSRS()
        let card = createCard()
        
        let result = try f.reschedule(currentCard: card, reviews: [])
        
        #expect(result.collections.isEmpty)
    }
    
    @Test("Reschedule processes review history")
    func testRescheduleWithHistory() throws {
        let f = createFSRS()
        let card = createCard()
        let baseDate = Date()
        
        let history: [FSRSHistory] = [
            FSRSHistory(
                rating: .good,
                review: baseDate,
                state: .new
            ),
            FSRSHistory(
                rating: .good,
                review: Calendar.current.date(byAdding: .day, value: 1, to: baseDate),
                state: .learning
            )
        ]
        
        let result = try f.reschedule(
            currentCard: card,
            reviews: history,
            options: RescheduleOptions(skipManual: true)
        )
        
        #expect(result.collections.count == 2)
    }
    
    @Test("Reschedule skips manual reviews when requested")
    func testRescheduleSkipsManual() throws {
        let f = createFSRS()
        let card = createCard()
        let baseDate = Date()
        
        let history: [FSRSHistory] = [
            FSRSHistory(rating: .good, review: baseDate, state: .new),
            FSRSHistory(rating: .manual, review: Calendar.current.date(byAdding: .day, value: 1, to: baseDate), state: .learning),
            FSRSHistory(rating: .good, review: Calendar.current.date(byAdding: .day, value: 2, to: baseDate), state: .learning)
        ]
        
        let result = try f.reschedule(
            currentCard: card,
            reviews: history,
            options: RescheduleOptions(skipManual: true)
        )
        
        // Should only process 2 non-manual reviews
        #expect(result.collections.count == 2)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Review on due date")
    func testReviewOnDueDate() throws {
        let f = createFSRS()
        let dueDate = Date()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            due: dueDate,
            state: .review,
            lastReview: Calendar.current.date(byAdding: .day, value: -10, to: dueDate),
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 1
        )
        
        let result = try f.next(card: card, now: dueDate, grade: .good)
        
        #expect(result.card.reps == 2)
        #expect(result.card.scheduledDays > 0)
    }
    
    @Test("Review before due date")
    func testReviewBeforeDueDate() throws {
        let f = createFSRS()
        let dueDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let card = TestCard(
            question: "Test",
            answer: "Test",
            due: dueDate,
            state: .review,
            lastReview: Date(),
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 1
        )
        
        let result = try f.next(card: card, now: Date(), grade: .good)
        
        #expect(result.card.reps == 2)
    }
    
    @Test("Review after due date")
    func testReviewAfterDueDate() throws {
        let f = createFSRS()
        let dueDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let card = TestCard(
            question: "Test",
            answer: "Test",
            due: dueDate,
            state: .review,
            lastReview: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
            stability: 10.0,
            difficulty: 5.0,
            scheduledDays: 10,
            reps: 1
        )
        
        let result = try f.next(card: card, now: Date(), grade: .good)
        
        #expect(result.card.reps == 2)
    }
    
    @Test("Very high stability card")
    func testVeryHighStability() throws {
        let f = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 1000.0,
            difficulty: 2.0,
            scheduledDays: 365,
            reps: 50
        )
        
        let result = try f.next(card: card, now: Date(), grade: .good)
        
        #expect(result.card.stability >= card.stability)
    }
    
    @Test("Very high difficulty card")
    func testVeryHighDifficulty() throws {
        let f = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 10.0,
            difficulty: 9.5,
            scheduledDays: 10,
            reps: 10
        )
        
        let result = try f.next(card: card, now: Date(), grade: .good)
        
        #expect(result.card.difficulty >= 1.0)
        #expect(result.card.difficulty <= 10.0)
    }
    
    @Test("Card with many lapses")
    func testManyLapses() throws {
        let f = createFSRS()
        let card = TestCard(
            question: "Test",
            answer: "Test",
            state: .review,
            stability: 5.0,
            difficulty: 8.0,
            scheduledDays: 5,
            reps: 20,
            lapses: 10
        )
        
        let result = try f.next(card: card, now: Date(), grade: .again)
        
        #expect(result.card.lapses == 11)
    }
    
    // MARK: - Short-term vs Long-term Scheduler Tests
    
    @Test("Short-term scheduler enabled uses learning steps")
    func testShortTermScheduler() throws {
        let f = createFSRS(enableShortTerm: true)
        let card = createCard()
        
        let recordLog = try f.repeat(card: card, now: Date())
        
        // With short-term enabled, learning steps should be used
        #expect(recordLog[.good]?.card.learningSteps != nil)
    }
    
    @Test("Long-term scheduler bypasses learning steps")
    func testLongTermScheduler() throws {
        let f = createFSRS(enableShortTerm: false)
        let card = createCard()
        
        let result = try f.next(card: card, now: Date(), grade: .good)
        
        // With short-term disabled, should go directly to review
        #expect(result.card.state == .review)
    }
    
    // MARK: - Review Log Tests
    
    @Test("Review log contains correct metadata")
    func testReviewLogMetadata() throws {
        let f = createFSRS()
        let card = createCard()
        let now = Date()
        
        let result = try f.next(card: card, now: now, grade: .good)
        let log = result.log
        
        #expect(log.rating == .good)
        #expect(log.state == .new) // Original state
        #expect(log.review == now)
        #expect(log.scheduledDays >= 0)
    }
    
    @Test("Review log tracks state transitions")
    func testReviewLogStateTransitions() throws {
        let f = createFSRS()
        let card = createCard()
        
        let result = try f.next(card: card, now: Date(), grade: .good)
        
        // Log should contain the old state
        #expect(result.log.state == .new)
        // Card should have new state
        #expect(result.card.state != .new)
    }
}

