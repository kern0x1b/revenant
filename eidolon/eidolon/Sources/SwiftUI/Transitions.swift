import UIKit
import CoreGraphics

struct TransitionSpec {
    var fades = false
    var scale: CGFloat?
    var offset: CGSize?
    var removals: [TransitionSpec] = []
    var animation: Animation?

    init(fades: Bool = false, scale: CGFloat? = nil, offset: CGSize? = nil) {
        self.fades = fades; self.scale = scale; self.offset = offset
    }

    var removal: TransitionSpec { removals.first ?? self }

    static let opacity = TransitionSpec(fades: true, scale: nil, offset: nil)

    func apply(_ view: UIView, entering: Bool) {
        if fades { view.alpha = 0 }
        var transform = CGAffineTransformIdentity
        if let scale { transform = CGAffineTransformScale(transform, scale, scale) }
        if let offset { transform = CGAffineTransformTranslate(transform, offset.width, offset.height) }
        view.transform = transform
    }

    func reset(_ view: UIView) {
        if fades { view.alpha = 1 }
        view.transform = CGAffineTransformIdentity
    }
}

enum Transitions {
    nonisolated(unsafe) static var specs: [ObjectIdentifier: TransitionSpec] = [:]

    static func spec(for view: UIView) -> TransitionSpec? { specs[ObjectIdentifier(view)] }

    static func register(_ view: UIView, _ spec: TransitionSpec) { specs[ObjectIdentifier(view)] = spec }

    static func forget(_ view: UIView) { specs.removeValue(forKey: ObjectIdentifier(view)) }
}

struct TransitionModifier: NodeModifier {
    let spec: TransitionSpec
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { TransitionNode() }
}

final class TransitionNode: ContainerNode {
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let spec = (m.modifierValue as! TransitionModifier).spec
        content = adopt(reconcile(content, m.modifiedContent, env))
        Transitions.register(uiView, spec)
        for kid in children { Transitions.register(kid.uiView, spec) }
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

extension AnyTransition {
    var spec: TransitionSpec { storage }
}

extension View {
    public func transition(_ transition: AnyTransition) -> some View {
        _ModifiedView(content: self, modifier: TransitionModifier(spec: transition.spec))
    }
}
