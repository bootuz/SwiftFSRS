# Swift FSRS

A Swift implementation of the Free Spaced Repetition Scheduler (FSRS-6) algorithm.

## Overview

Swift FSRS is a native Swift package that implements the FSRS-6 spaced repetition scheduler algorithm for flashcard applications. It provides a clean, type-safe API following Swift best practices.

## Features

- ✅ Complete FSRS-6 algorithm implementation
- ✅ Card scheduling with learning steps support
- ✅ Reschedule functionality for replaying review history
- ✅ Rollback capability to undo reviews
- ✅ Forget functionality to reset cards
- ✅ Customizable strategies (seed, learning steps, scheduler)
- ✅ Parameter migration support (FSRS-4/5/6 compatibility)

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-fsrs.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File → Add Packages...
2. Enter the repository URL
3. Select version and add to your target

## Usage

### Basic Example

```swift
import FSRS

// Create FSRS instance with default parameters
let f = fsrs()

// Create an empty card
let card = createEmptyCard()
let now = Date()

// Preview all rating scenarios
let recordLog = f.repeat(card: CardInput(from: card), now: .date(now))

// Get card for a specific rating
let goodCard = recordLog[.good]!.card
let goodLog = recordLog[.good]!.log

// Review with a specific grade
let nextCard = f.next(card: CardInput(from: card), now: .date(now), grade: .good)

// Get retrievability
let retrievability = f.getRetrievability(card: CardInput(from: card), now: .date(now), format: true)
print(retrievability) // "90.00%"
```

### Custom Parameters

```swift
let params = PartialFSRSParameters(
    requestRetention: 0.9,
    maximumInterval: 36500,
    enableFuzz: true,
    enableShortTerm: true
)
let f = fsrs(params: params)
```

### Reschedule with History

```swift
let reviews: [FSRSHistory] = [
    FSRSHistory(rating: .good, review: .date(Date())),
    FSRSHistory(rating: .good, review: .date(Date().addingTimeInterval(86400))),
    FSRSHistory(rating: .again, review: .date(Date().addingTimeInterval(172800)))
]

let result = f.reschedule(
    currentCard: CardInput(from: card),
    reviews: reviews
)

print(result.collections.count) // Number of replayed reviews
```

### Rollback

```swift
let previousCard = f.rollback(
    card: CardInput(from: currentCard),
    log: ReviewLogInput(from: reviewLog)
)
```

## Architecture

The package is organized into the following modules:

- **Models**: Core data structures (Card, ReviewLog, Parameters, Enums)
- **Core**: Main algorithm (FSRSAlgorithm, FSRS) and parameter management
- **Schedulers**: Scheduling logic (BasicScheduler, LongTermScheduler)
- **Strategies**: Extensible strategy system (seed, learning steps)
- **Utilities**: Helper functions (TypeConverter, DateHelpers, MathHelpers, Alea PRNG)
- **Features**: Advanced features (Reschedule)

## Algorithm Precision

The implementation maintains numerical precision matching the TypeScript version. All calculations use `Double` precision with rounding to 8 decimal places (matching TypeScript's `.toFixed(8)`).

## Platform Support

- iOS 13+
- macOS 10.15+
- watchOS 6+
- tvOS 13+

## Swift Version

Requires Swift 5.9+

## License

MIT License - same as ts-fsrs

## Status

This is a complete port of ts-fsrs v5.2.3. All core functionality has been implemented. Unit tests and integration tests are pending (see TODO list).

## Contributing

Contributions are welcome! Please ensure:
- Code follows Swift style guidelines
- Tests are added for new features
- Numerical precision matches TypeScript implementation
- Documentation is updated

## Related Projects

- [ts-fsrs](https://github.com/open-spaced-repetition/ts-fsrs) - TypeScript implementation
- [fsrs-rs](https://github.com/open-spaced-repetition/fsrs-rs) - Rust implementation

