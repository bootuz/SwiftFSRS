import Foundation

/// Comprehensive FSRS error type covering all failure modes
public enum FSRSError: Error, Sendable, LocalizedError {
    // MARK: - Parameter Errors
    case invalidParameter(String)
    case invalidRequestRetention(Double)
    case invalidStability(String)
    case invalidDifficulty(String)
    case invalidRetrievability(String)
    case invalidElapsedDays(String)
    case invalidScheduledInterval(String)

    // MARK: - Rating/Grade Errors
    case invalidRating(String)
    case invalidGrade(String)
    case manualGradeNotAllowed

    // MARK: - State Errors
    case invalidState(String)
    case invalidMemoryState
    case invalidDeltaT(Double)

    // MARK: - Conversion Errors
    case invalidDate(String)
    case invalidCardType(String)
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        // Parameter Errors
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .invalidRequestRetention(let value):
            return "Invalid request retention: \(value). Must be between 0 and 1."
        case .invalidStability(let message):
            return "Invalid stability: \(message)"
        case .invalidDifficulty(let message):
            return "Invalid difficulty: \(message)"
        case .invalidRetrievability(let message):
            return "Invalid retrievability: \(message)"
        case .invalidElapsedDays(let message):
            return "Invalid elapsed days: \(message)"
        case .invalidScheduledInterval(let message):
            return "Invalid scheduled interval: \(message)"

        // Rating/Grade Errors
        case .invalidRating(let message):
            return "Invalid rating: \(message)"
        case .invalidGrade(let message):
            return "Invalid rating: \(message)"
        case .manualGradeNotAllowed:
            return "Manual rating cannot be used for scheduling operations"

        // State Errors
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .invalidMemoryState:
            return "Invalid memory state: difficulty and stability must be valid"
        case .invalidDeltaT(let value):
            return "Invalid elapsed time: \(value). Must be non-negative."

        // Conversion Errors
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        case .invalidCardType(let message):
            return "Invalid card type: \(message)"
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        }
    }
}
