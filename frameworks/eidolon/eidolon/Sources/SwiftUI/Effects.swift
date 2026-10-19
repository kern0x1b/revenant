import UIKit
import CoreGraphics

struct VisualEffect {
    var opacity: CGFloat?
    var cornerRadius: CGFloat?
    var borderColor: UIColor?
    var borderWidth: CGFloat = 0
    var shadowColor: UIColor?
    var shadowRadius: CGFloat = 0
    var shadowOffset = CGSize.zero
    var clips = false
    var hidden = false
    var offset = CGSize.zero
    var rotation: CGFloat = 0
    var rotationAnchor = UnitPoint.center
    var scale = CGSize(width: 1, height: 1)
    var scaleAnchor = UnitPoint.center
    var interaction: Bool?
    var dimmed = false   // .disabled dims what it covers; .allowsHitTesting does not

    // an effect that only turns touches on or off, which is all .disabled and .allowsHitTesting say
    var onlyInteraction: Bool {
        opacity == nil && cornerRadius == nil && borderColor == nil && borderWidth == 0 && shadowColor == nil && shadowRadius == 0
            && shadowOffset == .zero && !clips && !hidden && offset == .zero && rotation == 0 && scale == CGSize(width: 1, height: 1)
    }
}

struct EffectModifier: NodeModifier {
    let effect: VisualEffect
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { EffectNode() }
}

final class EffectNode: ContainerNode {
    var effect = VisualEffect()

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        effect = (m.modifierValue as! EffectModifier).effect
        content = adopt(reconcile(content, m.modifiedContent, env))
        let layer = uiView.layer
        uiView.alpha = (effect.opacity ?? 1) * (effect.dimmed ? 0.4 : 1)
        uiView.isHidden = effect.hidden
        layer.cornerRadius = effect.cornerRadius ?? 0
        layer.borderWidth = effect.borderWidth
        layer.borderColor = effect.borderColor?.cgColor
        layer.masksToBounds = effect.clips || effect.cornerRadius != nil
        if let shadow = effect.shadowColor {
            layer.shadowColor = shadow.cgColor
            layer.shadowRadius = effect.shadowRadius
            layer.shadowOffset = effect.shadowOffset
            layer.shadowOpacity = 1
            layer.masksToBounds = false
        } else {
            layer.shadowOpacity = 0
        }
        if let interaction = effect.interaction { uiView.isUserInteractionEnabled = interaction }
        applyTransform(uiView.bounds.size)
    }

    func applyTransform(_ size: CGSize) {
        func around(_ anchor: UnitPoint, _ body: (CGAffineTransform) -> CGAffineTransform) -> CGAffineTransform {
            let dx = (anchor.x - 0.5) * size.width, dy = (anchor.y - 0.5) * size.height
            let moved = CGAffineTransformMakeTranslation(dx, dy)
            return CGAffineTransformTranslate(body(moved), -dx, -dy)
        }
        var transform = CGAffineTransformIdentity
        if effect.scale.width != 1 || effect.scale.height != 1 {
            transform = around(effect.scaleAnchor) { CGAffineTransformScale($0, effect.scale.width, effect.scale.height) }
        }
        if effect.rotation != 0 {
            transform = CGAffineTransformConcat(transform, around(effect.rotationAnchor) { CGAffineTransformRotate($0, effect.rotation) })
        }
        let now = uiView.transform
        if now.a != transform.a || now.b != transform.b || now.c != transform.c || now.d != transform.d || now.tx != transform.tx || now.ty != transform.ty {
            uiView.transform = transform
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: effect.offset.width, y: effect.offset.height, width: size.width, height: size.height))
        if effect.rotationAnchor != .center || effect.scaleAnchor != .center { applyTransform(size) }
    }
}

struct DecorationModifier: NodeModifier {
    let decoration: () -> any View
    let above: Bool
    let alignment: Alignment
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { DecorationNode() }
}

final class DecorationNode: ContainerNode {
    var contentNode: Node?
    var decorationNode: Node?
    var above = true
    var alignment = Alignment.center

    override var disposableChildren: [Node] { [contentNode, decorationNode].compactMap { $0 } }

    override var children: [LayoutNode] {
        above ? (contentNode?.flattened ?? []) + (decorationNode?.flattened ?? [])
              : (decorationNode?.flattened ?? []) + (contentNode?.flattened ?? [])
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let decoration = m.modifierValue as! DecorationModifier
        above = decoration.above
        alignment = decoration.alignment
        contentNode = adopt(reconcile(contentNode, m.modifiedContent, env))
        decorationNode = adopt(reconcile(decorationNode, decoration.decoration(), env))
    }

