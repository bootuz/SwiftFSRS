import Foundation

/// Partial FSRS parameters for initialization
public struct PartialFSRSParameters {
    public var requestRetention: Double?
    public var maximumInterval: Int?
    public var w: [Double]?
    public var enableFuzz: Bool?
    public var enableShortTerm: Bool?
    public var learningSteps: [StepUnit]?
    public var relearningSteps: [StepUnit]?
    
    public init(
        requestRetention: Double? = nil,
        maximumInterval: Int? = nil,
        w: [Double]? = nil,
        enableFuzz: Bool? = nil,
        enableShortTerm: Bool? = nil,
        learningSteps: [StepUnit]? = nil,
        relearningSteps: [StepUnit]? = nil
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

/// FSRS Parameters Generator
public struct FSRSParametersGenerator {
    private static let generator: ParameterGenerator = DefaultParameterGenerator()
    
    /// Generate FSRS parameters from partial parameters
    /// - Parameter props: Partial parameters
    /// - Returns: Complete FSRS parameters
    public static func generate(from props: PartialFSRSParameters) -> FSRSParameters {
        generator.generate(from: props)
    }
    
    private static let validator: ParameterValidator = DefaultParameterValidator()
    private static let migrator: ParameterMigrator = DefaultParameterMigrator()
    
    /// Check if parameters are valid
    /// - Parameter parameters: Parameters array to check
    /// - Returns: Validated parameters array
    /// - Throws: Error if parameters are invalid
    public static func checkParameters(_ parameters: [Double]) throws -> [Double] {
        try validator.validate(parameters)
    }
    
    /// Migrate parameters from older FSRS versions (17/19 elements) to FSRS-6 (21 elements)
    /// - Parameters:
    ///   - parameters: Parameters array (17, 19, or 21 elements)
    ///   - numRelearningSteps: Number of relearning steps
    ///   - enableShortTerm: Whether short-term scheduling is enabled
    /// - Returns: Migrated parameters array (21 elements)
    public static func migrateParameters(
        parameters: [Double]?,
        numRelearningSteps: Int = 0,
        enableShortTerm: Bool = defaultEnableShortTerm
    ) -> [Double] {
        migrator.migrate(
            parameters: parameters,
            numRelearningSteps: numRelearningSteps,
            enableShortTerm: enableShortTerm
        )
    }
    
    /// Clip parameters to valid bounds
    /// - Parameters:
    ///   - parameters: Parameters array to clip
    ///   - numRelearningSteps: Number of relearning steps
    ///   - enableShortTerm: Whether short-term scheduling is enabled
    /// - Returns: Clipped parameters array
    public static func clipParameters(
        parameters: [Double],
        numRelearningSteps: Int,
        enableShortTerm: Bool = defaultEnableShortTerm
    ) -> [Double] {
        var w17W18Ceiling = W17_W18_Ceiling
        
        if max(0, numRelearningSteps) > 1 {
            let value = -(
                log(parameters[11]) +
                log(pow(2.0, parameters[13]) - 1.0) +
                parameters[14] * 0.3
            ) / Double(numRelearningSteps)
            
            w17W18Ceiling = clamp(value, min: 0.01, max: 2.0)
        }
        
        let bounds = clampParameters(
            w17W18Ceiling: w17W18Ceiling,
            enableShortTerm: enableShortTerm
        )
        
        return validator.clip(parameters, bounds: bounds)
    }
}

// FSRSError is now defined in FSRSErrors.swift
