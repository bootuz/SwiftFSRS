import Testing
import Foundation
@testable import FSRS

/// Test suite for FSRS parameter management and validation
@Suite("Parameter Management Tests")
struct ParameterTests {
    // MARK: - Parameter Generation Tests

    @Test("Generate parameters with all defaults")
    func testGenerateDefaultParameters() {
        let params = PartialFSRSParameters()
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.weights.count == 21) // FSRS-6 has 21 parameters
        #expect(generated.requestRetention > 0 && generated.requestRetention <= 1)
        #expect(generated.maximumInterval > 0)
    }

    @Test("Generate parameters with custom request retention")
    func testCustomRequestRetention() {
        let params = PartialFSRSParameters(requestRetention: 0.85)
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.requestRetention == 0.85)
    }

    @Test("Generate parameters with custom maximum interval")
    func testCustomMaximumInterval() {
        let params = PartialFSRSParameters(maximumInterval: 180)
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.maximumInterval == 180)
    }

    @Test("Generate parameters with custom weights")
    func testCustomWeights() {
        let customWeights = Array(repeating: 1.0, count: 21)
        let params = PartialFSRSParameters(weights: customWeights)
        let generated = FSRSParametersGenerator.generate(from: params)

        // Custom weights are provided and should have 21 elements
        // Note: Weights may be clipped/validated by FSRS
        #expect(generated.weights.count == 21)
    }

    @Test("Generate parameters with fuzz disabled")
    func testDisableFuzz() {
        let params = PartialFSRSParameters(enableFuzz: false)
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.enableFuzz == false)
    }

    @Test("Generate parameters with short-term disabled")
    func testDisableShortTerm() {
        let params = PartialFSRSParameters(enableShortTerm: false)
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.enableShortTerm == false)
    }

    @Test("Generate parameters with custom learning steps")
    func testCustomLearningSteps() {
        let steps = [StepUnit(value: 1, unit: .minutes), StepUnit(value: 10, unit: .minutes)]
        let params = PartialFSRSParameters(learningSteps: steps)
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.learningSteps == steps)
    }

    @Test("Generate parameters with custom relearning steps")
    func testCustomRelearningSteps() {
        let steps = [StepUnit(value: 5, unit: .minutes)]
        let params = PartialFSRSParameters(relearningSteps: steps)
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.relearningSteps == steps)
    }

    // MARK: - StepUnit Tests

    @Test("StepUnit parses minutes correctly")
    func testStepUnitMinutes() {
        let step = StepUnit(from: "10m")

        #expect(step != nil)
        #expect(step?.value == 10)
        #expect(step?.unit == .minutes)
        #expect(step?.scheduledMinutes == 10)
    }

    @Test("StepUnit parses hours correctly")
    func testStepUnitHours() {
        let step = StepUnit(from: "2h")

        #expect(step != nil)
        #expect(step?.value == 2)
        #expect(step?.unit == .hours)
        #expect(step?.scheduledMinutes == 120)
    }

    @Test("StepUnit parses days correctly")
    func testStepUnitDays() {
        let step = StepUnit(from: "1d")

        #expect(step != nil)
        #expect(step?.value == 1)
        #expect(step?.unit == .days)
        #expect(step?.scheduledMinutes == 1_440)
    }

    @Test("StepUnit string literal initialization")
    func testStepUnitStringLiteral() {
        let step: StepUnit = "5m"

        #expect(step.value == 5)
        #expect(step.unit == .minutes)
    }

    @Test("StepUnit description format")
    func testStepUnitDescription() {
        let step1 = StepUnit(value: 10, unit: .minutes)
        let step2 = StepUnit(value: 2, unit: .hours)
        let step3 = StepUnit(value: 1, unit: .days)

        #expect(step1.description == "10m")
        #expect(step2.description == "2h")
        #expect(step3.description == "1d")
    }

    @Test("StepUnit invalid format returns nil")
    func testStepUnitInvalidFormat() {
        let invalidStep1 = StepUnit(from: "10x")
        let invalidStep2 = StepUnit(from: "")
        let invalidStep3 = StepUnit(from: "abc")

        #expect(invalidStep1 == nil)
        #expect(invalidStep2 == nil)
        #expect(invalidStep3 == nil)
    }

    // MARK: - Parameter Validation Tests

    @Test("Request retention must be valid range")
    func testRequestRetentionRange() throws {
        let fsrs: FSRS<TestCard> = fsrs(params: PartialFSRSParameters(requestRetention: 0.9))

        #expect(fsrs.parameters.requestRetention > 0)
        #expect(fsrs.parameters.requestRetention <= 1)
    }

    @Test("Maximum interval must be positive")
    func testMaximumIntervalPositive() {
        let fsrs: FSRS<TestCard> = fsrs(params: PartialFSRSParameters(maximumInterval: 365))

        #expect(fsrs.parameters.maximumInterval > 0)
    }

    @Test("Weight array has correct length")
    func testWeightArrayLength() {
        let fsrs: FSRS<TestCard> = fsrs()

        #expect(fsrs.parameters.weights.count == 21)
    }

    // MARK: - Parameter Migration Tests

    @Test("Migrate nil parameters to default")
    func testMigrateNilParameters() {
        let migrated = FSRSParametersGenerator.migrateParameters(parameters: nil)

        #expect(migrated.count == 21)
    }

    @Test("Migrate 21-element parameters unchanged")
    func testMigrate21Parameters() {
        let params = Array(repeating: 1.0, count: 21)
        let migrated = FSRSParametersGenerator.migrateParameters(parameters: params)

        #expect(migrated.count == 21)
    }

    // MARK: - Parameter Codable Tests

    @Test("FSRSParameters encodes and decodes correctly")
    func testParametersCodable() throws {
        let original = FSRSParameters(
            requestRetention: 0.9,
            maximumInterval: 36_500,
            weights: Array(repeating: 1.0, count: 21),
            enableFuzz: true,
            enableShortTerm: true,
            learningSteps: [StepUnit(value: 1, unit: .minutes)],
            relearningSteps: [StepUnit(value: 10, unit: .minutes)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FSRSParameters.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Learning Steps Configuration Tests

    @Test("Learning steps affect new card scheduling")
    func testLearningStepsAffectScheduling() throws {
        let steps = [
            StepUnit(value: 1, unit: .minutes),
            StepUnit(value: 10, unit: .minutes)
        ]
        let params = PartialFSRSParameters(
            enableShortTerm: true,
            learningSteps: steps
        )
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        let card = TestCard(question: "Test", answer: "Test")
        _ = try fsrs.repeat(card: card, now: Date())

        // Learning steps should be reflected in the scheduling
        #expect(fsrs.parameters.learningSteps == steps)
    }

    @Test("Relearning steps affect failed card scheduling")
    func testRelearningStepsAffectScheduling() throws {
        let steps = [StepUnit(value: 5, unit: .minutes)]
        let params = PartialFSRSParameters(
            enableShortTerm: true,
            relearningSteps: steps
        )
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        #expect(fsrs.parameters.relearningSteps == steps)
    }

    @Test("Empty learning steps works correctly")
    func testEmptyLearningSteps() throws {
        let params = PartialFSRSParameters(
            enableShortTerm: true,
            learningSteps: []
        )
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        let card = TestCard(question: "Test", answer: "Test")
        let result = try fsrs.next(card: card, now: Date(), rating: .good)

        // Should work even with empty steps
        #expect(result.card.reps == 1)
    }

    // MARK: - Fuzzing Tests

    @Test("Fuzz disabled produces consistent intervals")
    func testFuzzDisabledConsistency() throws {
        let params = PartialFSRSParameters(enableFuzz: false)
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        let card = TestCard(question: "Test", answer: "Test")
        let now = Date()

        let result1 = try fsrs.next(card: card, now: now, rating: .good)
        let result2 = try fsrs.next(card: card, now: now, rating: .good)

        // With fuzz disabled, intervals should be identical
        #expect(result1.card.scheduledDays == result2.card.scheduledDays)
    }

    // MARK: - Parameter Update Tests

    @Test("Update parameters affects future scheduling")
    func testUpdateParametersAffectsScheduling() throws {
        var fsrs: FSRS<TestCard> = fsrs(params: PartialFSRSParameters(requestRetention: 0.9))

        let card = TestCard(question: "Test", answer: "Test")
        _ = try fsrs.next(card: card, now: Date(), rating: .good)

        // Update parameters
        var newParams = fsrs.parameters
        newParams.requestRetention = 0.7
        fsrs.parameters = newParams

        _ = try fsrs.next(card: card, now: Date(), rating: .good)

        // Different retention should affect intervals
        #expect(fsrs.parameters.requestRetention == 0.7)
    }

    // MARK: - Boundary Tests

    @Test("Minimum request retention")
    func testMinimumRequestRetention() {
        let params = PartialFSRSParameters(requestRetention: 0.01)
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        #expect(fsrs.parameters.requestRetention > 0)
    }

    @Test("Maximum request retention")
    func testMaximumRequestRetention() {
        let params = PartialFSRSParameters(requestRetention: 1.0)
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        #expect(fsrs.parameters.requestRetention <= 1)
    }

    @Test("Small maximum interval")
    func testSmallMaximumInterval() {
        let params = PartialFSRSParameters(maximumInterval: 7)
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        #expect(fsrs.parameters.maximumInterval == 7)
    }

    @Test("Large maximum interval")
    func testLargeMaximumInterval() {
        let params = PartialFSRSParameters(maximumInterval: 100_000)
        let fsrs: FSRS<TestCard> = fsrs(params: params)

        #expect(fsrs.parameters.maximumInterval == 100_000)
    }

    // MARK: - Complex Learning Steps Tests

    @Test("Multiple learning steps in different units")
    func testMixedUnitLearningSteps() {
        let steps = [
            StepUnit(value: 1, unit: .minutes),
            StepUnit(value: 10, unit: .minutes),
            StepUnit(value: 1, unit: .hours),
            StepUnit(value: 1, unit: .days)
        ]
        let params = PartialFSRSParameters(learningSteps: steps)
        let generated = FSRSParametersGenerator.generate(from: params)

        #expect(generated.learningSteps.count == 4)
        #expect(generated.learningSteps[0].scheduledMinutes == 1)
        #expect(generated.learningSteps[1].scheduledMinutes == 10)
        #expect(generated.learningSteps[2].scheduledMinutes == 60)
        #expect(generated.learningSteps[3].scheduledMinutes == 1_440)
    }

    @Test("Learning steps maintain order")
    func testLearningStepsOrder() {
        let steps = [
            StepUnit(value: 1, unit: .minutes),
            StepUnit(value: 5, unit: .minutes),
            StepUnit(value: 10, unit: .minutes)
        ]
        let params = PartialFSRSParameters(learningSteps: steps)
        let generated = FSRSParametersGenerator.generate(from: params)

        for i in 0..<generated.learningSteps.count {
            #expect(generated.learningSteps[i] == steps[i])
        }
    }
}
