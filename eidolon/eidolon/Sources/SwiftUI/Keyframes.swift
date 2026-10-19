import UIKit
import CoreGraphics

// MARK: the keyframes themselves

/// One step of a keyframed animation: where the value is at the end of it, how long it takes to get
/// there, and how it travels.
public struct _ResolvedKeyframe<Value> {
    var to: Value
    public var duration: Double
    var timing: Timing

    enum Timing {
        case linear
        case curve(UnitCurve)
        case spring(Spring)
    }

    init(to: Value, duration: Double, timing: Timing) {
        self.to = to
        self.duration = duration
        self.timing = timing
    }
}

/// A whole keyframe track, resolved: the steps, where the animation starts and how fast.
public struct _ResolvedKeyframes<Value> {
    // Apple's _ResolvedKeyframes is an empty struct: the track the port resolves into it is its own
    // reading, and the test that measures a track reads it, so the names it answers are SPI of the
    // tests' group, not public API.
    @_spi(Probe) public var keyframes: [_ResolvedKeyframe<Value>]
    @_spi(Probe) public var initialValue: Value
    @_spi(Probe) public var initialVelocity: Value?

    public init(keyframes: [_ResolvedKeyframe<Value>] = [], initialValue: Value, initialVelocity: Value? = nil) {
        self.keyframes = keyframes
        self.initialValue = initialValue
        self.initialVelocity = initialVelocity
    }

    /// How long the whole track takes.
    public var duration: Double { keyframes.reduce(0) { $0 + $1.duration } }

    /// Where the track is at a moment, as a share of the way it has to travel.
    @_spi(Probe) public func progress(at time: Double) -> Double {
        guard duration > 0 else { return 1 }
        var passed = 0.0
        for (index, keyframe) in keyframes.enumerated() {
            if time < passed + keyframe.duration || index == keyframes.count - 1 {
                let step = keyframe.duration > 0 ? (time - passed) / keyframe.duration : 1
                return (Double(index) + eased(step, by: keyframe.timing)) / Double(keyframes.count)
            }
            passed += keyframe.duration
        }
        return 1
    }

    fileprivate func eased(_ t: Double, by timing: _ResolvedKeyframe<Value>.Timing) -> Double {
        switch timing {
        case .linear: return t
        case .curve(let curve): return curve.value(at: t)
        case .spring(let spring): return 1 - spring.remaining(initialVelocity: 0, time: t * spring.response)
        }
    }

    /// The value at a moment. A keyframe's value is the value at that point of the track, so each
    /// step travels from the value before it to its own.
    public func value(at time: Double) -> Value where Value: Animatable {
        keyframed(self, at: time)
    }
}

/// One keyframe's own data, resolved: how far the value has to go and how long it takes.
public struct _ResolvedKeyframeTrackContent<Value> {
    // as on _ResolvedKeyframes: the port's own reading of one keyframe, which only the module reads
    var to: Value
    public var duration: Double
    var timing: _ResolvedKeyframe<Value>.Timing
    var startVelocity: Value?
    var endVelocity: Value?

    init(to: Value, duration: Double, timing: _ResolvedKeyframe<Value>.Timing = .linear,
                startVelocity: Value? = nil, endVelocity: Value? = nil) {
        self.to = to
        self.duration = duration
        self.timing = timing
        self.startVelocity = startVelocity
        self.endVelocity = endVelocity
    }
}

/// The value a keyframed animation has reached at a moment: each keyframe travels from the value
/// before it to its own, along its own curve, and the last one leaves the value where it wrote it.
func keyframed<V: Animatable>(_ track: _ResolvedKeyframes<V>, at elapsed: Double) -> V {
    var from = track.initialValue
    var time = elapsed
    for keyframe in track.keyframes {
        if keyframe.duration <= 0 {
            from = keyframe.to
            continue
        }
        if time < keyframe.duration {
            let step = min(max(time / keyframe.duration, 0), 1)
            var value = from
            value.animatableData = from.animatableData + (keyframe.to.animatableData - from.animatableData).scaled(by: track.eased(step, by: keyframe.timing))
            return value
        }
        time -= keyframe.duration
        from = keyframe.to
    }
    return from
}

// MARK: the protocols an app writes

