import UIKit
import CoreGraphics

public struct GeometryProxy {
    public let size: CGSize
    weak var node: GeometryNode?
    public var safeAreaInsets: EdgeInsets { EdgeInsets() }
    public func frame(in space: CoordinateSpace) -> CGRect {
        let local = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let node, let view = node.uiView as UIView? else { return local }
        switch space {
        case .local:
            return local
        case .global:
            return view.convert(local, to: topmost(view))
        case .named(let name):
            return view.convert(local, to: namedSpace(name, above: node) ?? topmost(view))
        }
    }
}

func topmost(_ view: UIView) -> UIView {
    var root = view
    while let parent = root.superview { root = parent }
    return root
}

public struct GeometryReader<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public var content: (GeometryProxy) -> Content
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) { self.content = content }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = GeometryNode(); n.update(self, env); return n }
}

protocol GeometryReaderLike {
    func geometryContent(_ proxy: GeometryProxy) -> any View
}

extension GeometryReader: GeometryReaderLike {
    func geometryContent(_ proxy: GeometryProxy) -> any View { content(proxy) }
}

final class GeometryNode: ContainerNode {
    var source: GeometryReaderLike?
    var lastSize = CGSize.zero

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        source = view as? GeometryReaderLike
        rebuild(lastSize)
    }

    func rebuild(_ size: CGSize) {
        guard let source else { return }
        content = adopt(reconcile(content, source.geometryContent(GeometryProxy(size: size, node: self)), env))
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        CGSize(width: p.width ?? 10, height: p.height ?? 10)
    }

    override func layoutContents(_ size: CGSize) {
        if size != lastSize {
            lastSize = size
            rebuild(size)
            mount()
        }
        for kid in children {
            let wanted = kid.sizeThatFits(ProposedSize(width: size.width, height: size.height))
            kid.place(CGRect(x: 0, y: 0, width: wanted.width, height: wanted.height))
        }
    }
}

public struct LazyVStack<Content: View>: View, PrimitiveView, VStackLike {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let alignment: HorizontalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    var stackSpacing: CGFloat? { spacing }
    var stackAlignment: Int { alignment.raw }
    var stackGuide: StackGuide { alignment.guide }
    var stackContent: any View { content }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = StackNode(); n.axis = .vertical; n.update(self, env); return n }
}

public struct LazyHStack<Content: View>: View, PrimitiveView, VStackLike {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let alignment: VerticalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    var stackSpacing: CGFloat? { spacing }
    var stackAlignment: Int { alignment.raw }
    var stackGuide: StackGuide { alignment.guide }
    var stackContent: any View { content }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = StackNode(); n.axis = .horizontal; n.update(self, env); return n }
}

public struct PinnedScrollableViews: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1)
    public static let sectionFooters = PinnedScrollableViews(rawValue: 2)
}

public struct Form<Content: View>: View, PrimitiveView, EnvironmentGroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    var childViews: [any View] { [_GroupedForm(content: content)] }
    func childViews(in env: EnvironmentValues) -> [any View] {
        [applyStyle(env, FormStyleConfiguration(content: .init(wrapped: content))) { _GroupedForm(content: content) }]
    }
}

public struct Label<Title: View, Icon: View>: View, PrimitiveView, EnvironmentGroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let title: Title
    let icon: Icon
    public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {
        self.title = title(); self.icon = icon()
    }
    var childViews: [any View] { [HStack(spacing: 6) { icon; title }] }
    func childViews(in env: EnvironmentValues) -> [any View] {
        guard let style = env.labelStyle else { return childViews }
        let configuration = LabelStyleConfiguration(title: .init(content: title), icon: .init(content: icon))
        return [withEnvironment(style(configuration)) { $0.labelStyle = nil }]
    }
}

extension Label where Title == LabelStyleConfiguration.Title, Icon == LabelStyleConfiguration.Icon {
    public init(_ configuration: LabelStyleConfiguration) {
        self.init(title: { configuration.title }, icon: { configuration.icon })
    }
}

extension Label where Title == Text, Icon == Image {
    public init(_ titleKey: LocalizedStringKey, image name: String) {
        self.init(title: { Text(titleKey) }, icon: { Image(name) })
    }
    public init(_ titleKey: LocalizedStringKey, systemImage name: String) {
        self.init(title: { Text(titleKey) }, icon: { Image(systemName: name) })
    }
}

public struct TabView<SelectionValue: Hashable, Content: View>: View, PrimitiveView, EnvironmentGroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let selection: Binding<SelectionValue>?
    let content: Content
    var childViews: [any View] { [_BarTabs(source: self)] }
    func childViews(in env: EnvironmentValues) -> [any View] {
        guard let paging = env.paging else { return childViews }
        return [_PagedTabs(source: self, settings: paging)]
    }
}

