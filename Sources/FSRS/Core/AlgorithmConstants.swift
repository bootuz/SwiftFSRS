import Foundation

// MARK: - Retrievability and Decay Constants

/// Target retrievability used in forgetting curve calculations (90%)
public let RETRIEVABILITY_TARGET: Double = 0.9

/// Divisor used in the forgetting curve formula
/// R(t,S) = (1 + FACTOR × t/(RETRIEVABILITY_CURVE_DIVISOR·S))^DECAY
public let RETRIEVABILITY_CURVE_DIVISOR: Double = 9.0

// MARK: - Difficulty Constants

/// Minimum difficulty value
public let DIFFICULTY_RANGE_MIN: Double = 1.0

/// Maximum difficulty value
public let DIFFICULTY_RANGE_MAX: Double = 10.0

/// Span of difficulty range (10 - 1 = 9)
public let DIFFICULTY_RANGE_SPAN: Double = 9.0

/// Center point used in stability calculations (11 - difficulty)
public let DIFFICULTY_CENTER_POINT: Double = 11.0

// MARK: - Grade Constants

/// Neutral grade value (Good rating = 3)
public let GRADE_NEUTRAL_VALUE: Double = 3.0

// MARK: - Time Conversion Constants

/// Number of minutes in one day
public let MINUTES_PER_DAY: Int = 1440

/// Number of minutes in one hour
public let MINUTES_PER_HOUR: Int = 60

/// Number of seconds in one day
public let SECONDS_PER_DAY: Double = 86400.0

// MARK: - Fuzzing Constants

/// Minimum interval (in days) to apply fuzzing
public let FUZZ_MINIMUM_INTERVAL: Double = 2.5

/// Threshold to determine if interval is considered short-term
public let SHORT_TERM_THRESHOLD_MINUTES: Int = MINUTES_PER_DAY

