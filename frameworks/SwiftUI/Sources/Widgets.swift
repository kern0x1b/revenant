import SwiftUI
import CoreGraphics

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol Widget {
    associatedtype Body: WidgetConfiguration
    var body: Body { get }
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol WidgetConfiguration {
    associatedtype Body: WidgetConfiguration
    var body: Body { get }
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol WidgetBundle {
    associatedtype Body: Widget
    @WidgetBundleBuilder var body: Body { get }
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
@frozen public struct EmptyWidgetConfiguration: WidgetConfiguration {
    public typealias Body = EmptyWidgetConfiguration
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    public init() {}
}

@_functionBuilder
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public struct WidgetBundleBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: Widget { content }
    public static func buildBlock() -> some Widget { WidgetBox(wrapped: EmptyWidget()) }
    public static func buildBlock<Content>(_ content: Content) -> some Widget where Content: Widget { content }
    public static func buildOptional(_ widget: (any Widget & _LimitedAvailabilityWidgetMarker)?) -> some Widget {
        return WidgetBox(wrapped: AnyWidget())
    }

    public static func buildOptional<W>(_ widget: W?) where W: Widget {
        WidgetBox(wrapped: widget)
    }
    @available(*, unavailable, message: "if statements in a WidgetBundleBuilder can only be used with #available clauses")
    public static func buildOptional<W>(_ widget: W?) -> any Widget & _LimitedAvailabilityWidgetMarker where W: Widget {
        AnyLimitedAvailabilityWidget()
    }

    public static func buildLimitedAvailability(_ widget: some Widget) -> any Widget & _LimitedAvailabilityWidgetMarker {
        AnyLimitedAvailabilityWidget(erasing: widget)
    }

    @_disfavoredOverload
    public static func buildLimitedAvailability(_ widget: any Widget) -> any Widget & _LimitedAvailabilityWidgetMarker {
        AnyLimitedAvailabilityWidget()
    }

    public static func buildLimitedAvailability(_ widget: some ControlWidget) -> any Widget & _LimitedAvailabilityWidgetMarker {
        AnyLimitedAvailabilityWidget()
    }
}

@available(*, unavailable)
extension WidgetBundleBuilder: Sendable {}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol _LimitedAvailabilityWidgetMarker: Widget {}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct AnyLimitedAvailabilityWidget: _LimitedAvailabilityWidgetMarker {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    var erased: (any Widget)?
    init(erasing widget: some Widget) { erased = widget }
    init() {}
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct AnyWidgetConfiguration: WidgetConfiguration {
    public typealias Body = EmptyWidgetConfiguration
    var erased: (any WidgetConfiguration)?
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    init(_ configuration: any WidgetConfiguration) { erased = configuration }
    public init() {}
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
private func _widget(_ widget: some Widget) -> some Widget { EmptyWidget() }

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct AnyWidget: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct WidgetBox<Wrapped>: Widget where Wrapped: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    var wrapped: Wrapped?
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct EmptyWidget: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: EmptyWidgetConfiguration { let empty = EmptyWidgetConfiguration(); return empty }
}


@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
@preconcurrency @MainActor public protocol ControlWidget {
    associatedtype Body: WidgetConfiguration
    var body: Body { get }
}

@available(iOS 16.1, macOS 13.0, watchOS 9.1, *)
@available(tvOS, unavailable)
@frozen public struct LimitedAvailabilityConfiguration: WidgetConfiguration {
    public typealias Body = EmptyWidgetConfiguration
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    public init() {}
}
