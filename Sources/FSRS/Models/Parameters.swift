import Foundation

/// FSRS parameters configuration
public struct FSRSParameters: Codable, Equatable {
    /// Requested retention rate (0 < request_retention <= 1)
    public var requestRetention: Double
    
    /// Maximum interval in days
    public var maximumInterval: Int
    
    /// Weight parameters array (21 elements for FSRS-6)
    public var w: [Double]
    
    /// Enable fuzzing for intervals
    public var enableFuzz: Bool
    
    /// Enable short-term scheduling (learning steps)
    public var enableShortTerm: Bool
    
    /// Learning steps configuration
    public var learningSteps: [StepUnit]
    
    /// Relearning steps configuration
    public var relearningSteps: [StepUnit]
    
    public init(
        requestRetention: Double,
        maximumInterval: Int,
        w: [Double],
        enableFuzz: Bool,
        enableShortTerm: Bool,
        learningSteps: [StepUnit],
        relearningSteps: [StepUnit]
    ) {
        self.requestRetention = requestRetention
        self.maximumInterval = maximumInterval
        self.w = w
        self.enableFuzz = enableFuzz
        self.enableShortTerm = enableShortTerm
        self.learningSteps = learningSteps
        self.relearningSteps = relearningSteps
    }
}

