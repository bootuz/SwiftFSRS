import Foundation

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
    FSRS<Card>(params: params, randomProvider: randomProvider, logger: logger)
}
