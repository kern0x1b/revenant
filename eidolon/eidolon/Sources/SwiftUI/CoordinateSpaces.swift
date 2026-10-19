import UIKit

struct CoordinateSpaceModifier: NodeModifier {
    let name: AnyHashable
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { CoordinateSpaceNode() }
}

final class CoordinateSpaceNode: Node {
    var child: Node?
    var name: AnyHashable = 0
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        name = (m.modifierValue as! CoordinateSpaceModifier).name
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

func namedSpace(_ name: AnyHashable, above node: Node) -> UIView? {
    var current = node.parent
    while let candidate = current {
        if let space = candidate as? CoordinateSpaceNode, space.name == name {
            return space.flattened.first?.uiView
        }
        current = candidate.parent
    }
    return nil
}

extension View {
    public func coordinateSpace<T: Hashable>(name: T) -> some View {
        _ModifiedView(content: self, modifier: CoordinateSpaceModifier(name: AnyHashable(name)))
    }
}
