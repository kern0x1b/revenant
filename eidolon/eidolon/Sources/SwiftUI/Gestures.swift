import UIKit
import CoreGraphics

public protocol Gesture {
    associatedtype Value
    associatedtype Body: Gesture = Never
    var body: Body { get }
    func _makeRuntime() -> _GestureRuntime<Value>
}

extension Gesture where Body == Never {
    public var body: Never { fatalError("\(Self.self) is a primitive gesture and has no body") }
}

extension Gesture where Value == Body.Value {
    public func _makeRuntime() -> _GestureRuntime<Value> { body._makeRuntime() }
}

extension Never: Gesture {
    public typealias Value = Never
    public func _makeRuntime() -> _GestureRuntime<Never> { fatalError("Never has no gesture") }
}

// MARK: events, leaves and runtimes

enum GesturePhase { case changed, ended, cancelled }

enum RawGestureEvent {
    case tap(CGPoint)
    case pressDown
    case pressRecognized
    case pressUp
    case drag(DragGesture.Value, GesturePhase)
    case pinch(CGFloat, GesturePhase)
    case rotate(Angle, GesturePhase)
}

enum Translated<V> {
    case changed(V)
    case ended(V)
    case cancelled
    case ignore
}

class GestureLeaf {
    enum Kind {
        case tap(count: Int, space: CoordinateSpace)
        case press(duration: Double, distance: CGFloat)
        case drag(space: CoordinateSpace)
        case pinch
        case rotation
    }
    let kind: Kind
    var active = true
    init(_ kind: Kind) { self.kind = kind }
    func handle(_ event: RawGestureEvent) {}
}

final class Leaf<V>: GestureLeaf {
    var changed: ((V) -> Void)?
    var ended: ((V) -> Void)?
    var cancelled: (() -> Void)?
    let translate: (RawGestureEvent) -> Translated<V>

    init(_ kind: Kind, _ translate: @escaping (RawGestureEvent) -> Translated<V>) {
        self.translate = translate
        super.init(kind)
    }

    override func handle(_ event: RawGestureEvent) {
        guard active else { return }
        switch translate(event) {
        case .changed(let value): changed?(value)
        case .ended(let value): ended?(value)
        case .cancelled: cancelled?()
        case .ignore: break
        }
    }
}

protocol AnyGestureRuntime: AnyObject {
    var leaves: [GestureLeaf] { get }
    var failurePairs: [(GestureLeaf, GestureLeaf)] { get }
}

public final class _GestureRuntime<Value>: AnyGestureRuntime {
    var leaves: [GestureLeaf]
    var failurePairs: [(GestureLeaf, GestureLeaf)]
    var changed: ((Value) -> Void)?
    var ended: ((Value) -> Void)?
    var cancelled: (() -> Void)?
    var retained: [AnyObject] = []

    init(leaves: [GestureLeaf], failurePairs: [(GestureLeaf, GestureLeaf)] = []) {
        self.leaves = leaves
        self.failurePairs = failurePairs
    }

    convenience init<Inner>(over inner: _GestureRuntime<Inner>) {
        self.init(leaves: inner.leaves, failurePairs: inner.failurePairs)
        retained = [inner]
    }
}

func leafRuntime<V>(_ leaf: Leaf<V>) -> _GestureRuntime<V> {
    let runtime = _GestureRuntime<V>(leaves: [leaf])
    leaf.changed = { [unowned runtime] in runtime.changed?($0) }
    leaf.ended = { [unowned runtime] in runtime.ended?($0) }
    leaf.cancelled = { [unowned runtime] in runtime.cancelled?() }
    return runtime
}

// State a gesture keeps between two evaluations of the view body: a re-render in the middle of a drag builds
// the runtime again, and what the gesture has seen so far has to survive it.
final class GestureStore {
    var boxes: [AnyObject] = []
    var cursor = 0

    func box<B: AnyObject>(_ make: () -> B) -> B {
        defer { cursor += 1 }
        if cursor < boxes.count, let existing = boxes[cursor] as? B { return existing }
        let created = make()
        if cursor < boxes.count { boxes[cursor] = created } else { boxes.append(created) }
        return created
    }
}

enum GestureBuild {
    nonisolated(unsafe) static var store = GestureStore()

