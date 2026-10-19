import UIKit
import CoreGraphics

// The value types SDK 26.2's environment keys name, declared as Apple declares them: an option set or a
// struct over a name, with the cases its own interface lists and the defaults the framework of macOS 27
// answers with (.agent-work/host/envdefaults.txt). They are what the keys in EnvironmentKeysExtra.swift
// store; a key is storage whether or not a view acts on it today.

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

/// A document being edited or read: iOS 6 has no document browser, so the configuration is the empty
/// one, and the key reads it as such.
public struct DocumentConfiguration: Hashable {
    public init() {}
}

/// A device an app is being driven on, as `Xcode` shows a Mac or a paired device. There is none on iOS 6.
public struct RemoteDeviceIdentifier: Hashable {
    public init() {}
}

// The three value types left: what device the app is being driven on, the focus system's own state, and
// the reset-focus action. iOS 6 has one device and the focus system the engine keeps, so each is the empty
// one until something fills it. Apple's `_DeviceVariant` names the sizes of a watch (compact, regular and two
// heights), and a device that is not a watch is `regular`.
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

/// Whether a find-and-replace sheet is up: iOS 6 has no find in a text view, so it is never presented
/// and never replaces.
public struct FindContext: Hashable {
    public var isPresented: Bool?
    public var supportsReplace: Bool
    public init(isPresented: Bool? = nil, supportsReplace: Bool = true) {
        self.isPresented = isPresented
        self.supportsReplace = supportsReplace
    }
}
