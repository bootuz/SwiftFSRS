import Foundation

/// Applies interval constraints to ensure proper ordering of intervals
/// Ensures: Again < Hard < Good < Easy
public struct IntervalConstraintApplier {
    
    /// Apply constraints to intervals for a new card
    ///
    /// - Parameters:
    ///   - again: Again interval
    ///   - hard: Hard interval
    ///   - good: Good interval
    ///   - easy: Easy interval
    /// - Returns: Tuple of constrained intervals (again, hard, good, easy)
    public static func applyNewCardConstraints(
        again: Int,
        hard: Int,
        good: Int,
        easy: Int
    ) -> (again: Int, hard: Int, good: Int, easy: Int) {
        var constrainedAgain = again
        var constrainedHard = hard
        var constrainedGood = good
        var constrainedEasy = easy
        
        // Ensure: again <= hard <= good <= easy
        constrainedAgain = min(constrainedAgain, constrainedHard)
        constrainedHard = max(constrainedHard, constrainedAgain + 1)
        constrainedGood = max(constrainedGood, constrainedHard + 1)
        constrainedEasy = max(constrainedEasy, constrainedGood + 1)
        
        return (
            again: constrainedAgain,
            hard: constrainedHard,
            good: constrainedGood,
            easy: constrainedEasy
        )
    }
    
    /// Apply constraints to intervals for a review card
    ///
    /// - Parameters:
    ///   - hard: Hard interval
    ///   - good: Good interval
    ///   - easy: Easy interval
    /// - Returns: Tuple of constrained intervals (hard, good, easy)
    public static func applyReviewCardConstraints(
        hard: Int,
        good: Int,
        easy: Int
    ) -> (hard: Int, good: Int, easy: Int) {
        var constrainedHard = hard
        var constrainedGood = good
        var constrainedEasy = easy
        
        // Ensure: hard <= good <= easy
        // Hard should be at most equal to good
        constrainedHard = min(constrainedHard, constrainedGood)
        
        // Good should be at least hard + 1
        constrainedGood = max(constrainedGood, constrainedHard + 1)
        
        // Easy should be at least good + 1
        constrainedEasy = max(constrainedEasy, constrainedGood + 1)
        
        return (
            hard: constrainedHard,
            good: constrainedGood,
            easy: constrainedEasy
        )
    }
}

