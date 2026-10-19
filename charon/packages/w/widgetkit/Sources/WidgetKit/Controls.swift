// The controls: the widgets the Control Centre and the Lock Screen draw, and the labels they carry.
//
// A control is a widget the system draws in a place the owner reaches for, and it has one more thing a
// widget does not: a value, asked for through a provider, and a push token so the system can tell the
// app it changed. There is no Control Centre on these releases and no Lock Screen control, so what a
// control holds is the app's own, and what draws it is the app's own surface.

import Foundation
import AppIntents

/// A control: the app's own description of one, and the value it shows.
public protocol ControlWidgetConfiguration: WidgetConfiguration {
    /// What the control is called, in the system's own gallery.
    func displayName(_ context: ControlWidgetButtonContext?) -> String
    /// The description the system's own gallery shows under the name.
    func description(_ context: ControlWidgetDescriptionContext?) -> String
    /// What the system asks the owner before it offers the control.
    func promptsForUserConfiguration() -> [String]
    /// The handler the system calls when the control's push token changes.
    func pushHandler(_ handler: ControlPushHandler) -> ControlPushHandler
}

/// A control that is drawn from a template the app names.
public protocol ControlWidgetTemplate {
    /// The control's colour.
    func tint(_ color: Any?) -> Self
    /// Whether the control is drawn dimmed.
    func disabled(_ disabled: Bool) -> Self
    /// Whether the control's value is private, which keeps it out of the system's own logs.
    func privacySensitive(_ sensitive: Bool) -> Self
}

/// What the system tells a control's name and description what it is drawn for.
public struct ControlWidgetButtonContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

/// The same, for the description.
public struct ControlWidgetDescriptionContext {
    public let family: WidgetFamily
    public let isPreview: Bool

    public init(family: WidgetFamily, isPreview: Bool = false) {
        self.family = family
        self.isPreview = isPreview
    }
}

/// The control the app's own gallery shows, which is the framework's name for the gallery's entry
/// point.
public enum ControlWidget {
    /// The controls the app has installed, which is the port's own record.
    public static func main() -> [ControlInfo] { return CharonWidgetRegistry.shared.controls() }
}

/// The button control: a value that is acted on rather than shown.
public struct ControlWidgetButton<Content: WidgetBody>: ControlWidgetConfiguration, ControlWidgetTemplate {
    public typealias Body = Content

    public static var kind: String { return String(describing: Content.self) }

    /// The value the button carries, which is what the system shows on it.
    public let value: String
    /// What the button does when it is pressed.
    public let action: () -> Void
    /// The label under the button, which the app names.
    public let label: Content
    /// The label the system shows when the app named none.
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

    /// The control's own kind, which the system reads off the value.
    public var _controlType: String { return "button" }
}

/// The label the system shows under a button the app did not name.
public struct ControlWidgetButtonDefaultActionLabel: WidgetBody {
    public typealias Body = Never

    public init() {}


}

extension ControlWidgetButtonDefaultActionLabel {
    public typealias BodyType = Never
}

/// The toggle control: a value that is turned on and off.
public struct ControlWidgetToggle<Value: ControlValueProvider, Content: WidgetBody>: ControlWidgetConfiguration,
                                                                       ControlWidgetTemplate {
    /// The provider the value is asked through when the app named one; the two other spellings carry
    /// the value on the control itself, and the control is its own provider.
    private let named: Value?
    public typealias Body = Content

    public static var kind: String { return String(describing: Value.self) }

    /// The value the control shows, which the system asks the provider for.
    public let isOn: Bool
    /// What the control does when it is turned on or off.
    public let action: (Bool) -> Void
    /// The label under the control, which the app names.
    public let label: Content
    /// The value label, which the app names when the control shows more than a name.
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

    /// The value the control shows, which is the app's own when it named one.
    public var valueProvider: ControlValueProvider { return named ?? CharonBoolProvider(isOn: isOn) }
}

/// The value label the system shows beside a toggle the app did not name.
public struct ControlWidgetToggleDefaultLabel: WidgetBody {
    public typealias Body = Never

    public init() {}


}

extension ControlWidgetToggleDefaultLabel {
    public typealias BodyType = Never
}

/// The value a control shows, which the system asks the app's own provider for when it is drawn.
public struct CharonBoolProvider: ControlValueProvider {
    public let isOn: Bool

    public init(isOn: Bool) {
        self.isOn = isOn
    }

    public func currentValue() async throws -> Bool { return isOn }
    public var previewValue: Bool { return isOn }
}

/// A control's label, which the app's own surface draws.
public struct CharonControlLabel<Content>: WidgetBody {
    public typealias BodyType = Content

    let value: Content

    public init(value: Content) {
        self.value = value
    }

}
