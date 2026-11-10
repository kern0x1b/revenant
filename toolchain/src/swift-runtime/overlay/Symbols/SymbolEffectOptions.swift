import Foundation

public struct SymbolEffectOptions: Hashable, Sendable {
    enum Repetition: Hashable, Sendable {
        case unspecified
        case indefinite
        case count(Int)
    }

    var repetition = Repetition.unspecified
    var speedMultiplier = 1.0

    init() {
    }

    public static var `default`: SymbolEffectOptions {
        return SymbolEffectOptions()
    }

    public static func speed(_ speed: Double) -> SymbolEffectOptions {
        return SymbolEffectOptions().speed(speed)
    }

    public func speed(_ speed: Double) -> SymbolEffectOptions {
        var options = self
        options.speedMultiplier = speed
        return options
    }

    public static func `repeat`(_ count: Int?) -> SymbolEffectOptions {
        return SymbolEffectOptions().repeat(count)
    }

    public func `repeat`(_ count: Int?) -> SymbolEffectOptions {
        var options = self
        options.repetition = count.map { Repetition.count($0) } ?? .unspecified
        return options
    }

    public static var repeating: SymbolEffectOptions {
        return SymbolEffectOptions().repeating
    }

    public var repeating: SymbolEffectOptions {
        var options = self
        options.repetition = .indefinite
        return options
    }

    public static var nonRepeating: SymbolEffectOptions {
        return SymbolEffectOptions().nonRepeating
    }

    public var nonRepeating: SymbolEffectOptions {
        var options = self
        options.repetition = .count(1)
        return options
    }
}
