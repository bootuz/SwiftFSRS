import Foundation

/// Time unit for date calculations
public enum CalculationTimeUnit {
    case days
    case minutes
}

/// Calculate date offset by adding time
/// - Parameters:
///   - now: Current date
///   - offset: Time offset value
///   - isDay: If true, offset is in days; if false, offset is in minutes
/// - Returns: New date with offset applied
public func dateScheduler(now: Date, offset: Double, isDay: Bool) -> Date {
    let interval: TimeInterval
    if isDay {
        interval = offset * 24 * 60 * 60 // days to seconds
    } else {
        interval = offset * 60 // minutes to seconds
    }
    return now.addingTimeInterval(interval)
}

/// Calculate difference between two dates
/// - Parameters:
///   - now: Current date
///   - previous: Previous date
///   - unit: Unit of measurement (days or minutes)
/// - Returns: Difference in specified unit
public func dateDiff(now: Date, previous: Date, unit: CalculationTimeUnit) -> Double {
    let diff = now.timeIntervalSince(previous)
    
    switch unit {
    case .days:
        return floor(diff / (24 * 60 * 60))
    case .minutes:
        return floor(diff / 60)
    }
}

/// Format date as string
/// - Parameter date: Date to format
/// - Returns: Formatted date string (yyyy-MM-dd HH:mm:ss)
public func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: date)
}

/// Calculate difference in days using UTC (discarding time and timezone)
/// - Parameters:
///   - last: Previous date
///   - current: Current date
/// - Returns: Number of days difference
public func dateDiffInDays(last: Date, current: Date) -> Int {
    let calendar = Calendar(identifier: .gregorian)
    let components = calendar.dateComponents([.day], from: last, to: current)
    return components.day ?? 0
}

/// Show difference message between two dates
/// - Parameters:
///   - due: Due date
///   - lastReview: Last review date
///   - unit: Whether to include unit in output
///   - timeUnit: Custom time unit labels
/// - Returns: Formatted difference string
public func showDiffMessage(
    due: Date,
    lastReview: Date,
    unit: Bool = false,
    timeUnit: [String] = ["second", "min", "hour", "day", "month", "year"]
) -> String {
    var diff = due.timeIntervalSince(lastReview)
    let timeUnits: [TimeInterval] = [60, 60, 24, 31, 12]
    
    var i = 0
    diff /= 1000 // Convert to seconds
    
    while i < timeUnits.count && diff >= timeUnits[i] {
        diff /= timeUnits[i]
        i += 1
    }
    
    let value = Int(floor(diff))
    if unit && i < timeUnit.count {
        return "\(value)\(timeUnit[i])"
    } else {
        return "\(value)"
    }
}

