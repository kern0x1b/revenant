import UIKit
import CoreGraphics

public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifier_Content<Self>
    @ViewBuilder func body(content: Content) -> Body
}

public struct _ViewModifier_Content<Modifier: ViewModifier>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: any View
    var childViews: [any View] { [content] }
}

public struct ModifiedContent<Content: View, Modifier: ViewModifier>: View, EnvironmentalBody {
    let content: Content
    let modifier: Modifier
    public var body: Modifier.Body { modifier.body(content: _ViewModifier_Content(content: content)) }
    func environmentalBody(_ env: EnvironmentValues) -> (any View)? {
        guard let environmental = modifier as? any EnvironmentalModifier else { return nil }
        return resolveEnvironmental(environmental, content, env)
    }
}

func resolveEnvironmental<M: EnvironmentalModifier>(_ modifier: M, _ content: any View, _ env: EnvironmentValues) -> any View {
    AnyView(content).modifier(modifier.resolve(in: env))
}

protocol EnvironmentalBody {
    func environmentalBody(_ env: EnvironmentValues) -> (any View)?
}

public protocol EnvironmentalModifier: ViewModifier where Body == Never {
    associatedtype ResolvedModifier: ViewModifier
    func resolve(in environment: EnvironmentValues) -> ResolvedModifier
}

extension EnvironmentalModifier {
    public func body(content: Content) -> Never { neverBody(Self.self) }
}


extension View {
    public func modifier<M: ViewModifier>(_ modifier: M) -> ModifiedContent<Self, M> { ModifiedContent(content: self, modifier: modifier) }
}

protocol NodeModifier {
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node
}

public struct _ModifiedView<Content: View, Modifier>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    let modifier: Modifier
    func makeNode(_ env: EnvironmentValues) -> Node {
        let node = (modifier as! NodeModifier).makeModifierNode(content, env)
        node.update(self, env)
        return node
    }
}

protocol ModifiedViewLike { var modifiedContent: any View { get }; var modifierValue: Any { get } }
extension _ModifiedView: ModifiedViewLike { var modifiedContent: any View { content }; var modifierValue: Any { modifier } }

struct PaddingModifier: NodeModifier {
    let insets: EdgeInsets
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PaddingNodeM() }
}

final class PaddingNodeM: ContainerNode {
    let inner = PaddingNode()
    override var flattened: [LayoutNode] { [inner] }
    override var disposableChildren: [Node] { [inner] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        self.env = env
        inner.parent = self
        let m = view as! ModifiedViewLike
        let insets = (m.modifierValue as! PaddingModifier).insets
        if insets != inner.insets { invalidateLayout() }
        inner.insets = insets
        inner.content = inner.adopt(reconcile(inner.content, m.modifiedContent, env))
    }
    override func mountContents() { inner.mount() }
}

struct FrameModifier: NodeModifier {
    var width: CGFloat?, height: CGFloat?, maxWidth: CGFloat?, maxHeight: CGFloat?
    var minWidth: CGFloat?, minHeight: CGFloat?
    var alignment = 0
    var fixed = false
    var vertical = 0
    var fixedAxes: Axis.Set = [.horizontal, .vertical]
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { FrameNodeM() }
}

final class FrameNodeM: ContainerNode {
    let inner = FrameNode()
    override var flattened: [LayoutNode] { [inner] }
    override var disposableChildren: [Node] { [inner] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        self.env = env
        inner.parent = self
        let m = view as! ModifiedViewLike
        let f = m.modifierValue as! FrameModifier
        let changed = f.width != inner.width || f.height != inner.height || f.maxWidth != inner.maxWidth || f.maxHeight != inner.maxHeight
            || f.minWidth != inner.minWidth || f.minHeight != inner.minHeight || f.alignment != inner.alignment || f.fixed != inner.fixed
            || f.vertical != inner.vertical || f.fixedAxes != inner.fixedAxes
        if changed { invalidateLayout() }
        inner.width = f.width; inner.height = f.height; inner.maxWidth = f.maxWidth; inner.maxHeight = f.maxHeight
        inner.minWidth = f.minWidth; inner.minHeight = f.minHeight; inner.alignment = f.alignment; inner.fixed = f.fixed
        inner.vertical = f.vertical; inner.fixedAxes = f.fixedAxes
        inner.content = inner.adopt(reconcile(inner.content, m.modifiedContent, env))
    }
    override func mountContents() { inner.mount() }
}

struct BackgroundModifier: NodeModifier {
    let color: UIColor
    let cornerRadius: CGFloat
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { BackgroundNodeM() }
}

final class BackgroundNodeM: ContainerNode {
    let inner = PaddingNode()
    override var flattened: [LayoutNode] { [inner] }
    override var disposableChildren: [Node] { [inner] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        self.env = env
        inner.parent = self
        let m = view as! ModifiedViewLike
        let b = m.modifierValue as! BackgroundModifier
        inner.uiView.backgroundColor = b.color
        inner.uiView.layer.cornerRadius = b.cornerRadius
        inner.content = inner.adopt(reconcile(inner.content, m.modifiedContent, env))
    }
    override func mountContents() { inner.mount() }
}

