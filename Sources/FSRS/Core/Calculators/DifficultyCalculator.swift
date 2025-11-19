import Foundation

/// Calculator for all difficulty-related FSRS formulas
/// Difficulty represents how hard a card is to remember (1-10 scale)
public struct DifficultyCalculator {
    private let parameters: FSRSParameters
    private let logger: (any FSRSLogger)?
    
    public init(parameters: FSRSParameters, logger: (any FSRSLogger)? = nil) {
        self.parameters = parameters
        self.logger = logger
    }
    
    // MARK: - Initial Difficulty
    
    /// Initialize difficulty for a new card based on grade
    /// D₀(G) = w[4] - e^((G-1)·w[5]) + 1
    /// D₀ = min{max{D₀(G), 1}, 10}
    ///
    /// - Parameter grade: Grade rating
    /// - Returns: Initial difficulty
    public func initDifficulty(for grade: Rating) throws -> Difficulty {
        let gradeValue = Double(grade.rawValue)
        let difficultyValue = parameters.w[4] - exp((gradeValue - 1) * parameters.w[5]) + 1
        let clampedValue = clamp(difficultyValue, min: DIFFICULTY_RANGE_MIN, max: DIFFICULTY_RANGE_MAX)
        let difficulty = try Difficulty(roundToFixed(clampedValue))
        
        logger?.debug("Initial difficulty for grade \(grade): \(difficulty.value)")
        
        return difficulty
    }
    
    // MARK: - Next Difficulty
    
    /// Calculate next difficulty after a review
    /// delta_d = -w[6] × (G - 3)
    /// next_d = D + linear_damping(delta_d, D)
    /// D'(D,R) = w[7] × D₀(4) + (1 - w[7]) × next_d
    ///
    /// - Parameters:
    ///   - currentDifficulty: Current difficulty
    ///   - grade: Grade rating
    /// - Returns: Next difficulty
    public func nextDifficulty(
        current currentDifficulty: Difficulty,
        grade: Rating
    ) throws -> Difficulty {
        let gradeValue = Double(grade.rawValue)
        let delta = -parameters.w[6] * (gradeValue - GRADE_NEUTRAL_VALUE)
        
        let damped = linearDamping(delta: delta, currentDifficulty: currentDifficulty)
        let afterDamping = currentDifficulty.value + damped
        
        // Clamp afterDamping before creating Difficulty object to prevent negative values
        let clampedAfterDamping = clamp(afterDamping, min: DIFFICULTY_RANGE_MIN, max: DIFFICULTY_RANGE_MAX)
        
        let withReversion = try applyMeanReversion(
            initial: try initDifficulty(for: .easy),
            current: try Difficulty(clampedAfterDamping)
        )
        
        let clampedValue = clamp(withReversion.value, min: DIFFICULTY_RANGE_MIN, max: DIFFICULTY_RANGE_MAX)
        let newDifficulty = try Difficulty(clampedValue)
        
        logger?.debug("""
            Next difficulty: \
            d=\(currentDifficulty.value) -> \(newDifficulty.value), \
            grade=\(grade), \
            delta=\(delta)
            """)
        
        return newDifficulty
    }
    
    // MARK: - Helper Methods
    
    /// Apply linear damping to difficulty change
    /// This prevents extreme difficulty changes for cards near boundaries
    ///
    /// - Parameters:
    ///   - delta: Raw difficulty change
    ///   - currentDifficulty: Current difficulty value
    /// - Returns: Damped difficulty change
    private func linearDamping(delta: Double, currentDifficulty: Difficulty) -> Double {
        let damped = (delta * (DIFFICULTY_RANGE_MAX - currentDifficulty.value)) / DIFFICULTY_RANGE_SPAN
        return roundToFixed(damped)
    }
    
    /// Apply mean reversion to pull difficulty toward initial value
    /// D' = w[7] × D_initial + (1 - w[7]) × D_current
    ///
    /// - Parameters:
    ///   - initial: Initial difficulty value
    ///   - current: Current difficulty value
    /// - Returns: Difficulty with mean reversion applied
    private func applyMeanReversion(
        initial: Difficulty,
        current: Difficulty
    ) throws -> Difficulty {
        let reverted = parameters.w[7] * initial.value + (1 - parameters.w[7]) * current.value
        return try Difficulty(roundToFixed(reverted))
    }
}
