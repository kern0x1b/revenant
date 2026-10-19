import UIKit
import CoreGraphics

public struct WritingToolsBehavior: Hashable {
    let name: String
    public static let automatic = WritingToolsBehavior(name: "automatic")
    public static let complete = WritingToolsBehavior(name: "complete")
    public static let limited = WritingToolsBehavior(name: "limited")
    public static let disabled = WritingToolsBehavior(name: "disabled")
}

public struct SpringLoadingBehavior: Hashable {
    let name: String
    public static let automatic = SpringLoadingBehavior(name: "automatic")
    public static let enabled = SpringLoadingBehavior(name: "enabled")
    public static let disabled = SpringLoadingBehavior(name: "disabled")
}

public struct TabBarPlacement: Hashable {
    let name: String
    public static let topBar = TabBarPlacement(name: "topBar")
    public static let sidebar = TabBarPlacement(name: "sidebar")
    public static let bottomBar = TabBarPlacement(name: "bottomBar")
    public static let ornament = TabBarPlacement(name: "ornament")
    public static let pageIndicator = TabBarPlacement(name: "pageIndicator")
}

public enum TabViewBottomAccessoryPlacement: Hashable { case inline, expanded }

public enum SidebarRowSize: Hashable { case small, medium, large }

public enum TextSelectionAffinity: Hashable { case automatic, upstream, downstream }

public struct PencilPreferredAction: Hashable {
    let name: String
    public static let switchEraser = PencilPreferredAction(name: "switchEraser")
    public static let switchPrevious = PencilPreferredAction(name: "switchPrevious")
    public static let showColorPalette = PencilPreferredAction(name: "showColorPalette")
    public static let showInkAttributes = PencilPreferredAction(name: "showInkAttributes")
    public static let showContextualPalette = PencilPreferredAction(name: "showContextualPalette")
    public static let runSystemShortcut = PencilPreferredAction(name: "runSystemShortcut")
    public static let ignore = PencilPreferredAction(name: "ignore")
}

public enum SymbolColorRenderingMode: Hashable { case linear, hierarchical, palette }

public enum SymbolVariableValueMode: Hashable { case standard, fill }

public struct ToolbarLabelStyle: Hashable {
    let name: String
    public static let automatic = ToolbarLabelStyle(name: "automatic")
    public static let iconOnly = ToolbarLabelStyle(name: "iconOnly")
    public static let titleOnly = ToolbarLabelStyle(name: "titleOnly")
    public static let titleAndIcon = ToolbarLabelStyle(name: "titleAndIcon")
}

public enum ButtonSizing: Hashable { case automatic, flexible, fitted }

public struct ButtonRepeatBehavior: Hashable {
    let name: String
    public static let automatic = ButtonRepeatBehavior(name: "automatic")
    public static let enabled = ButtonRepeatBehavior(name: "enabled")
    public static let disabled = ButtonRepeatBehavior(name: "disabled")
}

public struct BackgroundProminence: Hashable {
    let name: String
    public static let standard = BackgroundProminence(name: "standard")
    public static let increased = BackgroundProminence(name: "increased")
}

public struct BadgeProminence: Hashable {
    let name: String
    public static let standard = BadgeProminence(name: "standard")
    public static let increased = BadgeProminence(name: "increased")
}

public struct MaterialActiveAppearance: Hashable {
    let name: String
    public static let automatic = MaterialActiveAppearance(name: "automatic")
    public static let active = MaterialActiveAppearance(name: "active")
    public static let inactive = MaterialActiveAppearance(name: "inactive")
}

public struct DocumentConfiguration: Hashable {
    public init() {}
}

public struct RemoteDeviceIdentifier: Hashable {
    public init() {}
}

public enum _DeviceVariant: Equatable { case compact, regular, h394, h448 }

public struct _FocusSystem {
    var onResetToDefault: (() -> Void)?
    public init() {}
}

public struct ResetFocusAction {
    var bridge: (() -> Void)?
    public init() {}
    public func callAsFunction() { bridge?() }
}

public struct FindContext: Hashable {
    public var isPresented: Bool?
    public var supportsReplace: Bool
    public init(isPresented: Bool? = nil, supportsReplace: Bool = true) {
        self.isPresented = isPresented
        self.supportsReplace = supportsReplace
    }
}
