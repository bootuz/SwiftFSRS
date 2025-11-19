import Foundation

// https://github.com/davidbau/seedrandom/blob/released/lib/alea.js
// A port of an algorithm by Johannes Baagøe <baagoe@baagoe.com>, 2010
// http://baagoe.com/en/RandomMusings/javascript/
// https://github.com/nquinlan/better-random-numbers-for-javascript-mirror
// Original work is under MIT license

/// Alea PRNG state
public struct AleaState {
    var c: UInt32
    var s0: Double
    var s1: Double
    var s2: Double
}

/// Type-safe seed value for Alea PRNG
public enum AleaSeed: Sendable {
    case string(String)
    case double(Double)
    case int(Int)

    fileprivate var hashableValue: String {
        switch self {
        case .string(let s):
            return s
        case .double(let d):
            return String(describing: d)
        case .int(let i):
            return String(describing: i)
        }
    }
}

/// Alea PRNG implementation
private final class Alea: @unchecked Sendable {
    private var c: UInt32 = 1
    private var s0: Double = 0
    private var s1: Double = 0
    private var s2: Double = 0

    init(seed: AleaSeed? = nil) {
        let mash = Mash()
        self.c = 1
        self.s0 = mash(" ")
        self.s1 = mash(" ")
        self.s2 = mash(" ")

        let seedValue = seed?.hashableValue ?? String(Date().timeIntervalSince1970)
        self.s0 -= mash(seedValue)
        if self.s0 < 0 { self.s0 += 1 }
        self.s1 -= mash(seedValue)
        if self.s1 < 0 { self.s1 += 1 }
        self.s2 -= mash(seedValue)
        if self.s2 < 0 { self.s2 += 1 }
    }

    func next() -> Double {
        let t = 2_091_639.0 * s0 + Double(c) * 2.3283064365386963e-10  // 2^-32
        s0 = s1
        s1 = s2
        c = UInt32(t)
        s2 = t - Double(c)
        return s2
    }

    var state: AleaState {
        get {
            AleaState(c: c, s0: s0, s1: s1, s2: s2)
        }
        set {
            c = newValue.c
            s0 = newValue.s0
            s1 = newValue.s1
            s2 = newValue.s2
        }
    }
}

/// Mash function for seed hashing
private func Mash() -> (String) -> Double {
    var n: UInt32 = 0xefc8_249d

    return { dataString in
        for char in dataString.utf8 {
            n = n &+ UInt32(char)
            var h = 0.02519603282416938 * Double(n)
            n = UInt32(h)
            h -= Double(n)
            h *= Double(n)
            n = UInt32(h)
            h -= Double(n)
            n = n &+ UInt32(h * 0x1_0000_0000)  // 2^32
        }
        return Double(n) * 2.3283064365386963e-10  // 2^-32
    }
}

/// Alea PRNG function factory
/// - Parameter seed: Optional seed. Defaults to current timestamp.
/// - Returns: PRNG function
public func alea(seed: AleaSeed? = nil) -> () -> Double {
    let xg = Alea(seed: seed)

    func prng() -> Double {
        xg.next()
    }

    // Note: In Swift, we can't attach properties to functions like in JavaScript
    // Instead, we return a struct that contains the function and additional methods
    return prng
}

/// Alea PRNG with additional methods
public struct AleaPRNG: Sendable {
    private let alea: Alea

    public init(seed: AleaSeed? = nil) {
        self.alea = Alea(seed: seed)
    }

    /// Convenience initializer with String seed
    public init(seed: String) {
        self.alea = Alea(seed: .string(seed))
    }

    /// Generate next random number [0, 1)
    public mutating func next() -> Double {
        alea.next()
    }

    /// Generate random 32-bit integer
    public mutating func int32() -> Int32 {
        Int32(alea.next() * 0x1_0000_0000)
    }

    /// Generate random double precision number
    public mutating func double() -> Double {
        let prng1 = alea.next()
        let prng2 = alea.next()
        return prng1 + (Double(Int32(prng2 * 0x200000)) * 1.1102230246251565e-16)  // 2^-53
    }

    /// Get current state
    public var state: AleaState {
        alea.state
    }

    /// Import state
    public mutating func importState(_ state: AleaState) {
        alea.state = state
    }
}
