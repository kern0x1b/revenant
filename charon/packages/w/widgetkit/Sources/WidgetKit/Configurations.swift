import Foundation
import AppIntents

public protocol Widget {
    static var kind: String { get }
    associatedtype Body: WidgetBody
    var body: Body { get }
}

public protocol WidgetBody {
    associatedtype BodyType
}

public typealias WidgetView = CharonControlLabel<Never>

public protocol WidgetConfiguration {
    static var kind: String { get }
}

public struct StaticConfiguration<Provider: TimelineProvider, Content: WidgetBody>: WidgetConfiguration {
    public typealias Body = Content

    public static var kind: String { return Provider.Entry.widgetKind }

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
    public static var widgetKind: String { return String(describing: self) }
}

public struct AppIntentRecommendation<Intent: WidgetConfigurationIntent> {
    public let intent: Intent
    public let description: String

    public init(intent: Intent, description: String) {
        self.intent = intent
        self.description = description
    }
}

public struct IntentRecommendation<T> {
    public let intent: T
    public let description: String

    public init(intent: T, description: String) {
        self.intent = intent
        self.description = description
    }
}