extension TabView where SelectionValue == Int {
    @_disfavoredOverload
    public init(@ViewBuilder content: () -> Content) { self.init(selection: nil, content: content()) }
    @_disfavoredOverload
    public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content())
    }
}

protocol TabViewLike {
    var tabChildren: [any View] { get }
    var tabSelectedIndex: Int? { get }
    func tabSelect(_ index: Int)
}

// The pages of a tab view: what the builder made, with a ForEach or a group opened into its views.
func tabPages(_ view: any View) -> [any View] {
    if let each = view as? ForEachLike { return each.identifiedViews.flatMap { tabPages($0.1) } }
    if let group = view as? GroupView, !(view is EnvironmentGroupView), !(view is TaggedViewLike) { return group.childViews.flatMap(tabPages) }
    return [view]
}

extension TabView: TabViewLike {
    var tabChildren: [any View] { tabPages(content) }
    // a selection is matched to a page by its tag; without tags the page number is the selection
    var tabSelectedIndex: Int? {
        guard let value = selection?.wrappedValue else { return nil }
        let tags = tabChildren.map { ($0 as? TaggedViewLike)?.tagValue }
        if let index = tags.firstIndex(where: { $0 == AnyHashable(value) }) { return index }
        return value as? Int
    }
    func tabSelect(_ index: Int) {
        guard let selection else { return }
        let pages = tabChildren
        if index < pages.count, let tag = (pages[index] as? TaggedViewLike)?.tagValue, let value = tag.base as? SelectionValue {
            selection.wrappedValue = value
        } else if let value = index as? SelectionValue {
            selection.wrappedValue = value
        }
    }
}

struct TabItemModifier: NodeModifier {
    let label: () -> any View
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { TabItemNode() }
}

final class TabItemNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var title: String?
    var imageName: String?
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let label = (m.modifierValue as! TabItemModifier).label()
        title = findText(label)?.content
        imageName = findImage(label)?.name
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

func findImage(_ view: any View) -> Image? {
    if let image = view as? Image { return image }
    if let label = view as? LabelParts { return findImage(label.labelIcon) }
    if let group = view as? GroupView { for child in group.childViews { if let found = findImage(child) { return found } } }
    if let wrapper = view as? WrappedView { return findImage(wrapper.wrapped) }
    return nil
}

final class TabViewNode: LayoutNode {
    let tabs = UITabBarController()
    var hosts: [_HostingViewController] = []
    var delegateTarget = TabDelegate()

    init() {
        super.init(view: tabs.view)
        tabs.delegate = delegateTarget
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = (view as? _BarTabs)?.source else { return }
        if tabs.parent == nil, let host = env.host { host.addChild(tabs) }
        let children = source.tabChildren
        while hosts.count < children.count {
            hosts.append(_HostingViewController(rootView: EmptyView()))
        }
        if hosts.count > children.count { hosts.removeSubrange(children.count...) }
        for (index, child) in children.enumerated() {
            let host = hosts[index]
            host.setRootView(child, env: env)
            let item = tabItemInfo(child)
            host.tabBarItem = UITabBarItem(title: item.0 ?? "Item \(index + 1)",
                                           image: item.1.flatMap { UIImage(named: $0) },
                                           tag: index)
            host.tabBarItem.badgeValue = item.2
        }
        if tabs.viewControllers?.count != hosts.count {
            tabs.setViewControllers(hosts, animated: false)
        }
        delegateTarget.selected = { source.tabSelect($0) }
        if let index = source.tabSelectedIndex, index < hosts.count, tabs.selectedIndex != index {
            tabs.selectedIndex = index
        }
    }

    func tabItemInfo(_ view: any View) -> (String?, String?, String?) {
        var badge: String?
        var current: any View = view
        while true {
            // .tabItem is usually written before .tag, so the tag is what wraps it
            if let tagged = current as? TaggedViewLike { current = tagged.taggedContent; continue }
            guard let modified = current as? ModifiedViewLike else { break }
            if let trait = modified.modifierValue as? RowTraitModifier, let value = trait.badge { badge = badge ?? value }
            if let item = modified.modifierValue as? TabItemModifier {
                let label = item.label()
                return (findText(label)?.content, findImage(label)?.name, badge)
            }
            current = modified.modifiedContent
        }
        return (findText(view)?.content, nil, badge)
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
}

final class TabDelegate: NSObject, UITabBarControllerDelegate {
    var selected: (Int) -> Void = { _ in }
    func tabBarController(_ controller: UITabBarController, didSelect viewController: UIViewController) {
        selected(controller.selectedIndex)
    }
}

extension View {
    public func tabItem<V: View>(@ViewBuilder _ label: @escaping () -> V) -> some View {
        _ModifiedView(content: self, modifier: TabItemModifier(label: { label() }))
    }
}
