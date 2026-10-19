// The configuration: what a widget is, what it is drawn with, and what it is asked for.
//
// A configuration is the app's own description of a widget: its kind, the provider that answers for
// it, and the view it draws. There is no widget host on these releases, so the view is the app's own
// type - whatever the app draws a widget with, including the SwiftUI a port already has - and the
// configuration is what the module hands the app's in-app surface.

import Foundation
import AppIntents

/// A widget: something the system shows on a surface of its own, on a family, redrawn when the
/// system asks for a new timeline.
public protocol Widget {
    /// The kind the widget is registered under, which is what the system's own record names.
    static var kind: String { get }
    /// What the widget draws.
    associatedtype Body: WidgetBody
    /// The body.
    var body: Body { get }
}

/// What a widget draws. The framework's own is a SwiftUI view; a port draws its widget with whatever
/// it has, and this is the one requirement both agree on.
public protocol WidgetBody {
    /// The type the system draws.
    associatedtype BodyType
}

/// A view of the port's own, which is what a widget's body is when the app has no framework to draw
/// with: the app's type, and the app's own surface that shows it.
public typealias WidgetView = CharonControlLabel<Never>

/// The configuration of a widget the system keeps: its kind and the configuration string that says
/// which instance is drawn.
public protocol WidgetConfiguration {
    /// The kind the widget is registered under.
    static var kind: String { get }
}

/// The configuration of a widget without an intent: a kind, a provider and what it draws.
public struct StaticConfiguration<Provider: TimelineProvider, Content: WidgetBody>: WidgetConfiguration {
    public typealias Body = Content

    public static var kind: String { return Provider.Entry.widgetKind }

    /// The provider the system asks for entries and a timeline.
    public let provider: Provider
    /// What the widget draws.
    public let content: Content
    /// The kind, when the app named one itself.
    public let widgetKind: String?

    public init(kind: String, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.provider = provider
        self.content = content
    }

    public init(kind: String? = nil, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.provider = provider
        self.content = content
    }

    public var body: Content { return content }
}

/// The configuration of a widget configured by an app intent.
public struct AppIntentConfiguration<Intent: WidgetConfigurationIntent, Provider: AppIntentTimelineProvider,
                                     Content: WidgetBody>: WidgetConfiguration {
    public typealias Body = Content

    public static var kind: String { return Provider.Entry.widgetKind }

    public let intent: Intent
    public let provider: Provider
    public let content: Content
    public let widgetKind: String?

    public init(kind: String, intent: Intent, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.intent = intent
        self.provider = provider
        self.content = content
    }

    public init(kind: String? = nil, intent: Intent, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.intent = intent
        self.provider = provider
        self.content = content
    }

    public var body: Content { return content }
}

/// The configuration of a widget configured by an `INIntent`, which the framework still names.
public struct IntentConfiguration<Intent: AppIntent, Provider: IntentTimelineProvider, Content: WidgetBody>
    : WidgetConfiguration {
    public typealias Body = Content

    public static var kind: String { return Provider.Entry.widgetKind }

    public let intent: Intent
    public let provider: Provider
    public let content: Content
    public let widgetKind: String?

    public init(kind: String, intent: Intent, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.intent = intent
        self.provider = provider
        self.content = content
    }

    public init(kind: String? = nil, intent: Intent, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.intent = intent
        self.provider = provider
        self.content = content
    }

    public var body: Content { return content }
}

/// The configuration of a control configured by an app intent.
public struct AppIntentControlConfiguration<Intent: WidgetConfigurationIntent, Content: WidgetBody>
    : WidgetConfiguration {
    public typealias Body = Content

    public static var kind: String { return Intent.persistentIdentifier }

    public let intent: Intent
    public let content: Content
    public let widgetKind: String?

    public init(kind: String, intent: Intent, content: Content) {
        self.widgetKind = kind
        self.intent = intent
        self.content = content
    }

    public var body: Content { return content }
}

/// The configuration of a control with a provider of its own.
public struct StaticControlConfiguration<Provider: ControlValueProvider, Content: WidgetBody>: WidgetConfiguration {
    public typealias Body = Content

    public static var kind: String { return String(describing: Provider.self) }

    public let provider: Provider
    public let content: Content
    public let widgetKind: String?

    public init(kind: String, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.provider = provider
        self.content = content
    }

    public init(kind: String? = nil, provider: Provider, content: Content) {
        self.widgetKind = kind
        self.provider = provider
        self.content = content
    }

    public var body: Content { return content }
}

extension TimelineEntry {
    /// The kind the widget of this entry is registered under, which the framework reads off the entry's
    /// own type name.
    public static var widgetKind: String { return String(describing: self) }
}

/// A recommendation the system offers for a widget it does not have, which is what a widget asks for
/// when it wants the owner to add it.
public struct AppIntentRecommendation<Intent: WidgetConfigurationIntent> {
    public let intent: Intent
    public let description: String

    public init(intent: Intent, description: String) {
        self.intent = intent
        self.description = description
    }
}

/// The same, over an `INIntent`, which the framework still names.
public struct IntentRecommendation<T> {
    public let intent: T
    public let description: String

    public init(intent: T, description: String) {
        self.intent = intent
        self.description = description
    }
}
