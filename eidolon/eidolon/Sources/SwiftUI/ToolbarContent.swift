import UIKit

public protocol ToolbarContent {
    associatedtype Body: ToolbarContent
    @ToolbarContentBuilder var body: Body { get }
    var _toolbarViews: [any View] { get }
}

extension ToolbarContent {
    public var _toolbarViews: [any View] { body._toolbarViews }
}

public protocol CustomizableToolbarContent: ToolbarContent where Body: CustomizableToolbarContent {}

extension Never: ToolbarContent, CustomizableToolbarContent {
    public var _toolbarViews: [any View] { [] }
}

extension ToolbarItem: ToolbarContent, CustomizableToolbarContent {
    public var _toolbarViews: [any View] { [self] }
}

extension ToolbarItemGroup: ToolbarContent {
    public var _toolbarViews: [any View] { [self] }
}

public struct TupleToolbarContent<T>: ToolbarContent, CustomizableToolbarContent {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let value: T
    let views: [any View]
    public var _toolbarViews: [any View] { views }
}

public struct _ConditionalToolbarContent<T: ToolbarContent, F: ToolbarContent>: ToolbarContent, CustomizableToolbarContent {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let views: [any View]
    public var _toolbarViews: [any View] { views }
}

public struct _OptionalToolbarContent<Wrapped: ToolbarContent>: ToolbarContent, CustomizableToolbarContent {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let views: [any View]
    public var _toolbarViews: [any View] { views }
}

@resultBuilder
public struct ToolbarContentBuilder {
    public static func buildExpression<C: ToolbarContent>(_ content: C) -> C { content }
    public static func buildBlock<C: ToolbarContent>(_ content: C) -> C { content }
    public static func buildBlock<each C: ToolbarContent>(_ content: repeat each C) -> TupleToolbarContent<(repeat each C)> {
        var views: [any View] = []
        for part in repeat each content { views += part._toolbarViews }
        return TupleToolbarContent(value: (repeat each content), views: views)
    }
    public static func buildIf<C: ToolbarContent>(_ content: C?) -> _OptionalToolbarContent<C> {
        _OptionalToolbarContent(views: content?._toolbarViews ?? [])
    }
    public static func buildEither<T: ToolbarContent, F: ToolbarContent>(first: T) -> _ConditionalToolbarContent<T, F> {
        _ConditionalToolbarContent(views: first._toolbarViews)
    }
    public static func buildEither<T: ToolbarContent, F: ToolbarContent>(second: F) -> _ConditionalToolbarContent<T, F> {
        _ConditionalToolbarContent(views: second._toolbarViews)
    }
}

extension View {
    public func toolbar<Content: ToolbarContent>(@ToolbarContentBuilder content: @escaping () -> Content) -> some View {
        toolbar { () -> TupleView<Void> in
            TupleView((), views: content()._toolbarViews)
        }
    }
    public func toolbar<Content: CustomizableToolbarContent>(id: String, @ToolbarContentBuilder content: @escaping () -> Content) -> some View {
        toolbar(content: content)
    }
}
