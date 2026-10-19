import UIKit
import CoreGraphics

// iOS 6 draws one thing over the content: the status bar. That is the whole safe area here, so a view
// that ignores the safe area extends under the bar and one that does not is pushed below it.
func statusBarHeight() -> CGFloat {
    UIScreen.main.scale > 1 ? 40 : 20
}

struct ContainerFrameModifier: NodeModifier {
    let axes: Axis.Set
    let alignment: Alignment
    let count: Int?
    let span: Int
    let spacing: CGFloat
    let length: ((CGFloat, Axis) -> CGFloat)?
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ContainerFrameNode() }
}

final class ContainerFrameNode: LayoutNode {
    var axes: Axis.Set = .vertical
    var alignment = Alignment.center
    var count: Int?
    var span = 1
    var spacing: CGFloat = 0
    var length: ((CGFloat, Axis) -> CGFloat)?
    let inner = ContainerFrameInner()
    override var flattened: [LayoutNode] { [inner] }
    override var disposableChildren: [Node] { [inner] }
    init() { super.init(view: UIView()) }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        self.env = env
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! ContainerFrameModifier
        if modifier.axes != axes || modifier.alignment != alignment || modifier.count != count
            || modifier.span != span || modifier.spacing != spacing {
            invalidateLayout()
        }
        axes = modifier.axes; alignment = modifier.alignment
        count = modifier.count; span = modifier.span; spacing = modifier.spacing
        length = modifier.length
        inner.parent = self
        inner.content = inner.adopt(reconcile(inner.content, m.modifiedContent, env))
    }
    override func mountContents() { inner.mount() }

    // The container is whatever laid this view out: its parent's size, which is what the frame is relative to.
    private var container: CGSize {
        guard let host = uiView.superview, host.bounds.size.width > 0 else { return CGSize(width: 320, height: 480) }
        return host.bounds.size
    }

    private func extent(_ axis: Axis, _ whole: CGFloat) -> CGFloat {
        if let length { return length(whole, axis) }
        if let count, count > 0 {
            let share = (whole - spacing * CGFloat(count - 1)) / CGFloat(count)
            return share * CGFloat(span) + spacing * CGFloat(span - 1)
        }
        return whole
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let size = container
        let wanted = CGSize(width: axes.contains(.horizontal) ? extent(.horizontal, size.width) : p.width ?? size.width,
                            height: axes.contains(.vertical) ? extent(.vertical, size.height) : p.height ?? size.height)
        let kid = inner.sizeThatFits(ProposedSize(width: wanted.width, height: wanted.height))
        return CGSize(width: axes.contains(.horizontal) ? wanted.width : kid.width,
                      height: axes.contains(.vertical) ? wanted.height : kid.height)
    }

    override func layoutContents(_ size: CGSize) {
        let kid = inner.flattened.first?.sizeThatFits(ProposedSize(width: size.width, height: size.height)) ?? .zero
        let x = alignment.horizontal.raw < 0 ? 0 : alignment.horizontal.raw > 0 ? size.width - kid.width : (size.width - kid.width) / 2
        let y = alignment.vertical.raw < 0 ? 0 : alignment.vertical.raw > 0 ? size.height - kid.height : (size.height - kid.height) / 2
        inner.place(CGRect(x: x, y: y, width: kid.width, height: kid.height))
        uiView.bounds = CGRect(origin: .zero, size: size)
    }
}

final class ContainerFrameInner: ContainerNode {}

extension View {
    public func safeAreaInset<V: View>(edge: HorizontalEdge, alignment: VerticalAlignment = .center,
                                      spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View {
        HStack(spacing: spacing ?? 0) {
            if edge == .leading { content() }
            self
            if edge == .trailing { content() }
        }
    }
    public func safeAreaPadding(_ edges: Edge.Set = .all) -> some View {
        safeAreaPadding(edges, nil)
    }
    public func safeAreaPadding(_ length: CGFloat) -> some View {
        safeAreaPadding(.all, length)
    }
    public func safeAreaPadding(_ insets: EdgeInsets) -> some View {
        padding(EdgeInsets(top: insets.top + statusBarHeight(), leading: insets.leading,
                           bottom: insets.bottom, trailing: insets.trailing))
    }
    public func safeAreaPadding(_ edges: Edge.Set = .all, _ length: CGFloat?) -> some View {
        let bar = statusBarHeight()
        return padding(EdgeInsets(top: edges.contains(.top) ? length ?? bar : 0,
                                  leading: edges.contains(.leading) ? length ?? 0 : 0,
                                  bottom: edges.contains(.bottom) ? length ?? bar : 0,
                                  trailing: edges.contains(.trailing) ? length ?? 0 : 0))
    }
    public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center) -> some View {
        _ModifiedView(content: self, modifier: ContainerFrameModifier(axes: axes, alignment: alignment, count: nil,
                                                                      span: 1, spacing: 0, length: nil))
    }
    public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center,
                                       _ length: @escaping (CGFloat, Axis) -> CGFloat) -> some View {
        _ModifiedView(content: self, modifier: ContainerFrameModifier(axes: axes, alignment: alignment, count: nil,
                                                                      span: 1, spacing: 0, length: length))
    }
    public func containerRelativeFrame(_ axes: Axis.Set, count: Int, span: Int = 1, spacing: CGFloat,
                                       alignment: Alignment = .center) -> some View {
        _ModifiedView(content: self, modifier: ContainerFrameModifier(axes: axes, alignment: alignment, count: count,
                                                                      span: span, spacing: spacing, length: nil))
    }
}