    static func box<B: AnyObject>(_ make: () -> B) -> B { store.box(make) }

    static func build(with store: GestureStore, _ make: () -> AnyGestureRuntime) -> AnyGestureRuntime {
        let previous = self.store
        store.cursor = 0
        self.store = store
        defer { self.store = previous }
        return make()
    }
}

final class Flag { var value = false }

// MARK: primitive gestures

public struct TapGesture: Gesture {
    public typealias Value = Void
    public typealias Body = Never
    public var count: Int
    public init(count: Int = 1) { self.count = count }

    public func _makeRuntime() -> _GestureRuntime<Void> {
        leafRuntime(Leaf<Void>(.tap(count: count, space: .local)) { event in
            if case .tap = event { return .ended(()) }
            return .ignore
        })
    }
}

public struct SpatialTapGesture: Gesture {
    public typealias Body = Never
    public struct Value: Equatable {
        public var location: CGPoint
    }
    public var count: Int
    public var coordinateSpace: CoordinateSpace
    public init(count: Int = 1, coordinateSpace: CoordinateSpace = .local) { self.count = count; self.coordinateSpace = coordinateSpace }

    public func _makeRuntime() -> _GestureRuntime<Value> {
        leafRuntime(Leaf<Value>(.tap(count: count, space: coordinateSpace)) { event in
            if case .tap(let location) = event { return .ended(Value(location: location)) }
            return .ignore
        })
    }
}

func pressRuntime(duration: Double, distance: CGFloat, pressing: ((Bool) -> Void)?) -> _GestureRuntime<Bool> {
    let recognized: Flag = GestureBuild.box { Flag() }
    return leafRuntime(Leaf<Bool>(.press(duration: duration, distance: distance)) { event in
        switch event {
        case .pressDown:
            recognized.value = false
            pressing?(true)
            return .changed(true)
        case .pressRecognized:
            recognized.value = true
            pressing?(false)
            return .ended(true)
        case .pressUp:
            defer { recognized.value = false }
            if recognized.value { return .cancelled }
            pressing?(false)
            return .cancelled
        default:
            return .ignore
        }
    })
}

public struct LongPressGesture: Gesture {
    public typealias Value = Bool
    public typealias Body = Never
    public var minimumDuration: Double
    public var maximumDistance: CGFloat
    public init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) {
        self.minimumDuration = minimumDuration
        self.maximumDistance = maximumDistance
    }

    public func _makeRuntime() -> _GestureRuntime<Bool> {
        pressRuntime(duration: minimumDuration, distance: maximumDistance, pressing: nil)
    }
}

struct PressingLongPress: Gesture {
    typealias Value = Bool
    typealias Body = Never
    let minimumDuration: Double
    let maximumDistance: CGFloat
    let pressing: (Bool) -> Void

    func _makeRuntime() -> _GestureRuntime<Bool> {
        pressRuntime(duration: minimumDuration, distance: maximumDistance, pressing: pressing)
    }
}

final class DragState {
    var started = false
}

public struct DragGesture: Gesture {
    public typealias Body = Never
    public struct Value: Equatable {
        public var time: Date
        public var location: CGPoint
        public var startLocation: CGPoint
        public var translation: CGSize
        public var velocity: CGSize
        public var predictedEndLocation: CGPoint
        public var predictedEndTranslation: CGSize
    }
    public var minimumDistance: CGFloat
    public var coordinateSpace: CoordinateSpace
    public init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) {
        self.minimumDistance = minimumDistance
        self.coordinateSpace = coordinateSpace
    }

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let state: DragState = GestureBuild.box { DragState() }
        let minimum = minimumDistance
        return leafRuntime(Leaf<Value>(.drag(space: coordinateSpace)) { event in
            guard case .drag(let value, let phase) = event else { return .ignore }
            switch phase {
            case .changed:
                if !state.started {
                    guard hypot(value.translation.width, value.translation.height) >= minimum else { return .ignore }
                    state.started = true
                }
                return .changed(value)
            case .ended:
                guard state.started else { return .ignore }
                state.started = false
                return .ended(value)
            case .cancelled:
                guard state.started else { return .ignore }
                state.started = false
                return .cancelled
            }
        })
    }
}

public enum CoordinateSpace: Hashable {
    case global
    case local
    case named(AnyHashable)
}

