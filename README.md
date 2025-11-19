# Swift FSRS

[![Swift](https://github.com/bootuz/SwiftFSRS/actions/workflows/swift.yml/badge.svg)](https://github.com/bootuz/SwiftFSRS/actions/workflows/swift.yml)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey.svg)
[![License](https://img.shields.io/github/license/bootuz/SwiftFSRS.svg)](https://github.com/bootuz/SwiftFSRS/blob/main/LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://swift.org/package-manager/)

A Swift implementation of the Free Spaced Repetition Scheduler (FSRS-6) algorithm.

## Overview

Swift FSRS is a native Swift package that implements the FSRS-6 spaced repetition scheduler algorithm for flashcard applications. It provides a clean, type-safe API following Swift best practices.

## Features

- ✅ Complete FSRS-6 algorithm implementation
- ✅ Protocol-oriented design - works with your own card types
- ✅ Concurrency support
- ✅ Card scheduling with learning steps support (BasicScheduler)
- ✅ Long-term scheduling without learning steps (LongTermScheduler)
- ✅ Reschedule functionality for replaying review history
- ✅ Rollback capability to undo reviews
- ✅ Forget functionality to reset cards
- ✅ Retrievability calculation (formatted and numeric)
- ✅ Customizable strategies (seed, learning steps)
- ✅ Parameter migration support (FSRS-4/5/6 compatibility)
- ✅ Logging support with FSRSLogger protocol

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

### Implementing FSRSCard Protocol

First, create a card type that conforms to the `FSRSCard` protocol:

```swift
import FSRS

struct Flashcard: FSRSCard {
    // Your custom properties
    let id: UUID
    var question: String
    var answer: String
    
    // FSRS required properties
    var due: Date
    var state: State
    var lastReview: Date?
    var stability: Double
    var difficulty: Double
    var scheduledDays: Int
    var learningSteps: Int
    var reps: Int
    var lapses: Int
    
    init(question: String, answer: String) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        
        // Initialize FSRS properties for new card
        self.due = Date()
        self.state = .new
        self.lastReview = nil
        self.stability = 0
        self.difficulty = 0
        self.scheduledDays = 0
        self.learningSteps = 0
        self.reps = 0
        self.lapses = 0
    }
}
```

### Basic Example

```swift
import FSRS

// Create FSRS instance with default parameters (specify your card type)
let f = fsrs<Flashcard>()

// Create a new card
let card = Flashcard(question: "What is the capital of France?", answer: "Paris")
let now = Date()

// Preview all rating scenarios
let recordLog = try f.repeat(card: card, now: now)

// Get card for a specific rating
let goodCard = recordLog[.good]!.card
let goodLog = recordLog[.good]!.log

// Review with a specific grade
let result = try f.next(card: card, now: now, grade: .good)
let nextCard = result.card

// Get retrievability as formatted string
let retrievability = f.getRetrievability(card: card, now: now)
print(retrievability) // "90.00%"

// Get retrievability as numeric value
let retrievabilityValue = f.getRetrievabilityValue(card: card, now: now)
print(retrievabilityValue) // 0.9
```

### Custom Parameters

```swift
let params = PartialFSRSParameters(
    requestRetention: 0.9,
    maximumInterval: 36500,
    enableFuzz: true,
    enableShortTerm: true
)
let f = fsrs<Flashcard>(params: params)
```

### Reschedule with History

Replay a card's review history to recalculate its state:

```swift
let now = Date()
let reviews: [FSRSHistory] = [
    FSRSHistory(rating: .good, review: now),
    FSRSHistory(rating: .good, review: now.addingTimeInterval(86400)),
    FSRSHistory(rating: .again, review: now.addingTimeInterval(172800))
]

let options = RescheduleOptions<Flashcard>(
    updateMemoryState: true,
    now: Date()
)

let result = try f.reschedule(
    currentCard: card,
    reviews: reviews,
    options: options
)

print(result.collections.count) // Number of replayed reviews
if let rescheduleItem = result.rescheduleItem {
    let updatedCard = rescheduleItem.card
}
```

### Rollback

Undo a review and restore the card to its previous state:

```swift
// After reviewing a card, you get a RecordLogItem
let result = try f.next(card: card, now: Date(), grade: .good)
let currentCard = result.card
let reviewLog = result.log

// Rollback to previous state
let previousCard = try f.rollback(card: currentCard, log: reviewLog)
```

### Forget Card

Reset a card back to the new state:

```swift
let forgottenResult = f.forget(card: card, now: Date(), resetCount: false)
let newCard = forgottenResult.card
// Card is now in .new state with reset stability and difficulty
```

## Architecture

The package is organized into the following modules:

### Core Components
- **Models**: Core data structures (ReviewLog, Parameters, Enums, ValueObjects)
- **Protocols**: Protocol definitions (FSRSCard, AlgorithmProtocols, SchedulerProtocol)
- **Core**: Main algorithm (FSRSAlgorithm, FSRS, Factory) and parameter management
- **Schedulers**: Scheduling logic (BasicScheduler, LongTermScheduler, BaseScheduler)
- **Calculators**: Separate calculators for stability, difficulty, and intervals

### Features
- **Strategies**: Extensible strategy system (seed, learning steps)
- **Features**: Advanced features (Reschedule, RetrievabilityService, CardStateService)
- **Utilities**: Helper functions (DateHelpers, MathHelpers, Alea PRNG, FSRSLogger)

### Design Patterns
- **Protocol-Oriented**: Use `FSRSCard` protocol to work with your own card types
- **Generic Types**: FSRS is generic over any card type conforming to FSRSCard
- **Value Objects**: Type-safe wrappers for domain values (Stability, Difficulty, etc.)
- **Service Layer**: Separate services for retrievability, card state, and rescheduling


## Swift Version

Requires Swift 5.9+

## Testing

- **State Transition Tests**: Verify correct state machine behavior for all card states
- **Parameter Tests**: Test parameter validation, migration, and clipping
- **Integration Tests**: End-to-end testing of complete workflows
- **API Tests**: Verify all public API methods work correctly

How to run tests:

```bash
swift test
```

Run specific test suites:

```bash
swift test --filter StateTransitionTests
swift test --filter IntegrationTests
```

## Status

This is a complete, production-ready implementation of FSRS-6 for Swift. All core functionality has been implemented and tested:

- ✅ Complete FSRS-6 algorithm with all formulas
- ✅ Short-term and long-term scheduling modes
- ✅ Protocol-based generic design for flexibility
- ✅ Comprehensive test suite with 125+ tests

## Contributing

Contributions are welcome! Please ensure:
- All changes are made through forked repository
- Code follows Swift style guidelines
- Tests are added for new features
- All tests pass: `swift test`
- Documentation is updated