struct EnvironmentModifier: NodeModifier {
    let apply: (inout EnvironmentValues) -> Void
    let onUpdate: ((EnvironmentValues) -> Void)?
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { EnvironmentNode() }
}

final class EnvironmentNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let e = m.modifierValue as! EnvironmentModifier
        var inner = env
        e.apply(&inner)
        e.onUpdate?(inner)
        child = adopt(reconcile(child, m.modifiedContent, inner))
    }
    override func mountContents() { child?.mount() }
}

extension View {
    public func padding(_ length: CGFloat = 16) -> some View {
        padding(.all, length)
    }
    public func padding(_ insets: EdgeInsets) -> some View { _ModifiedView(content: self, modifier: PaddingModifier(insets: insets)) }
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let amount = length ?? 16
        return padding(EdgeInsets(top: edges.contains(.top) ? amount : 0,
                                  leading: edges.contains(.leading) ? amount : 0,
                                  bottom: edges.contains(.bottom) ? amount : 0,
                                  trailing: edges.contains(.trailing) ? amount : 0))
    }
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        _ModifiedView(content: self, modifier: FrameModifier(width: width, height: height, alignment: alignment.horizontal.raw, vertical: alignment.vertical.raw))
    }
    public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                      minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
                      alignment: Alignment = .center) -> some View {
        _ModifiedView(content: self, modifier: FrameModifier(width: nil, height: nil, maxWidth: maxWidth, maxHeight: maxHeight,
                                                             minWidth: minWidth, minHeight: minHeight, alignment: alignment.horizontal.raw, vertical: alignment.vertical.raw))
    }
    public func fixedSize() -> some View { _ModifiedView(content: self, modifier: FrameModifier(fixed: true)) }
    public func fixedSize(horizontal: Bool, vertical: Bool) -> some View {
        var axes: Axis.Set = []
        if horizontal { axes.insert(.horizontal) }
        if vertical { axes.insert(.vertical) }
        return _ModifiedView(content: self, modifier: FrameModifier(fixed: !axes.isEmpty, fixedAxes: axes))
    }
    public func layoutPriority(_ value: Double) -> some View {
        _ModifiedView(content: self, modifier: PriorityModifier(priority: value))
    }
    public func background(_ color: Color, cornerRadius: CGFloat = 0) -> some View {
        _ModifiedView(content: self, modifier: BackgroundModifier(color: color.uiColor, cornerRadius: cornerRadius))
    }
    public func font(_ font: Font?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.fontValue = font?.uiFont }, onUpdate: nil))
    }
    public func foregroundColor(_ color: Color?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.foregroundColor = color?.uiColor }, onUpdate: nil))
    }
    public func multilineTextAlignment(_ alignment: TextAlignment) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.textAlignment = alignment == .leading ? .left : alignment == .trailing ? .right : .center }, onUpdate: nil))
    }
    public func environmentObject<O: ObservableObject>(_ object: O) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.objects[ObjectIdentifier(O.self)] = object }, onUpdate: nil))
    }
    public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View {
        navigationTitle(text: titleKey.text)
    }
    public func navigationTitle<S: StringProtocol>(_ title: S) -> some View {
        navigationTitle(text: String(title))
    }
    func navigationTitle(text title: String) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { env in
            if env.host?.navigationItem.title != title { env.host?.navigationItem.title = title }
        }))
    }
    public func navigationBarTitle(_ titleKey: LocalizedStringKey) -> some View { navigationTitle(titleKey) }
    public func listStyle<S: ListStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.listStyleGrouped = style is GroupedListStyle || style is InsetGroupedListStyle }, onUpdate: nil))
    }
    public func onAppear(perform action: (() -> Void)? = nil) -> some View {
        _ModifiedView(content: self, modifier: AppearModifier(action: action, disappear: nil))
    }
}

public enum TextAlignment { case leading, center, trailing }

struct PriorityModifier: NodeModifier {
    let priority: Double
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PriorityNode() }
}

final class PriorityNode: ContainerNode {
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        content = adopt(reconcile(content, m.modifiedContent, env))
        layoutPriority = (m.modifierValue as! PriorityModifier).priority
        children.first?.layoutPriority = layoutPriority
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

struct AppearModifier: NodeModifier {
    let action: (() -> Void)?
    var disappear: (() -> Void)?
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AppearNode() }
}

final class AppearNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var appeared = false
    var disappear: (() -> Void)?

    override func dispose() {
        super.dispose()
        disappear?()
    }

    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        child = adopt(reconcile(child, m.modifiedContent, env))
        let modifier = m.modifierValue as! AppearModifier
        disappear = modifier.disappear
        if !appeared, let action = modifier.action {
            appeared = true
            DispatchQueue.main.async { action() }
        }
    }
    override func mountContents() { child?.mount() }
}
