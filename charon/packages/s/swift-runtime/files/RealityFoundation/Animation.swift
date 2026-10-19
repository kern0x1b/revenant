// Animation: an entity's transform changing over time.
//
// An animation here is a definition - a value that moves from one state to another over a
// duration, with a timing function and a repeat mode - and a resource that names it. Playing one
// hands back a controller, and the controller is advanced by the same step that advances the
// physics: the render loop, or a program calling `__advancePhysics(deltaTime:)` itself. There is
// no clock of its own, so a frame is what time is.

import simd
import Foundation


// MARK: - The timing

/// How an animation's progress maps onto its duration.
public struct AnimationTimingFunction: Hashable {
    /// Which part of the animation the function shapes.
    public enum Mode: Hashable {
        case easeIn
        case easeOut
        case easeInOut
    }

    /// The curve, as a cubic Bézier over the unit interval: the two control points, and
    /// whatever else the function needs. Every function below is one of these.
    public var controlPoint1: SIMD2<Float>
    public var controlPoint2: SIMD2<Float>
    /// A spring, an elastic or a bounce: the parameters the curve does not describe.
    public var parameters: [String: Float]

    public init(controlPoint1: SIMD2<Float>, controlPoint2: SIMD2<Float>, parameters: [String: Float] = [:]) {
        self.controlPoint1 = controlPoint1
        self.controlPoint2 = controlPoint2
        self.parameters = parameters
    }

    // The control points below are the documented ones - CoreAnimation's, which are also CSS's -
    // because this SDK's `CAMediaTimingFunction` does not hand the Bezier's four control points
    // out, so there is no system here to measure them against (measured 2026-09-27 on the host:
    // `getControlPoint(at: 0)` answers [0, 0] for every function, and index 1 answers
    // [0.42, 0] for easeIn, where the curve's first point is (0.42, 0)). The matrix and quaternion
    // maths, by contrast, is the release's own simd, which this port's simd module is built from.

    /// Straight from the start to the end.
    public static let linear = AnimationTimingFunction(controlPoint1: SIMD2<Float>(1.0 / 3.0, 1.0 / 3.0),
                                                      controlPoint2: SIMD2<Float>(2.0 / 3.0, 2.0 / 3.0))
    /// Slow at the start, fast at the end.
    public static let easeIn = AnimationTimingFunction(controlPoint1: SIMD2<Float>(0.42, 0),
                                                       controlPoint2: SIMD2<Float>(1, 1))
    /// Fast at the start, slow at the end.
    public static let easeOut = AnimationTimingFunction(controlPoint1: SIMD2<Float>(0, 0),
                                                        controlPoint2: SIMD2<Float>(0.58, 1))
    /// Slow at both ends.
    public static let easeInOut = AnimationTimingFunction(controlPoint1: SIMD2<Float>(0.42, 0),
                                                          controlPoint2: SIMD2<Float>(0.58, 1))
    /// The system's own default, which is `easeInOut`.
    public static let `default` = AnimationTimingFunction.easeInOut

    /// A curve through two control points, which is what every other function is.
    public static func cubicBezier(controlPoint1: SIMD2<Float>, controlPoint2: SIMD2<Float>) -> AnimationTimingFunction {
        AnimationTimingFunction(controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    }

    /// The progress a duration's fraction reaches: the Bézier through (0,0), the two control
    /// points and (1,1), solved for the parameter that gives the wanted value and read off
    /// the curve.
    public func value(at progress: Float) -> Float {
        let t = progress
        // The x of the curve is not the parameter, so the parameter is found by bisection; the
        // curve's x is monotonic, which is what makes bisection sound.
        var low: Float = 0
        var high: Float = 1
        for _ in 0..<24 {
            let middle = (low + high) / 2
            if __bezierX(middle) < t { low = middle } else { high = middle }
        }
        return __bezierY((low + high) / 2)
    }

    private func __bezier(_ parameter: Float, t: Float, y: Float) -> Float {
        let u = 1 - parameter
        return 3 * u * u * parameter * t + 3 * u * parameter * parameter * y + parameter * parameter * parameter
    }

    /// The x of the curve at a parameter, which is what the bisection above compares.
    private func __bezierX(_ parameter: Float) -> Float {
        __bezier(parameter, t: controlPoint1.x, y: controlPoint2.x)
    }

    /// The y of the curve at a parameter.
    private func __bezierY(_ parameter: Float) -> Float {
        __bezier(parameter, t: controlPoint1.y, y: controlPoint2.y)
    }
}

/// How often an animation runs.
public enum AnimationRepeatMode: Hashable {
    case none
    case `repeat`
    case cumulative
    case autoReverse
}

/// Which way an animation carries on past its end.
public struct AnimationFillMode: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let `default` = AnimationFillMode()
    public static let removed = AnimationFillMode(rawValue: 1 << 0)
    public static let forwards = AnimationFillMode(rawValue: 1 << 1)
    public static let backwards = AnimationFillMode(rawValue: 1 << 2)
    public static let both: AnimationFillMode = [.forwards, .backwards]
}

