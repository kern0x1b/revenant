import Foundation

public struct SeededGenerator: Swift.RandomNumberGenerator {
    private var state: (UInt64, UInt64, UInt64, UInt64)

    public init(seed: UInt64) {
        var z = seed &+ 0x9E3779B97F4A7C15
        func next() -> UInt64 {
            z = z &+ 0x9E3779B97F4A7C15
            var value = z
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
        state = (next(), next(), next(), next())
    }

    public mutating func next() -> UInt64 {
        let result = rotl(state.1 &* 5, 7) &* 9
        let t = state.1 << 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = rotl(state.3, 45)
        return result
    }

    @inline(__always)
    private func rotl(_ value: UInt64, _ count: UInt64) -> UInt64 {
        (value << count) | (value >> (64 - count))
    }

    public mutating func nextUniform() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    public mutating func nextInteger(below bound: Int) -> Int {
        precondition(bound > 0, "a range of \(bound) values holds no draw")
        let product = UInt64(bound) &* next()
        return Int(product >> 64)
    }

    public mutating func nextInteger(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + nextInteger(below: range.count)
    }

    public mutating func nextGaussian(mean: Double = 0, standardDeviation: Double = 1) -> Double {
        var u = 0.0, v = 0.0, squared = 2.0
        while squared >= 1 || squared == 0 {
            u = 2 * nextUniform() - 1
            v = 2 * nextUniform() - 1
            squared = u * u + v * v
        }
        let factor = (-2 * log(squared) / squared).squareRoot()
        return mean + standardDeviation * u * factor
    }

    public mutating func nextCategory(weights: [Double]) -> Int {
        precondition(!weights.isEmpty, "a categorical distribution needs a bucket")
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        var target = nextUniform() * total
        var index = 0
        while index < weights.count - 1, target >= weights[index] {
            target -= weights[index]
            index += 1
        }
        return index
    }

    public mutating func shuffle<T>(_ elements: inout [T]) {
        guard elements.count > 1 else { return }
        for index in stride(from: elements.count - 1, to: 0, by: -1) {
            elements.swapAt(index, nextInteger(below: index + 1))
        }
    }

    public mutating func bootstrap(population: Int, count: Int) -> [Int] {
        guard population > 0 else { return [] }
        return (0..<count).map { _ in nextInteger(below: population) }
    }
}

extension SeededGenerator {
    public static func timestampSeed() -> UInt64 {
        let now = Date().timeIntervalSince1970
        let micros = UInt64(max(0, now) * 1_000_000)
        return micros &* 0x9E3779B97F4A7C15 &+ UInt64(UInt32(bitPattern: getpid()))
    }
}
