import UIKit
import CoreGraphics

// MARK: what a custom animation is given to work with

public protocol AnimationStateKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

/// The scratch pad a custom animation may keep values in while it runs.
public struct AnimationState<Value> {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: AnimationStateKey>(key: K.Type) -> K.Value where K.Value == Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

/// What a custom animation is told: where it stands, whether it is over, and the environment.
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

/// An animation of one's own: the three questions SwiftUI asks of it.
public protocol CustomAnimation: Hashable {
    /// Where the value is at a moment, or nil to leave it to SwiftUI.
    func animate<V: VectorArithmetic>(value: V, time: Double, context: inout AnimationContext<V>) -> V?
    /// How fast the value is moving there, or nil when it is not moving.
    func velocity<V: VectorArithmetic>(value: V, time: Double, context: AnimationContext<V>) -> V?
    /// Whether this animation may take over from another one that is already running.
    func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: Double, context: inout AnimationContext<V>) -> Bool
}

/// A custom animation held in a value of its own: an `Animation` compares and hashes by it, and an
/// existential does neither by itself. The port's own box — the port's name for what an
/// `any CustomAnimation` is stored in, and not an SDK type.
struct CustomAnimationBox: Hashable {
    let base: any CustomAnimation

    init(_ base: any CustomAnimation) { self.base = base }

    public static func == (a: CustomAnimationBox, b: CustomAnimationBox) -> Bool { equatableEqual(a.base, b.base) }
    public func hash(into hasher: inout Hasher) { withUnsafeBytes(of: base) { hasher.combine(bytes: $0) } }
}

extension Animation {
    /// An animation that computes its own values, rather than naming a curve or a spring.
    public init<A: CustomAnimation>(_ base: A) {
        curve = .linear
        duration = 0
        custom = CustomAnimationBox(base)
    }

    public var base: (any CustomAnimation)? { custom?.base }

    // A custom animation under `.speed`, `.delay`, `.logicallyComplete` or a repeat is asked for the time those make of the one it is
    // given, answers no velocity and does not merge, whatever it would say itself, as Apple's does (every call made on it, even a speed of
    // one, a layer around it: `host/springcmp.swift` records what a custom animation is asked under each).
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

// MARK: when an animation counts as finished

public struct AnimationCompletionCriteria: Hashable {
    var isRemoved: Bool
    public static let logicallyComplete = AnimationCompletionCriteria(isRemoved: false)
    public static let removed = AnimationCompletionCriteria(isRemoved: true)
}

/// One closure added by `Transaction.addAnimationCompletion`: it runs once, whichever copy of the transaction it was added
/// to or used through, and however many times the transaction is used.
final class CompletionToken {
    let criteria: AnimationCompletionCriteria
    private var action: (() -> Void)?
    /// An animation holds it: the change in a transaction's body that took it for that animation's end, so the transaction
    /// going away does not run it.
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

/// The closures of a transaction and its copies. Apple's framework runs the closures a transaction still holds, that no
/// animation took, when the last copy of it goes away: the ones that wait for the animation of a logically complete
/// view, newest first, then the ones that wait for its removal, newest first (macOS 27, `.agent-work/runs/7-dup/h.swift`).
final class CompletionList {
    var tokens: [CompletionToken] = []

    deinit {
        let waiting = tokens.filter { !$0.claimed }
        for token in waiting.reversed() where !token.criteria.isRemoved { token.run() }
        for token in waiting.reversed() where token.criteria.isRemoved { token.run() }
    }
}

extension Transaction {
    /// A closure to run when the animations of this transaction are over. SwiftUI calls it once the
    /// animation has logically finished, or once the view is gone, whichever the criteria ask for.
    public mutating func addAnimationCompletion(criteria: AnimationCompletionCriteria = .logicallyComplete, _ completion: @escaping () -> Void) {
        let token = CompletionToken(criteria: criteria, action: completion)
        let list = completionList ?? CompletionList()
        list.tokens.append(token)
        completionList = list
        Updates.expect(token)
    }
}
