import Foundation

extension SymbolEffectConfiguration {
    @_spi(Revenant) public var objectiveCEffect: __NSSymbolEffect {
        switch storage {
        case .pulse(let scope):
            let effect = __NSSymbolPulseEffect()
            switch scope {
            case .unspecified: return effect
            case .byLayer: return effect.withByLayer()
            case .wholeSymbol: return effect.withWholeSymbol()
            }
        case .bounce(let scope, let direction):
            let effect: __NSSymbolBounceEffect
            switch direction {
            case .unspecified: effect = __NSSymbolBounceEffect()
            case .up: effect = __NSSymbolBounceEffect.bounceUp()
            case .down: effect = __NSSymbolBounceEffect.bounceDown()
            }
            switch scope {
            case .unspecified: return effect
            case .byLayer: return effect.withByLayer()
            case .wholeSymbol: return effect.withWholeSymbol()
            }
        case .scale(let scope, let direction):
            let effect: __NSSymbolScaleEffect
            switch direction {
            case .unspecified: effect = __NSSymbolScaleEffect()
            case .up: effect = __NSSymbolScaleEffect.scaleUp()
            case .down: effect = __NSSymbolScaleEffect.scaleDown()
            }
            switch scope {
            case .unspecified: return effect
            case .byLayer: return effect.withByLayer()
            case .wholeSymbol: return effect.withWholeSymbol()
            }
        case .variableColor(let reversal, let fill, let inactive):
            var effect = __NSSymbolVariableColorEffect()
            switch reversal {
            case .unspecified: break
            case .reversing: effect = effect.withReversing()
            case .nonReversing: effect = effect.withNonReversing()
            }
            switch fill {
            case .unspecified: break
            case .cumulative: effect = effect.withCumulative()
            case .iterative: effect = effect.withIterative()
            }
            switch inactive {
            case .unspecified: break
            case .hide: effect = effect.withHideInactiveLayers()
            case .dim: effect = effect.withDimInactiveLayers()
            }
            return effect
        }
    }
}

extension SymbolEffectOptions {
    @_spi(Revenant) public var objectiveCOptions: __NSSymbolEffectOptions {
        var options = __NSSymbolEffectOptions()
        switch repetition {
        case .unspecified:
            break
        case .indefinite:
            options = options.withRepeating()
        case .count(let count):
            options = count <= 1 ? options.withNonRepeating() : options.withRepeatCount(count)
        }
        return options.withSpeed(speedMultiplier)
    }
}
