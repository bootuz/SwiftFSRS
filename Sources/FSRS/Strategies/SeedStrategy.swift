import Foundation

/// Default seed strategy implementation
/// Generates seed from review time, reps, and difficulty × stability
public struct DefaultSeedStrategy: SeedStrategyProtocol {
    public init() {}
    
    public func generateSeed(for scheduler: any SchedulerProtocol) -> String {
        let time = scheduler.reviewTime.timeIntervalSince1970
        let reps = scheduler.current.reps
        let mul = scheduler.current.difficulty * scheduler.current.stability
        return "\(time)_\(reps)_\(mul)"
    }
}

/// Card ID-based seed strategy
/// Uses card identifier for seed generation
public struct CardIdSeedStrategy: SeedStrategyProtocol {
    public init() {}
    
    public func generateSeed(for scheduler: any SchedulerProtocol) -> String {
        // Generate seed based on card properties
        let reps = scheduler.current.reps
        let timestamp = scheduler.reviewTime.timeIntervalSince1970
        return "\(Int(timestamp))_\(reps)"
    }
}

// MARK: - Function-Based Strategy Helpers

/// Default seed strategy function
/// Generates seed from review time, reps, and difficulty × stability
public func defaultInitSeedStrategy(_ scheduler: any SchedulerProtocol) -> String {
    let defaultStrategy = DefaultSeedStrategy()
    return defaultStrategy.generateSeed(for: scheduler)
}

/// Generate seed strategy using card ID
/// - Returns: Seed strategy function
public func cardIdSeedStrategy(_ scheduler: any SchedulerProtocol) -> String {
    let strategy = CardIdSeedStrategy()
    return strategy.generateSeed(for: scheduler)
}