public struct MagnificationGesture: Gesture {
    public typealias Value = CGFloat
    public typealias Body = Never
    public var minimumScaleDelta: CGFloat
    public init(minimumScaleDelta: CGFloat = 0.01) { self.minimumScaleDelta = minimumScaleDelta }

    public func _makeRuntime() -> _GestureRuntime<CGFloat> {
        let started: Flag = GestureBuild.box { Flag() }
        let minimum = minimumScaleDelta
        return leafRuntime(Leaf<CGFloat>(.pinch) { event in
            guard case .pinch(let scale, let phase) = event else { return .ignore }
            switch phase {
            case .changed:
                if !started.value {
                    guard abs(scale - 1) >= minimum else { return .ignore }
                    started.value = true
                }
                return .changed(scale)
            case .ended:
                guard started.value else { return .ignore }
                started.value = false
                return .ended(scale)
            case .cancelled:
                guard started.value else { return .ignore }
                started.value = false
                return .cancelled
            }
        })
    }
}

public struct RotationGesture: Gesture {
    public typealias Value = Angle
    public typealias Body = Never
    public var minimumAngleDelta: Angle
    public init(minimumAngleDelta: Angle = .degrees(1)) { self.minimumAngleDelta = minimumAngleDelta }

    public func _makeRuntime() -> _GestureRuntime<Angle> {
        let started: Flag = GestureBuild.box { Flag() }
        let minimum = abs(minimumAngleDelta.radians)
        return leafRuntime(Leaf<Angle>(.rotation) { event in
            guard case .rotate(let angle, let phase) = event else { return .ignore }
            switch phase {
            case .changed:
                if !started.value {
                    guard abs(angle.radians) >= minimum else { return .ignore }
                    started.value = true
                }
                return .changed(angle)
            case .ended:
                guard started.value else { return .ignore }
                started.value = false
                return .ended(angle)
            case .cancelled:
                guard started.value else { return .ignore }
                started.value = false
                return .cancelled
            }
        })
    }
}

// MARK: combinators

public struct _ChangedGesture<Content: Gesture>: Gesture {
    public typealias Value = Content.Value
    public typealias Body = Never
    let content: Content
    let action: (Content.Value) -> Void

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let inner = content._makeRuntime()
        let out = _GestureRuntime<Value>(over: inner)
        let action = self.action
        inner.changed = { [unowned out] value in
            action(value)
            out.changed?(value)
        }
        inner.ended = { [unowned out] in out.ended?($0) }
        inner.cancelled = { [unowned out] in out.cancelled?() }
        return out
    }
}

public struct _EndedGesture<Content: Gesture>: Gesture {
    public typealias Value = Content.Value
    public typealias Body = Never
    let content: Content
    let action: (Content.Value) -> Void

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let inner = content._makeRuntime()
        let out = _GestureRuntime<Value>(over: inner)
        let action = self.action
        inner.changed = { [unowned out] in out.changed?($0) }
        inner.ended = { [unowned out] value in
            action(value)
            out.ended?(value)
        }
        inner.cancelled = { [unowned out] in out.cancelled?() }
        return out
    }
}

public struct _MapGesture<Content: Gesture, Value>: Gesture {
    public typealias Body = Never
    let content: Content
    let transform: (Content.Value) -> Value

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let inner = content._makeRuntime()
        let out = _GestureRuntime<Value>(over: inner)
        let transform = self.transform
        inner.changed = { [unowned out] in out.changed?(transform($0)) }
        inner.ended = { [unowned out] in out.ended?(transform($0)) }
        inner.cancelled = { [unowned out] in out.cancelled?() }
        return out
    }
}

public struct GestureStateGesture<Base: Gesture, State>: Gesture {
    public typealias Value = Base.Value
    public typealias Body = Never
    public var base: Base
    public var state: GestureState<State>
    public var body: (Value, inout State, inout Transaction) -> Void

    public init(base: Base, state: GestureState<State>, body: @escaping (Value, inout State, inout Transaction) -> Void) {
        self.base = base
        self.state = state
        self.body = body
    }

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let inner = base._makeRuntime()
        let out = _GestureRuntime<Value>(over: inner)
        let state = self.state
        let update = self.body
        inner.changed = { [unowned out] value in
            if let storage = state.storage {
                var current = storage.value
                var transaction = Transaction()
                update(value, &current, &transaction)
                storage.value = current
            }
            out.changed?(value)
        }
        inner.ended = { [unowned out] value in
            state.reset()
            out.ended?(value)
        }
        inner.cancelled = { [unowned out] in
            state.reset()
            out.cancelled?()
        }
        return out
    }
}

