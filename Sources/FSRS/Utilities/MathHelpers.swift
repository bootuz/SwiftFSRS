import Foundation

/// Clamp value between min and max
/// - Parameters:
///   - value: Value to clamp
///   - min: Minimum value
///   - max: Maximum value
/// - Returns: Clamped value
@inlinable
public func clamp(_ value: Double, min: Double, max: Double) -> Double {
    return Swift.min(Swift.max(value, min), max)
}

/// Fuzz range configuration
private struct FuzzRange {
    let start: Double
    let end: Double
    let factor: Double
}

private let fuzzRanges: [FuzzRange] = [
    FuzzRange(start: 2.5, end: 7.0, factor: 0.15),
    FuzzRange(start: 7.0, end: 20.0, factor: 0.1),
    FuzzRange(start: 20.0, end: Double.infinity, factor: 0.05)
]

/// Get fuzz range for interval
/// - Parameters:
///   - interval: Base interval
///   - elapsedDays: Days elapsed since last review
///   - maximumInterval: Maximum allowed interval
/// - Returns: Tuple of (min_ivl, max_ivl)
public func getFuzzRange(
    interval: Double,
    elapsedDays: Double,
    maximumInterval: Int
) -> (min: Int, max: Int) {
    var delta = 1.0
    let maxIntervalDouble = Double(maximumInterval)
    
    for range in fuzzRanges {
        let rangeEnd = Swift.min(interval, range.end)
        let rangeStart = Swift.max(range.start, 0.0)
        delta += range.factor * Swift.max(rangeEnd - rangeStart, 0.0)
    }
    
    let clampedInterval = Swift.min(interval, maxIntervalDouble)
    var minIvl = Swift.max(2, Int(round(clampedInterval - delta)))
    let maxIvl = Swift.min(Int(round(clampedInterval + delta)), maximumInterval)
    
    if interval > elapsedDays {
        minIvl = Swift.max(minIvl, Int(elapsedDays) + 1)
    }
    
    minIvl = Swift.min(minIvl, maxIvl)
    
    return (min: minIvl, max: maxIvl)
}

/// Round to fixed decimal places (matching TypeScript's toFixed)
/// - Parameters:
///   - value: Value to round
///   - places: Number of decimal places
/// - Returns: Rounded value
public func roundToFixed(_ value: Double, places: Int = 8) -> Double {
    let multiplier = pow(10.0, Double(places))
    return round(value * multiplier) / multiplier
}

