@_exported import Symbols

public protocol SymbolEffect: Hashable, Sendable {
    var configuration: SymbolEffectConfiguration { get }
}

@_marker public protocol IndefiniteSymbolEffect {
}

@_marker public protocol DiscreteSymbolEffect {
}

public struct SymbolEffectConfiguration: Hashable, Sendable {
    enum Scope: Hashable, Sendable {
        case unspecified
        case byLayer
        case wholeSymbol
    }

    enum Direction: Hashable, Sendable {
        case unspecified
        case up
        case down
    }

    enum Reversal: Hashable, Sendable {
        case unspecified
        case reversing
        case nonReversing
    }

    enum Fill: Hashable, Sendable {
        case unspecified
        case cumulative
        case iterative
    }

    enum Inactive: Hashable, Sendable {
        case unspecified
        case hide
        case dim
    }

    enum Storage: Hashable, Sendable {
        case pulse(Scope)
        case bounce(Scope, Direction)
        case scale(Scope, Direction)
        case variableColor(Reversal, Fill, Inactive)
    }

    let storage: Storage
}

public struct PulseSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {
    var scope = SymbolEffectConfiguration.Scope.unspecified

    init() {
    }

    public var byLayer: PulseSymbolEffect {
        var effect = self
        effect.scope = .byLayer
        return effect
    }

    public var wholeSymbol: PulseSymbolEffect {
        var effect = self
        effect.scope = .wholeSymbol
        return effect
    }

    public var configuration: SymbolEffectConfiguration {
        return SymbolEffectConfiguration(storage: .pulse(scope))
    }
}

public struct BounceSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {
    var scope = SymbolEffectConfiguration.Scope.unspecified
    var direction = SymbolEffectConfiguration.Direction.unspecified

    init() {
    }

    public var up: BounceSymbolEffect {
        var effect = self
        effect.direction = .up
        return effect
    }

    public var down: BounceSymbolEffect {
        var effect = self
        effect.direction = .down
        return effect
    }

    public var byLayer: BounceSymbolEffect {
        var effect = self
        effect.scope = .byLayer
        return effect
    }

    public var wholeSymbol: BounceSymbolEffect {
        var effect = self
        effect.scope = .wholeSymbol
        return effect
    }

    public var configuration: SymbolEffectConfiguration {
        return SymbolEffectConfiguration(storage: .bounce(scope, direction))
    }
}

public struct ScaleSymbolEffect: SymbolEffect, IndefiniteSymbolEffect {
    var scope = SymbolEffectConfiguration.Scope.unspecified
    var direction = SymbolEffectConfiguration.Direction.unspecified

    init() {
    }

    public var up: ScaleSymbolEffect {
        var effect = self
        effect.direction = .up
        return effect
    }

    public var down: ScaleSymbolEffect {
        var effect = self
        effect.direction = .down
        return effect
    }

    public var byLayer: ScaleSymbolEffect {
        var effect = self
        effect.scope = .byLayer
        return effect
    }

    public var wholeSymbol: ScaleSymbolEffect {
        var effect = self
        effect.scope = .wholeSymbol
        return effect
    }

    public var configuration: SymbolEffectConfiguration {
        return SymbolEffectConfiguration(storage: .scale(scope, direction))
    }
}

public struct VariableColorSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, DiscreteSymbolEffect {
    var reversal = SymbolEffectConfiguration.Reversal.unspecified
    var fill = SymbolEffectConfiguration.Fill.unspecified
    var inactive = SymbolEffectConfiguration.Inactive.unspecified

    init() {
    }

    public var reversing: VariableColorSymbolEffect {
        var effect = self
        effect.reversal = .reversing
        return effect
    }

    public var nonReversing: VariableColorSymbolEffect {
        var effect = self
        effect.reversal = .nonReversing
        return effect
    }

    public var cumulative: VariableColorSymbolEffect {
        var effect = self
        effect.fill = .cumulative
        return effect
    }

    public var iterative: VariableColorSymbolEffect {
        var effect = self
        effect.fill = .iterative
        return effect
    }

    public var hideInactiveLayers: VariableColorSymbolEffect {
        var effect = self
        effect.inactive = .hide
        return effect
    }

    public var dimInactiveLayers: VariableColorSymbolEffect {
        var effect = self
        effect.inactive = .dim
        return effect
    }

    public var configuration: SymbolEffectConfiguration {
        return SymbolEffectConfiguration(storage: .variableColor(reversal, fill, inactive))
    }
}

extension SymbolEffect where Self == PulseSymbolEffect {
    public static var pulse: PulseSymbolEffect {
        return PulseSymbolEffect()
    }
}

extension SymbolEffect where Self == BounceSymbolEffect {
    public static var bounce: BounceSymbolEffect {
        return BounceSymbolEffect()
    }
}

extension SymbolEffect where Self == ScaleSymbolEffect {
    public static var scale: ScaleSymbolEffect {
        return ScaleSymbolEffect()
    }
}

extension SymbolEffect where Self == VariableColorSymbolEffect {
    public static var variableColor: VariableColorSymbolEffect {
        return VariableColorSymbolEffect()
    }
}
