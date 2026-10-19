import UIKit
import CoreGraphics

// MARK: KeyframeAnimator

public struct KeyframeAnimator<Value: Animatable, KeyframePath: Keyframes, Content: View>: View, PrimitiveView where Value == KeyframePath.Value {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let initial: Value
    let trigger: Any?
    let repeating: Bool
    let content: (Value) -> Content
    let keyframes: (Value) -> KeyframePath

    public init(initialValue: Value, trigger: some Equatable, @ViewBuilder content: @escaping (Value) -> Content,
                @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath) {
        self.init(initialValue: initialValue, trigger: trigger, repeating: false, content: content, keyframes: keyframes)
    }

    public init(initialValue: Value, repeating: Bool = true, @ViewBuilder content: @escaping (Value) -> Content,
                @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath) {
        self.init(initialValue: initialValue, trigger: nil, repeating: repeating, content: content, keyframes: keyframes)
    }

    init(initialValue: Value, trigger: Any?, repeating: Bool, content: @escaping (Value) -> Content, keyframes: @escaping (Value) -> KeyframePath) {
        self.initial = initialValue
        self.trigger = trigger
        self.repeating = repeating
        self.content = content
        self.keyframes = keyframes
    }

    func makeNode(_ env: EnvironmentValues) -> Node {
        let node = KeyframeAnimatorNode<Value, KeyframePath, Content>(initial: initial)
        node.update(self, env)
        return node
    }
}

/// Whether two triggers are the same value, whatever its type: SwiftUI only asks that a trigger
/// changed, and an `Equatable` of any type can be compared through the engine's own comparison.
func sameTrigger(_ a: Any?, _ b: Any?) -> Bool {
    guard let a, let b else { return a == nil && b == nil }
    if let equatable = a as? any Equatable { return equatableEqual(equatable, b) }
    return false
}

final class KeyframeAnimatorNode<Value: Animatable, KeyframePath: Keyframes, Content: View>: ContainerNode where Value == KeyframePath.Value {
    private var current: Value
    private var animator: ValueAnimator?
    private var lastTrigger: Any?
    private var repeating = false
    private var placed = false
    private var animatorView: KeyframeAnimator<Value, KeyframePath, Content>?

    init(initial: Value) { current = initial; super.init() }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let described = view as! KeyframeAnimator<Value, KeyframePath, Content>
        animatorView = described
        repeating = described.repeating
        let changed = !placed || repeating || !sameTrigger(described.trigger, lastTrigger)
        lastTrigger = described.trigger
        placed = true
        if !changed { return }
        rebuild()
        startLeg()
    }

    private func rebuild() {
        guard let described = animatorView else { return }
        content = adopt(reconcile(content, described.content(current), env))
    }

    /// One leg of the animation: from where the value is now to the value the keyframes are written
    /// for. A repeating animation runs the legs one after another, as long as it is on screen.
    private func startLeg() {
        animator?.stop()
        guard let described = animatorView else { return }
        var track = _ResolvedKeyframes<Value>(initialValue: current)
        described.keyframes(current)._resolve(into: &track, initialValue: current, initialVelocity: nil)
        let length = track.duration
        guard length > 0 else {
            current = keyframed(track, at: 0)
            settle()
            return
        }
        let animator = ValueAnimator(delay: 0, total: length) { [weak self] now in
            guard let self else { return (0, true) }
            self.current = keyframed(track, at: now)
            return (0, now >= length)
        }
        animator.apply = { [weak self] _ in self?.settle() }
        animator.finished = { [weak self] in
            guard let self else { return }
            self.current = keyframed(track, at: length)
            if self.repeating { self.startLeg() }
        }
        self.animator = animator
        animator.start()
    }

    private func settle() {
        rebuild()
        mount()
        if let host = env.host { host.view.setNeedsLayout() }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    override func dispose() {
        super.dispose()
        animator?.stop()
        animator = nil
    }
}

// MARK: PhaseAnimator

public struct PhaseAnimator<Phase: Equatable, Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let phases: [Phase]
    let trigger: Any?
    let content: (Phase) -> Content
    let animation: (Phase) -> Animation?

    public init(_ phases: some Sequence<Phase>, trigger: some Equatable, @ViewBuilder content: @escaping (Phase) -> Content,
                animation: @escaping (Phase) -> Animation? = { _ in .default }) {
        self.phases = Array(phases)
        self.trigger = trigger
        self.content = content
        self.animation = animation
    }

    public init(_ phases: some Sequence<Phase>, @ViewBuilder content: @escaping (Phase) -> Content,
                animation: @escaping (Phase) -> Animation? = { _ in .default }) {
        self.phases = Array(phases)
        self.trigger = nil
        self.content = content
        self.animation = animation
    }

    func makeNode(_ env: EnvironmentValues) -> Node { let n = PhaseAnimatorNode(); n.update(self, env); return n }
}

protocol PhaseAnimatorLike {
    func phaseCount() -> Int
    func phaseContent(_ index: Int) -> any View
    func phaseAnimation(_ index: Int) -> Animation?
    var phaseTrigger: Any? { get }
}

extension PhaseAnimator: PhaseAnimatorLike {
    func phaseCount() -> Int { phases.count }
    func phaseContent(_ index: Int) -> any View { phases.indices.contains(index) ? content(phases[index]) : AnyView(EmptyView()) }
    func phaseAnimation(_ index: Int) -> Animation? { phases.indices.contains(index) ? animation(phases[index]) : nil }
    var phaseTrigger: Any? { trigger }
}

final class PhaseAnimatorNode: ContainerNode {
    private var animator: ValueAnimator?
    private var index = 0
    private var lastTrigger: Any?
    private var started = false

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let described = view as! PhaseAnimatorLike
        guard described.phaseCount() > 0 else { return }
        let changed = !started || !sameTrigger(described.phaseTrigger, lastTrigger)
        lastTrigger = described.phaseTrigger
        if changed { index = 0 }
        started = true
        rebuild(described)
        if changed { enter(index, described) }
    }

    private func rebuild(_ described: PhaseAnimatorLike) {
        content = adopt(reconcile(content, described.phaseContent(index), env))
    }

    /// Stay in a phase for as long as that phase's own animation runs, then go to the next one; a
    /// change of the trigger starts again at the first phase.
    private func enter(_ phase: Int, _ described: PhaseAnimatorLike) {
        animator?.stop()
        index = phase
        rebuild(described)
        mount()
        if let host = env.host { host.view.setNeedsLayout() }
        let duration = described.phaseAnimation(phase)?.logicalDuration ?? 0
        let animator = ValueAnimator(delay: 0, total: duration) { now in (0, now >= duration) }
        animator.finished = { [weak self] in
            guard let self, described.phaseCount() > 0 else { return }
            self.enter((phase + 1) % described.phaseCount(), described)
        }
        self.animator = animator
        if duration > 0 { animator.start() }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    override func dispose() {
        super.dispose()
        animator?.stop()
        animator = nil
    }
}