public struct AnyGesture<Value>: Gesture {
    public typealias Body = Never
    let make: () -> _GestureRuntime<Value>
    public init<G: Gesture>(_ gesture: G) where G.Value == Value { make = { gesture._makeRuntime() } }
    public func _makeRuntime() -> _GestureRuntime<Value> { make() }
}

final class SequenceState<First> {
    var firstDone = false
    var firstValue: First?
    func reset() { firstDone = false; firstValue = nil }
}

public struct SequenceGesture<First: Gesture, Second: Gesture>: Gesture {
    public typealias Body = Never
    public enum Value {
        case first(First.Value)
        case second(First.Value, Second.Value?)
    }
    public var first: First
    public var second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let state: SequenceState<First.Value> = GestureBuild.box { SequenceState() }
        let a = first._makeRuntime()
        let b = second._makeRuntime()
        let out = _GestureRuntime<Value>(leaves: a.leaves + b.leaves, failurePairs: a.failurePairs + b.failurePairs)
        out.retained = [a, b]
        let secondLeaves = b.leaves
        secondLeaves.forEach { $0.active = state.firstDone }
        a.changed = { [unowned out] value in
            state.reset()
            secondLeaves.forEach { $0.active = false }
            out.changed?(.first(value))
        }
        a.ended = { [unowned out] value in
            state.firstDone = true
            state.firstValue = value
            secondLeaves.forEach { $0.active = true }
            out.changed?(.second(value, nil))
        }
        a.cancelled = { [unowned out] in
            guard !state.firstDone else { return }
            out.cancelled?()
        }
        b.changed = { [unowned out] value in
            guard let opening = state.firstValue else { return }
            out.changed?(.second(opening, value))
        }
        b.ended = { [unowned out] value in
            guard let opening = state.firstValue else { return }
            state.reset()
            secondLeaves.forEach { $0.active = false }
            out.ended?(.second(opening, value))
        }
        b.cancelled = { [unowned out] in
            state.reset()
            secondLeaves.forEach { $0.active = false }
            out.cancelled?()
        }
        return out
    }
}

final class SimultaneousState<First, Second> {
    var first: First?
    var second: Second?
    var firstActive = false
    var secondActive = false
    func reset() { first = nil; second = nil; firstActive = false; secondActive = false }
}

public struct SimultaneousGesture<First: Gesture, Second: Gesture>: Gesture {
    public typealias Body = Never
    public struct Value {
        public var first: First.Value?
        public var second: Second.Value?
    }
    public var first: First
    public var second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let state: SimultaneousState<First.Value, Second.Value> = GestureBuild.box { SimultaneousState() }
        let a = first._makeRuntime()
        let b = second._makeRuntime()
        let out = _GestureRuntime<Value>(leaves: a.leaves + b.leaves, failurePairs: a.failurePairs + b.failurePairs)
        out.retained = [a, b]
        a.changed = { [unowned out] value in
            state.first = value
            state.firstActive = true
            out.changed?(Value(first: state.first, second: state.second))
        }
        a.ended = { [unowned out] value in
            state.first = value
            state.firstActive = false
            guard !state.secondActive else { return }
            let final = Value(first: state.first, second: state.second)
            state.reset()
            out.ended?(final)
        }
        a.cancelled = { [unowned out] in
            state.firstActive = false
            guard !state.secondActive else { return }
            state.reset()
            out.cancelled?()
        }
        b.changed = { [unowned out] value in
            state.second = value
            state.secondActive = true
            out.changed?(Value(first: state.first, second: state.second))
        }
        b.ended = { [unowned out] value in
            state.second = value
            state.secondActive = false
            guard !state.firstActive else { return }
            let final = Value(first: state.first, second: state.second)
            state.reset()
            out.ended?(final)
        }
        b.cancelled = { [unowned out] in
            state.secondActive = false
            guard !state.firstActive else { return }
            state.reset()
            out.cancelled?()
        }
        return out
    }
}

