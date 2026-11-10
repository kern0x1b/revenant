@_spi(Revenant) import Symbols
import UIKit

public typealias UISymbolEffectCompletion = (UISymbolEffectCompletionContext) -> Void

public struct UISymbolEffectCompletionContext {
    private let context: __UISymbolEffectCompletionContext
    private let completed: any SymbolEffect

    init(_ context: __UISymbolEffectCompletionContext, effect: any SymbolEffect) {
        self.context = context
        self.completed = effect
    }

    public var isFinished: Bool {
        return context.isFinished
    }

    public var sender: AnyObject? {
        return context.sender
    }

    public var effect: any SymbolEffect {
        return completed
    }
}

extension UIImageView {
    private func add(_ effect: some SymbolEffect, _ options: SymbolEffectOptions, _ animated: Bool, _ completion: UISymbolEffectCompletion?) {
        let handler: __UISymbolEffectCompletion? = completion.map { completion in
            { context in
                completion(UISymbolEffectCompletionContext(context, effect: effect))
            }
        }
        __add(effect.configuration.objectiveCEffect, options: options.objectiveCOptions, animated: animated, completion: handler)
    }

    public func addSymbolEffect(_ effect: some SymbolEffect & DiscreteSymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        add(effect, options, animated, completion)
    }

    public func addSymbolEffect(_ effect: some SymbolEffect & IndefiniteSymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        add(effect, options, animated, completion)
    }

    public func addSymbolEffect(_ effect: some SymbolEffect & DiscreteSymbolEffect & IndefiniteSymbolEffect, options: SymbolEffectOptions = .default, animated: Bool = true, completion: UISymbolEffectCompletion? = nil) {
        add(effect, options, animated, completion)
    }

    public func removeAllSymbolEffects(options: SymbolEffectOptions = .default, animated: Bool = true) {
        __removeAllSymbolEffects(with: options.objectiveCOptions, animated: animated)
    }
}
