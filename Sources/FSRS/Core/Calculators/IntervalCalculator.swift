import Foundation

/// Calculator for scheduled intervals with optional fuzzing
public struct IntervalCalculator {
    private let parameters: FSRSParameters
    private let randomProvider: RandomProvider?
    private let timeProvider: TimeProvider
    private let logger: (any FSRSLogger)?

    public init(
        parameters: FSRSParameters,
        randomProvider: RandomProvider? = nil,
        timeProvider: TimeProvider = SystemTimeProvider(),
        logger: (any FSRSLogger)? = nil
    ) {
        self.parameters = parameters
        self.randomProvider = randomProvider
        self.timeProvider = timeProvider
        self.logger = logger
    }

    // MARK: - Interval Calculation

    /// Calculate the scheduled interval for next review
    /// I = min(max(1, round(S × modifier)), maximumInterval)
    ///
    /// - Parameters:
    ///   - stability: Current stability
    ///   - elapsedDays: Days elapsed since last review
    ///   - intervalModifier: Modifier based on request retention
    /// - Returns: Scheduled interval in days
    public func calculateScheduledInterval(
        stability: Stability,
        elapsedDays: ElapsedDays,
        intervalModifier: Double
    ) -> Int {
        let baseInterval = max(1, Int(round(stability.value * intervalModifier)))
        let constrainedInterval = min(baseInterval, parameters.maximumInterval)

        logger?.debug("""
            Interval calc: \
            stability=\(stability.value), \
            modifier=\(intervalModifier) -> \
            base=\(baseInterval), \
            constrained=\(constrainedInterval)
            """)

        if parameters.enableFuzz && Double(constrainedInterval) >= FUZZ_MINIMUM_INTERVAL {
            let fuzzedInterval = applyFuzz(
                interval: Double(constrainedInterval),
                elapsedDays: elapsedDays
            )
            logger?.info("Fuzz applied: \(constrainedInterval) -> \(fuzzedInterval)")
            return fuzzedInterval
        } else {
            logger?.info("Fuzz skipped: interval=\(constrainedInterval), enableFuzz=\(parameters.enableFuzz)")
            return constrainedInterval
        }
    }

    // MARK: - Fuzzing

    /// Apply fuzzing to interval to add variability
    /// Prevents cards from clustering at exact intervals
    ///
    /// - Parameters:
    ///   - interval: Base interval in days
    ///   - elapsedDays: Days elapsed since last review
    /// - Returns: Fuzzed interval
    private func applyFuzz(
        interval: Double,
        elapsedDays: ElapsedDays
    ) -> Int {
        // Get random value [0, 1)
        let fuzzFactor: Double
        if let provider = randomProvider {
            var mutableProvider = provider
            fuzzFactor = mutableProvider.next()
        } else {
            // Fallback to system random
            fuzzFactor = Double.random(in: 0..<1)
        }

        let (minInterval, maxInterval) = getFuzzRange(
            interval: interval,
            elapsedDays: elapsedDays.value,
            maximumInterval: parameters.maximumInterval
        )

        let result = Int(floor(fuzzFactor * Double(maxInterval - minInterval + 1) + Double(minInterval)))

        logger?.info("""
            Fuzz details: \
            factor=\(fuzzFactor), \
            range=[\(minInterval), \(maxInterval)], \
            result=\(result)
            """)

        return result
    }
}