final class ExclusiveState {
    var winner = 0
}

public struct ExclusiveGesture<First: Gesture, Second: Gesture>: Gesture {
    public typealias Body = Never
    public enum Value {
        case first(First.Value)
        case second(Second.Value)
    }
    public var first: First
    public var second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }

    public func _makeRuntime() -> _GestureRuntime<Value> {
        let state: ExclusiveState = GestureBuild.box { ExclusiveState() }
        let a = first._makeRuntime()
        let b = second._makeRuntime()
        var pairs = a.failurePairs + b.failurePairs
        for winner in a.leaves { for waiting in b.leaves { pairs.append((winner, waiting)) } }
        let out = _GestureRuntime<Value>(leaves: a.leaves + b.leaves, failurePairs: pairs)
        out.retained = [a, b]
        a.changed = { [unowned out] value in
            guard state.winner != 2 else { return }
            state.winner = 1
            out.changed?(.first(value))
        }
        a.ended = { [unowned out] value in
            guard state.winner != 2 else { return }
            state.winner = 0
            out.ended?(.first(value))
        }
        a.cancelled = { [unowned out] in
            guard state.winner != 2 else { return }
            state.winner = 0
            out.cancelled?()
        }
        b.changed = { [unowned out] value in
            guard state.winner != 1 else { return }
            state.winner = 2
            out.changed?(.second(value))
        }
        b.ended = { [unowned out] value in
            guard state.winner != 1 else { return }
            state.winner = 0
            out.ended?(.second(value))
        }
        b.cancelled = { [unowned out] in
            guard state.winner != 1 else { return }
            state.winner = 0
            out.cancelled?()
        }
        return out
    }
}

extension Gesture {
    public func onEnded(_ action: @escaping (Value) -> Void) -> _EndedGesture<Self> {
        _EndedGesture(content: self, action: action)
    }
    public func onChanged(_ action: @escaping (Value) -> Void) -> _ChangedGesture<Self> {
        _ChangedGesture(content: self, action: action)
    }
    public func map<T>(_ body: @escaping (Value) -> T) -> _MapGesture<Self, T> {
        _MapGesture(content: self, transform: body)
    }
    public func updating<State>(_ state: GestureState<State>, body: @escaping (Value, inout State, inout Transaction) -> Void) -> GestureStateGesture<Self, State> {
        GestureStateGesture(base: self, state: state, body: body)
    }
    public func simultaneously<Other: Gesture>(with other: Other) -> SimultaneousGesture<Self, Other> {
        SimultaneousGesture(self, other)
    }
    public func sequenced<Other: Gesture>(before other: Other) -> SequenceGesture<Self, Other> {
        SequenceGesture(self, other)
    }
    public func exclusively<Other: Gesture>(before other: Other) -> ExclusiveGesture<Self, Other> {
        ExclusiveGesture(self, other)
    }
}

@propertyWrapper
public struct GestureState<Value>: DynamicProperty, DynamicPropertyInstaller {
    let initial: Value
    var storage: StateStorage<Value>?
    public init(wrappedValue: Value) { initial = wrappedValue }
    public init(initialValue: Value) { initial = initialValue }
    public var wrappedValue: Value { storage?.value ?? initial }
    public var projectedValue: GestureState<Value> { self }

    func reset() { storage?.value = initial }

    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: GestureState<Value>.self)
        if let existing = node.storages[key] as? StateStorage<Value> {
            p.pointee.storage = existing
        } else {
            let storage = StateStorage(p.pointee.initial)
            storage.node = node
            node.storages[key] = storage
            p.pointee.storage = storage
        }
    }
}

public struct GestureMask: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let none = GestureMask(rawValue: 0)
    public static let gesture = GestureMask(rawValue: 1)
    public static let subviews = GestureMask(rawValue: 2)
    public static let all = GestureMask(rawValue: 3)
}

// MARK: UIKit side

// A long-press recogniser that also reports the finger going down and up: SwiftUI's LongPressGesture is "pressed"
// from the touch, while UIKit only reports once the duration has passed.
final class PressRecognizer: UILongPressGestureRecognizer {
    var touchDown: (() -> Void)?
    var touchUp: (() -> Void)?
    private var origin = CGPoint.zero
    private var down = false

