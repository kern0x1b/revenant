import UIKit
import CoreGraphics

public struct FocusedValues {}
public protocol LayoutValueKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
public enum PresentationBackgroundInteraction { case automatic, enabled, disabled }
public enum PresentationContentInteraction { case automatic, resizes, scrolls }

extension VerticalEdge {
    public struct Set: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1)
        public static let bottom = Set(rawValue: 2)
        public static let all = Set(rawValue: 3)
    }
}

extension View {
    public func accessibilityChartDescriptor<R>(_ representable: R) -> some View {
        ignored(self, "accessibilityChartDescriptor", "a chart descriptor is AXChartDescriptor, iOS 13; the accessibility of this release speaks a label, a value and a hint")
    }
    public func accessibilityQuickAction<Content: View>(style: Any, @ViewBuilder content: () -> Content) -> some View {
        ignored(self, "accessibilityQuickAction", "an assistive quick action is iOS 13, and the peek and pop of iOS 9 is a preview of a view; this release has neither")
    }
    public func accessibilityRotor<Content>(_ label: Text, @ViewBuilder entries: () -> Content) -> some View {
        ignored(self, "accessibilityRotor", "a rotor of one's own is UIAccessibilityCustomRotor, iOS 11; VoiceOver of iOS 6 has its own rotors and no API to add to them")
    }
    public func accessibilityRotorEntry<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        ignored(self, "accessibilityRotorEntry", "a rotor of one's own is UIAccessibilityCustomRotor, iOS 11; VoiceOver of iOS 6 has its own rotors and no API to add to them")
    }
    public func digitalCrownAccessory(_ visibility: Visibility) -> some View {
        ignored(self, "digitalCrownAccessory", "the digital crown is a watch, and this release is not one; there is no crown to turn and no accessory to show")
    }
    public func exportableToServices<T>(_ payload: @escaping () -> [T]) -> some View {
        // the share sheet of the release is a UIActivityViewController, and it takes what is shared as its items: a
        // string, a URL, an image, a file. Its completion is iOS 8, so nothing can be told back that the share happened.
        _Unsupported.note("exportableToServices", "the sheet of iOS 6 takes what is shared and offers it, but it has no completion, so an app is not told that the share happened — that is iOS 8")
        return onLongPressGesture {
            guard let host = UIApplication.shared.keyWindow?.rootViewController else { return }
            host.present(UIActivityViewController(activityItems: activityItems(payload()), applicationActivities: nil),
                         animated: true, completion: nil)
        }
    }
    @available(iOS 8.0, *)
    public func exportsItemProviders(_ contentTypes: [String], onExport: @escaping () -> [NSItemProvider]) -> some View {
        ignored(self, "exportsItemProviders", "an item provider is NSItemProvider, iOS 8; the pasteboard of this release takes a string, a URL or an image, which is what .copyable and .cuttable use")
    }
    public func importableFromServices<T>(for payloadType: T.Type, action: @escaping ([T]) -> Bool) -> some View {
        ignored(self, "importableFromServices", "what came back from a service needs the completion of the sheet, which is iOS 8")
    }
    @available(iOS 8.0, *)
    public func importsItemProviders(_ contentTypes: [String], onImport: @escaping ([NSItemProvider]) -> Bool) -> some View {
        ignored(self, "importsItemProviders", "an item provider is NSItemProvider, iOS 8; the pasteboard of this release takes a string, a URL or an image, which is what .copyable and .cuttable use")
    }
    public func focusScope(_ namespace: Namespace.ID) -> some View {
        ignored(self, "focusScope", "this release has no focus engine: UIFocusSystem and UIFocusGuide are iOS 11 for a pad and the focus of a remote is tvOS, and a view of this release is focused when it takes a touch")
    }
    public func focusedValue<T>(_ keyPath: WritableKeyPath<FocusedValues, T?>, _ value: T) -> some View {
        ignored(self, "focusedValue", "this release has no focus engine: UIFocusSystem and UIFocusGuide are iOS 11 for a pad and the focus of a remote is tvOS, and a view of this release is focused when it takes a touch")
    }
    public func focusedObject<T: ObservableObject>(_ object: T?) -> some View {
        ignored(self, "focusedObject", "this release has no focus engine: UIFocusSystem and UIFocusGuide are iOS 11 for a pad and the focus of a remote is tvOS, and a view of this release is focused when it takes a touch")
    }
    public func focusedSceneValue<T>(_ keyPath: WritableKeyPath<FocusedValues, T?>, _ value: T) -> some View {
        ignored(self, "focusedSceneValue", "scenes are iOS 13, and this release has one screen rather than scenes")
    }
    public func focusedSceneObject<T: ObservableObject>(_ object: T?) -> some View {
        ignored(self, "focusedSceneObject", "scenes are iOS 13, and this release has one screen rather than scenes")
    }
    public func listRowPlatterColor(_ color: Color?) -> some View {
        ignored(self, "listRowPlatterColor", "platters belong to watchOS")
    }
    public func listRowSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View {
        if !edges.contains(.bottom) { _Unsupported.note("listRowSeparatorTint(edges:)", "a table of iOS 6 draws no line above a row, so a request for the top edge alone is what the release already does") }
        return _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.separatorTint = color?.uiColor }))
    }
    public func listSectionSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View {
        ignored(self, "listSectionSeparatorTint", "the table of iOS 6 draws no separator of its own between sections")
    }
    public func menuButtonStyle<S>(_ style: S) -> some View {
        ignored(self, "menuButtonStyle", "a menu button with a style belongs to macOS, where a menu keeps its own look; the menu here is the UIActionSheet of this release")
    }
    public func onCommand(_ selector: Selector, perform action: (() -> Void)?) -> some View {
        ignored(self, "onCommand", "a command is a menu item of macOS; this release has no menu of its own to put one in — .commands on a scene says as much")
    }
    public func pageCommand<V: Strideable>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride) -> some View {
        ignored(self, "pageCommand", "a page command is a button of the remote of tvOS; this release has no remote and no page of its own to turn")
    }
    public func pasteDestination<T>(for payloadType: T.Type, action: @escaping ([T]) -> Void) -> some View {
        ignored(self, "pasteDestination", "a paste destination is iOS 16; the pasteboard of this release is a place an app reads and writes, and nothing in it is a destination a system offers")
    }
    public func presentationBackgroundInteraction(_ interaction: PresentationBackgroundInteraction) -> some View {
        ignored(self, "presentationBackgroundInteraction", "a modal screen of this release is presented over the whole screen and the background behind it takes no touches; the choice of what it does take is iOS 16")
    }
    public func presentationContentInteraction(_ behavior: PresentationContentInteraction) -> some View {
        ignored(self, "presentationContentInteraction", "a modal screen of this release takes the touches that are on it and the ones that reach past it; the choice between them is iOS 16")
    }
    public func presentedWindowStyle<S>(_ style: S) -> some View {
        ignored(self, "presentedWindowStyle", "a window with a style of its own is a window of macOS; a screen of this release is a view controller of a navigation controller")
    }
    public func presentedWindowToolbarStyle<S>(_ style: S) -> some View {
        ignored(self, "presentedWindowToolbarStyle", "a window with a style of its own is a window of macOS; a screen of this release is a view controller of a navigation controller")
    }
    public func previewContext<C>(_ value: C) -> some View {
        ignored(self, "previewContext", "a preview is a canvas of Xcode that is built on a machine with a newer system than the device has; nothing of it is drawn on the device, and the modifier says so in the log")
    }
    public func toolbarTitleMenu<C: View>(@ViewBuilder content: () -> C) -> some View {
        ignored(self, "toolbarTitleMenu", "iOS 6 navigation bars have no title menu")
    }
    public func touchBarCustomizationLabel(_ label: Text) -> some View {
        ignored(self, "touchBarCustomizationLabel", "a touch bar is a strip of a MacBook, and this release runs on a device with no such strip")
    }
    public func touchBarItemPresence(_ presence: Any) -> some View {
        ignored(self, "touchBarItemPresence", "a touch bar is a strip of a MacBook, and this release runs on a device with no such strip")
    }
    public func touchBarItemPrincipal(_ principal: Bool = true) -> some View {
        ignored(self, "touchBarItemPrincipal", "a touch bar is a strip of a MacBook, and this release runs on a device with no such strip")
    }
}
