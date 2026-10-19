import UIKit
import CoreGraphics

public protocol AnimationStateKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct AnimationState<Value> {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: AnimationStateKey>(key: K.Type) -> K.Value where K.Value == Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

public struct AnimationContext<Value> where Value: VectorArithmetic {
    public var state: AnimationState<Value>
    public var isLogicallyComplete: Bool
    public private(set) var environment: EnvironmentValues

    public init() {
        self.state = AnimationState()
        self.isLogicallyComplete = false
        self.environment = EnvironmentValues()
    }

    public init(environment: EnvironmentValues) {
        self.state = AnimationState()
        self.isLogicallyComplete = false
        self.environment = environment
    }

    public func withState<T>(_ state: AnimationState<T>) -> AnimationContext<T> where T: VectorArithmetic {
        var copy = AnimationContext<T>(environment: environment)
        copy.isLogicallyComplete = isLogicallyComplete
        return copy
    }
}

public protocol CustomAnimation: Hashable {
    func animate<V: VectorArithmetic>(value: V, time: Double, context: inout AnimationContext<V>) -> V?
    func velocity<V: VectorArithmetic>(value: V, time: Double, context: AnimationContext<V>) -> V?
    func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: Double, context: inout AnimationContext<V>) -> Bool
}

struct CustomAnimationBox: Hashable {
    let base: any CustomAnimation

    init(_ base: any CustomAnimation) { self.base = base }

    public static func == (a: CustomAnimationBox, b: CustomAnimationBox) -> Bool { equatableEqual(a.base, b.base) }
    public func hash(into hasher: inout Hasher) { withUnsafeBytes(of: base) { hasher.combine(bytes: $0) } }
}

extension Animation {
    public init<A: CustomAnimation>(_ base: A) {
        curve = .linear
        duration = 0
        custom = CustomAnimationBox(base)
    }

    public var base: (any CustomAnimation)? { custom?.base }

    public func animate<V: VectorArithmetic>(value: V, time: Double, context: inout AnimationContext<V>) -> V? {
        custom?.base.animate(value: value, time: retiming.baseTime(at: time), context: &context)
    }

    public func velocity<V: VectorArithmetic>(value: V, time: Double, context: AnimationContext<V>) -> V? {
        retiming.isRetimed ? nil : custom?.base.velocity(value: value, time: time, context: context)
    }

    public func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: Double, context: inout AnimationContext<V>) -> Bool {
        retiming.isRetimed ? false : custom?.base.shouldMerge(previous: previous, value: value, time: time, context: &context) ?? false
    }
}

extension Animation: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { custom.map { "custom(\($0))" } ?? "Animation(curve: \(curve), duration: \(duration), delay: \(delay))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror {
        Mirror(self, children: [
            "curve": curve,
            "duration": duration,
            "delay": delay,
            "timing": String(describing: timing),
            "custom": String(describing: custom),
        ])
    }
}

public struct AnimationCompletionCriteria: Hashable {
    var isRemoved: Bool
    public static let logicallyComplete = AnimationCompletionCriteria(isRemoved: false)
    public static let removed = AnimationCompletionCriteria(isRemoved: true)
}

final class CompletionToken {
    let criteria: AnimationCompletionCriteria
    private var action: (() -> Void)?
    var claimed = false

    init(criteria: AnimationCompletionCriteria, action: @escaping () -> Void) {
        self.criteria = criteria
        self.action = action
    }

    func run() {
        guard let action else { return }
        self.action = nil
        action()
    }
}

final class CompletionList {
    var tokens: [CompletionToken] = []

    deinit {
        let waiting = tokens.filter { !$0.claimed }
        for token in waiting.reversed() where !token.criteria.isRemoved { token.run() }
        for token in waiting.reversed() where token.criteria.isRemoved { token.run() }
    }
}

extension Transaction {
    public mutating func addAnimationCompletion(criteria: AnimationCompletionCriteria = .logicallyComplete, _ completion: @escaping () -> Void) {
        let token = CompletionToken(criteria: criteria, action: completion)
        let list = completionList ?? CompletionList()
        list.tokens.append(token)
        completionList = list
        Updates.expect(token)
    }
}