/// A value an animation can move: it is interpolated between two of them.
public protocol AnimatableData {}

extension Float: AnimatableData {}
extension Int: AnimatableData {}
extension Double: AnimatableData {}
extension SIMD2: AnimatableData where Scalar: AnimatableData {}
extension SIMD3: AnimatableData where Scalar: AnimatableData {}
extension SIMD4: AnimatableData where Scalar: AnimatableData {}

/// What every animation has: a name, a duration, and how it is timed.
public protocol AnimationDefinition {
    var name: String { get set }
    var blendLayer: Int32 { get set }
    var fillMode: AnimationFillMode { get set }
    var duration: TimeInterval { get set }
    var timing: AnimationTimingFunction { get set }
    var repeatMode: AnimationRepeatMode { get set }
    var speed: Float { get set }
    var delay: TimeInterval { get set }
    var offset: TimeInterval { get set }
    var isAdditive: Bool { get set }
}

/// An animation that moves a value from one state to another, or along a path by a step.
@frozen public struct FromToByAnimation<Value>: AnimationDefinition where Value: AnimatableData {
    public var name: String
    public var blendLayer: Int32
    public var fillMode: AnimationFillMode
    public var isAdditive: Bool
    public var timing: AnimationTimingFunction
    public var trimStart: TimeInterval?
    public var trimEnd: TimeInterval?
    public var trimDuration: TimeInterval?
    public var offset: TimeInterval
    public var delay: TimeInterval
    public var speed: Float
    public var repeatMode: AnimationRepeatMode
    public var duration: TimeInterval
    /// Where the animation starts from, and where it ends, and the step it takes by.
    public var fromValue: Value?
    public var toValue: Value?
    public var byValue: Value?

    public init(name: String = "", from: Value? = nil, to: Value? = nil, by: Value? = nil,
                duration: TimeInterval = 1.0, timing: AnimationTimingFunction = .linear,
                isAdditive: Bool = false, blendLayer: Int32 = 0,
                repeatMode: AnimationRepeatMode = .none, fillMode: AnimationFillMode = [],
                trimStart: TimeInterval? = nil, trimEnd: TimeInterval? = nil,
                trimDuration: TimeInterval? = nil, offset: TimeInterval = 0, delay: TimeInterval = 0,
                speed: Float = 1) {
        self.name = name
        fromValue = from
        toValue = to
        byValue = by
        self.duration = duration
        self.timing = timing
        self.isAdditive = isAdditive
        self.blendLayer = blendLayer
        self.repeatMode = repeatMode
        self.fillMode = fillMode
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.trimDuration = trimDuration
        self.offset = offset
        self.delay = delay
        self.speed = speed
    }
}

// MARK: - Playing one

/// One animation playing on one entity, and what a caller can do to it.
@MainActor
public final class AnimationPlaybackController: Hashable {
    /// The entity being animated, which the controller does not keep alive.
    public weak var entity: Entity?
    /// The step reads and writes these, so a caller reads them and only a step changes them.
    public internal(set) var isPaused: Bool
    public internal(set) var isComplete: Bool
    /// The name the animation was given, which is what `playAnimation(named:)` looks up.
    public let name: String
    /// The token the controller is filed under on its node.
    public let identifier: UInt64
    /// How long the animation runs for, and how long it has run.
    public let duration: TimeInterval
    public internal(set) var elapsed: TimeInterval
    /// How many times the animation has run to its end.
    public internal(set) var cycles: Int = 0
    /// Whether an auto-reversing animation is on its way back.
    internal var reversed = false