public protocol Keyframes<Value> {
    associatedtype Value = Body.Value
    associatedtype Body: Keyframes where Body.Value == Value
    @KeyframesBuilder<Value> var body: Body { get }
    func _resolve(into resolved: inout _ResolvedKeyframes<Value>, initialValue: Value, initialVelocity: Value?)
}

extension Keyframes where Body == Self {
    public func _resolve(into resolved: inout _ResolvedKeyframes<Value>, initialValue: Value, initialVelocity: Value?) {
        var track = _ResolvedKeyframes<Value>(initialValue: initialValue, initialVelocity: initialVelocity)
        body._resolve(into: &track, initialValue: initialValue, initialVelocity: initialVelocity)
        resolved = track
    }
}

public protocol KeyframeTrackContent<Value> {
    associatedtype Value: Animatable = Body.Value
    associatedtype Body: KeyframeTrackContent where Body.Value == Value
    @KeyframeTrackContentBuilder<Value> var body: Body { get }
    func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>)
    /// Every keyframe this content stands for, in the order they are written.
    func _steps() -> [_ResolvedKeyframeTrackContent<Value>]
}

extension KeyframeTrackContent {
    public func _steps() -> [_ResolvedKeyframeTrackContent<Value>] { body._steps() }
}

// MARK: the four kinds of keyframe

public struct CubicKeyframe<Value>: KeyframeTrackContent where Value: Animatable {
    // Apple's CubicKeyframe carries an initialiser and `_resolve` and nothing else: the values a
    // keyframe holds are the port's own, and are internal so that no member of an Apple type carries a
    // name Apple's 26.2 interface does not use.
    var to: Value
    var duration: Double
    var startVelocity: Value?
    var endVelocity: Value?

    public init(_ to: Value, duration: Double, startVelocity: Value? = nil, endVelocity: Value? = nil) {
        self.to = to
        self.duration = duration
        self.startVelocity = startVelocity
        self.endVelocity = endVelocity
    }

    public typealias Body = CubicKeyframe<Value>
    public var body: Body { self }
    public func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>) {
        resolved = _ResolvedKeyframeTrackContent(to: to, duration: duration, timing: .curve(.easeInOut),
                                                startVelocity: startVelocity, endVelocity: endVelocity)
    }
}

extension CubicKeyframe {
    public func _steps() -> [_ResolvedKeyframeTrackContent<Value>] {
        [_ResolvedKeyframeTrackContent(to: to, duration: duration, timing: .curve(.easeInOut),
                                       startVelocity: startVelocity, endVelocity: endVelocity)]
    }
}

public struct LinearKeyframe<Value>: KeyframeTrackContent where Value: Animatable {
    var to: Value
    var duration: Double
    var timingCurve: UnitCurve

    public init(_ to: Value, duration: Double, timingCurve: UnitCurve = .linear) {
        self.to = to
        self.duration = duration
        self.timingCurve = timingCurve
    }

    public typealias Body = LinearKeyframe<Value>
    public var body: Body { self }
    public func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>) {
        resolved = _ResolvedKeyframeTrackContent(to: to, duration: duration, timing: .curve(timingCurve))
    }
}

extension LinearKeyframe {
    public func _steps() -> [_ResolvedKeyframeTrackContent<Value>] {
        [_ResolvedKeyframeTrackContent(to: to, duration: duration, timing: .curve(timingCurve))]
    }
}

public struct SpringKeyframe<Value>: KeyframeTrackContent where Value: Animatable {
    var to: Value
    var duration: Double?
    var spring: Spring
    var startVelocity: Value?

    public init(_ to: Value, duration: Double? = nil, spring: Spring = Spring(), startVelocity: Value? = nil) {
        self.to = to
        self.duration = duration
        self.spring = spring
        self.startVelocity = startVelocity
    }

    public typealias Body = SpringKeyframe<Value>
    public var body: Body { self }
    public func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>) {
        resolved = _ResolvedKeyframeTrackContent(to: to, duration: duration ?? spring.settlingDuration,
                                                timing: .spring(spring), startVelocity: startVelocity)
    }
}

extension SpringKeyframe {
    public func _steps() -> [_ResolvedKeyframeTrackContent<Value>] {
        [_ResolvedKeyframeTrackContent(to: to, duration: duration ?? spring.settlingDuration, timing: .spring(spring), startVelocity: startVelocity)]
    }
}

