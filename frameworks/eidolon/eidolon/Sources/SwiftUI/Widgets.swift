import SwiftUI
import CoreGraphics

// MARK: - the three protocols a widget is written with

/// A widget: a configuration, and nothing that draws on this device. Apple declares it for iOS 14 and up
/// and not for tvOS (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:19484-19489`).
///
/// iOS 6.1.3 has no widget host - a widget is a view the system puts on a home screen, and the system of
/// iOS 6 has no such place - so a widget written here is never shown, exactly as a widget is in an app
/// whose extension is not installed. The protocol and its body are what the port carries; the host is
/// what the platform does not have.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol Widget {
    associatedtype Body: WidgetConfiguration
    var body: Body { get }
}

/// What a widget is told: a family it is laid out for, a schedule it updates on. Apple's shape from the
/// SDK of 16.4 (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:12988-12992`).
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol WidgetConfiguration {
    associatedtype Body: WidgetConfiguration
    // no builder: `WidgetConfigurationBuilder` is in neither SwiftUI's interface nor WidgetKit's
    // (`grep -c` is 0 in both), and 26.2 spells these three bodies plainly
    // (SwiftUI.swiftinterface:24911, :16719, :11775)
    var body: Body { get }
}

/// A bundle of widgets, which is what an extension's entry point is. Apple's shape from the same file
/// (`:11775-11779`), with the bundle's body built by `WidgetBundleBuilder`.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol WidgetBundle {
    associatedtype Body: Widget
    @WidgetBundleBuilder var body: Body { get }
}

/// A widget with nothing in it, which is what a configuration that says no more than that is.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
@frozen public struct EmptyWidgetConfiguration: WidgetConfiguration {
    // the configuration that says nothing, and says it by itself: a `Never` body would not be a
    // `WidgetConfiguration` and the builder could not hand one out for an empty block
    public typealias Body = EmptyWidgetConfiguration
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    public init() {}
}

// MARK: - the builders, as the interface spells them

@_functionBuilder
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public struct WidgetBundleBuilder {
    // the six functions of the SDK's own builder, at
    // `arm64e-apple-ios.swiftinterface:7114-7142` and nothing else: the multi-member `buildBlock`
    // overloads and the `buildEither` pair a previous version of this file carried are not Apple's
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: Widget { content }
    public static func buildBlock() -> some Widget { WidgetBox(wrapped: EmptyWidget()) }
    public static func buildBlock<Content>(_ content: Content) -> some Widget where Content: Widget { content }
    public static func buildOptional(_ widget: (any Widget & _LimitedAvailabilityWidgetMarker)?) -> some Widget {
        // an existential does not answer `Widget`, so the branch goes through a box that does
        return WidgetBox(wrapped: AnyWidget())
    }

    public static func buildOptional<W>(_ widget: W?) where W: Widget {
        WidgetBox(wrapped: widget)
    }
    /// The second of the interface's two forms
    /// (`arm64e-apple-ios.swiftinterface:21970`), unavailable and **generic**, with Apple's message: a
    /// bare `if` in a bundle - whether it yields `any Widget` or a named widget type - is a compile
    /// error there, and has to be an error here too. The generic shape is what makes that true of both.
    @available(*, unavailable, message: "if statements in a WidgetBundleBuilder can only be used with #available clauses")
    public static func buildOptional<W>(_ widget: W?) -> any Widget & _LimitedAvailabilityWidgetMarker where W: Widget {
        AnyLimitedAvailabilityWidget()
    }

    public static func buildLimitedAvailability(_ widget: some Widget) -> any Widget & _LimitedAvailabilityWidgetMarker {
        AnyLimitedAvailabilityWidget(erasing: widget)
    }

    /// The disfavoured overload of the same name the interface carries at :21979, for a widget handed in
    /// as an existential rather than as `some Widget`.
    @_disfavoredOverload
    public static func buildLimitedAvailability(_ widget: any Widget) -> any Widget & _LimitedAvailabilityWidgetMarker {
        AnyLimitedAvailabilityWidget()
    }

    /// A control widget is a widget the system puts a control on, and it opens the same way
    /// (:21995). iOS 6 has no control widgets, so none is ever handed here.
    public static func buildLimitedAvailability(_ widget: some ControlWidget) -> any Widget & _LimitedAvailabilityWidgetMarker {
        AnyLimitedAvailabilityWidget()
    }
}