    /// What the entity looked like before the animation started, which a stopped animation
    /// leaves it at unless the fill mode says otherwise.
    let startTransform: Transform
    let animation: __REAnimation
    let node: __REEntity
    /// The parts of a group or a sequence, and nil for a single animation. This is what a
    /// sequencer is for: the step asks it where in the group a time falls and applies that part.
    let sequencer: __RESequencer?
    init(entity: Entity, animation: __REAnimation, startsPaused: Bool,
         sequencer: __RESequencer? = nil) {
        self.node = entity.coreEntity
        self.entity = entity
        self.animation = animation
        self.sequencer = sequencer
        name = animation.name
        duration = sequencer.map { __RESequencer.duration(of: $0) } ?? animation.duration
        elapsed = 0
        isPaused = startsPaused
        isComplete = false
        startTransform = entity.coreEntity.transform
        identifier = __REComponentRegistry.shared.nextSynchronizationIdentifier()
    }

    public func pause() { isPaused = true }
    public func resume() { isPaused = false }

    /// Stops the animation. The entity keeps the value it has reached, and a fill mode that
    /// removes the value puts it back to what it was before the animation.
    public func stop() {
        isComplete = true
        isPaused = false
        if animation.fillMode.contains(.removed) {
            node.transform = startTransform
        }
        node.animations.removeValue(forKey: identifier)
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(identifier) }

    public static func == (lhs: AnimationPlaybackController, rhs: AnimationPlaybackController) -> Bool {
        lhs === rhs
    }
}

/// Applies one part of a group or a sequence: the part's own timing over the time that falls
/// inside it, from the state the entity was in when the group began.
@MainActor
func applyPart(_ definition: AnimationDefinition, to node: __REEntity, over local: TimeInterval,
               from start: Transform) {
    let length = max(definition.duration, 0)
    let timed = length > 0 ? Float(local / length) : 1
    __reAnimation(from: definition, name: definition.name)
        .apply(to: node, at: definition.timing.value(at: min(max(timed, 0), 1)), from: start)
}

/// The animations playing on one node.
@MainActor
extension __REEntity {
    func __advanceAnimations(_ deltaTime: TimeInterval) {
        guard !animations.isEmpty else { return }
        var finished: [UInt64] = []
        for (token, controller) in animations {
            guard !controller.isPaused else { continue }
            controller.elapsed += deltaTime * TimeInterval(controller.animation.speed)
            let progress = controller.duration > 0 ? Float(controller.elapsed / controller.duration) : 1
            if progress >= 1 {
                controller.cycles += 1
                let repeats = controller.animation.repeatMode != .none
                let countedOff = controller.animation.repeatCount > 0 && controller.cycles >= controller.animation.repeatCount
                let windowedOff = controller.animation.repeatWindow.map { controller.elapsed >= $0 } ?? false
                if repeats && !countedOff && !windowedOff {
                    // Another run: the value wraps to where the run began, and the cycles the
                    // caller asked for are counted rather than the duration stretched.
                    // The overshoot carries into the next run, so a fixed step does not lose it
                    // and the animation does not jump a whole step.
                    let overshoot = controller.elapsed - controller.duration
                    controller.elapsed = overshoot > 0 ? overshoot : 0
                    controller.animation.apply(to: controller.node,
                                               at: Float(controller.elapsed / controller.duration),
                                               from: controller.startTransform)
                    if controller.animation.repeatMode == .autoReverse {
                        controller.reversed.toggle()
                    }
                    continue
                }
                // The last run's last value is applied before the animation is called complete,
                // so that an animation which runs out leaves the entity where it said it would.
                controller.animation.apply(to: controller.node, at: controller.reversed ? 0 : 1,
                                           from: controller.startTransform)
                controller.isComplete = true
                finished.append(token)
                continue
            }
            // The delay and the offset move the window the animation is timed over.
            let window = controller.elapsed - controller.animation.delay - controller.animation.offset
            guard window >= 0 else { continue }
            if let sequencer = controller.sequencer {
                // A group or a sequence has no definition of its own: the time belongs to its
                // parts, and the sequencer is what divides it between them.
                switch sequencer.kind {
                case .sequence:
                    // One part at a time: the division says which, and how far into it.
                    let (part, local) = sequencer.placement(at: window)
                    guard let definition = sequencer.parts[part].resource.definition else { continue }
                    applyPart(definition, to: controller.node, over: local,
                              from: controller.startTransform)
                case .group:
                    // Every part over the whole time. Two parts of a group that drive the same
                    // property of the same entity are in conflict, and they are here as they are
                    // in the system: the last one written holds, and the blend layer is what
                    // separates them when a program needs both.
                    for part in sequencer.parts {
                        guard let definition = part.resource.definition else { continue }
                        applyPart(definition, to: controller.node, over: window,
                                  from: controller.startTransform)
                    }
                }
                continue
            }
            let timed = controller.duration > 0 ? Float(window / controller.duration) : 1
            controller.animation.apply(to: controller.node,
                                       at: controller.animation.timing.value(at: min(max(timed, 0), 1)),
                                       from: controller.startTransform)
        }
        for token in finished { animations.removeValue(forKey: token) }
    }
}

