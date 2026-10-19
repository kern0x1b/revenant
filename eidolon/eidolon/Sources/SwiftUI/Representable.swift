import UIKit
import CoreGraphics

public struct UIViewRepresentableContext<Representable: UIViewRepresentable> {
    public let coordinator: Representable.Coordinator
    public var environment: EnvironmentValues
    public var transaction = Transaction()
}

public struct UIViewControllerRepresentableContext<Representable: UIViewControllerRepresentable> {
    public let coordinator: Representable.Coordinator
    public var environment: EnvironmentValues
    public var transaction = Transaction()
}

public protocol UIViewRepresentable: View, _RepresentableHost {
    associatedtype UIViewType: UIView
    associatedtype Coordinator = Void
    typealias Context = UIViewRepresentableContext<Self>
    func makeCoordinator() -> Coordinator
    func makeUIView(context: Context) -> UIViewType
    func updateUIView(_ uiView: UIViewType, context: Context)
    static func dismantleUIView(_ uiView: UIViewType, coordinator: Coordinator)
}

public struct _ProposedSize {
    public var width: CGFloat?
    public var height: CGFloat?
}

extension UIViewRepresentable where Coordinator == Void {
    public func makeCoordinator() -> Void { () }
}

extension UIViewRepresentable {
    public static func dismantleUIView(_ uiView: UIViewType, coordinator: Coordinator) {}
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
}

public protocol _RepresentableHost {
    func _makeRepresentableNode(_ env: EnvironmentValues) -> AnyObject
}

extension UIViewRepresentable {
    public func _makeRepresentableNode(_ env: EnvironmentValues) -> AnyObject {
        let node = RepresentableNode<Self>()
        node.update(self, env)
        return node
    }
}

final class RepresentableNode<R: UIViewRepresentable>: LayoutNode {
    var coordinator: R.Coordinator?
    var made: R.UIViewType?

    init() { super.init(view: UIView()) }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let representable = view as? R else { return }
        if coordinator == nil { coordinator = representable.makeCoordinator() }
        let context = UIViewRepresentableContext<R>(coordinator: coordinator!, environment: env)
        if made == nil {
            let created = representable.makeUIView(context: context)
            made = created
            replaceView(created)
        }
        representable.updateUIView(made!, context: context)
    }

    override func dispose() {
        super.dispose()
        if let made, let coordinator { R.dismantleUIView(made, coordinator: coordinator) }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        guard let made else { return .zero }
        if let representable = (env.host as Any?) as? R { _ = representable }
        let wanted = made.sizeThatFits(CGSize(width: p.width ?? infinity, height: p.height ?? infinity))
        if wanted.width > 0 || wanted.height > 0 {
            return CGSize(width: min(wanted.width, p.width ?? wanted.width), height: min(wanted.height, p.height ?? wanted.height))
        }
        return CGSize(width: p.width ?? 0, height: p.height ?? 0)
    }
}

public protocol UIViewControllerRepresentable: View, _RepresentableHost {
    associatedtype UIViewControllerType: UIViewController
    associatedtype Coordinator = Void
    typealias Context = UIViewControllerRepresentableContext<Self>
    func makeCoordinator() -> Coordinator
    func makeUIViewController(context: Context) -> UIViewControllerType
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context)
    static func dismantleUIViewController(_ uiViewController: UIViewControllerType, coordinator: Coordinator)
}

extension UIViewControllerRepresentable where Coordinator == Void {
    public func makeCoordinator() -> Void { () }
}

extension UIViewControllerRepresentable {
    public static func dismantleUIViewController(_ uiViewController: UIViewControllerType, coordinator: Coordinator) {}
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
}

final class ControllerRepresentableNode<R: UIViewControllerRepresentable>: LayoutNode {
    var coordinator: R.Coordinator?
    var controller: R.UIViewControllerType?

    init() { super.init(view: UIView()) }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let representable = view as? R else { return }
        if coordinator == nil { coordinator = representable.makeCoordinator() }
        let context = UIViewControllerRepresentableContext<R>(coordinator: coordinator!, environment: env)
        if controller == nil {
            let made = representable.makeUIViewController(context: context)
            controller = made
            env.host?.addChild(made)
            replaceView(made.view)
        }
        representable.updateUIViewController(controller!, context: context)
    }

    override func dispose() {
        super.dispose()
        if let controller, let coordinator { R.dismantleUIViewController(controller, coordinator: coordinator) }
        controller?.removeFromParent()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        CGSize(width: p.width ?? 0, height: p.height ?? 0)
    }
}

extension UIViewControllerRepresentable {
    public func _makeRepresentableNode(_ env: EnvironmentValues) -> AnyObject {
        let node = ControllerRepresentableNode<Self>()
        node.update(self, env)
        return node
    }
}

public struct ViewThatFits<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let axes: Axis.Set
    let content: Content
    public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content) {
        self.axes = axes; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ViewThatFitsNode(); n.update(self, env); return n }
}

protocol ViewThatFitsLike {
    var candidates: [any View] { get }
    var fitAxes: Axis.Set { get }
}

extension ViewThatFits: ViewThatFitsLike {
    var candidates: [any View] { (content as? GroupView)?.childViews ?? [content] }
    var fitAxes: Axis.Set { axes }
}

final class ViewThatFitsNode: ContainerNode {
    var options: [Node] = []
    var axes: Axis.Set = [.horizontal, .vertical]
    var chosen: Int = 0

    override var children: [LayoutNode] { options.indices.contains(chosen) ? options[chosen].flattened : [] }
    override var disposableChildren: [Node] { options }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let source = view as? ViewThatFitsLike else { return }
        axes = source.fitAxes
        let views = source.candidates
        var next: [Node] = []
        for (index, candidate) in views.enumerated() {
            next.append(adopt(reconcile(index < options.count ? options[index] : nil, candidate, env)))
        }
        options = next
    }

    func pick(_ p: ProposedSize) -> Int {
        for (index, option) in options.enumerated() {
            guard let node = option.flattened.first else { continue }
            let size = node.sizeThatFits(ProposedSize(width: nil, height: nil))
            let fitsWidth = !axes.contains(.horizontal) || p.width == nil || size.width <= p.width!
            let fitsHeight = !axes.contains(.vertical) || p.height == nil || size.height <= p.height!
            if fitsWidth && fitsHeight || index == options.count - 1 { return index }
        }
        return 0
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        chosen = pick(p)
        guard let node = options.indices.contains(chosen) ? options[chosen].flattened.first : nil else { return .zero }
        return node.sizeThatFits(p)
    }

    override func layoutContents(_ size: CGSize) {
        chosen = pick(ProposedSize(width: size.width, height: size.height))
        syncSubviews(uiView, children)
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    override func mountContents() {
        options.forEach { $0.mount() }
        syncSubviews(uiView, children)
    }
}

extension Color {
    public init(uiColor: UIColor) { self.init(uiColor) }
}