/// The builder is Sendable in 26.2 (`arm64e-apple-ios.swiftinterface:21943`), and a result builder is a
/// value the system may hold across threads.
/// The conformance is `@available(*, unavailable)` in 26.2
/// (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:21942-21943`): a result builder that the
/// system may hold across threads is not one SwiftUI gives out.
@available(*, unavailable)
extension WidgetBundleBuilder: Sendable {}

/// The marker the interface's `buildLimitedAvailability` returns. It is underscored, so it is the
/// port's own and internal: nothing outside can name it, and nothing outside needs to.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
/// The marker the interface's own `buildOptional` and `buildLimitedAvailability` name in their
/// signatures, so it is public here as it is there: an underscored name in Swift is public, and a
/// public function cannot name a type that is not.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public protocol _LimitedAvailabilityWidgetMarker: Widget {}

/// The marker the interface's `buildLimitedAvailability` hands back, boxed so the existential the
/// signature names can be one. Internal, because the name is underscored and nothing outside names it.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct AnyLimitedAvailabilityWidget: _LimitedAvailabilityWidgetMarker {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    var erased: (any Widget)?
    init(erasing widget: some Widget) { erased = widget }
    init() {}
}

/// A widget's configuration that is behind an availability, which the interface builds through
/// `buildLimitedAvailability(_:)`.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct AnyWidgetConfiguration: WidgetConfiguration {
    public typealias Body = EmptyWidgetConfiguration
    /// What the availability hid, when the configuration it was given is still around.
    var erased: (any WidgetConfiguration)?
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    init(_ configuration: any WidgetConfiguration) { erased = configuration }
    public init() {}
}

@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
private func _widget(_ widget: some Widget) -> some Widget { EmptyWidget() }

/// A widget that was behind an availability, as a value: an existential does not conform to `Widget`,
/// so the optional branch of the builder goes through a box that does.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct AnyWidget: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
}

/// A widget with the one it wraps, for a branch that may have none. The type is generic, so each call
/// has one underlying type and the widget it was given survives.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct WidgetBox<Wrapped>: Widget where Wrapped: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    /// The widget the branch found, nil for the branch that found none.
    var wrapped: Wrapped?
}

/// The widget an empty bundle holds. The port's own: Apple's `buildBlock()` answers `some Widget`, and a
/// bundle with nothing in it still has to be a widget.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
struct EmptyWidget: Widget {
    typealias Body = EmptyWidgetConfiguration
    var body: EmptyWidgetConfiguration { let empty = EmptyWidgetConfiguration(); return empty }
}


// MARK: - a control widget

/// A widget the system puts a control on. Apple's shape from the SDK of 26.2
/// (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:4968`): a body like a widget's, and nothing
/// else the interface spells. iOS 6.1.3 has no such place either, for the same reason a widget has
/// none: the system has nowhere to put a control.
@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)
@available(tvOS, unavailable)
@preconcurrency @MainActor public protocol ControlWidget {
    associatedtype Body: WidgetConfiguration
    var body: Body { get }
}

// MARK: - a widget that says "not on this platform"

// A configuration that is behind an availability, which is what a widget bundle's `if #available`
// branch needs. Apple's shape from the SDK of 26.2
// (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:9248`): a `@frozen` struct of
// `WidgetConfiguration`, `@available(iOS 16.1, macOS 13.0, watchOS 9.1, *)` and unavailable on tvOS.
//
// The availability is kept, and it means what it means there: on iOS 6 there is no widget host at all, so
// this configuration - like every other in this file - is never asked for a body.
@available(iOS 16.1, macOS 13.0, watchOS 9.1, *)
@available(tvOS, unavailable)
@frozen public struct LimitedAvailabilityConfiguration: WidgetConfiguration {
    public typealias Body = EmptyWidgetConfiguration
    public var body: Body { let empty = EmptyWidgetConfiguration(); return empty }
    public init() {}
}
