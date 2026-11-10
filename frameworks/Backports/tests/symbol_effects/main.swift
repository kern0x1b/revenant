import Foundation
import Symbols

func equivalence<Effect: SymbolEffect>(_ name: String, _ items: [(String, Effect)]) -> String {
    var line = name + ":"
    for (i, a) in items.enumerated() {
        for (j, b) in items.enumerated() where j > i {
            let equal = a.1 == b.1
            let sameHash = a.1.hashValue == b.1.hashValue
            let sameConfiguration = a.1.configuration == b.1.configuration
            line += " \(a.0)~\(b.0)=\(equal ? 1 : 0)\(sameHash ? 1 : 0)\(sameConfiguration ? 1 : 0)"
        }
    }
    return line
}

print(equivalence("bounce", [
    ("default", BounceSymbolEffect.bounce),
    ("up", BounceSymbolEffect.bounce.up),
    ("down", BounceSymbolEffect.bounce.down),
    ("whole", BounceSymbolEffect.bounce.wholeSymbol),
    ("layer", BounceSymbolEffect.bounce.byLayer),
    ("upwhole", BounceSymbolEffect.bounce.up.wholeSymbol),
    ("wholeup", BounceSymbolEffect.bounce.wholeSymbol.up),
    ("updown", BounceSymbolEffect.bounce.up.down),
    ("wholelayer", BounceSymbolEffect.bounce.wholeSymbol.byLayer),
]))
print(equivalence("pulse", [
    ("default", PulseSymbolEffect.pulse),
    ("whole", PulseSymbolEffect.pulse.wholeSymbol),
    ("layer", PulseSymbolEffect.pulse.byLayer),
]))
print(equivalence("scale", [
    ("default", ScaleSymbolEffect.scale),
    ("up", ScaleSymbolEffect.scale.up),
    ("down", ScaleSymbolEffect.scale.down),
    ("whole", ScaleSymbolEffect.scale.wholeSymbol),
    ("layer", ScaleSymbolEffect.scale.byLayer),
    ("updown", ScaleSymbolEffect.scale.up.down),
]))
print(equivalence("variableColor", [
    ("default", VariableColorSymbolEffect.variableColor),
    ("reversing", VariableColorSymbolEffect.variableColor.reversing),
    ("nonReversing", VariableColorSymbolEffect.variableColor.nonReversing),
    ("cumulative", VariableColorSymbolEffect.variableColor.cumulative),
    ("iterative", VariableColorSymbolEffect.variableColor.iterative),
    ("hide", VariableColorSymbolEffect.variableColor.hideInactiveLayers),
    ("dim", VariableColorSymbolEffect.variableColor.dimInactiveLayers),
    ("cumulativeIterative", VariableColorSymbolEffect.variableColor.cumulative.iterative),
    ("iterativeCumulative", VariableColorSymbolEffect.variableColor.iterative.cumulative),
    ("reversingNonReversing", VariableColorSymbolEffect.variableColor.reversing.nonReversing),
    ("hideDim", VariableColorSymbolEffect.variableColor.hideInactiveLayers.dimInactiveLayers),
    ("dimHide", VariableColorSymbolEffect.variableColor.dimInactiveLayers.hideInactiveLayers),
]))

let options: [(String, SymbolEffectOptions)] = [
    ("default", .default),
    ("nonRepeating", .nonRepeating),
    ("repeating", .repeating),
    ("repeat0", .repeat(0)),
    ("repeat1", .repeat(1)),
    ("repeat2", .repeat(2)),
    ("repeat3", .repeat(3)),
    ("repeat1000", .repeat(1000)),
    ("repeatNeg1", .repeat(-1)),
    ("repeatNeg2", .repeat(-2)),
    ("repeatMax", .repeat(Int.max)),
    ("repeatMaxMinus1", .repeat(Int.max - 1)),
    ("repeatMin", .repeat(Int.min)),
    ("repeatNil", .repeat(nil)),
    ("speed0", .speed(0)),
    ("speedNegZero", .speed(-0.0)),
    ("speed1", .speed(1)),
    ("speed2", .speed(2)),
    ("speed2.0001", .speed(2.0001)),
    ("speed2.5", .speed(2.5)),
    ("speed2.5b", .speed(2.5000001)),
    ("speedNeg1", .speed(-1)),
    ("speedNaN", .speed(.nan)),
    ("speedInf", .speed(.infinity)),
    ("speedTiny", .speed(1e-300)),
    ("speed1e300", .speed(1e300)),
    ("speed1000", .speed(1000)),
    ("repeat3speed2", .repeat(3).speed(2)),
    ("speed2repeat3", .speed(2).repeat(3)),
    ("repeat3nonRepeating", .repeat(3).nonRepeating),
    ("nonRepeatingrepeat3", .nonRepeating.repeat(3)),
    ("repeatingRepeating", .repeating.repeating),
    ("repeat3repeating", .repeat(3).repeating),
    ("repeatingrepeat3", .repeating.repeat(3)),
    ("speed2speed1", .speed(2).speed(1)),
    ("repeat0nonRepeating", .repeat(0).nonRepeating),
    ("repeat0repeating", .repeat(0).repeating),
    ("nonRepeatingspeed1", .nonRepeating.speed(1)),
    ("repeat2speed0.5", .repeat(2).speed(0.5)),
    ("staticSpeed2", SymbolEffectOptions.speed(2)),
    ("instanceSpeed2", SymbolEffectOptions.default.speed(2)),
]

var equal = "equal:"
var unequalToItself = "unequalToItself:"
var unequalWithSameHash = "unequalWithSameHash:"
for (i, a) in options.enumerated() {
    if a.1 != a.1 {
        unequalToItself += " \(a.0)"
    }
    for (j, b) in options.enumerated() where j > i {
        if a.1 == b.1 {
            equal += " \(a.0)==\(b.0)\(a.1.hashValue == b.1.hashValue ? "" : "(hashDiffers)")"
        } else if a.1.hashValue == b.1.hashValue {
            unequalWithSameHash += " \(a.0)#\(b.0)"
        }
    }
}
print(equal)
print(unequalToItself)
print(unequalWithSameHash)
