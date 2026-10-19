import UIKit

struct ContentShapeModifier: NodeModifier {
    let path: (CGRect) -> Path
    let eoFill: Bool
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ContentShapeNode() }
}

final class ContentShapeNode: Node {
    var child: Node?
    var path: (CGRect) -> Path = { Path(CGRect(x: 0, y: 0, width: $0.size.width, height: $0.size.height)) }
    var eoFill = false
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! ContentShapeModifier
        path = modifier.path
        eoFill = modifier.eoFill
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }

    func contains(_ point: CGPoint, in view: UIView) -> Bool {
        guard let shaped = flattened.first?.uiView else { return true }
        let frame = shaped.convert(shaped.bounds, to: view)
        let local = CGPoint(x: point.x - frame.origin.x, y: point.y - frame.origin.y)
        let shape = path(CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        return shape.cgPath.contains(local, using: eoFill ? .evenOdd : .winding)
    }
}

func contentShape(below node: Node?) -> ContentShapeNode? {
    var current = node
    while let candidate = current {
        if let shaped = candidate as? ContentShapeNode { return shaped }
        let next = candidate.disposableChildren
        guard next.count == 1 else { return nil }
        current = next[0]
    }
    return nil
}

extension View {
    public func contentShape<S: Shape>(_ shape: S, eoFill: Bool = false) -> some View {
        _ModifiedView(content: self, modifier: ContentShapeModifier(path: { shape.path(in: $0) }, eoFill: eoFill))
    }
    public func baselineOffset(_ offset: CGFloat) -> some View {
        self.offset(y: -offset)
    }
    public func listSectionSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View {
        ignored(self, "listSectionSeparator", "a UITableView of iOS 6 draws no separator of its own between sections, only between rows")
    }
    public func navigationViewStyle<S: NavigationViewStyle>(_ style: S) -> some View {
        if S.self == DoubleColumnNavigationViewStyle.self && UIDevice.current.userInterfaceIdiom == .pad {
            _Unsupported.pendingNote("navigationViewStyle(.columns) on iPad")
        }
        return self
    }
    public func datePickerStyle<S: DatePickerStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.datePickerBody = { configuration in AnyView(style.makeBody(configuration: configuration)) }
        }, onUpdate: nil))
    }
}
