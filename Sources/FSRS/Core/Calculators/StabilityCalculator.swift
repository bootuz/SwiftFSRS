import Foundation

/// Calculator for all stability-related FSRS formulas
/// Stability represents the interval at which retrievability = 90%
public struct StabilityCalculator {
    private let parameters: FSRSParameters
    private let logger: (any FSRSLogger)?
    
    public init(parameters: FSRSParameters, logger: (any FSRSLogger)? = nil) {
        self.parameters = parameters
        self.logger = logger
    }
    
    // MARK: - Forgetting Curve
    
    /// Calculate retrievability using the forgetting curve
    /// R(t,S) = (1 + FACTOR × t/(9·S))^DECAY
    ///
    /// - Parameters:
    ///   - elapsedDays: Days since last review
    ///   - stability: Current stability
    /// - Returns: Retrievability (probability of recall)
    public func forgettingCurve(
        elapsedDays: ElapsedDays,
        stability: Stability
    ) throws -> Retrievability {
        let (decay, factor) = Self.computeDecayFactor(parameters.w)
        let result = pow(
            1 + (factor * elapsedDays.value) / (RETRIEVABILITY_CURVE_DIVISOR * stability.value),
            decay
        )
        
        let clampedResult = clamp(result, min: 0.0, max: 1.0)
        let retrievability = try Retrievability(roundToFixed(clampedResult))
        
        logger?.info("Forgetting curve: elapsed=\(elapsedDays.value)d, stability=\(stability.value) -> retrievability=\(retrievability.value)")
        
        return retrievability
    }
    
    /// Compute decay factor from parameters
    /// - Parameter weights: Weight parameters array
    /// - Returns: Tuple of (decay, factor)
    public static func computeDecayFactor(_ weights: [Double]) -> (decay: Double, factor: Double) {
        let decay = -weights[20]
        let factor = exp(pow(decay, -1) * log(RETRIEVABILITY_TARGET)) - 1.0
        return (decay: decay, factor: roundToFixed(factor))
    }
    
    // MARK: - Initial Stability
    
    /// Initialize stability for a new card based on grade
    /// S₀(G) = w[G-1]
    /// S₀ = max{S₀, 0.1}
    ///
    /// - Parameter grade: Grade rating (Again, Hard, Good, Easy)
    /// - Returns: Initial stability
    public func initStability(for grade: Rating) throws -> Stability {
        let gradeValue = grade.rawValue
        guard gradeValue >= 1 && gradeValue <= 4 else {
            throw FSRSError.invalidRating("Grade must be Again(1), Hard(2), Good(3), or Easy(4), got \(grade)")
        }
        
        let stabilityValue = max(parameters.w[gradeValue - 1], 0.1)
        let stability = try Stability(stabilityValue)
        
        logger?.debug("Initial stability for grade \(grade): \(stability.value)")
        
        return stability
    }
    
    // MARK: - Recall Stability (Success)
    
    /// Calculate next stability after successful recall
    /// S'_r(D,S,R,G) = S × (e^w[8] × (11-D) × S^(-w[9]) × (e^(w[10]×(1-R))-1) × w[15](if G=2) × w[16](if G=4) + 1)
    ///
    /// - Parameters:
    ///   - difficulty: Current difficulty
    ///   - stability: Current stability
    ///   - retrievability: Retrievability at time of review
    ///   - grade: Grade rating
    /// - Returns: New stability after successful recall
    public func nextRecallStability(
        difficulty: Difficulty,
        stability: Stability,
        retrievability: Retrievability,
        grade: Rating
    ) throws -> Stability {
        let hardPenalty = (grade == .hard) ? parameters.w[15] : 1.0
        let easyBonus = (grade == .easy) ? parameters.w[16] : 1.0
        
        let result = stability.value * (
            1 + exp(parameters.w[8]) *
            (DIFFICULTY_CENTER_POINT - difficulty.value) *
            pow(stability.value, -parameters.w[9]) *
            (exp((1 - retrievability.value) * parameters.w[10]) - 1) *
            hardPenalty *
            easyBonus
        )
        
        let clampedResult = clamp(result, min: S_MIN, max: S_MAX)
        let newStability = try Stability(clampedResult)
        
        logger?.debug("""
            Recall stability: \
            s=\(stability.value) -> \(newStability.value), \
            d=\(difficulty.value), \
            r=\(retrievability.value), \
            grade=\(grade)
            """)
        
        return newStability
    }
    
    // MARK: - Forget Stability (Failure)
    
    /// Calculate next stability after forgetting (Again rating in review state)
    /// S'_f(D,S,R) = w[11] × D^(-w[12]) × ((S+1)^w[13]-1) × e^(w[14]×(1-R))
    ///
    /// - Parameters:
    ///   - difficulty: Current difficulty
    ///   - stability: Current stability
    ///   - retrievability: Retrievability at time of review
    /// - Returns: New stability after forgetting
    public func nextForgetStability(
        difficulty: Difficulty,
        stability: Stability,
        retrievability: Retrievability
    ) throws -> Stability {
        let result = parameters.w[11] *
            pow(difficulty.value, -parameters.w[12]) *
            (pow(stability.value + 1, parameters.w[13]) - 1) *
            exp((1 - retrievability.value) * parameters.w[14])
        
        let clampedResult = clamp(result, min: S_MIN, max: S_MAX)
        let newStability = try Stability(clampedResult)
        
        logger?.debug("""
            Forget stability: \
            s=\(stability.value) -> \(newStability.value), \
            d=\(difficulty.value), \
            r=\(retrievability.value)
            """)
        
        return newStability
    }
    
    // MARK: - Short-term Stability
    
    /// Calculate next short-term stability (for learning/relearning steps)
    /// S'_s(S,G) = S × (S^(-w[19]) × e^(w[17] × (G-3+w[18])))
    ///
    /// - Parameters:
    ///   - stability: Current stability
    ///   - grade: Grade rating
    /// - Returns: New short-term stability
    public func nextShortTermStability(
        stability: Stability,
        grade: Rating
    ) throws -> Stability {
        let gradeValue = Double(grade.rawValue)
        let sinc = pow(stability.value, -parameters.w[19]) *
            exp(parameters.w[17] * (gradeValue - GRADE_NEUTRAL_VALUE + parameters.w[18]))
        
        // Apply mask: if grade >= Good (3), sinc should be at least 1.0
        let maskedSinc = gradeValue >= GRADE_NEUTRAL_VALUE ? max(sinc, 1.0) : sinc
        let result = stability.value * maskedSinc
        
        let clampedResult = clamp(result, min: S_MIN, max: S_MAX)
        let newStability = try Stability(clampedResult)
        
        logger?.debug("""
            Short-term stability: \
            s=\(stability.value) -> \(newStability.value), \
            grade=\(grade)
            """)
        
        return newStability
    }
}

