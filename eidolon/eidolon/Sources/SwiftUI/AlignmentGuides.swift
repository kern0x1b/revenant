import UIKit
import CoreGraphics

struct StackGuide {
    let key: String
    let defaultValue: (ViewDimensions) -> CGFloat
    let custom: Bool
}

extension HorizontalAlignment {
    var guide: StackGuide { StackGuide(key: "h:" + id, defaultValue: defaultValue, custom: custom != nil) }
}

extension VerticalAlignment {
    var guide: StackGuide { StackGuide(key: "v:" + id, defaultValue: defaultValue, custom: custom != nil) }
}

struct AlignmentGuideModifier: NodeModifier {
    let key: String
    let compute: (ViewDimensions) -> CGFloat
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AlignmentGuideNode() }
}

final class AlignmentGuideNode: Node {
    var child: Node?
    var key = ""
    var compute: (ViewDimensions) -> CGFloat = { _ in 0 }
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! AlignmentGuideModifier
        key = modifier.key
        compute = modifier.compute
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

func dimensions(_ kid: LayoutNode, _ size: CGSize, upTo container: Node) -> ViewDimensions {
    var chain: [AlignmentGuideNode] = []
    var current: Node? = kid
    while let node = current, node !== container {
        if let guide = node as? AlignmentGuideNode { chain.append(guide) }
        current = node.parent
    }
    var d = ViewDimensions(width: size.width, height: size.height)
    for guide in chain { d.explicit[guide.key] = guide.compute(d) }
    return d
}

func hasGuides(_ kids: [LayoutNode], upTo container: Node) -> Bool {
    kids.contains { kid in
        if kid is ExplicitAlignmentProvider { return true }
        var current: Node? = kid
        while let node = current, node !== container {
            if node is AlignmentGuideNode { return true }
            current = node.parent
        }
        return false
    }
}

func alignedOffsets(_ kids: [LayoutNode], _ sizes: [CGSize], _ guide: StackGuide, _ cross: Axis, upTo container: Node) -> (offsets: [CGFloat], extent: CGFloat) {
    let lines = zip(kids, sizes).map { kid, size -> CGFloat in
        let d = dimensions(kid, size, upTo: container)
        return d.explicit[guide.key] ?? (kid as? ExplicitAlignmentProvider)?.explicitGuide(key: guide.key, size: size) ?? guide.defaultValue(d)
    }
    let before = lines.max() ?? 0
    let after = zip(lines, sizes).map { $1[cross] - $0 }.max() ?? 0
    return (lines.map { before - $0 }, before + after)
}

extension View {
    public func alignmentGuide(_ g: HorizontalAlignment, computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View {
        _ModifiedView(content: self, modifier: AlignmentGuideModifier(key: g.guide.key, compute: computeValue))
    }
    public func alignmentGuide(_ g: VerticalAlignment, computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View {
        _ModifiedView(content: self, modifier: AlignmentGuideModifier(key: g.guide.key, compute: computeValue))
    }
}
