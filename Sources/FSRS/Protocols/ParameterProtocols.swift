import Foundation

/// Protocol for parameter validation
public protocol ParameterValidator {
    /// Check if parameters are valid
    /// - Parameter parameters: Parameters array to check
    /// - Returns: Validated parameters array
    /// - Throws: FSRSError if parameters are invalid
    func validate(_ parameters: [Double]) throws -> [Double]

    /// Clip parameters to valid bounds
    /// - Parameters:
    ///   - parameters: Parameters array to clip
    ///   - bounds: Array of (min, max) tuples for each parameter
    /// - Returns: Clipped parameters array
    func clip(_ parameters: [Double], bounds: [(Double, Double)]) -> [Double]
}

/// Protocol for parameter generation
public protocol ParameterGenerator {
    /// Generate complete parameters from partial parameters
    /// - Parameter partial: Partial parameters with optional values
    /// - Returns: Complete FSRS parameters with all defaults filled in
    func generate(from partial: PartialFSRSParameters) -> FSRSParameters
}

/// Protocol for parameter migration
public protocol ParameterMigrator {
    /// Migrate parameters from older FSRS versions to current version
    /// - Parameters:
    ///   - parameters: Parameters array (17, 19, or 21 elements)
    ///   - numRelearningSteps: Number of relearning steps
    ///   - enableShortTerm: Whether short-term scheduling is enabled
    /// - Returns: Migrated parameters array (21 elements)
    func migrate(
        parameters: [Double]?,
        numRelearningSteps: Int,
        enableShortTerm: Bool
    ) -> [Double]
}

public struct DefaultParameterValidator: ParameterValidator {
    public init() {}

    public func validate(_ parameters: [Double]) throws -> [Double] {
        let invalid = parameters.first { !$0.isFinite || $0.isNaN }
        if let invalidValue = invalid {
            throw FSRSError.invalidParameter("Non-finite or NaN value in parameters: \(invalidValue)")
        }

        if ![17, 19, 21].contains(parameters.count) {
            throw FSRSError.invalidParameter("Invalid parameter length: \(parameters.count). Must be 17, 19 or 21 for FSRSv4, 5 and 6 respectively.")
        }

        return parameters
    }

    public func clip(_ parameters: [Double], bounds: [(Double, Double)]) -> [Double] {
        var result: [Double] = []
        for (index, param) in parameters.enumerated() {
            if index < bounds.count {
                let (min, max) = bounds[index]
                result.append(clamp(param, min: min, max: max))
            } else {
                result.append(param)
            }
        }
        return result
    }
}

public struct DefaultParameterMigrator: ParameterMigrator {
    private let validator: ParameterValidator

    public init(validator: ParameterValidator = DefaultParameterValidator()) {
        self.validator = validator
    }

    public func migrate(
        parameters: [Double]?,
        numRelearningSteps: Int = 0,
        enableShortTerm: Bool = defaultEnableShortTerm
    ) -> [Double] {
        guard let params = parameters else {
            return Array(defaultW)
        }

        switch params.count {
        case 21:
            return clipParameters(
                parameters: Array(params),
                numRelearningSteps: numRelearningSteps,
                enableShortTerm: enableShortTerm,
                validator: validator
            )

        case 19:
            print("[FSRS-6] auto fill weights from 19 to 21 length")
            var clipped = clipParameters(
                parameters: Array(params),
                numRelearningSteps: numRelearningSteps,
                enableShortTerm: enableShortTerm,
                validator: validator
            )
            clipped.append(0.0)
            clipped.append(FSRS5_DEFAULT_DECAY)
            return clipped

        case 17:
            var weights = clipParameters(
                parameters: Array(params),
                numRelearningSteps: numRelearningSteps,
                enableShortTerm: enableShortTerm,
                validator: validator
            )
            weights[4] = roundToFixed(weights[5] * 2.0 + weights[4])
            weights[5] = roundToFixed(log(weights[5] * 3.0 + 1.0) / 3.0)
            weights[6] = roundToFixed(weights[6] + 0.5)
            print("[FSRS-6] auto fill weights from 17 to 21 length")
            weights.append(0.0)
            weights.append(0.0)
            weights.append(0.0)
            weights.append(FSRS5_DEFAULT_DECAY)
            return weights

        default:
            print("[FSRS] Invalid parameters length, using default parameters")
            return Array(defaultW)
        }
    }

    private func clipParameters(
        parameters: [Double],
        numRelearningSteps: Int,
        enableShortTerm: Bool,
        validator: ParameterValidator
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

/// Default parameter generator implementation
public struct DefaultParameterGenerator: ParameterGenerator {
    private let migrator: ParameterMigrator

    public init(migrator: ParameterMigrator = DefaultParameterMigrator()) {
        self.migrator = migrator
    }

    public func generate(from props: PartialFSRSParameters) -> FSRSParameters {
        let learningSteps = props.learningSteps ?? defaultLearningSteps
        let relearningSteps = props.relearningSteps ?? defaultRelearningSteps
        let enableShortTerm = props.enableShortTerm ?? defaultEnableShortTerm

        let weights = migrator.migrate(
            parameters: props.weights,
            numRelearningSteps: relearningSteps.count,
            enableShortTerm: enableShortTerm
        )

        return FSRSParameters(
            requestRetention: props.requestRetention ?? defaultRequestRetention,
            maximumInterval: props.maximumInterval ?? defaultMaximumInterval,
            weights: weights,
            enableFuzz: props.enableFuzz ?? defaultEnableFuzz,
            enableShortTerm: enableShortTerm,
            learningSteps: learningSteps,
            relearningSteps: relearningSteps
        )
    }
}