/// An animation, reduced to what the step needs: a curve over a transform, from a start state.
@MainActor
struct __REAnimation {
    let name: String
    let duration: TimeInterval
    let timing: AnimationTimingFunction
    let repeatMode: AnimationRepeatMode
    let repeatCount: Int
    let repeatWindow: TimeInterval?
    let fillMode: AnimationFillMode
    let speed: Float
    let delay: TimeInterval
    let offset: TimeInterval
    let from: Transform?
    let to: Transform?
    let by: Transform?

    /// The transform at a progress, which is where `to` is when it is named and `from * by` when
    /// it is not.
    func transform(at progress: Float, from start: Transform) -> Transform {
        let target = to ?? Transform(scale: start.scale * (by?.scale ?? .one),
                                     rotation: (by.map { start.rotation * $0.rotation } ?? start.rotation),
                                     translation: start.translation + (by?.translation ?? .zero))
        guard let origin = from else { return target }
        return Transform(scale: origin.scale + (target.scale - origin.scale) * progress,
                         rotation: simd_quatf(vector: origin.rotation.vector + (target.rotation.vector - origin.rotation.vector) * progress),
                         translation: origin.translation + (target.translation - origin.translation) * progress)
    }

    /// Writes the transform at a progress onto the node.
    func apply(to node: __REEntity, at progress: Float, from start: Transform) {
        node.transform = transform(at: progress, from: start)
    }
}

// MARK: - Playing one on an entity

/// A transform is what an entity's animation moves, so it is the value kind the definitions
/// this module builds are of.
extension Transform: AnimatableData {}

/// An animation as a resource: a name and the definition behind it.
@MainActor
open class AnimationResource {
    /// The name the animation is looked up and printed under.
    public let name: String?
    /// The definition the step applies, when this resource carries one. A resource loaded from
    /// a file carries its own, and a resource built here is the definition it was built from.
    public let definition: AnimationDefinition?

    /// The sequencer behind a group or a sequence, and nil for one animation.
    let sequencer: __RESequencer?

    /// The animation behind a definition, under a name a caller can look it up by.
    ///
    /// This one is public, and Apple's is not: in both SDKs read for this port (16.4:7028 and
    /// 26.2:14980) `AnimationResource` carries `name` and no initializer and no public loader,
    /// because there an animation is a compiled asset the system reads out of a bundle and the
    /// format is closed. A program on a release this old cannot produce one of those, so the
    /// module's own public definitions - `FromToByAnimation<Value>` and the rest of
    /// `AnimationDefinition` - would have nothing to become: they could be written down and never
    /// played. The definition is the input this port takes instead, and a group or a sequence is
    /// made through the same initializer with a `sequencer` of its own.
    public convenience init(name: String? = nil, definition: AnimationDefinition? = nil) {
        self.init(name: name, definition: definition, sequencer: nil)
    }

    /// The initializer a group or a sequence is made through, which takes the sequencer that
    /// makes it. Internal with its internal parameter: a caller makes those two with
    /// `AnimationResource.group(_:)` and `AnimationResource.sequence(_:)`.
    internal init(name: String? = nil, definition: AnimationDefinition? = nil,
                  sequencer: __RESequencer? = nil) {
        self.name = name
        self.definition = definition
        self.sequencer = sequencer
    }

    /// The animation that repeats for ever.
    public func `repeat`(duration: TimeInterval = .infinity) -> AnimationResource {
        guard let definition else { return self }
        var copy = __REAnimationDefinition(definition)
        copy.repeatMode = .repeat
        copy.repeatCount = 0
        // A duration given for the repetition itself, which is not the length of one run.
        copy.repeatWindow = duration
        return AnimationResource(name: name, definition: copy)
    }

