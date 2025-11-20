import Foundation

/// Core FSRS algorithm protocol
/// Combines all calculator protocols and provides core algorithm functionality
public protocol FSRSAlgorithmProtocol {
    /// Algorithm parameters
    var parameters: FSRSParameters { get set }

    /// Optional logger for debugging and monitoring
    var logger: (any FSRSLogger)? { get set }

    /// Interval modifier (precomputed for performance)
    var intervalModifier: Double { get }

    /// Random provider (for dependency injection)
    var randomProvider: RandomProvider? { get }

    /// Forgetting curve function (legacy interface, kept for compatibility)
    /// - Parameters:
    ///   - elapsedDays: Days since last review
    ///   - stability: Current stability
    /// - Returns: Retrievability (probability of recall)
    func forgettingCurve(_ elapsedDays: Double, _ stability: Double) -> Double
}
