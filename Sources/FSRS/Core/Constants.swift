import Foundation

/// Default requested retention rate
public let defaultRequestRetention: Double = 0.9

/// Default maximum interval in days
public let defaultMaximumInterval: Int = 36_500

/// Default fuzzing enabled state
public let defaultEnableFuzz: Bool = false

/// Default short-term scheduling enabled state
public let defaultEnableShortTerm: Bool = true

/// Default learning steps: [1m, 10m]
public let defaultLearningSteps: [StepUnit] = [
    StepUnit(value: 1, unit: TimeUnit.minutes),
    StepUnit(value: 10, unit: TimeUnit.minutes),
]

/// Default relearning steps: [10m]
public let defaultRelearningSteps: [StepUnit] = [
    StepUnit(value: 10, unit: TimeUnit.minutes)
]

/// Minimum stability value
public let S_MIN: Double = 0.001

/// Maximum stability value
public let S_MAX: Double = 36_500.0

/// Maximum initial stability
public let INIT_S_MAX: Double = 100.0

/// FSRS-5 default decay factor
public let FSRS5_DEFAULT_DECAY: Double = 0.5

/// FSRS-6 default decay factor
public let FSRS6_DEFAULT_DECAY: Double = 0.1542

/// Default weight parameters for FSRS-6 (21 elements)
public let defaultW: [Double] = [
    0.212,      // w[0] - initial stability (Again)
    1.2931,     // w[1] - initial stability (Hard)
    2.3065,     // w[2] - initial stability (Good)
    8.2956,     // w[3] - initial stability (Easy)
    6.4133,     // w[4] - initial difficulty (Good)
    0.8334,     // w[5] - initial difficulty multiplier
    3.0194,     // w[6] - difficulty multiplier
    0.001,      // w[7] - difficulty multiplier (mean reversion)
    1.8722,     // w[8] - stability exponent
    0.1666,     // w[9] - stability negative power
    0.796,      // w[10] - stability exponent
    1.4835,     // w[11] - fail stability multiplier
    0.0614,     // w[12] - fail stability negative power
    0.2629,     // w[13] - fail stability power
    1.6483,     // w[14] - fail stability exponent
    0.6014,     // w[15] - stability multiplier for Hard
    1.8729,     // w[16] - stability multiplier for Easy
    0.5425,     // w[17] - short-term stability exponent
    0.0912,     // w[18] - short-term stability exponent
    0.0658,     // w[19] - short-term last-stability exponent
    FSRS6_DEFAULT_DECAY,  // w[20] - decay factor
]

/// W17_W18 ceiling value
public let W17_W18_Ceiling: Double = 2.0

/// Parameter clamp bounds for validation
/// Returns array of (min, max) tuples for each parameter index
public func clampParameters(
    w17W18Ceiling: Double = W17_W18_Ceiling,
    enableShortTerm: Bool = defaultEnableShortTerm
) -> [(Double, Double)] {
    [
        (S_MIN, INIT_S_MAX),  // initial stability (Again)
        (S_MIN, INIT_S_MAX),  // initial stability (Hard)
        (S_MIN, INIT_S_MAX),  // initial stability (Good)
        (S_MIN, INIT_S_MAX),  // initial stability (Easy)
        (1.0, 10.0),          // initial difficulty (Good)
        (0.001, 4.0),         // initial difficulty (multiplier)
        (0.001, 4.0),         // difficulty (multiplier)
        (0.001, 0.75),        // difficulty (multiplier)
        (0.0, 4.5),           // stability (exponent)
        (0.0, 0.8),            // stability (negative power)
        (0.001, 3.5),         // stability (exponent)
        (0.001, 5.0),         // fail stability (multiplier)
        (0.001, 0.25),        // fail stability (negative power)
        (0.001, 0.9),         // fail stability (power)
        (0.0, 4.0),           // fail stability (exponent)
        (0.0, 1.0),           // stability (multiplier for Hard)
        (1.0, 6.0),           // stability (multiplier for Easy)
        (0.0, w17W18Ceiling), // short-term stability (exponent)
        (0.0, w17W18Ceiling), // short-term stability (exponent)
        (enableShortTerm ? 0.01 : 0.0, 0.8), // short-term last-stability (exponent)
        (0.1, 0.8),            // decay
    ]
}
