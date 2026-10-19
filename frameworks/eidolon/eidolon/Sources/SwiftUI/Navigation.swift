import UIKit
import CoreGraphics

public struct NavigationView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = NavigationNode(); n.update(self, env); return n }
}

protocol NavigationViewLike { var navigationContent: any View { get } }
extension NavigationView: NavigationViewLike { var navigationContent: any View { content } }

final class NavigationNode: LayoutNode {
    let root: _HostingViewController
    let navigation: UINavigationController
    init() {
        root = _HostingViewController(rootView: EmptyView())
        navigation = UINavigationController(rootViewController: root)
        super.init(view: navigation.view)
    }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        if navigation.parent == nil, let host = env.host {
            host.addChild(navigation)
        }
        root.setRootView((view as! NavigationViewLike).navigationContent, env: env)
        if let child = root.root { child.parent = self }
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
}

public struct NavigationLink<Label: View, Destination: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let destination: Destination
    let label: Label
    var isActive: Binding<Bool>?
    public init(destination: Destination, @ViewBuilder label: () -> Label) { self.destination = destination; self.label = label() }
    public init(destination: Destination, isActive: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.destination = destination; self.label = label(); self.isActive = isActive
    }
    public init<V: Hashable>(destination: Destination, tag: V, selection: Binding<V?>, @ViewBuilder label: () -> Label) {
        self.destination = destination; self.label = label()
        isActive = Binding(get: { selection.wrappedValue == tag }, set: { selection.wrappedValue = $0 ? tag : (selection.wrappedValue == tag ? nil : selection.wrappedValue) })
    }
    public init(isActive: Binding<Bool>, @ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination(); self.label = label(); self.isActive = isActive
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = NavigationLinkNode(); n.update(self, env); return n }
}

extension NavigationLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: Destination) { self.init(destination: destination) { Text(titleKey) } }
    public init<S: StringProtocol>(_ title: S, destination: Destination) { self.init(destination: destination) { Text(title) } }
}

protocol NavigationLinkLike { var linkDestination: any View { get }; var linkLabel: any View { get }; var linkActive: Binding<Bool>? { get } }
extension NavigationLink: NavigationLinkLike {
    var linkDestination: any View { destination }
    var linkLabel: any View { label }
    var linkActive: Binding<Bool>? { isActive }
}

final class NavigationLinkNode: ContainerNode {
    var destination: (any View)?
    var active: Binding<Bool>?
    weak var pushed: _HostingViewController?
    let tapTarget = ControlTarget()
    var tapInstalled = false

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let l = view as! NavigationLinkLike
        destination = l.linkDestination
        active = l.linkActive
        // outside a list a link is tinted like a button
        let accent = Color(env.foregroundColor ?? env.tint ?? UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1))
        content = adopt(reconcile(content, env.list == nil ? AnyView(l.linkLabel).foregroundColor(accent) : l.linkLabel, env))
        if env.list == nil && !tapInstalled {
            tapInstalled = true
            tapTarget.action = { [weak self] in self?.activate() }
            let recognizer = UITapGestureRecognizer(target: tapTarget, action: #selector(ControlTarget.fire))
            uiView.addGestureRecognizer(recognizer)
            uiView.isUserInteractionEnabled = true
        }
        if let pushed, let host = env.host, host.navigationController?.viewControllers.contains(pushed) == true {
            pushed.setRootView(l.linkDestination, env: env)
        }
        guard let active else { return }
        if active.wrappedValue && pushed == nil {
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { [weak self] in
                guard let self, self.pushed == nil, self.active?.wrappedValue == true else { return }
                self.activate()
            }
            CFRunLoopWakeUp(CFRunLoopGetMain())
        } else if !active.wrappedValue, let pushed, let navigation = pushed.navigationController,
                  let index = navigation.viewControllers.firstIndex(where: { $0 === pushed }), index > 0 {
            self.pushed = nil
            navigation.popToViewController(navigation.viewControllers[index - 1], animated: true)
        }
    }

    func activate() {
        if let valued = destination as? _ValueDestination, let value = valued.value, let state = env.stackState {
            state.append(value)
            return
        }
        guard pushed == nil, let destination, let controller = pushDestination(destination, from: env) else { return }
        pushed = controller
        active?.wrappedValue = true
        controller.onPopped = { [weak self] in
            guard let self else { return }
            self.pushed = nil
            if self.active?.wrappedValue == true { self.active?.wrappedValue = false }
        }
    }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        let size = StackMeasure.vertical(children, p)
        guard env.list == nil else { return size }
        let width = children.map { $0.sizeThatFits(ProposedSize(width: p.width, height: nil)).width }.max() ?? size.width
        return CGSize(width: min(width, p.width ?? width), height: size.height)
    }
    override func layoutContents(_ size: CGSize) {
        var y: CGFloat = 0
        for kid in children {
            let s = kid.sizeThatFits(ProposedSize(width: size.width, height: nil))
            kid.place(CGRect(x: 0, y: y, width: size.width, height: s.height))
            y += s.height
        }
    }
}

enum StackMeasure {
    static func vertical(_ kids: [LayoutNode], _ p: ProposedSize) -> CGSize {
        var w: CGFloat = 0, h: CGFloat = 0
        for k in kids { let s = k.sizeThatFits(ProposedSize(width: p.width, height: nil)); w = max(w, s.width); h += s.height }
        return CGSize(width: p.width ?? w, height: h)
    }
}

@discardableResult
func pushDestination(_ destination: any View, from env: EnvironmentValues) -> _HostingViewController? {
    guard let navigation = env.host?.navigationController else { return nil }
    var destination = destination
    if let valued = destination as? _ValueDestination {
        guard let value = valued.value,
              let build = env.destinations[ObjectIdentifier(type(of: value.base))] else { return nil }
        destination = build(value)
    }
    let controller = _HostingViewController(rootView: EmptyView())
    var inner = env
    inner.dismiss = DismissAction(action: { [weak controller] in
        guard let controller, let stack = controller.navigationController,
              let index = stack.viewControllers.firstIndex(where: { $0 === controller }), index > 0 else { return }
        stack.popToViewController(stack.viewControllers[index - 1], animated: true)
    })
    controller.setRootView(destination, env: inner)
    navigation.pushViewController(controller, animated: true)
    return controller
}