    private func lift() {
        guard down else { return }
        down = false
        touchUp?()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard !down, let touch = touches.first else { return }
        down = true
        origin = touch.location(in: view)
        touchDown?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard down, state == .possible, let touch = touches.first else { return }
        let point = touch.location(in: view)
        if hypot(point.x - origin.x, point.y - origin.y) > allowableMovement { lift() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        lift()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        lift()
    }
}

enum GesturePriority { case normal, high }

final class GestureTarget: NSObject, UIGestureRecognizerDelegate {
    var runtime: AnyGestureRuntime?
    var leaves: [GestureLeaf] = []
    var indices: [ObjectIdentifier: Int] = [:]
    weak var view: UIView?
    weak var node: Node?
    var priority = GesturePriority.normal

    func install(_ runtime: AnyGestureRuntime, on view: UIView) {
        self.runtime = runtime
        leaves = runtime.leaves
        guard indices.isEmpty else { return }
        var made: [ObjectIdentifier: UIGestureRecognizer] = [:]
        for (index, leaf) in leaves.enumerated() {
            let recognizer: UIGestureRecognizer
            switch leaf.kind {
            case .tap(let count, _):
                let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
                tap.numberOfTapsRequired = count
                recognizer = tap
            case .press(let duration, let distance):
                let press = PressRecognizer(target: self, action: #selector(pressed(_:)))
                press.minimumPressDuration = duration
                press.allowableMovement = distance
                press.touchDown = { [weak self] in self?.deliver(.pressDown, toLeafAt: index) }
                press.touchUp = { [weak self] in self?.deliver(.pressUp, toLeafAt: index) }
                recognizer = press
            case .drag:
                recognizer = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
            case .pinch:
                recognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
            case .rotation:
                recognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:)))
            }
            recognizer.delegate = self
            indices[ObjectIdentifier(recognizer)] = index
            made[ObjectIdentifier(leaf)] = recognizer
            view.addGestureRecognizer(recognizer)
        }
        for (winner, waiting) in runtime.failurePairs {
            if let first = made[ObjectIdentifier(winner)], let second = made[ObjectIdentifier(waiting)] {
                second.require(toFail: first)
            }
        }
    }

    func leaf(for recognizer: UIGestureRecognizer) -> (index: Int, leaf: GestureLeaf)? {
        guard let index = indices[ObjectIdentifier(recognizer)], index < leaves.count else { return nil }
        return (index, leaves[index])
    }

    func deliver(_ event: RawGestureEvent, toLeafAt index: Int) {
        guard index < leaves.count else { return }
        leaves[index].handle(event)
    }

    // Used by the probe: every leaf sees the event and takes what belongs to it.
    func inject(_ event: RawGestureEvent) {
        for leaf in leaves { leaf.handle(event) }
    }

    func referenceView(_ view: UIView, space: CoordinateSpace) -> UIView {
        switch space {
        case .local: return view
        case .global: return topmost(view)
        case .named(let name): return node.flatMap { namedSpace(name, above: $0) } ?? topmost(view)
        }
    }

    @objc func tapped(_ recognizer: UITapGestureRecognizer) {
        guard let view, let (index, leaf) = leaf(for: recognizer), case .tap(_, let space) = leaf.kind else { return }
        deliver(.tap(recognizer.location(in: referenceView(view, space: space))), toLeafAt: index)
    }

    @objc func pressed(_ recognizer: UILongPressGestureRecognizer) {
        guard let (index, _) = leaf(for: recognizer), recognizer.state == .began else { return }
        deliver(.pressRecognized, toLeafAt: index)
    }

    @objc func pinched(_ recognizer: UIPinchGestureRecognizer) {
        guard let (index, _) = leaf(for: recognizer), let phase = phase(of: recognizer) else { return }
        deliver(.pinch(recognizer.scale, phase), toLeafAt: index)
    }

    @objc func rotated(_ recognizer: UIRotationGestureRecognizer) {
        guard let (index, _) = leaf(for: recognizer), let phase = phase(of: recognizer) else { return }
        deliver(.rotate(Angle(radians: Double(recognizer.rotation)), phase), toLeafAt: index)
    }

    @objc func dragged(_ recognizer: UIPanGestureRecognizer) {
        guard let view, let (index, leaf) = leaf(for: recognizer), case .drag(let space) = leaf.kind, let phase = phase(of: recognizer) else { return }
        let reference = referenceView(view, space: space)
        let translation = recognizer.translation(in: reference)
        let location = recognizer.location(in: reference)
        let velocity = recognizer.velocity(in: reference)
        let value = DragGesture.Value(
            time: Date(),
            location: location,
            startLocation: CGPoint(x: location.x - translation.x, y: location.y - translation.y),
            translation: CGSize(width: translation.x, height: translation.y),
            velocity: CGSize(width: velocity.x, height: velocity.y),
            predictedEndLocation: CGPoint(x: location.x + velocity.x / 4, y: location.y + velocity.y / 4),
            predictedEndTranslation: CGSize(width: translation.x + velocity.x / 4, height: translation.y + velocity.y / 4))
        deliver(.drag(value, phase), toLeafAt: index)
    }

    func phase(of recognizer: UIGestureRecognizer) -> GesturePhase? {
        switch recognizer.state {
        case .changed: return .changed
        case .ended: return .ended
        case .cancelled, .failed: return .cancelled
        default: return nil
        }
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    // A gesture added with highPriorityGesture makes the recognisers of the views below it wait for its own.
    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        guard priority == .high, let mine = view, let theirs = other.view, theirs !== mine else { return false }
        return theirs.isDescendant(of: mine)
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view else { return true }
        return accepts(touch.location(in: view))
    }

    func accepts(_ point: CGPoint) -> Bool {
        guard let view, let shaped = contentShape(below: (node as? ContainerNode)?.content) else { return true }
        return shaped.contains(point, in: view)
    }
}

