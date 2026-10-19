// Random.swift — the randomness an estimator needs, and the reproducibility that has to come with it.
//
// Every estimator here takes a seed, and every draw comes from the generator below. That is not a
// convenience: CreateML's documented promise is that a model trained twice from the same data with
// the same seed is the same model, and that is only true of a generator the port owns, since
// `arc4random` is not a documented sequence and has changed between releases.
//
import Foundation

// SplitMix64 as the seeder and xoshiro256** as the stream: both are defined by their constants
// rather than by a table, so the same seed gives the same stream on every release and every
// architecture — which is what makes a seed a seed instead of a suggestion.

/// A seed, and the stream it names.
public struct SeededGenerator: Swift.RandomNumberGenerator {
    private var state: (UInt64, UInt64, UInt64, UInt64)

    public init(seed: UInt64) {
        // SplitMix64, spelled out: the standard's own constants, so the state is a function of the
        // seed alone and nothing of the host's own generator leaks in.
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

    /// A uniform draw in `[0, 1)`, as 53 bits of the stream.
    ///
    /// 53 bits and not 64 because a `Double`'s significand is 53 bits wide: taking more of them
    /// would only shift the value left, and taking the top bits rather than a modulo is what keeps
    /// the range exactly `[0, 1)` — a modulo would bias the low end, which is where a seeded
    /// bootstrap sample lives.
    public mutating func nextUniform() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// A uniform integer in `0..<bound`, by Lemire's multiply-shift: one draw, no rejection loop,
    /// and the modulo bias is below 2^-53 for any bound a table can hold.
    public mutating func nextInteger(below bound: Int) -> Int {
        precondition(bound > 0, "a range of \(bound) values holds no draw")
        let product = UInt64(bound) &* next()
        return Int(product >> 64)
    }

    /// A uniform integer in `range`, closed at both ends.
    public mutating func nextInteger(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + nextInteger(below: range.count)
    }

    /// A standard normal draw by the polar Box-Muller method.
    ///
    /// The polar form and not the trigonometric one, because the trigonometric form draws two
    /// uniforms to return one normal and throws the sine away; the polar form rejects and re-draws
    /// once per pair on average and uses both. The `2` in the log is `-2·log(u)` with
    /// `u = 1 - v` and `v` uniform on the unit disc, so the radius is the square root of an
    /// exponential variable of rate 1 — the normal's own construction.
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

    /// A draw from a categorical distribution, by the cumulative-sum walk every fitted categorical
    /// is scored with — one pass, and the last bucket takes whatever the rounding left so that the
    /// distribution sums to one over the weights rather than to one minus an epsilon.
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

    /// A Fisher-Yates shuffle, descending, which is the one direction the standard's proof uses.
    public mutating func shuffle<T>(_ elements: inout [T]) {
        guard elements.count > 1 else { return }
        for index in stride(from: elements.count - 1, to: 0, by: -1) {
            elements.swapAt(index, nextInteger(below: index + 1))
        }
    }

    /// A sample of `count` indices out of `population`, with replacement, which is what a forest's
    /// bootstrap is and what a bagged split search needs.
    public mutating func bootstrap(population: Int, count: Int) -> [Int] {
        guard population > 0 else { return [] }
        return (0..<count).map { _ in nextInteger(below: population) }
    }
}

extension SeededGenerator {
    /// The seed CreateML derives for a caller who passed none, from the clock and the process.
    ///
    /// The name is `timestampSeed` for a reason: the value is the current time to the microsecond,
    /// which is what a caller who does not care about reproducibility wants — a different stream on
    /// every call, so two models trained from the same data at different moments differ.
    public static func timestampSeed() -> UInt64 {
        let now = Date().timeIntervalSince1970
        let micros = UInt64(max(0, now) * 1_000_000)
        // Mixed with the process id so that two calls inside one microsecond — two training sessions
        // started in a loop, which is exactly what an evaluation sweep does — still differ.
        return micros &* 0x9E3779B97F4A7C15 &+ UInt64(UInt32(bitPattern: getpid()))
    }
}
