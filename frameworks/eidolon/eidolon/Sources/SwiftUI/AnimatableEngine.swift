import UIKit
import QuartzCore
import CoreGraphics

extension CGSize: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(width, height) }
        set { self = CGSize(width: newValue.first, height: newValue.second) }
    }
}

extension CGPoint: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(x, y) }
        set { self = CGPoint(x: newValue.first, y: newValue.second) }
    }
}

extension CGRect: Animatable {
    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(origin.animatableData, size.animatableData) }
        set {
            origin.animatableData = newValue.first
            size.animatableData = newValue.second
        }
    }
}

extension Angle: Animatable {
    public var animatableData: Double {
        get { radians }
        set { self = Angle(radians: newValue) }
    }
}

extension UnitPoint: Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(x, y) }
        set { self = UnitPoint(x: newValue.first, y: newValue.second) }
    }
}

enum Easing {
    static func apply(_ curve: Animation.Curve, _ t: Double) -> Double {
        switch curve {
        case .linear: return UnitCurve.linear.value(at: t)
        case .easeIn: return UnitCurve.easeIn.value(at: t)
        case .easeOut: return UnitCurve.easeOut.value(at: t)
        case .easeInOut, .spring: return UnitCurve.easeInOut.value(at: t)
        }
    }
}

final class ValueAnimator {
    nonisolated(unsafe) static var clock: () -> CFTimeInterval = { CACurrentMediaTime() }
    nonisolated(unsafe) static var manual = false
    nonisolated(unsafe) static var active: [ValueAnimator] = []

    private final class Proxy: NSObject {
        @objc func fire() { ValueAnimator.tickAll() }
    }
    nonisolated(unsafe) private static var sharedLink: CADisplayLink?

    private static func updateLink() {
        if manual { return }
        if active.isEmpty {
            sharedLink?.invalidate()
            sharedLink = nil
        } else if sharedLink == nil {
            let link = CADisplayLink(target: Proxy(), selector: #selector(Proxy.fire))
            link.add(to: .main, forMode: .common)
            sharedLink = link
        }
    }

    let animation: Animation
    var apply: (Double) -> Void
    var finished: (() -> Void)?
    private(set) var started: CFTimeInterval = 0
    private let elapsed: (Double) -> (value: Double, done: Bool)
    private var frame: ((CFTimeInterval) -> Bool)?

    init(delay: Double, total: Double, at: @escaping (CFTimeInterval) -> (value: Double, done: Bool), apply: @escaping (Double) -> Void = { _ in }) {
        self.animation = Animation(curve: .linear, duration: total, delay: delay)
        self.apply = apply
        self.elapsed = { at($0 - delay) }
    }

    init(animation: Animation, frame: @escaping (CFTimeInterval) -> Bool) {
        self.animation = animation
        self.apply = { _ in }
        self.elapsed = { _ in (0, false) }
        self.frame = frame
    }

    func start() {
        started = ValueAnimator.clock()
        ValueAnimator.active.append(self)
        if let frame { _ = frame(started) } else { apply(0) }
        ValueAnimator.updateLink()
    }

    func stop() {
        ValueAnimator.active.removeAll { $0 === self }
        ValueAnimator.updateLink()
    }

    static func tickAll() {
        for animator in active { animator.tick() }
    }

    func tick() {
        let done: Bool
        if let frame {
            done = frame(ValueAnimator.clock())
        } else {
            let (value, over) = progress(at: ValueAnimator.clock())
            apply(value)
            done = over
        }
        if done {
            stop()
            finished?()
        }
    }

    func progress(at now: CFTimeInterval) -> (value: Double, done: Bool) { elapsed(now - started) }
}

final class Journey<Value: Animatable> {
    typealias Data = Value.AnimatableData

    private(set) var shown: Value?
    private var target: Value?
    private var passage: Passage<Data>?
    private var animator: ValueAnimator?
    private let compatible: (Value, Value) -> Bool
    private let frame: () -> Void

    init(compatible: @escaping (Value, Value) -> Bool = { _, _ in true }, frame: @escaping () -> Void) {
        self.compatible = compatible
        self.frame = frame
    }

    private func valued(_ data: Data, like template: Value) -> Value {
        var value = template
        value.animatableData = data
        return value
    }

    func retarget(_ new: Value, animation: Animation?, animates: Bool = true) {
        let last = target
        target = new
        guard let current = shown, let last else { shown = new; return }
        guard compatible(current, new), animates else { finish(at: new); return }
        let now = ValueAnimator.clock()
        let end = new.animatableData
        if let passage {
            let next = Passage.redirecting(passage, to: end, pace: animation?.pace, now: now)
            if next === passage {
                shown = valued(passage.data(at: now), like: new)
                return
            }
            self.passage = next
            if let animation { drive(animation) }
            return
        }
        let start = current.animatableData
        guard let animation, (end - start).magnitudeSquared > 1e-12 else { shown = new; return }
        passage = Passage.redirecting(Passage(end: start), to: end, pace: animation.pace, now: now)
        drive(animation)
    }

