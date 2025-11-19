/// Card state enumeration matching FSRS state machine
public enum State: Int, Codable, CaseIterable, Sendable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// Rating enumeration for card reviews
public enum Rating: Int, Codable, CaseIterable, Sendable {
    case manual = 0
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var description: String {
        switch self {
        case .manual:
            return "Manual"
        case .again:
            return "Again"
        case .hard:
            return "Hard"
        case .good:
            return "Good"
        case .easy:
            return "Easy"
        }
    }
}

/// Grade type excludes Manual rating
public typealias Grade = Rating

/// Time unit for calculations
public enum TimeUnit: String, Codable, Sendable {
    case minutes = "m"
    case hours = "h"
    case days = "d"
}

/// Step unit format: e.g., "1m", "10m", "5h"
public struct StepUnit: Codable, Hashable, Sendable, CustomStringConvertible {
    public let value: Int
    public let unit: TimeUnit

    public init(value: Int, unit: TimeUnit) {
        self.value = value
        self.unit = unit
    }

    /// Convert step unit to minutes
    public var scheduledMinutes: Int {
        switch unit {
        case .minutes:
            return value
        case .hours:
            return value * 60
        case .days:
            return value * 24 * 60
        }
    }

    /// Initialize from string format like "1m", "10m", "5h"
    public init?(from string: String) {
        guard !string.isEmpty else { return nil }

        guard let unitChar = string.last else { return nil }
        guard let unit = TimeUnit(rawValue: String(unitChar)) else { return nil }

        let valueString = String(string.dropLast())
        guard let value = Int(valueString) else { return nil }

        self.value = value
        self.unit = unit
    }

    /// Convert to string format
    public var description: String {
        "\(value)\(unit.rawValue)"
    }
}

extension StepUnit: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        // Note: ExpressibleByStringLiteral can't throw, so we create invalid value
        // Users should use StepUnit(from:) for proper error handling
        if let stepUnit = StepUnit(from: value) {
            self = stepUnit
        } else {
            // Create a default invalid value - this is a limitation of ExpressibleByStringLiteral
            self = StepUnit(value: 0, unit: .minutes)
        }
    }
}

/// All valid grades (excluding Manual)
public let Grades: [Grade] = [.again, .hard, .good, .easy]
