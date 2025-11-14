import Foundation

/// Create FSRS instance with parameters
/// - Parameters:
///   - params: Partial FSRS parameters
///   - timeProvider: Time provider (defaults to SystemTimeProvider)
///   - randomProvider: Random provider (optional, created when needed)
/// - Returns: Generic FSRS instance for your card type
///
/// Example:
/// ```swift
/// struct MyCard: FSRSCard { ... }
/// let scheduler = fsrs<MyCard>()
/// ```
///
struct ConsoleLogger: FSRSLogger {
    func log(message: FSRSLogMessage) {
        print(message.description)
    }
}

public func fsrs<Card: FSRSCard>(
    params: PartialFSRSParameters = PartialFSRSParameters(),
    randomProvider: RandomProvider? = nil,
    logger: (any FSRSLogger)? = nil
) -> FSRS<Card> {
    return FSRS<Card>(params: params, randomProvider: randomProvider, logger: logger)
}

