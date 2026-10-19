import UIKit

public struct NavigationSplitViewVisibility: Equatable, Codable {
    let raw: Int
    public init(raw: Int) { self.raw = raw }
    public static let automatic = NavigationSplitViewVisibility(raw: 0)
    public static let all = NavigationSplitViewVisibility(raw: 1)
    public static let doubleColumn = NavigationSplitViewVisibility(raw: 2)
    public static let detailOnly = NavigationSplitViewVisibility(raw: 3)
    public init(from decoder: any Decoder) throws {
        raw = try decoder.singleValueContainer().decode(Int.self)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
    public static func == (lhs: NavigationSplitViewVisibility, rhs: NavigationSplitViewVisibility) -> Bool {
        lhs.raw == rhs.raw
    }
}

/// What a style is told about the split view it draws, and the view it draws for it. The release's own
/// columns are the same whichever style an app asks for, so the body is the columns as they are.
public protocol NavigationSplitViewStyle {
    associatedtype Body: View
    typealias Configuration = NavigationSplitViewStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct NavigationSplitViewStyleConfiguration {
    public var isExpanded: Bool
    public var horizontalSizeClass: Int
    public init() { isExpanded = true; horizontalSizeClass = 0 }
}

extension NavigationSplitViewStyle {
    public var columns: some View { makeBody(configuration: NavigationSplitViewStyleConfiguration()) }
}

public struct AutomaticNavigationSplitViewStyle: NavigationSplitViewStyle {
    public init() {}
    public func makeBody(configuration: NavigationSplitViewStyleConfiguration) -> some View { EmptyView() }
}
public struct BalancedNavigationSplitViewStyle: NavigationSplitViewStyle {
    public init() {}
    public func makeBody(configuration: NavigationSplitViewStyleConfiguration) -> some View { EmptyView() }
}
public struct ProminentDetailNavigationSplitViewStyle: NavigationSplitViewStyle {
    public init() {}
    public func makeBody(configuration: NavigationSplitViewStyleConfiguration) -> some View { EmptyView() }
}

extension NavigationSplitViewStyle where Self == AutomaticNavigationSplitViewStyle {
    public static var automatic: AutomaticNavigationSplitViewStyle { AutomaticNavigationSplitViewStyle() }
}
extension NavigationSplitViewStyle where Self == BalancedNavigationSplitViewStyle {
    public static var balanced: BalancedNavigationSplitViewStyle { BalancedNavigationSplitViewStyle() }
}
extension NavigationSplitViewStyle where Self == ProminentDetailNavigationSplitViewStyle {
    public static var prominentDetail: ProminentDetailNavigationSplitViewStyle { ProminentDetailNavigationSplitViewStyle() }
}

public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let sidebar: Sidebar
    let content: Content?
    let detail: Detail
    let visibility: Binding<NavigationSplitViewVisibility>?
    func makeNode(_ env: EnvironmentValues) -> Node { let n = SplitNode(); n.update(self, env); return n }
}

extension NavigationSplitView {
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar(), content: content(), detail: detail(), visibility: nil)
    }
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar(), content: content(), detail: detail(), visibility: columnVisibility)
    }
}

extension NavigationSplitView where Content == EmptyView {
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar(), content: nil, detail: detail(), visibility: nil)
    }
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.init(sidebar: sidebar(), content: nil, detail: detail(), visibility: columnVisibility)
    }
}

protocol SplitViewLike {
    var splitSidebar: any View { get }
    var splitContent: (any View)? { get }
    var splitDetail: any View { get }
}

extension NavigationSplitView: SplitViewLike {
    var splitSidebar: any View { sidebar }
    var splitContent: (any View)? { content }
    var splitDetail: any View { detail }
}

final class SplitNode: LayoutNode {
    let root = _HostingViewController(rootView: EmptyView())
    let navigation: UINavigationController
    var columns: [_HostingViewController] = []
    var source: SplitViewLike?

    init() {
        navigation = UINavigationController(rootViewController: root)
        super.init(view: navigation.view)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        if navigation.parent == nil, let host = env.host { host.addChild(navigation) }
        if UIDevice.current.userInterfaceIdiom == .pad {
            _Unsupported.pendingNote("NavigationSplitView columns on iPad")
        }
        let split = view as! SplitViewLike
        source = split
        root.setRootView(split.splitSidebar, env: stageEnv(env, 0))
        if let child = root.root { child.parent = self }
        for (index, column) in columns.enumerated() {
            column.setRootView(stageView(index + 1), env: stageEnv(env, index + 1))
        }
    }

    func stageView(_ stage: Int) -> any View {
        guard let source else { return EmptyView() }
        if stage == 1, let content = source.splitContent { return content }
        return source.splitDetail
    }

    var lastStage: Int { source?.splitContent == nil ? 1 : 2 }

    func stageEnv(_ env: EnvironmentValues, _ stage: Int) -> EnvironmentValues {
        var inner = env
        inner.splitStage = stage
        inner.splitPush = stage < lastStage ? { [weak self] clear in self?.push(from: stage, clear: clear) } : nil
        return inner
    }

    func push(from stage: Int, clear: @escaping () -> Void) {
        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { [weak self] in
            guard let self else { return }
            let next = stage + 1
            while self.columns.count >= next { self.columns.removeLast() }
            let controller = _HostingViewController(rootView: EmptyView())
            controller.setRootView(self.stageView(next), env: self.stageEnv(self.env, next))
            controller.onPopped = { [weak self, weak controller] in
                clear()
                if let self, let controller { self.columns.removeAll { $0 === controller } }
            }
            self.columns.append(controller)
            self.navigation.pushViewController(controller, animated: true)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
}

extension View {
    public func navigationSplitViewStyle<S: NavigationSplitViewStyle>(_ style: S) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad { _Unsupported.pendingNote("navigationSplitViewStyle on iPad") }
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.splitStyle = style.columns }, onUpdate: nil))
    }
    public func navigationSplitViewColumnWidth(_ width: CGFloat) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad { _Unsupported.pendingNote("navigationSplitViewColumnWidth on iPad") }
        return self
    }
    public func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad { _Unsupported.pendingNote("navigationSplitViewColumnWidth on iPad") }
        return self
    }
}
