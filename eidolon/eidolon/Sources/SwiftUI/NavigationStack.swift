import UIKit

// A NavigationStack is a UINavigationController whose pushed screens follow a path of values: NavigationLink(value:)
// adds a value to the path, the stack pushes the screen that navigationDestination(for:) gives for it, and a tap on the
// back button removes the value again. The path is the app's own binding when it has one, and the stack's own otherwise.
final class NavigationStackState {
    var builders: [ObjectIdentifier: (AnyHashable) -> any View] = [:]
    var getPath: () -> [AnyHashable] = { [] }
    var setPath: ([AnyHashable]) -> Void = { _ in }
    var internalPath: [AnyHashable] = []
    var entries: [(value: AnyHashable, controller: _HostingViewController)] = []

    func append(_ value: AnyHashable) { setPath(getPath() + [value]) }
}

public struct NavigationStack<Data, Root: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let root: Root
    let read: (() -> [AnyHashable])?
    let write: (([AnyHashable]) -> Void)?
    func makeNode(_ env: EnvironmentValues) -> Node { let n = NavigationStackNode(); n.update(self, env); return n }
}

extension NavigationStack where Data == NavigationPath {
    public init(@ViewBuilder root: () -> Root) {
        self.root = root(); read = nil; write = nil
    }
    public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) {
        self.root = root()
        read = { path.wrappedValue.items }
        write = { path.wrappedValue = NavigationPath($0) }
    }
}

extension NavigationStack where Data: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, Data.Element: Hashable {
    public init(path: Binding<Data>, @ViewBuilder root: () -> Root) {
        self.root = root()
        read = { path.wrappedValue.map { AnyHashable($0) } }
        write = { items in path.wrappedValue = Data(items.compactMap { $0.base as? Data.Element }) }
    }
}

extension NavigationPath {
    public init<S: Sequence>(_ elements: S) where S.Element == AnyHashable { items = Array(elements) }
}

protocol NavigationStackLike {
    var stackRoot: any View { get }
    var stackRead: (() -> [AnyHashable])? { get }
    var stackWrite: (([AnyHashable]) -> Void)? { get }
}

extension NavigationStack: NavigationStackLike {
    var stackRoot: any View { root }
    var stackRead: (() -> [AnyHashable])? { read }
    var stackWrite: (([AnyHashable]) -> Void)? { write }
}

final class NavigationStackNode: LayoutNode {
    let rootController: _HostingViewController
    let navigation: UINavigationController
    let state = NavigationStackState()

    init() {
        rootController = _HostingViewController(rootView: EmptyView())
        navigation = UINavigationController(rootViewController: rootController)
        super.init(view: navigation.view)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let stack = view as? NavigationStackLike else { return }
        if navigation.parent == nil, let host = env.host { host.addChild(navigation) }
        if let read = stack.stackRead, let write = stack.stackWrite {
            state.getPath = read
            state.setPath = write
        } else {
            state.getPath = { [state] in state.internalPath }
            state.setPath = { [weak self, state] in
                state.internalPath = $0
                self?.syncPath()
            }
        }
        var inner = env
        inner.stackState = state
        stackEnvironment = inner
        rootController.setRootView(stack.stackRoot, env: inner)
        if let child = rootController.root { child.parent = self }
        syncPath()
    }

    var stackEnvironment = EnvironmentValues()

    func syncPath() {
        let wanted = state.getPath()
        var keep = 0
        while keep < state.entries.count, keep < wanted.count, state.entries[keep].value == wanted[keep] { keep += 1 }
        if keep < state.entries.count {
            let target = keep == 0 ? rootController : state.entries[keep - 1].controller
            state.entries.removeSubrange(keep...)
            if navigation.viewControllers.contains(where: { $0 === target }) { navigation.popToViewController(target, animated: true) }
        }
        for index in keep..<wanted.count {
            let value = wanted[index]
            guard let build = state.builders[ObjectIdentifier(type(of: value.base))] else {
                _Unsupported.note("NavigationStack path", "a value in the path has no navigationDestination(for:) to show it, so nothing is pushed for it")
                break
            }
            let controller = _HostingViewController(rootView: EmptyView())
            var inner = stackEnvironment
            inner.dismiss = DismissAction(action: { [weak controller, weak self] in
                guard let controller, let self, let position = self.state.entries.firstIndex(where: { $0.controller === controller }) else { return }
                self.state.setPath(Array(self.state.getPath().prefix(position)))
            })
            controller.setRootView(build(value), env: inner)
            controller.onPopped = { [weak self, weak controller] in
                guard let self, let controller, let position = self.state.entries.firstIndex(where: { $0.controller === controller }) else { return }
                self.state.entries.removeSubrange(position...)
                self.state.setPath(Array(self.state.getPath().prefix(position)))
            }
            state.entries.append((value, controller))
            navigation.pushViewController(controller, animated: true)
        }
        // the screens follow the state of the views that made them
        for entry in state.entries {
            guard let build = state.builders[ObjectIdentifier(type(of: entry.value.base))] else { continue }
            entry.controller.setRootView(build(entry.value), env: entry.controller.baseEnv)
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
}