struct GestureModifier: NodeModifier {
    let make: () -> AnyGestureRuntime
    var priority = GesturePriority.normal
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { GestureNode() }
}

final class GestureNode: ContainerNode {
    let target = GestureTarget()
    let store = GestureStore()
    var installed = false

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! GestureModifier
        let runtime = GestureBuild.build(with: store, modifier.make)
        target.priority = modifier.priority
        target.view = uiView
        target.node = self
        content = adopt(reconcile(content, m.modifiedContent, env))
        if !installed {
            installed = true
            uiView.isUserInteractionEnabled = true
        }
        target.install(runtime, on: uiView)
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

extension View {
    func attaching<G: Gesture>(_ gesture: G, priority: GesturePriority, mask: GestureMask) -> some View {
        if !mask.contains(.subviews) {
            _Unsupported.note("gesture(including:)", "the recognisers of iOS 6 cannot be switched off for a whole view hierarchy; the gestures of the subviews stay enabled")
        }
        guard mask.contains(.gesture) else { return AnyView(self) }
        return AnyView(_ModifiedView(content: self, modifier: GestureModifier(make: { gesture._makeRuntime() }, priority: priority)))
    }

    public func gesture<G: Gesture>(_ gesture: G, including mask: GestureMask = .all) -> some View {
        attaching(gesture, priority: .normal, mask: mask)
    }

    public func simultaneousGesture<G: Gesture>(_ gesture: G, including mask: GestureMask = .all) -> some View {
        attaching(gesture, priority: .normal, mask: mask)
    }

    public func highPriorityGesture<G: Gesture>(_ gesture: G, including mask: GestureMask = .all) -> some View {
        attaching(gesture, priority: .high, mask: mask)
    }

    public func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform action: @escaping (CGPoint) -> Void) -> some View {
        gesture(SpatialTapGesture(count: count, coordinateSpace: coordinateSpace).onEnded { action($0.location) })
    }

    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View {
        gesture(TapGesture(count: count).onEnded { action() })
    }

    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, pressing: ((Bool) -> Void)? = nil, perform action: @escaping () -> Void) -> some View {
        gesture(PressingLongPress(minimumDuration: minimumDuration, maximumDistance: maximumDistance, pressing: pressing ?? { _ in }).onEnded { _ in action() })
    }
    @_disfavoredOverload
    @available(*, deprecated, message: "use onLongPressGesture(minimumDuration:maximumDistance:pressing:perform:)")
    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, perform action: @escaping () -> Void, onPressingChanged: ((Bool) -> Void)? = nil) -> some View {
        onLongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance, pressing: onPressingChanged, perform: action)
    }

}
