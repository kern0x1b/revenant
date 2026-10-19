import simd
import Foundation


public struct AnimationTimingFunction: Hashable {
    public enum Mode: Hashable {
        case easeIn
        case easeOut
        case easeInOut
    }

    public var controlPoint1: SIMD2<Float>
    public var controlPoint2: SIMD2<Float>
    public var parameters: [String: Float]

    public init(controlPoint1: SIMD2<Float>, controlPoint2: SIMD2<Float>, parameters: [String: Float] = [:]) {
        self.controlPoint1 = controlPoint1
        self.controlPoint2 = controlPoint2
        self.parameters = parameters
    }

    public static let linear = AnimationTimingFunction(controlPoint1: SIMD2<Float>(1.0 / 3.0, 1.0 / 3.0),
                                                      controlPoint2: SIMD2<Float>(2.0 / 3.0, 2.0 / 3.0))
    public static let easeIn = AnimationTimingFunction(controlPoint1: SIMD2<Float>(0.42, 0),
                                                       controlPoint2: SIMD2<Float>(1, 1))
    public static let easeOut = AnimationTimingFunction(controlPoint1: SIMD2<Float>(0, 0),
                                                        controlPoint2: SIMD2<Float>(0.58, 1))
    public static let easeInOut = AnimationTimingFunction(controlPoint1: SIMD2<Float>(0.42, 0),
                                                          controlPoint2: SIMD2<Float>(0.58, 1))
    public static let `default` = AnimationTimingFunction.easeInOut

    public static func cubicBezier(controlPoint1: SIMD2<Float>, controlPoint2: SIMD2<Float>) -> AnimationTimingFunction {
        AnimationTimingFunction(controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    }

    public func value(at progress: Float) -> Float {
        let t = progress
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

    private func __bezierX(_ parameter: Float) -> Float {
        __bezier(parameter, t: controlPoint1.x, y: controlPoint2.x)
    }

    private func __bezierY(_ parameter: Float) -> Float {
        __bezier(parameter, t: controlPoint1.y, y: controlPoint2.y)
    }
}

public enum AnimationRepeatMode: Hashable {
    case none
    case `repeat`
    case cumulative
    case autoReverse
}

public struct AnimationFillMode: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let `default` = AnimationFillMode()
    public static let removed = AnimationFillMode(rawValue: 1 << 0)
    public static let forwards = AnimationFillMode(rawValue: 1 << 1)
    public static let backwards = AnimationFillMode(rawValue: 1 << 2)
    public static let both: AnimationFillMode = [.forwards, .backwards]
}

public protocol AnimatableData {}

extension Float: AnimatableData {}
extension Int: AnimatableData {}
extension Double: AnimatableData {}
extension SIMD2: AnimatableData where Scalar: AnimatableData {}
extension SIMD3: AnimatableData where Scalar: AnimatableData {}
extension SIMD4: AnimatableData where Scalar: AnimatableData {}

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

@MainActor
public final class AnimationPlaybackController: Hashable {
    public weak var entity: Entity?
    public internal(set) var isPaused: Bool
    public internal(set) var isComplete: Bool
    public let name: String
    public let identifier: UInt64
    public let duration: TimeInterval
    public internal(set) var elapsed: TimeInterval
    public internal(set) var cycles: Int = 0
    internal var reversed = false

