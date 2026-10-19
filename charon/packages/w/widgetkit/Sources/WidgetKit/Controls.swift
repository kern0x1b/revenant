import Foundation
import AppIntents

public protocol ControlWidgetConfiguration: WidgetConfiguration {
    func displayName(_ context: ControlWidgetButtonContext?) -> String
    func description(_ context: ControlWidgetDescriptionContext?) -> String
    func promptsForUserConfiguration() -> [String]
    func pushHandler(_ handler: ControlPushHandler) -> ControlPushHandler
}

public protocol ControlWidgetTemplate {
    func tint(_ color: Any?) -> Self
    func disabled(_ disabled: Bool) -> Self
    func privacySensitive(_ sensitive: Bool) -> Self
}

public struct ControlWidgetButtonContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

public struct ControlWidgetDescriptionContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

public enum ControlWidget {
    public static func main() -> [ControlInfo] { return CharonWidgetRegistry.shared.controls() }
}

public struct ControlWidgetButton<Content: WidgetBody>: ControlWidgetConfiguration, ControlWidgetTemplate {
    public typealias Body = Content

    public static var kind: String { return String(describing: Content.self) }

    public let value: String
    public let action: () -> Void
    public let label: Content
    public let actionLabel: ControlWidgetButtonDefaultActionLabel?

    public init(action: @escaping () -> Void, label: Content) {
        self.value = ""
        self.action = action
        self.label = label
        self.actionLabel = nil
    }

    public init(action: @escaping () -> Void, label: Content, actionLabel: ControlWidgetButtonDefaultActionLabel? = nil) {
        self.value = ""
        self.action = action
        self.label = label
        self.actionLabel = actionLabel
    }

    public func tint(_ color: Any?) -> Self { return self }
    public func disabled(_ disabled: Bool) -> Self { return self }
    public func privacySensitive(_ sensitive: Bool) -> Self { return self }

    public func displayName(_ context: ControlWidgetButtonContext?) -> String { return value }
    public func description(_ context: ControlWidgetDescriptionContext?) -> String { return value }
    public func promptsForUserConfiguration() -> [String] { return [] }
    public func pushHandler(_ handler: ControlPushHandler) -> ControlPushHandler { return handler }

    public var body: Content { return label }

    public var _controlType: String { return "button" }
}

public struct ControlWidgetButtonDefaultActionLabel: WidgetBody {
    public typealias Body = Never

    public init() {}


}

extension ControlWidgetButtonDefaultActionLabel {
    public typealias BodyType = Never
}

public struct ControlWidgetToggle<Value: ControlValueProvider, Content: WidgetBody>: ControlWidgetConfiguration,
                                                                       ControlWidgetTemplate {
    private let named: Value?
    public typealias Body = Content

    public static var kind: String { return String(describing: Value.self) }

    public let isOn: Bool
    public let action: (Bool) -> Void
    public let label: Content
    public let valueLabel: ControlWidgetToggleDefaultLabel?

    public init(isOn: Bool, action: @escaping (Bool) -> Void, label: Content) {
        self.named = nil
        self.isOn = isOn
        self.action = action
        self.label = label
        self.valueLabel = nil
    }

    public init(isOn: Bool, action: @escaping (Bool) -> Void, label: Content,
                valueLabel: ControlWidgetToggleDefaultLabel? = nil) {
        self.named = nil
        self.isOn = isOn
        self.action = action
        self.label = label
        self.valueLabel = valueLabel
    }

    public func tint(_ color: Any?) -> Self { return self }
    public func disabled(_ disabled: Bool) -> Self { return self }
    public func privacySensitive(_ sensitive: Bool) -> Self { return self }

    public func displayName(_ context: ControlWidgetButtonContext?) -> String { return String(describing: Self.self) }
    public func description(_ context: ControlWidgetDescriptionContext?) -> String { return String(describing: Self.self) }
    public func promptsForUserConfiguration() -> [String] { return [] }
    public func pushHandler(_ handler: ControlPushHandler) -> ControlPushHandler { return handler }

    public var body: Content { return label }

    public var _controlType: String { return "toggle" }

    public var valueProvider: ControlValueProvider { return named ?? CharonBoolProvider(isOn: isOn) }
}

public struct ControlWidgetToggleDefaultLabel: WidgetBody {
    public typealias Body = Never

    public init() {}


}

extension ControlWidgetToggleDefaultLabel {
    public typealias BodyType = Never
}

public struct CharonBoolProvider: ControlValueProvider {
    public let isOn: Bool

    public init(isOn: Bool) {
        self.isOn = isOn
    }

    public func currentValue() async throws -> Bool { return isOn }
    public var previewValue: Bool { return isOn }
}

public struct CharonControlLabel<Content>: WidgetBody {
    public typealias BodyType = Content

    let value: Content

    public init(value: Content) {
        self.value = value
    }

}