/// A keyframe with no duration of its own: the value is there from the moment it is reached.
public struct MoveKeyframe<Value>: KeyframeTrackContent where Value: Animatable {
    var to: Value

    public init(_ to: Value) { self.to = to }

    public typealias Body = MoveKeyframe<Value>
    public var body: Body { self }
    public func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>) {
        resolved = _ResolvedKeyframeTrackContent(to: to, duration: 0)
    }
}

extension MoveKeyframe {
    public func _steps() -> [_ResolvedKeyframeTrackContent<Value>] { [_ResolvedKeyframeTrackContent(to: to, duration: 0)] }
}

// MARK: the track a builder makes

public struct KeyframeTrack<Root, Value, Content>: Keyframes where Value: Animatable, Content: KeyframeTrackContent, Content.Value == Value {
    public var content: Content
    let root: KeyPath<Root, Value>?

    public init(@KeyframeTrackContentBuilder<Root> content: () -> Content) where Root == Value {
        self.content = content()
        self.root = nil
    }

    public init(_ keyPath: WritableKeyPath<Root, Value>, @KeyframeTrackContentBuilder<Value> content: () -> Content) {
        self.content = content()
        self.root = keyPath
    }

    public typealias Body = KeyframeTrack<Root, Value, Content>
    public var body: Body { self }
    public func _resolve(into resolved: inout _ResolvedKeyframes<Value>, initialValue: Value, initialVelocity: Value?) {
        var list: [_ResolvedKeyframe<Value>] = []
        for step in content._steps() {
            list.append(_ResolvedKeyframe(to: step.to, duration: step.duration, timing: step.timing))
        }
        resolved = _ResolvedKeyframes(keyframes: list, initialValue: initialValue, initialVelocity: initialVelocity)
    }
}

// MARK: the builders

@_functionBuilder
public struct KeyframesBuilder<Value> {
    public static func buildExpression<K>(_ expression: K) -> K where Value == K.Value, K: KeyframeTrackContent { expression }
    public static func buildArray(_ components: [some KeyframeTrackContent<Value>]) -> some KeyframeTrackContent<Value> {
        KeyframeTrackSteps(steps: components.flatMap { $0._steps() })
    }
    public static func buildEither<First, Second>(first component: First) -> KeyframesBuilder<Value>.Conditional<Value, First, Second>
        where Value == First.Value, First: KeyframeTrackContent, Second: KeyframeTrackContent, First.Value == Second.Value {
        KeyframesBuilder<Value>.Conditional(steps: component._steps())
    }
    public static func buildEither<First, Second>(second component: Second) -> KeyframesBuilder<Value>.Conditional<Value, First, Second>
        where Value == First.Value, First: KeyframeTrackContent, Second: KeyframeTrackContent, First.Value == Second.Value {
        KeyframesBuilder<Value>.Conditional(steps: component._steps())
    }
    public static func buildPartialBlock<K>(first: K) -> K where Value == K.Value, K: KeyframeTrackContent { first }
    public static func buildBlock() -> some KeyframeTrackContent<Value> where Value: Animatable {
        KeyframeTrackSteps(steps: [])
    }
    public static func buildFinalResult<Content>(_ component: Content) -> KeyframeTrack<Value, Value, Content>
        where Value == Content.Value, Content: KeyframeTrackContent {
        KeyframeTrack(content: { component })
    }
    public static func buildExpression<Content>(_ expression: Content) -> Content where Value == Content.Value, Content: Keyframes { expression }
    public static func buildPartialBlock<Content>(first: Content) -> Content where Value == Content.Value, Content: Keyframes { first }
    public static func buildPartialBlock(accumulated: some Keyframes<Value>, next: some Keyframes<Value>) -> some Keyframes<Value> where Value: Animatable {
        KeyframesPair(first: accumulated, second: next)
    }
    public static func buildBlock() -> some Keyframes<Value> { EmptyKeyframes<Value>() }
    public static func buildFinalResult<Content>(_ component: Content) -> Content where Value == Content.Value, Content: Keyframes { component }
}