    private func drive(_ animation: Animation) {
        animator?.stop()
        let driver = ValueAnimator(animation: animation) { [weak self] now in
            guard let self, let passage = self.passage, let template = self.target else { return true }
            self.shown = self.valued(passage.data(at: now), like: template)
            self.frame()
            return passage.isOver(at: now)
        }
        driver.finished = { [weak self] in
            self?.animator = nil
            self?.passage = nil
        }
        animator = driver
        driver.start()
    }

    func finish(at new: Value) {
        animator?.stop()
        animator = nil
        passage = nil
        shown = new
    }

    func dispose() {
        animator?.stop()
        animator = nil
        passage = nil
    }
}

private func vector<A: Animatable>(of value: A) -> ErasedVector {
    if let wrapped = value as? AnyShape { return vector(of: wrapped.base) }
    return ErasedVector(value.animatableData)
}

private func rebuilt<A: Animatable>(_ value: A, from data: ErasedVector) -> A {
    var copy = value
    if let own = data.data(as: A.AnimatableData.self) { copy.animatableData = own }
    return copy
}

private func rebuiltShape<S: Shape>(_ shape: S, from data: ErasedVector) -> any Shape {
    if let wrapped = shape as? AnyShape { return AnyShape(rebuiltShape(wrapped.base, from: data)) }
    return rebuilt(shape, from: data)
}

struct AnimatedShape: Animatable {
    var shape: any Shape

    var animatableData: ErasedVector {
        get { vector(of: shape) }
        set { shape = rebuiltShape(shape, from: newValue) }
    }

    static func isOneKind(_ a: AnimatedShape, _ b: AnimatedShape) -> Bool {
        if let left = a.shape as? AnyShape, let right = b.shape as? AnyShape { return isOneKind(AnimatedShape(shape: left.base), AnimatedShape(shape: right.base)) }
        return type(of: a.shape) == type(of: b.shape)
    }
}

struct AnimatedEffect: Animatable {
    var effect: any GeometryEffect

    var animatableData: ErasedVector {
        get { vector(of: effect) }
        set { effect = rebuilt(effect, from: newValue) }
    }

    static func isOneKind(_ a: AnimatedEffect, _ b: AnimatedEffect) -> Bool { type(of: a.effect) == type(of: b.effect) }
}

extension ProjectionTransform {
    var layerTransform: CATransform3D {
        var t = CATransform3DIdentity
        t.m11 = m11; t.m12 = m12; t.m14 = m13
        t.m21 = m21; t.m22 = m22; t.m24 = m23
        t.m41 = m31; t.m42 = m32; t.m44 = m33
        return t
    }
}

protocol GeometryEffectViewLike {
    var effectContent: any View { get }
    var effectValue: any GeometryEffect { get }
}

public struct _GeometryEffectView<Content: View, Effect: GeometryEffect>: View, PrimitiveView, GeometryEffectViewLike {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    let effect: Effect
    var effectContent: any View { content }
    var effectValue: any GeometryEffect { effect }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = GeometryEffectNode(); n.update(self, env); return n }
}

final class GeometryEffectNode: ContainerNode {
    var effect: (any GeometryEffect)? { journey.shown?.effect }
    lazy var journey = Journey<AnimatedEffect>(compatible: AnimatedEffect.isOneKind) { [unowned self] in self.applyTransform() }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let described = view as! GeometryEffectViewLike
        content = adopt(reconcile(content, described.effectContent, env))
        journey.retarget(AnimatedEffect(effect: described.effectValue), animation: Updates.animationForFlush ?? env.animation)
        applyTransform()
    }

    func applyTransform() {
        guard let effect else { return }
        let size = uiView.bounds.size
        let value = effect.effectValue(size: size)
        let toOrigin = CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        let back = CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0)
        let wanted = CATransform3DConcat(CATransform3DConcat(toOrigin, value.layerTransform), back)
        if !CATransform3DEqualToTransform(uiView.layer.transform, wanted) { uiView.layer.transform = wanted }
    }

    override func dispose() {
        journey.dispose()
        super.dispose()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        applyTransform()
    }
}

extension GeometryEffect {
    public func body(content: Content) -> some View {
        _GeometryEffectView(content: content, effect: self)
    }
}