    /// The animation that runs a number of times.
    public func `repeat`(count: Int) -> AnimationResource {
        guard let definition else { return self }
        var copy = __REAnimationDefinition(definition)
        copy.repeatMode = .repeat
        copy.repeatCount = max(0, count)
        return AnimationResource(name: name, definition: copy)
    }
}

@MainActor
extension Entity {
    /// Plays an animation on this entity, and hands back the controller that runs it.
    ///
    /// The animation is advanced by the step that advances the simulation, so nothing plays
    /// until a frame is drawn: a view's render loop, or a program calling
    /// `__advancePhysics(deltaTime:)` itself.
    @discardableResult
    public func playAnimation(_ animation: AnimationResource, transitionDuration: TimeInterval = 0,
                              startsPaused: Bool = false) -> AnimationPlaybackController {
        // A group or a sequence has no definition of its own: what it plays is its parts, and
        // the step reads them through the sequencer. A resource with neither a definition nor any
        // part - one loaded from a file this port cannot read - has nothing to apply, and the
        // controller says so by being complete at once rather than by pretending to run.
        // Read before the local `animation` below shadows the resource the parameter names.
        let sequencer = animation.sequencer
        guard let definition = animation.definition ?? animation.__parts.first?.resource.definition else {
            let controller = AnimationPlaybackController(entity: self,
                                                        animation: __REAnimation(name: animation.name ?? "",
                                                                                duration: 0, timing: .linear,
                                                                                repeatMode: .none, repeatCount: 0,
                                                                                repeatWindow: nil, fillMode: [],
                                                                                speed: 1, delay: 0, offset: 0,
                                                                                from: nil, to: nil, by: nil),
                                                        startsPaused: false)
            controller.stop()
            return controller
        }
        // The controller's own animation is what the step times a single animation by; for a
        // group or a sequence it is built from the first part, and the step's sequencer branch
        // is what applies the part the time has reached.
        let animation = __reAnimation(from: definition, name: animation.name ?? definition.name)
        let controller = AnimationPlaybackController(entity: self, animation: animation,
                                                     startsPaused: startsPaused,
                                                     sequencer: sequencer)
        coreEntity.animations[controller.identifier] = controller
        return controller
    }

    /// Stops every animation playing on this entity, and with `recursive` on everything below it.
    public func stopAllAnimations(recursive: Bool = true) {
        for (_, controller) in coreEntity.animations { controller.stop() }
        if recursive {
            for child in coreEntity.children { child.entity.stopAllAnimations(recursive: true) }
        }
    }
}

/// A definition of the entity's own kind, copied so that `repeat(count:)` changes a
/// resource's timing without changing the definition the caller passed in.
struct __REAnimationDefinition: AnimationDefinition {
    var name: String
    var blendLayer: Int32
    var fillMode: AnimationFillMode
    var isAdditive: Bool
    var timing: AnimationTimingFunction
    var offset: TimeInterval
    var delay: TimeInterval
    var speed: Float
    var repeatMode: AnimationRepeatMode
    var duration: TimeInterval
    /// How long the repetition itself runs for, which is what `repeat(duration:)` sets.
    var repeatWindow: TimeInterval?
    /// How many times the animation runs; zero is for ever, which is what `repeat(duration:)`
    /// with no count means. The duration is the length of *one* run, so a two-count animation is
    /// two curves rather than one long one.
    var repeatCount: Int
    var trimStart: TimeInterval?
    var trimEnd: TimeInterval?
    var trimDuration: TimeInterval?
    var fromValue: Transform?
    var toValue: Transform?
    var byValue: Transform?

    init(_ definition: AnimationDefinition) {
        name = definition.name
        blendLayer = definition.blendLayer
        fillMode = definition.fillMode
        isAdditive = definition.isAdditive
        timing = definition.timing
        offset = definition.offset
        delay = definition.delay
        speed = definition.speed
        repeatMode = definition.repeatMode
        duration = definition.duration
        repeatCount = 0
        let transform = definition as? FromToByAnimation<Transform>
        fromValue = transform?.fromValue
        toValue = transform?.toValue
        byValue = transform?.byValue
        trimStart = transform?.trimStart
        trimEnd = transform?.trimEnd
        trimDuration = transform?.trimDuration
    }
}