@_functionBuilder
public struct KeyframeTrackContentBuilder<Value> where Value: Animatable {
    public static func buildExpression<K>(_ expression: K) -> K where Value == K.Value, K: KeyframeTrackContent { expression }
    public static func buildArray(_ components: [some KeyframeTrackContent<Value>]) -> some KeyframeTrackContent<Value> {
        KeyframeTrackSteps(steps: components.flatMap { $0._steps() })
    }
    public static func buildEither<First, Second>(first component: First) -> KeyframesBuilder<Value>.Conditional<Value, First, Second>
        where Value == First.Value, First: KeyframeTrackContent, Second: KeyframeTrackContent, First.Value == Second.Value {
        KeyframesBuilder<Value>.Conditional(steps: component._steps())
    }
    public static func buildEither<First, Second>(second component: Second) -> KeyframesBuilder<Value>.Conditional<Value, First, Second>
        where Value == First.Value, First: KeyframeTrackContent, Second: KeyframeTrackContent, First.Value == Second.Value {
        KeyframesBuilder<Value>.Conditional(steps: component._steps())
    }
    public static func buildPartialBlock<K>(first: K) -> K where Value == K.Value, K: KeyframeTrackContent { first }
    public static func buildPartialBlock(accumulated: some KeyframeTrackContent<Value>, next: some KeyframeTrackContent<Value>) -> some KeyframeTrackContent<Value> {
        KeyframeTrackSteps(steps: accumulated._steps() + next._steps())
    }
    public static func buildBlock() -> some KeyframeTrackContent<Value> { KeyframeTrackSteps(steps: []) }
}

public extension KeyframeTrackContentBuilder {
    /// One of two branches of a keyframe track, the way `if`/`else` makes one.
    struct Conditional<Value, First, Second>: KeyframeTrackContent where Value: Animatable, First: KeyframeTrackContent, Second: KeyframeTrackContent, First.Value == Value, Second.Value == Value {
        var steps: [_ResolvedKeyframeTrackContent<Value>]
        public typealias Body = Conditional<Value, First, Second>
        public var body: Body { self }
        public func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>) { resolved = steps[steps.count - 1] }
    }
}

public extension KeyframesBuilder {
    /// One of two branches of a keyframe track, the way `if`/`else` makes one.
    struct Conditional<Value, First, Second>: KeyframeTrackContent where Value: Animatable, First: KeyframeTrackContent, Second: KeyframeTrackContent, First.Value == Value, Second.Value == Value {
        var steps: [_ResolvedKeyframeTrackContent<Value>]
        public typealias Body = Conditional<Value, First, Second>
        public var body: Body { self }
        public func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>) { resolved = steps[steps.count - 1] }
    }
}

/// The steps of a keyframe track, in the order they are written. The port's own accumulator: the
/// builders hand their keyframes to one of these, and Apple has no such type - a `KeyframeTrackContent`
/// is what a keyframe conforms to.
struct KeyframeTrackSteps<Value>: KeyframeTrackContent where Value: Animatable {
    public var steps: [_ResolvedKeyframeTrackContent<Value>]
    public typealias Body = KeyframeTrackSteps<Value>
    public var body: Body { self }
    public func _resolve(into resolved: inout _ResolvedKeyframeTrackContent<Value>) { resolved = steps[steps.count - 1] }
    public func _steps() -> [_ResolvedKeyframeTrackContent<Value>] { steps }
}

struct EmptyKeyframes<Value>: Keyframes {
    typealias Body = EmptyKeyframes<Value>
    var body: Body { self }
    func _resolve(into resolved: inout _ResolvedKeyframes<Value>, initialValue: Value, initialVelocity: Value?) {
        resolved = _ResolvedKeyframes(keyframes: [], initialValue: initialValue, initialVelocity: initialVelocity)
    }
}

struct KeyframesPair<Value, First, Second>: Keyframes where Value: Animatable, First: Keyframes, Second: Keyframes, First.Value == Value, Second.Value == Value {
    var first: First
    var second: Second
    typealias Body = KeyframesPair<Value, First, Second>
    var body: Body { self }
    func _resolve(into resolved: inout _ResolvedKeyframes<Value>, initialValue: Value, initialVelocity: Value?) {
        var track = resolved
        first._resolve(into: &track, initialValue: initialValue, initialVelocity: initialVelocity)
        var tail = track
        second._resolve(into: &tail, initialValue: initialValue, initialVelocity: initialVelocity)
        resolved = tail
    }
}

