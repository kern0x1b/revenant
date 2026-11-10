import Symbols
import UIKit

enum SymbolEffectUse {
    static func bounce(_ view: UIImageView, wholeSymbol: Bool, up: Bool, repeating: Bool, count: Int, speed: Double) {
        var effect: BounceSymbolEffect = .bounce
        if wholeSymbol {
            effect = effect.wholeSymbol
        }
        effect = up ? effect.up : effect.down
        var options: SymbolEffectOptions = repeating ? .repeating : .nonRepeating
        options = options.repeat(abs(count))
        options = options.speed(speed)
        view.addSymbolEffect(effect, options: options, animated: true)
    }

    static func pulse(_ view: UIImageView) {
        var effect: PulseSymbolEffect = .pulse
        effect = effect.wholeSymbol
        view.addSymbolEffect(effect, options: .nonRepeating, animated: true)
    }

    static func scale(_ view: UIImageView, up: Bool) {
        var effect: ScaleSymbolEffect = .scale
        effect = up ? effect.up : effect.down
        view.addSymbolEffect(effect, options: .nonRepeating, animated: true)
    }

    static func variableColor(_ view: UIImageView) {
        var effect: VariableColorSymbolEffect = .variableColor
        effect = effect.cumulative
        effect = effect.iterative
        effect = effect.hideInactiveLayers
        view.addSymbolEffect(effect)
    }

    static func clear(_ view: UIImageView) {
        view.removeAllSymbolEffects()
    }
}