/// The animation a definition describes, as a curve over the entity's transform.
@MainActor
private func __reAnimation(from definition: AnimationDefinition, name: String) -> __REAnimation {
    var from: Transform?
    var to: Transform?
    var by: Transform?
    // The values come from either kind of definition: a caller's own `FromToByAnimation`, or
    // the copy `repeat(count:)` made of it, which carries the same values under its own name.
    if let original = definition as? FromToByAnimation<Transform> {
        from = original.fromValue
        to = original.toValue
        by = original.byValue
    } else if let copy = definition as? __REAnimationDefinition {
        from = copy.fromValue
        to = copy.toValue
        by = copy.byValue
    }
    let copy = definition as? __REAnimationDefinition
    return __REAnimation(name: name.isEmpty ? definition.name : name, duration: definition.duration,
                          timing: definition.timing, repeatMode: definition.repeatMode,
                          repeatCount: copy?.repeatCount ?? 0, repeatWindow: copy?.repeatWindow,
                          fillMode: definition.fillMode, speed: definition.speed,
                          delay: definition.delay, offset: definition.offset,
                          from: from, to: to, by: by)
}

// MARK: - Sequencers

/// What a group of animations does to a value: a divider of the group's time into its parts'
/// own durations. This shape is ours alone.
///
/// It used to claim Filament's and Assimp's keyframe samplers, and it claimed them wrongly. The
/// text said a lower-bound search over a channel's own times, the *same* index on both sides
/// before the first key and after the last, the factor taken local to the pair of neighbouring
/// keys, a remembered frame reused while time moves forward, and the next frame wrapped modulo
/// the key count - and none of it was in this file. It was a description of a sampler, and what
/// is here is not a sampler: a group is a list of animations with a duration each, and asking
/// where a time falls in it is a walk over those durations. There is nothing in Apple's own
/// RealityFoundation for the cited machinery to sample either, measured on the 26.2 interface
/// (`iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/
/// RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface`): the module declares no
/// keyframe, sampler or track type at all, and `AnimationResource` carries no member but
/// `__coreAsset`. So the sentences are gone and what remains is what the code does.
///
/// What is true of the two upstreams, and is why the division is by part rather than by a share
/// of the whole: Filament's `Animator` (`libs/gltfio/src/Animator.cpp`, Apache-2.0) and Assimp's
/// `AnimEvaluator` (`tools/assimp_view/code/AnimEvaluator.cpp`, BSD-3-Clause) both walk a list of
/// spans whose lengths they know, and both hold the value at the ends rather than letting a time
/// past the last span run off. That is all that is taken, and the licences are recorded in
/// THIRD-PARTY.md.
@MainActor
struct __RESequencer {
    /// The animations in the order they run, and how long each one holds for.
    let parts: [(name: String, resource: AnimationResource)]
    /// How the group runs: all at once, or one after another.
    enum Kind {
        case sequence
        case group
    }
    let kind: Kind
    let name: String

    /// The names in the order a caller sees them.
    var names: [String] { parts.map { $0.name } }

    /// How long the group runs for: a sequence is as long as its parts added together, and a
    /// group is as long as its longest part, because every part of it runs over the whole time.
    static func duration(of sequencer: __RESequencer) -> TimeInterval {
        let lengths = sequencer.parts.map { max($0.resource.definition.map { $0.duration } ?? 0, 0) }
        switch sequencer.kind {
        case .group: return lengths.max() ?? 0
        case .sequence: return lengths.reduce(0, +)
        }
    }

    /// Where in a sequence a time falls, and how far through the part that holds it the time is.
    ///
    /// A sequence subtracts each part's duration from the time until one is long enough to hold
    /// what is left, so the answer is the index of that part and the time inside it; a time past
    /// the last part is held by the last part, which is the holding at the ends the two upstreams
    /// do. A group has no placement of its own - every part of it runs over the whole time - and
    /// for one this answers the first part with the whole time, which is the same fraction each
    /// part gets.
    func placement(at time: TimeInterval) -> (part: Int, local: TimeInterval) {
        switch kind {
        case .group:
            return (0, time)
        case .sequence:
            var remaining = time
            for (index, part) in parts.enumerated() {
                let length = part.resource.definition.map { max($0.duration, 0) } ?? 0
                if remaining < length || index == parts.count - 1 {
                    return (index, remaining)
                }
                remaining -= length
            }
            return (max(parts.count - 1, 0), 0)
        }
    }
}

