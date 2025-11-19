import Foundation

/// Protocol for random number providers (enables dependency injection for testing)
public protocol RandomProvider: Sendable {
    mutating func next() -> Double
    mutating func int32() -> Int32
}

/// Alea-based random provider (default implementation)
public struct AleaRandomProvider: RandomProvider {
    private var alea: AleaPRNG
    
    public init(seed: String) {
        self.alea = AleaPRNG(seed: seed)
    }
    
    public mutating func next() -> Double {
        alea.next()
    }
    
    public mutating func int32() -> Int32 {
        alea.int32()
    }
}

/// Mock random provider with predefined values (for testing)
public struct MockRandomProvider: RandomProvider {
    private let values: [Double]
    private var index: Int = 0
    
    public init(values: [Double]) {
        self.values = values
    }
    
    public mutating func next() -> Double {
        let value = values[index % values.count]
        index += 1
        return value
    }
    
    public mutating func int32() -> Int32 {
        Int32(next() * Double(Int32.max))
    }
}
