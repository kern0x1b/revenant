import UIKit
import CoreGraphics

final class HostState {
    var rootView: any View
    var root: Node?
    var baseEnv = EnvironmentValues()
    init(rootView: any View) { self.rootView = rootView }
}

open class _HostingViewController: UIViewController {
    let state: HostState

    var rootView: any View {
        get { state.rootView }
        set { state.rootView = newValue }
    }

    var root: Node? {
        get { state.root }
        set { state.root = newValue }
    }

    var baseEnv: EnvironmentValues {
        get { state.baseEnv }
        set { state.baseEnv = newValue }
    }

    init(rootView: any View) {
        state = HostState(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        Updates.hosts.append(WeakHost(host: self))
    }

    required public init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setRootView(_ view: any View, env: EnvironmentValues) {
        rootView = view
        baseEnv = env
        if isViewLoaded { rebuild() }
    }

    open override func loadView() {
        let v = _HostRootView(frame: UIScreen.main.applicationFrame)
        v.backgroundColor = .white
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view = v
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        rebuild()
    }

    func rebuild() {
        var env = baseEnv
        env.host = self
        env.scenePhase = AppRuntime.scenePhase
        root = reconcile(root, rootView, env)
        contentChanged()
    }

    var items: [LayoutNode] { root?.flattened ?? [] }

    func contentChanged() {
        guard isViewLoaded else { return }
        root?.mount()
        syncSubviews(view, items)
        view.setNeedsLayout()
    }

    var onPopped: (() -> Void)?

    // The screen's editing state is UIKit's own (editButtonItem, setEditing); lists and edit buttons follow it.
    var editingObservers: [ObjectIdentifier: (Bool) -> Void] = [:]
    open override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        for observer in Array(editingObservers.values) { observer(animated) }
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent { onPopped?() }
    }

    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let layoutStart = CFAbsoluteTimeGetCurrent()
        defer { LayoutCounters.layoutTime += CFAbsoluteTimeGetCurrent() - layoutStart }
        let bounds = view.bounds
        let nodes = items
        guard !nodes.isEmpty else { return }
        let proposal = ProposedSize(width: bounds.size.width, height: bounds.size.height)
        var sizes = nodes.map { $0.sizeThatFits(proposal) }
        if nodes.count == 1 { sizes[0] = CGSize(width: min(sizes[0].width, bounds.size.width), height: min(sizes[0].height, bounds.size.height)) }
        var y = (bounds.size.height - sizes.reduce(0) { $0 + $1.height }) / 2
        for (n, s) in zip(nodes, sizes) {
            n.place(CGRect(x: (bounds.size.width - s.width) / 2, y: max(0, y), width: s.width, height: s.height))
            y += s.height
        }
    }
}

open class UIHostingController<Content: View>: _HostingViewController {
    public init(rootView: Content) { super.init(rootView: rootView) }
    public var sizingOptions: UIHostingControllerSizingOptions = [] {
        didSet {
            guard sizingOptions.contains(.preferredContentSize) else { return }
            let size = sizeThatFits(in: CGSize(width: 320, height: 1e6))
            if #available(iOS 7.0, *) { preferredContentSize = size } else { setValue(NSValue(cgSize: size), forKey: "contentSizeForViewInPopover") }
        }
    }
    public func sizeThatFits(in size: CGSize) -> CGSize {
        let proposal = ProposedSize(width: size.width, height: size.height >= 1e5 ? nil : size.height)
        return items.first?.sizeThatFits(proposal) ?? .zero
    }
    required public init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