extension AnimationResource {
    /// The animations of this resource, or one animation when it is only one.
    var __parts: [(name: String, resource: AnimationResource)] {
        if let sequencer = sequencer { return sequencer.parts }
        return [(name: name ?? "", resource: self)]
    }

    /// Several animations played one after another, as one.
    ///
    /// The parts are timed by their own durations, in the order they are given.
    public static func sequence(with resources: [AnimationResource]) throws -> AnimationResource {
        guard !resources.isEmpty else { throw AnimationResourceError.emptySequence }
        return AnimationResource(name: nil, definition: nil,
                                 sequencer: __RESequencer(parts: resources.enumerated().map {
                                     (name: $0.element.name ?? "animation-\($0.offset)", resource: $0.element)
                                 }, kind: .sequence, name: "sequence"))
    }

    /// Several animations blended, as one: every part sees the whole time at once.
    public static func group(with resources: [AnimationResource]) throws -> AnimationResource {
        guard !resources.isEmpty else { throw AnimationResourceError.emptySequence }
        return AnimationResource(name: nil, definition: nil,
                                 sequencer: __RESequencer(parts: resources.enumerated().map {
                                     (name: $0.element.name ?? "animation-\($0.offset)", resource: $0.element)
                                 }, kind: .group, name: "group"))
    }

    /// The animation a definition describes, as a resource a caller can play.
    public static func generate(with definition: any AnimationDefinition) throws -> AnimationResource {
        AnimationResource(name: definition.name, definition: definition)
    }
}

/// Why a group or a sequence could not be made.
public enum AnimationResourceError: Error, Equatable {
    /// A group or a sequence needs at least one animation, and there were none.
    case emptySequence
    /// A sequence of resources that have no duration to divide the time by.
    case undefinedDuration
}

// MARK: - Playing by name

@MainActor
extension Entity {
    /// Plays the animation of that name, looked up in the model's library, and hands back the
    /// controller.
    @discardableResult
    public func playAnimation(named animationName: String, transitionDuration: TimeInterval = 0,
                              startsPaused: Bool = false, recursive: Bool = true) -> AnimationPlaybackController {
        let library = animationLibrary
        guard let resource = library?.animation(named: animationName) else {
            // A name the library does not hold plays nothing, and the controller says so by being
            // complete at once rather than by raising: a missing animation is a program's own
            // mistake and must not take the process down.
            let empty = AnimationPlaybackController(entity: self,
                                                   animation: __REAnimation(name: animationName, duration: 0,
                                                                           timing: .linear, repeatMode: .none,
                                                                           repeatCount: 0, repeatWindow: nil,
                                                                           fillMode: [], speed: 1, delay: 0,
                                                                           offset: 0, from: nil, to: nil, by: nil),
                                                   startsPaused: false)
            empty.stop()
            return empty
        }
        let controller = playAnimation(resource, startsPaused: startsPaused)
        if recursive {
            for child in coreEntity.children {
                child.entity.playAnimation(resource, startsPaused: startsPaused)
            }
        }
        return controller
    }
}

/// The animations an entity's model carries, by name, and the controller playing each.
@frozen public struct AnimationLibraryComponent: Component {
    /// The animations, by the name they are played under.
    public var resources: [String: AnimationResource]

    public init(resources: [String: AnimationResource] = [:]) {
        self.resources = resources
    }

    public init(dictionaryLiteral elements: (String, AnimationResource)...) {
        resources = [:]
        for (name, resource) in elements { resources[name] = resource }
    }

    /// The animation of that name, and nil for one the library does not hold.
    public func animation(named name: String) -> AnimationResource? { resources[name] }
    public subscript(name: String) -> AnimationResource? {
        get { resources[name] }
        set { resources[name] = newValue }
    }
}

extension Array: ExpressibleByDictionaryLiteral where Element == (String, AnimationResource) {
    public init(dictionaryLiteral elements: (String, AnimationResource)...) { self = elements.map { $0 } }
}

@MainActor
extension Entity {
    /// The animations this entity can be told to play by name.
    public var animationLibrary: AnimationLibraryComponent? {
        get { coreEntity.component(of: AnimationLibraryComponent.self) }
        set {
            if let newValue {
                coreEntity.setComponent(newValue)
            } else {
                coreEntity.removeComponent(of: AnimationLibraryComponent.self)
            }
        }
    }
}