    let startTransform: Transform
    let animation: __REAnimation
    let node: __REEntity
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

@MainActor
func applyPart(_ definition: AnimationDefinition, to node: __REEntity, over local: TimeInterval,
               from start: Transform) {
    let length = max(definition.duration, 0)
    let timed = length > 0 ? Float(local / length) : 1
    __reAnimation(from: definition, name: definition.name)
        .apply(to: node, at: definition.timing.value(at: min(max(timed, 0), 1)), from: start)
}

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
                controller.animation.apply(to: controller.node, at: controller.reversed ? 0 : 1,
                                           from: controller.startTransform)
                controller.isComplete = true
                finished.append(token)
                continue
            }
            let window = controller.elapsed - controller.animation.delay - controller.animation.offset
            guard window >= 0 else { continue }
            if let sequencer = controller.sequencer {
                switch sequencer.kind {
                case .sequence:
                    let (part, local) = sequencer.placement(at: window)
                    guard let definition = sequencer.parts[part].resource.definition else { continue }
                    applyPart(definition, to: controller.node, over: local,
                              from: controller.startTransform)
                case .group:
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

    func transform(at progress: Float, from start: Transform) -> Transform {
        let target = to ?? Transform(scale: start.scale * (by?.scale ?? .one),
                                     rotation: (by.map { start.rotation * $0.rotation } ?? start.rotation),
                                     translation: start.translation + (by?.translation ?? .zero))
        guard let origin = from else { return target }
        return Transform(scale: origin.scale + (target.scale - origin.scale) * progress,
                         rotation: simd_quatf(vector: origin.rotation.vector + (target.rotation.vector - origin.rotation.vector) * progress),
                         translation: origin.translation + (target.translation - origin.translation) * progress)
    }

    func apply(to node: __REEntity, at progress: Float, from start: Transform) {
        node.transform = transform(at: progress, from: start)
    }
}

extension Transform: AnimatableData {}

@MainActor
open class AnimationResource {
    public let name: String?
    public let definition: AnimationDefinition?

    let sequencer: __RESequencer?

    public convenience init(name: String? = nil, definition: AnimationDefinition? = nil) {
        self.init(name: name, definition: definition, sequencer: nil)
    }

    internal init(name: String? = nil, definition: AnimationDefinition? = nil,
                  sequencer: __RESequencer? = nil) {
        self.name = name
        self.definition = definition
        self.sequencer = sequencer
    }

    public func `repeat`(duration: TimeInterval = .infinity) -> AnimationResource {
        guard let definition else { return self }
        var copy = __REAnimationDefinition(definition)
        copy.repeatMode = .repeat
        copy.repeatCount = 0
        copy.repeatWindow = duration
        return AnimationResource(name: name, definition: copy)
    }

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
    @discardableResult
    public func playAnimation(_ animation: AnimationResource, transitionDuration: TimeInterval = 0,
                              startsPaused: Bool = false) -> AnimationPlaybackController {
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
        let animation = __reAnimation(from: definition, name: animation.name ?? definition.name)
        let controller = AnimationPlaybackController(entity: self, animation: animation,
                                                     startsPaused: startsPaused,
                                                     sequencer: sequencer)
        coreEntity.animations[controller.identifier] = controller
        return controller
    }

    public func stopAllAnimations(recursive: Bool = true) {
        for (_, controller) in coreEntity.animations { controller.stop() }
        if recursive {
            for child in coreEntity.children { child.entity.stopAllAnimations(recursive: true) }
        }
    }
}

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
    var repeatWindow: TimeInterval?
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

@MainActor
private func __reAnimation(from definition: AnimationDefinition, name: String) -> __REAnimation {
    var from: Transform?
    var to: Transform?
    var by: Transform?
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

@MainActor
struct __RESequencer {
    let parts: [(name: String, resource: AnimationResource)]
    enum Kind {
        case sequence
        case group
    }
    let kind: Kind
    let name: String

    var names: [String] { parts.map { $0.name } }

    static func duration(of sequencer: __RESequencer) -> TimeInterval {
        let lengths = sequencer.parts.map { max($0.resource.definition.map { $0.duration } ?? 0, 0) }
        switch sequencer.kind {
        case .group: return lengths.max() ?? 0
        case .sequence: return lengths.reduce(0, +)
        }
    }

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
    var __parts: [(name: String, resource: AnimationResource)] {
        if let sequencer = sequencer { return sequencer.parts }
        return [(name: name ?? "", resource: self)]
    }

    public static func sequence(with resources: [AnimationResource]) throws -> AnimationResource {
        guard !resources.isEmpty else { throw AnimationResourceError.emptySequence }
        return AnimationResource(name: nil, definition: nil,
                                 sequencer: __RESequencer(parts: resources.enumerated().map {
                                     (name: $0.element.name ?? "animation-\($0.offset)", resource: $0.element)
                                 }, kind: .sequence, name: "sequence"))
    }

    public static func group(with resources: [AnimationResource]) throws -> AnimationResource {
        guard !resources.isEmpty else { throw AnimationResourceError.emptySequence }
        return AnimationResource(name: nil, definition: nil,
                                 sequencer: __RESequencer(parts: resources.enumerated().map {
                                     (name: $0.element.name ?? "animation-\($0.offset)", resource: $0.element)
                                 }, kind: .group, name: "group"))
    }

    public static func generate(with definition: any AnimationDefinition) throws -> AnimationResource {
        AnimationResource(name: definition.name, definition: definition)
    }
}

public enum AnimationResourceError: Error, Equatable {
    case emptySequence
    case undefinedDuration
}

@MainActor
extension Entity {
    @discardableResult
    public func playAnimation(named animationName: String, transitionDuration: TimeInterval = 0,
                              startsPaused: Bool = false, recursive: Bool = true) -> AnimationPlaybackController {
        let library = animationLibrary
        guard let resource = library?.animation(named: animationName) else {
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

@frozen public struct AnimationLibraryComponent: Component {
    public var resources: [String: AnimationResource]

    public init(resources: [String: AnimationResource] = [:]) {
        self.resources = resources
    }

    public init(dictionaryLiteral elements: (String, AnimationResource)...) {
        resources = [:]
        for (name, resource) in elements { resources[name] = resource }
    }

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