    override func mountContents() {
        syncSubviews(uiView, children)
        contentNode?.mount()
        decorationNode?.mount()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        contentNode?.flattened.first?.sizeThatFits(p) ?? .zero
    }

    override func layoutContents(_ size: CGSize) {
        let box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        contentNode?.flattened.first?.place(box)
        for node in decorationNode?.flattened ?? [] {
            let wanted = node.sizeThatFits(ProposedSize(width: size.width, height: size.height))
            let x = alignment.horizontal.raw < 0 ? 0 : alignment.horizontal.raw > 0 ? size.width - wanted.width : (size.width - wanted.width) / 2
            let y = alignment.vertical.raw < 0 ? 0 : alignment.vertical.raw > 0 ? size.height - wanted.height : (size.height - wanted.height) / 2
            node.place(CGRect(x: x, y: y, width: wanted.width, height: wanted.height))
        }
    }
}

extension View {
    func effect(_ change: (inout VisualEffect) -> Void) -> some View {
        var effect = VisualEffect()
        change(&effect)
        return _ModifiedView(content: self, modifier: EffectModifier(effect: effect))
    }

    public func opacity(_ opacity: Double) -> some View { effect { $0.opacity = CGFloat(opacity) } }
    public func cornerRadius(_ radius: CGFloat, antialiased: Bool = true) -> some View { effect { $0.cornerRadius = radius } }
    public func clipped(antialiased: Bool = false) -> some View { effect { $0.clips = true } }
    public func hidden() -> some View { effect { $0.hidden = true } }
    public func disabled(_ disabled: Bool) -> some View { effect { $0.interaction = !disabled; $0.dimmed = disabled } }
    public func allowsHitTesting(_ enabled: Bool) -> some View { effect { $0.interaction = enabled } }
    public func offset(_ size: CGSize) -> some View { effect { $0.offset = size } }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View { effect { $0.offset = CGSize(width: x, height: y) } }
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View {
        effect { $0.rotation = CGFloat(angle.radians); $0.rotationAnchor = anchor }
    }
    public func scaleEffect(_ scale: CGFloat, anchor: UnitPoint = .center) -> some View {
        effect { $0.scale = CGSize(width: scale, height: scale); $0.scaleAnchor = anchor }
    }
    public func scaleEffect(_ scale: CGSize, anchor: UnitPoint = .center) -> some View { effect { $0.scale = scale; $0.scaleAnchor = anchor } }
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some View {
        effect { $0.scale = CGSize(width: x, height: y); $0.scaleAnchor = anchor }
    }
    public func shadow(color: Color = Color.black.opacity(0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        effect { $0.shadowColor = color.uiColor; $0.shadowRadius = radius; $0.shadowOffset = CGSize(width: x, height: y) }
    }
    public func border(_ color: Color, width: CGFloat = 1) -> some View {
        effect { $0.borderColor = color.uiColor; $0.borderWidth = width }
    }
    public func overlay<Overlay: View>(_ overlay: Overlay, alignment: Alignment = .center) -> some View {
        _ModifiedView(content: self, modifier: DecorationModifier(decoration: { overlay }, above: true, alignment: alignment))
    }
    public func overlay<Overlay: View>(alignment: Alignment = .center, @ViewBuilder content: @escaping () -> Overlay) -> some View {
        _ModifiedView(content: self, modifier: DecorationModifier(decoration: { content() }, above: true, alignment: alignment))
    }
    public func background<Background: View>(_ background: Background, alignment: Alignment = .center) -> some View {
        _ModifiedView(content: self, modifier: DecorationModifier(decoration: { background }, above: false, alignment: alignment))
    }
    public func background<Background: View>(alignment: Alignment = .center, @ViewBuilder content: @escaping () -> Background) -> some View {
        _ModifiedView(content: self, modifier: DecorationModifier(decoration: { content() }, above: false, alignment: alignment))
    }
    public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some View {
        _ModifiedView(content: self, modifier: ClipShapeModifier(shape: { shape }))
    }
}

public struct FillStyle: Equatable {
    public var isEOFilled: Bool
    public var isAntialiased: Bool
    public init(eoFill: Bool = false, antialiased: Bool = true) { isEOFilled = eoFill; isAntialiased = antialiased }
}

struct ClipShapeModifier: NodeModifier {
    let shape: () -> any Shape
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ClipShapeNode() }
}

final class ClipShapeNode: ContainerNode {
    var shape: (any Shape)?
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        shape = (m.modifierValue as! ClipShapeModifier).shape()
        content = adopt(reconcile(content, m.modifiedContent, env))
        uiView.layer.masksToBounds = true
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        guard let shape else { return }
        let mask = CAShapeLayer()
        mask.path = shape.path(in: CGRect(x: 0, y: 0, width: size.width, height: size.height)).cgPath
        uiView.layer.mask = mask
    }
}
