import Foundation

/// Core FSRS algorithm implementation with all mathematical formulas
open class FSRSAlgorithm: FSRSAlgorithmProtocol {
    /// FSRS parameters
    public var parameters: FSRSParameters

    /// Interval modifier (precomputed for performance)
    public var intervalModifier: Double

    /// Random provider (for dependency injection, created when needed)
    public var randomProvider: RandomProvider?

    /// Optional logger for debugging and monitoring
    public var logger: (any FSRSLogger)?

    /// Initialize FSRS algorithm with parameters
    /// - Parameters:
    ///   - params: Partial FSRS parameters (missing values use defaults)
    ///   - randomProvider: Random provider (optional, uses system random if not provided)
    ///   - logger: Optional logger for debugging and monitoring
    public init(
        params: PartialFSRSParameters = PartialFSRSParameters(),
        randomProvider: RandomProvider? = nil,
        logger: (any FSRSLogger)? = nil
    ) {
        self.randomProvider = randomProvider
        self.logger = logger
        self.parameters = FSRSParametersGenerator.generate(from: params)
        do {
            self.intervalModifier = try FSRSAlgorithm.calculateIntervalModifier(
                requestRetention: parameters.requestRetention,
                weights: parameters.weights
            )
            logger?.debug("Algorithm initialized: requestRetention=\(parameters.requestRetention), maximumInterval=\(parameters.maximumInterval), enableFuzz=\(parameters.enableFuzz), enableShortTerm=\(parameters.enableShortTerm)")
        } catch {
            // This should never happen with valid parameters, but handle gracefully
            logger?.error("Failed to calculate interval modifier: \(error)")
            self.intervalModifier = 1.0
        }
    }

    /// Forgetting curve implementation (legacy wrapper for compatibility)
    /// - Parameters:
    ///   - elapsedDays: Days since last review
    ///   - stability: Current stability
    /// - Returns: Retrievability (probability of recall)
    public func forgettingCurve(_ elapsedDays: Double, _ stability: Double) -> Double {
        let calculator = StabilityCalculator(parameters: parameters, logger: logger)
        let result = try? calculator.forgettingCurve(
            elapsedDays: ElapsedDays(unchecked: elapsedDays),
            stability: Stability(unchecked: stability)
        )
        let retrievability = result?.value ?? 0.0
        logger?.info("Forgetting curve: t=\(elapsedDays), s=\(stability) -> r=\(retrievability)")
        return retrievability
    }

    /// Calculate interval modifier
    /// I(r,s) = (r^(1/DECAY) - 1) / FACTOR × s
    /// - Parameters:
    ///   - requestRetention: Requested retention rate (0 < requestRetention <= 1)
    ///   - weights: Weight parameters array
    /// - Returns: Interval modifier
    internal static func calculateIntervalModifier(
        requestRetention: Double,
        weights: [Double]
    ) throws -> Double {
        guard requestRetention > 0 && requestRetention <= 1 else {
            throw FSRSError.invalidRequestRetention(requestRetention)
        }
        let (decay, factor) = StabilityCalculator.computeDecayFactor(weights)
        let result = (pow(requestRetention, 1 / decay) - 1) / factor
        return roundToFixed(result)
    }


    // Note: All calculation methods have been extracted to dedicated calculator classes:
    // - StabilityCalculator: stability-related formulas
    // - DifficultyCalculator: difficulty-related formulas
    // - IntervalCalculator: interval calculation and fuzzing
    //
    // The old nextState(), initStability(), nextDifficulty(), nextRecallStability(),
    // nextForgetStability(), nextShortTermStability(), nextInterval(), and applyFuzz()
    // methods have been removed as they are now implemented in the calculator classes.
    //
    // Schedulers now use these calculators directly via BaseScheduler.
}
