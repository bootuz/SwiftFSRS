# FSRS Test Suite

This directory contains comprehensive test cases for the SwiftFSRS library using Swift Testing framework.

## Test Files

### 1. FSRSAPITests.swift
Tests for the main FSRS API, covering core functionality:

- **Card Creation**: Tests for creating new cards with default values
- **Repeat (Preview)**: Tests for previewing all rating scenarios
  - Validates all 4 ratings (Again, Hard, Good, Easy)
  - Checks stability, difficulty, and state calculations
  - Verifies custom properties preservation
- **Next (Single Rating)**: Tests for specific rating actions
  - State transitions for each rating
  - Error handling for invalid ratings
- **Retrievability**: Tests for memory retention calculations
  - Formatted percentage output
  - Numeric value ranges
  - Time-based degradation
- **Rollback**: Tests for undoing reviews
  - State restoration
  - Lapses tracking
- **Forget**: Tests for resetting cards
  - Full reset vs. partial reset
  - Manual rating logs
- **Forgetting Curve**: Tests for mathematical forgetting curve
- **Parameters**: Tests for custom parameters and configuration
- **Reschedule**: Tests for rescheduling based on history
- **Edge Cases**: Tests for unusual scenarios
  - Future/past due dates
  - Very high stability/difficulty
  - Many lapses
- **Schedulers**: Tests for short-term vs. long-term scheduling
- **Review Logs**: Tests for review history tracking

**Test Count**: 47 tests

### 2. ParameterTests.swift
Tests for FSRS parameter management and validation:

- **Parameter Generation**: Tests for creating parameters from partial configs
  - Default parameters
  - Custom retention rates
  - Custom intervals
  - Custom weights
  - Fuzzing settings
  - Short-term settings
- **StepUnit**: Tests for learning step time units
  - Parsing "1m", "10m", "5h", "1d" formats
  - Conversion to minutes
  - String literals
  - Invalid format handling
- **Parameter Validation**: Tests for parameter bounds checking
  - Retention rate limits (0 < x ≤ 1)
  - Positive intervals
  - Weight array length (21 elements for FSRS-6)
- **Parameter Migration**: Tests for upgrading old parameter formats
- **Codable**: Tests for JSON encoding/decoding
- **Learning Steps**: Tests for custom learning/relearning steps
  - Multiple steps with different time units
  - Order preservation
  - Empty steps
- **Fuzzing**: Tests for interval randomization settings
- **Parameter Updates**: Tests for runtime parameter changes
- **Boundary Tests**: Tests for extreme parameter values

**Test Count**: 34 tests

### 3. StateTransitionTests.swift
Tests for FSRS state machine and state transitions:

- **New State Transitions**: Tests for new cards
  - New → Learning (Again, Hard, Good)
  - New → Review (Easy)
- **Learning State Transitions**: Tests for learning phase
  - Learning → Learning (Again)
  - Learning progress (Good)
  - Learning → Review (Easy)
- **Review State Transitions**: Tests for review phase
  - Review → Relearning (Again)
  - Review → Review (Hard, Good, Easy)
- **Relearning State Transitions**: Tests for relearning phase
  - Relearning restart (Again)
  - Relearning progress (Good)
  - Relearning → Review (Easy)
- **Lapses Tracking**: Tests for failure counting
  - Increment on review failures
  - No increment on learning failures
  - Persistence through successful reviews
- **Stability Progression**: Tests for memory stability
  - Increases on success
  - Decreases on failure
  - Rating-based differences
- **Difficulty Progression**: Tests for card difficulty
  - Increases on Again
  - Decreases on Easy
  - Bounds enforcement (1-10)
- **Scheduled Days**: Tests for interval calculations
- **Complete Lifecycles**: Tests for full card journeys
  - New → Learning → Review
  - Review → Relearning → Review
  - Multiple failures

**Test Count**: 30 tests

### 4. IntegrationTests.swift
Integration tests for real-world usage scenarios:

- **Real-world Scenarios**:
  - Consistent study schedule over multiple days
  - Struggling with difficult cards
  - Mastering easy cards quickly
  - Forgetting and relearning cycles
  - Long-term retention (1 year simulation)
  - Cramming vs. spaced repetition comparison
- **Batch Operations**:
  - Reviewing multiple cards in one session
  - Previewing cards before review
- **Undo/Redo Scenarios**:
  - Single undo with rollback
  - Multiple undo operations
- **Data Migration/Import**:
  - Importing cards from other systems
  - Resetting cards completely
- **Edge Cases**:
  - Future due dates
  - Very old due dates
  - Concurrent reviews (different paths)
- **Retrievability Monitoring**:
  - Tracking over time
  - Optimal review timing
- **Custom Properties**:
  - Preservation through full lifecycle
- **Stress Tests**:
  - Large number of reviews (100+)
  - Rapid successive reviews

**Test Count**: 16 tests

## Running Tests

### Run all tests:
```bash
swift test
```

### Run specific test suite:
```bash
swift test --filter FSRSAPITests
swift test --filter ParameterTests
swift test --filter StateTransitionTests
swift test --filter IntegrationTests
```

### Run specific test:
```bash
swift test --filter testRepeat
```

## Test Statistics

- **Total Tests**: 127 tests
- **Test Suites**: 4 suites
- **Coverage**: All major API methods and edge cases
- **Framework**: Swift Testing (Testing.framework)

## Test Helpers

### TestCard (Mocks/TestCard.swift)
A sample implementation of `FSRSCard` protocol used throughout tests:
- Contains question/answer fields
- Includes tags and notes
- Implements all FSRS-required properties

## Test Principles

1. **Deterministic**: Tests use fixed parameters (fuzzing disabled) for reproducibility
2. **Isolated**: Each test is independent and doesn't rely on others
3. **Comprehensive**: Covers happy paths, edge cases, and error conditions
4. **Real-world**: Integration tests simulate actual usage patterns
5. **Documented**: Each test has descriptive names and comments

## Continuous Integration

These tests are designed to run in CI environments:
- Fast execution (< 1 second for full suite)
- No external dependencies
- No network or file I/O
- Deterministic results

## Contributing

When adding new features to SwiftFSRS:
1. Add corresponding tests to the appropriate test file
2. Ensure all existing tests still pass
3. Follow the naming convention: descriptive test names
4. Add comments for complex test scenarios
5. Use helper functions to reduce duplication

## Test Coverage Areas

✅ Card creation and initialization  
✅ All rating scenarios (Again, Hard, Good, Easy)  
✅ State transitions (New, Learning, Review, Relearning)  
✅ Stability and difficulty calculations  
✅ Retrievability and forgetting curve  
✅ Rollback and undo functionality  
✅ Forget/reset functionality  
✅ Parameter management and validation  
✅ Learning steps configuration  
✅ Short-term vs. long-term scheduling  
✅ Review logs and metadata  
✅ Reschedule with history  
✅ Edge cases and boundary conditions  
✅ Real-world usage scenarios  
✅ Long-term retention simulation  
✅ Custom card properties preservation  

## Notes

- Tests use the `@testable import FSRS` directive to access internal APIs
- The `TestCard` struct is a reference implementation showing how to implement `FSRSCard`
- Some tests check for approximate values due to floating-point arithmetic
- Tests are designed to be maintainable and easy to understand

