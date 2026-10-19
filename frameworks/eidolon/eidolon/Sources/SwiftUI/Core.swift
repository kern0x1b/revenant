import UIKit
@_exported import CoreGraphics
@_exported import UIKit
@_exported import Foundation
@_exported import Combine

@MainActor @preconcurrency public protocol View {
    associatedtype Body: View
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs
    static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
    static func _viewListCount(inputs: _ViewListCountInputs) -> Int?
    @ViewBuilder var body: Body { get }
}

extension View {
    /// The body as a view, which is how a container reads a view's children the way SwiftUI does: a
    /// custom view that only stands for a group is that group, not a leaf of its own. The port's own, so
    /// it is not public API: an app reads a container's children through `ForEach(subviews:)` and
    /// `Group(subviews:)`, which is the interface 26.2 declares.
    var bodyView: any View {
        self is any PrimitiveView ? AnyView(self) : AnyView(body)
    }
}

extension View {
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var outputs = _ViewOutputs()
        outputs.node = makeNode(view.value, inputs.environment)
        return outputs
    }

    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        var outputs = _ViewListOutputs()
        outputs.nodes = [makeNode(view.value, inputs.environment)]
        return outputs
    }

    public static func _viewListCount(inputs: _ViewListCountInputs) -> Int? { nil }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError("Never has no body") }
}

protocol PrimitiveView {
    func makeNode(_ env: EnvironmentValues) -> Node
}


func neverBody(_ type: Any.Type) -> Never { fatalError("\(type) is a primitive view") }

public struct EmptyView: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public init() {}
    var childViews: [any View] { [] }
}

public struct TupleView<T>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public var value: T
    let views: [any View]
    public init(_ value: T) {
        self.value = value
        views = Mirror(reflecting: value).children.map { $0.value as! any View }
    }
    init(_ value: T, views: [any View]) { self.value = value; self.views = views }
    var childViews: [any View] { views }
}

public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    enum Storage { case trueContent(TrueContent), falseContent(FalseContent) }
    let storage: Storage
    var content: any View {
        switch storage { case .trueContent(let v): return v; case .falseContent(let v): return v }
    }
    var childViews: [any View] { [content] }
}

protocol BranchView { var branch: Bool { get } }
extension _ConditionalContent: BranchView {
    var branch: Bool { if case .trueContent = storage { return true } else { return false } }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension Optional: PrimitiveView, GroupView where Wrapped: View {
    var childViews: [any View] { self.map { [$0] } ?? [] }
}

public struct Group<Content: View>: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    var childViews: [any View] { [content] }
}

public struct AnyView: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let view: any View
    public init<V: View>(_ view: V) { self.view = view }
    var childViews: [any View] { [view] }
}

@resultBuilder
public struct ViewBuilder {
    public static func buildExpression<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)> {
        var views: [any View] = []
        for v in repeat each content { views.append(v) }
        return TupleView((repeat each content), views: views)
    }
    public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildOptional<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildEither<T: View, F: View>(first: T) -> _ConditionalContent<T, F> { .init(storage: .trueContent(first)) }
    public static func buildEither<T: View, F: View>(second: F) -> _ConditionalContent<T, F> { .init(storage: .falseContent(second)) }
    public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView { AnyView(content) }
}

protocol GroupView: PrimitiveView {
    var childViews: [any View] { get }
}

extension GroupView {
    func makeNode(_ env: EnvironmentValues) -> Node {
        let node = GroupNode(children: groupChildren(self, env).map { SwiftUI.makeNode($0, env) })
        node.branch = (self as? BranchView)?.branch
        return node
    }
}

protocol EnvironmentGroupView: GroupView {
    func childViews(in env: EnvironmentValues) -> [any View]
}

func groupChildren(_ view: GroupView, _ env: EnvironmentValues) -> [any View] {
    (view as? EnvironmentGroupView)?.childViews(in: env) ?? view.childViews
}

func withEnvironment(_ view: any View, _ apply: @escaping (inout EnvironmentValues) -> Void) -> any View {
    _ModifiedView(content: AnyView(view), modifier: EnvironmentModifier(apply: apply, onUpdate: nil))
}

func makeNode(_ view: any View, _ env: EnvironmentValues) -> Node {
    if let representable = view as? _RepresentableHost, let node = representable._makeRepresentableNode(env) as? Node {
        node.viewType = type(of: view)
        node.env = env
        return node
    }
    if let primitive = view as? PrimitiveView {
        let node = primitive.makeNode(env)
        node.viewType = type(of: view)
        node.env = env
        return node
    }
    if let animated = view as? AnimatedModifierMaking, let node = animated.makeAnimatedNode(env) {
        node.viewType = type(of: view)
        node.env = env
        return node
    }
    let node = CompositeNode(view: view)
    node.env = env
    node.render()
    return node
}