public struct _IgnoredByLayoutEffect<Base: GeometryEffect>: GeometryEffect {
    public var base: Base
    public init(_ base: Base) { self.base = base }
    public var animatableData: Base.AnimatableData {
        get { base.animatableData }
        set { base.animatableData = newValue }
    }
    public func effectValue(size: CGSize) -> ProjectionTransform { base.effectValue(size: size) }
}

extension GeometryEffect {
    public func ignoredByLayout() -> _IgnoredByLayoutEffect<Self> { _IgnoredByLayoutEffect(self) }
}

extension ProjectionTransform {
    public var isIdentity: Bool { self == ProjectionTransform() }
    public var isAffine: Bool { m13 == 0 && m23 == 0 && m33 == 1 }

    public init(_ transform: CATransform3D) {
        self.init()
        m11 = transform.m11; m12 = transform.m12; m13 = transform.m14
        m21 = transform.m21; m22 = transform.m22; m23 = transform.m24
        m31 = transform.m41; m32 = transform.m42; m33 = transform.m44
    }

    public func concatenating(_ rhs: ProjectionTransform) -> ProjectionTransform {
        var result = ProjectionTransform()
        let a = [[m11, m12, m13], [m21, m22, m23], [m31, m32, m33]]
        let b = [[rhs.m11, rhs.m12, rhs.m13], [rhs.m21, rhs.m22, rhs.m23], [rhs.m31, rhs.m32, rhs.m33]]
        var c = [[CGFloat]](repeating: [0, 0, 0], count: 3)
        for row in 0..<3 { for column in 0..<3 { for k in 0..<3 { c[row][column] += a[row][k] * b[k][column] } } }
        result.m11 = c[0][0]; result.m12 = c[0][1]; result.m13 = c[0][2]
        result.m21 = c[1][0]; result.m22 = c[1][1]; result.m23 = c[1][2]
        result.m31 = c[2][0]; result.m32 = c[2][1]; result.m33 = c[2][2]
        return result
    }

    public mutating func invert() -> Bool {
        let determinant = m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)
        guard abs(determinant) > 1e-12 else { return false }
        let inverse = ProjectionTransform.adjugate(self, determinant)
        self = inverse
        return true
    }

    public func inverted() -> ProjectionTransform {
        var copy = self
        return copy.invert() ? copy : self
    }

    private static func adjugate(_ t: ProjectionTransform, _ determinant: CGFloat) -> ProjectionTransform {
        var r = ProjectionTransform()
        r.m11 = (t.m22 * t.m33 - t.m23 * t.m32) / determinant
        r.m12 = (t.m13 * t.m32 - t.m12 * t.m33) / determinant
        r.m13 = (t.m12 * t.m23 - t.m13 * t.m22) / determinant
        r.m21 = (t.m23 * t.m31 - t.m21 * t.m33) / determinant
        r.m22 = (t.m11 * t.m33 - t.m13 * t.m31) / determinant
        r.m23 = (t.m13 * t.m21 - t.m11 * t.m23) / determinant
        r.m31 = (t.m21 * t.m32 - t.m22 * t.m31) / determinant
        r.m32 = (t.m12 * t.m31 - t.m11 * t.m32) / determinant
        r.m33 = (t.m11 * t.m22 - t.m12 * t.m21) / determinant
        return r
    }
}

extension CGAffineTransform {
    public init(_ m: ProjectionTransform) {
        self.init(a: m.m11, b: m.m12, c: m.m21, d: m.m22, tx: m.m31, ty: m.m32)
    }
}

protocol AnimatedModifierMaking {
    func makeAnimatedNode(_ env: EnvironmentValues) -> Node?
}

extension ModifiedContent: AnimatedModifierMaking where Modifier: Animatable {
    func makeAnimatedNode(_ env: EnvironmentValues) -> Node? {
        if modifier is any GeometryEffect || Modifier.AnimatableData.self == EmptyAnimatableData.self { return nil }
        let node = AnimatedModifierNode<Content, Modifier>()
        node.update(self, env)
        return node
    }
}

final class AnimatedModifierNode<C: View, M: ViewModifier & Animatable>: ContainerNode {
    var contentView: C?
    var shown: M? { journey.shown }
    lazy var journey = Journey<M> { [unowned self] in
        self.render()
        self.invalidateLayout()
        (self.env.host as? _HostingViewController)?.contentChanged()
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let modified = view as? ModifiedContent<C, M> else { return }
        contentView = modified.content
        journey.retarget(modified.modifier, animation: Updates.animationForFlush ?? env.animation)
        render()
    }

    func render() {
        guard let contentView, let shown else { return }
        let body = shown.body(content: _ViewModifier_Content(content: contentView))
        content = adopt(reconcile(content, AnyView(body), env))
    }

    override func dispose() {
        journey.dispose()
        super.dispose()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}
