import Foundation

/// Strategy mode enumeration
public enum StrategyMode: String, Hashable {
    case scheduler = "Scheduler"
    case learningSteps = "LearningSteps"
    case seed = "Seed"
}

/// Base strategy protocol
/// All strategies must conform to this protocol for type safety
public protocol Strategy: Sendable {
    /// The mode this strategy handles
    static var mode: StrategyMode { get }
}

/// Seed strategy protocol
/// Generates seeds for random number generation
public protocol SeedStrategyProtocol: Strategy {
    /// Generate seed for a scheduler
    /// - Parameter scheduler: The scheduler instance
    /// - Returns: Seed string
    func generateSeed(for scheduler: any SchedulerProtocol) -> String
}

/// Default implementation for SeedStrategyProtocol
extension SeedStrategyProtocol {
    public static var mode: StrategyMode { .seed }
}

/// Learning steps strategy protocol
/// Computes learning/relearning step intervals
public protocol LearningStepsStrategyProtocol: Strategy {
    /// Compute step information for grades
    /// - Parameters:
    ///   - params: FSRS parameters
    ///   - state: Current card state
    ///   - currentStep: Current learning step index
    /// - Returns: Dictionary mapping grades to step information
    func computeSteps(
        params: FSRSParameters,
        state: State,
        currentStep: Int
    ) -> [Rating: (scheduledMinutes: Int, nextStep: Int)]
}

/// Default implementation for LearningStepsStrategyProtocol
extension LearningStepsStrategyProtocol {
    public static var mode: StrategyMode { .learningSteps }
}

/// Scheduler strategy protocol
/// Creates custom scheduler implementations
public protocol SchedulerStrategyProtocol: Strategy {
    /// Create a scheduler instance
    /// - Parameters:
    ///   - card: Any card conforming to FSRSCard
    ///   - now: Current date
    ///   - algorithm: FSRS algorithm instance
    ///   - strategyManager: Strategy manager for nested strategies
    /// - Returns: Scheduler instance
    func createScheduler<C: FSRSCard>(
        card: C,
        now: Date,
        algorithm: any FSRSAlgorithmProtocol,
        strategyManager: StrategyManager
    ) -> any SchedulerProtocol
}

/// Default implementation for SchedulerStrategyProtocol
extension SchedulerStrategyProtocol {
    public static var mode: StrategyMode { .scheduler }
}

/// Type-safe strategy container
/// Holds specific strategy instances without using Any
public struct StrategyManager: Sendable {
    public var seedStrategy: (any SeedStrategyProtocol)?
    public var learningStepsStrategy: (any LearningStepsStrategyProtocol)?
    public var schedulerStrategy: (any SchedulerStrategyProtocol)?

    public init(
        seedStrategy: (any SeedStrategyProtocol)? = nil,
        learningStepsStrategy: (any LearningStepsStrategyProtocol)? = nil,
        schedulerStrategy: (any SchedulerStrategyProtocol)? = nil
    ) {
        self.seedStrategy = seedStrategy
        self.learningStepsStrategy = learningStepsStrategy
        self.schedulerStrategy = schedulerStrategy
    }

    /// Clear all strategies
    public mutating func clearAll() {
        seedStrategy = nil
        learningStepsStrategy = nil
        schedulerStrategy = nil
    }
}

// MARK: - Function-Based Strategy Support

/// Seed strategy function type
/// Function-based alternative to SeedStrategyProtocol for simple cases
/// - Parameter scheduler: The scheduler instance
/// - Returns: Seed string
public typealias SeedStrategy = (any SchedulerProtocol) -> String

/// Learning steps strategy function type
/// Function-based alternative to LearningStepsStrategyProtocol for simple cases
/// - Parameters:
///   - params: FSRS parameters
///   - state: Current card state
///   - curStep: Current learning step index
/// - Returns: Dictionary mapping grades to step information
public typealias LearningStepsStrategy = (
    FSRSParameters,
    State,
    Int
) -> [Rating: (scheduledMinutes: Int, nextStep: Int)]
