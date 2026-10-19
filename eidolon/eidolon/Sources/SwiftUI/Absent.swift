import UIKit
import CoreGraphics

public enum AccessibilityAdjustmentDirection { case increment, decrement }
public enum AccessibilityLabeledPairRole { case label, content }
public enum AccessibilityTextContentType { case plain, console, fileSystem, messaging, narrative, sourceCode, spreadsheet, wordProcessing }
public enum MoveCommandDirection { case up, down, left, right }
public struct PresentationDetent: Hashable {
    let name: String
    /// the app's own detent type, when it named one: its height is what the type computes
    let customType: Any.Type?
    init(name: String, custom: Any.Type? = nil) { self.name = name; customType = custom }
    /// The height the app's type computes from the context, which is the screen on this platform.
    var customHeight: CGFloat? {
        guard let customType else { return nil }
        return (customType as? any CustomPresentationDetent.Type)?.height(in: Context(maxDetentValue: maxDetentValue))
    }
    public static func == (a: PresentationDetent, b: PresentationDetent) -> Bool { a.name == b.name }
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }
    public var hashValue: Int { var h = Hasher(); hash(into: &h); return h.finalize() }
    public static let medium = PresentationDetent(name: "medium")
    public static let large = PresentationDetent(name: "large")
    public static func height(_ height: CGFloat) -> PresentationDetent { PresentationDetent(name: "height") }
    /// The detent an app's own type describes. Its height is the one it computes from the context, and
    /// the context's largest detent is the screen, because a modal screen of iOS 6 is the whole screen.
    public static func custom<D: CustomPresentationDetent>(_ type: D.Type) -> PresentationDetent {
        PresentationDetent(name: "custom-\(String(describing: type))", custom: type)
    }
    /// The largest detent this platform allows a modal screen to be: the screen, which is all of it here.
    public var maxDetentValue: CGFloat { Context.maximum }

    public static func fraction(_ fraction: CGFloat) -> PresentationDetent { PresentationDetent(name: "fraction") }
}
public enum PresentationAdaptation { case automatic, none, popover, sheet, fullScreenCover }
public enum ToolbarRole { case automatic, navigationStack, browser, editor }
public enum MenuOrder { case automatic, priority, fixed }
public enum MenuActionDismissBehavior { case automatic, enabled, disabled }
public struct ContentTransition: Equatable {
    enum Kind: Equatable { case identity, fade }
    let kind: Kind
    public static let identity = ContentTransition(kind: .identity)
    public static let opacity = ContentTransition(kind: .fade)
    public static let interpolate = ContentTransition(kind: .fade)
    public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition(kind: .fade) }
}
public enum HoverPhase { case active(CGPoint), ended }
public enum HoverEffect { case automatic, highlight, lift }
public struct PreviewDevice: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {}
    public init(rawValue: String) {}
}
public enum PreviewLayout { case device, sizeThatFits, fixed(width: CGFloat, height: CGFloat) }
public enum InterfaceOrientation { case portrait, portraitUpsideDown, landscapeLeft, landscapeRight }

extension View {
    public func accessibilityActions<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ignored(self, "accessibilityActions", "a custom action is UIAccessibilityCustomAction, iOS 8; UIAccessibility of this release has no list of them to put in")
    }
    public func accessibilityCustomContent(_ label: Text, _ value: Text) -> some View {
        ignored(self, "accessibilityCustomContent", "custom content is a pair of AXCustomContent values, iOS 9; UIAccessibilityElement of this release has a label, a hint, a value and traits")
    }
    public func accessibilityLabeledPair<ID: Hashable>(role: AccessibilityLabeledPairRole, id: ID, in namespace: Namespace.ID) -> some View {
        ignored(self, "accessibilityLabeledPair", "a labelled pair is accessibilityLabeledBy, iOS 9; an element of this release is a label, a value and a frame")
    }
    public func accessibilityLinkedGroup<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        ignored(self, "accessibilityLinkedGroup", "a linked group is accessibilityLinkedGroup, iOS 11; the accessibility of this release has no group of its own to link")
    }
    public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> some View {
        ignored(self, "accessibilityTextContentType", "a content type for a field is UITextContentType, iOS 12; VoiceOver of iOS 6 reads the text of a field as it is typed")
    }
    public func speechAdjustedPitch(_ value: Double) -> some View {
        ignored(self, "speechAdjustedPitch", "speech is not synthesised on this release: AVSpeechSynthesizer is iOS 7, and VoiceOver of iOS 6 takes no attributes of its own")
    }
    public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> some View {
        ignored(self, "speechAlwaysIncludesPunctuation", "speech is not synthesised on this release: AVSpeechSynthesizer is iOS 7, and VoiceOver of iOS 6 speaks the text as it is written")
    }
    public func speechAnnouncementsQueued(_ value: Bool = true) -> some View {
        ignored(self, "speechAnnouncementsQueued", "speech is not synthesised on this release: AVSpeechSynthesizer is iOS 7, and VoiceOver of iOS 6 has no queue of its own to announce in")
    }
    public func speechSpellsOutCharacters(_ value: Bool = true) -> some View {
        ignored(self, "speechSpellsOutCharacters", "speech is not synthesised on this release: AVSpeechSynthesizer is iOS 7, and VoiceOver of iOS 6 reads a character as a character")
    }
    public func focusable(_ isFocusable: Bool = true) -> some View {
        ignored(self, "focusable", "this release has no focus engine: UIFocusSystem and UIFocusGuide are iOS 11 for a pad and the focus of a remote is tvOS, and a view of this release is focused when it takes a touch")
    }
    public func focusSection() -> some View {
        ignored(self, "focusSection", "this release has no focus engine: UIFocusSystem and UIFocusGuide are iOS 11 for a pad and the focus of a remote is tvOS, and a view of this release is focused when it takes a touch")
    }
    public func defaultFocus<V: Hashable>(_ binding: FocusState<V>.Binding, _ value: V) -> some View {
        ignored(self, "defaultFocus", "this release has no focus engine: UIFocusSystem and UIFocusGuide are iOS 11 for a pad and the focus of a remote is tvOS, and a view of this release is focused when it takes a touch")
    }
    public func prefersDefaultFocus(_ prefersDefaultFocus: Bool = true, in namespace: Namespace.ID) -> some View {
        ignored(self, "prefersDefaultFocus", "this release has no focus engine: UIFocusSystem and UIFocusGuide are iOS 11 for a pad and the focus of a remote is tvOS, and a view of this release is focused when it takes a touch")
    }
    public func draggable<T>(_ payload: @autoclosure @escaping () -> T) -> some View {
        ignored(self, "draggable", "a drag of this release is a gesture, not a session: UIDragInteraction and UIDropInteraction are iOS 11, and the release hands an app no drag session and no preview to carry a payload in — a table of rows is moved with .onMove, and a drag of one's own is a DragGesture")
    }
    public func dropDestination<T>(for payloadType: T.Type, action: @escaping ([T], CGPoint) -> Bool) -> some View {
        ignored(self, "dropDestination", "a drag of this release is a gesture, not a session: UIDragInteraction and UIDropInteraction are iOS 11, and the release hands an app no drag session and no preview to carry a payload in — a table of rows is moved with .onMove, and a drag of one's own is a DragGesture")
    }
    public func copyable<T>(_ payload: @autoclosure @escaping () -> [T]) -> some View {
        // the edit menu of this release belongs to a text view, so what a view of its own offers on a long press is the
        // release's own sheet, with the same Copy item - and what is copied is the payload, as the pasteboard holds it
        onLongPressGesture {
            showReleaseMenu([("Copy", { copyToPasteboard(payload()) })], in: UIApplication.shared.keyWindow?.rootViewController?.view)
        }
    }
    public func cuttable<T>(for payloadType: T.Type, action: @escaping () -> [T]) -> some View {
        onLongPressGesture {
            showReleaseMenu([("Cut", { action(); clearPasteboard() })], in: UIApplication.shared.keyWindow?.rootViewController?.view)
        }
    }
    @available(iOS 8.0, *)
    public func itemProvider(_ action: (() -> NSItemProvider?)?) -> some View {
        ignored(self, "itemProvider", "an item provider is NSItemProvider, iOS 8; the pasteboard of this release takes a string, a URL or an image, which is what .copyable and .cuttable use")
    }
    @available(iOS 8.0, *)
    public func onCopyCommand(perform payloadAction: (() -> [NSItemProvider])?) -> some View {
        ignored(self, "onCopyCommand", "iOS 6 has the cut, copy and paste menu of a UITextView, and no command an app can attach it to: the command plumbing is what SwiftUI adds and iOS 6 has not")
    }
    @available(iOS 8.0, *)
    public func onCutCommand(perform action: (() -> [NSItemProvider])?) -> some View {
        ignored(self, "onCutCommand", "the command takes an NSItemProvider, which is iOS 8; there is nothing on this release for it to be, and what a view of its own can be cut as is .cuttable")
    }
    @available(iOS 8.0, *)
    public func onPasteCommand(of supportedTypes: [String], perform action: @escaping ([NSItemProvider]) -> Void) -> some View {
        ignored(self, "onPasteCommand", "the command takes an NSItemProvider, which is iOS 8; the pasteboard of this release takes a string, a URL or an image, and what is on it can be cut with .cuttable")
    }
    public func onDeleteCommand(perform action: (() -> Void)?) -> some View {
        ignored(self, "onDeleteCommand", "the command is a menu item of macOS; a row of a table of this release is deleted with the swipe of .swipeActions or with .onDelete")
    }
    public func onMoveCommand(perform action: ((MoveCommandDirection) -> Void)?) -> some View {
        ignored(self, "onMoveCommand", "the command is a menu item of macOS; the rows of a table of this release are moved in its editing mode, which .onMove and EditButton give")
    }
    public func onExitCommand(perform action: (() -> Void)?) -> some View {
        ignored(self, "onExitCommand", "the command is a menu item of macOS; a screen of this release is left with the back item of the navigation bar or with .dismiss")
    }
    public func onPlayPauseCommand(perform action: (() -> Void)?) -> some View {
        ignored(self, "onPlayPauseCommand", "the command comes from the remote of tvOS; a sound of this release is played with AVAudioPlayer and nothing else sends a play or a pause")
    }
    public func fileExporter<D>(isPresented: Binding<Bool>, document: D?, contentType: String, onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        ignored(self, "fileExporter", "a document browser is UIDocumentPickerViewController, iOS 8; this release has none, and it has no FileDocument to take a document from either")
    }
    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [String], onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        ignored(self, "fileImporter", "a document browser is UIDocumentPickerViewController, iOS 8; this release has none, and it has no FileDocument to take a document from either")
    }
    public func fileMover(isPresented: Binding<Bool>, file: URL?, onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        ignored(self, "fileMover", "a document browser is UIDocumentPickerViewController, iOS 8; this release has none, and it has no FileDocument to take a document from either")
    }
    public func renameAction(_ action: @escaping () -> Void) -> some View {
        ignored(self, "renameAction", "a rename is done on a name in a text field, which this release has; what a row offers as an affordance to rename it is iOS 15")
    }
    public func findNavigator(isPresented: Binding<Bool>) -> some View {
        ignored(self, "findNavigator", "a text view of this release has no find bar of its own; UITextView of iOS 6 has selectedText and typingAttributes, and nothing that finds a string in a text")
    }
    public func findDisabled(_ isDisabled: Bool = true) -> some View {
        ignored(self, "findDisabled", "a text view of this release has no find bar of its own; UITextView of iOS 6 has selectedText and typingAttributes, and nothing that finds a string in a text")
    }
    public func replaceDisabled(_ isDisabled: Bool = true) -> some View {
        ignored(self, "replaceDisabled", "a text view of this release has no find bar of its own; UITextView of iOS 6 has selectedText and typingAttributes, and nothing that finds a string in a text")
    }
    public func presentationDetents(_ detents: Set<PresentationDetent>) -> some View {
        ignored(self, "presentationDetents", "a modal screen of this release is one of three UIModalPresentationStyles — full screen, form sheet, page sheet — and the size of each is the size of iOS 6; a detent is a height of a screen of iOS 16")
    }
    public func presentationDragIndicator(_ visibility: Visibility) -> some View {
        ignored(self, "presentationDragIndicator", "the drag indicator is a bar at the top of a sheet of iOS 16, and no UIViewController of this release draws one")
    }
    public func presentationCornerRadius(_ cornerRadius: CGFloat?) -> some View {
        ignored(self, "presentationCornerRadius", "a form sheet and a page sheet of this release are rectangles with the corners of iOS 6, and a UIViewController here has no corner radius of its own to give")
    }
    public func presentationBackground<S: ShapeStyle>(_ style: S) -> some View {
        // a modal screen of this release is painted in the white the release gives it, and this is the colour that takes
        // the place of that white
        if let color = style._uiColor {
            return _ModifiedView(content: self, modifier: PresentationBackgroundModifier(color: color))
        }
        // a style that is not one colour (a gradient, a material) has no single colour to paint a screen with
        _Unsupported.note("presentationBackground(style)", "a presented screen of iOS 6 is painted in one colour, so a style that is not one colour paints none of it")
        return _ModifiedView(content: self, modifier: PresentationBackgroundModifier(color: nil))
    }

    public func presentationCompactAdaptation(_ adaptation: PresentationAdaptation) -> some View {
        ignored(self, "presentationCompactAdaptation", "a modal screen of this release is presented in one of three UIModalPresentationStyles and does not adapt: there is no second form to fall back to when there is no room")
    }
    public func toolbarColorScheme(_ colorScheme: ColorScheme?, for bars: ToolbarPlacement = .automatic) -> some View {
        if bars == .tabBar { _Unsupported.note("toolbarColorScheme(for: .tabBar)", "UITabBar of iOS 6 has no bar style") }
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { environment in
            guard bars != .tabBar, let bar = environment.host?.navigationController?.navigationBar else { return }
            bar.barStyle = colorScheme == .dark ? .black : .default
        }))
    }
    public func toolbarRole(_ role: ToolbarRole) -> some View {
        ignored(self, "toolbarRole", "the bars of this release are one kind of bar with no role among their items: UIToolbar has no role and the styles of a bar button item are iOS 13")
    }
    public func menuIndicator(_ visibility: Visibility) -> some View {
        ignored(self, "menuIndicator", "the menu here is the UIActionSheet of this release")
    }
    public func menuOrder(_ order: MenuOrder) -> some View {
        ignored(self, "menuOrder", "the menu here is the UIActionSheet of this release")
    }
    public func menuActionDismissBehavior(_ behavior: MenuActionDismissBehavior) -> some View {
        ignored(self, "menuActionDismissBehavior", "the menu here is the UIActionSheet of this release")
    }
    public func onHover(perform action: @escaping (Bool) -> Void) -> some View {
        ignored(self, "onHover", "a pointer of this release reports nothing to an app: there is no UIHoverEvent and no UIPointerInteraction, both iOS 13, and no other class hands an app a position on a pointing device")
    }
    public func onContinuousHover(coordinateSpace: CoordinateSpace = .local, perform action: @escaping (HoverPhase) -> Void) -> some View {
        ignored(self, "onContinuousHover", "a pointer of this release reports nothing to an app: there is no UIHoverEvent and no UIPointerInteraction, both iOS 13, and no other class hands an app a position on a pointing device")
    }
    public func hoverEffect(_ effect: HoverEffect = .automatic) -> some View {
        ignored(self, "hoverEffect", "a pointer of this release reports nothing to an app: there is no UIHoverEvent and no UIPointerInteraction, both iOS 13, and no other class hands an app a position on a pointing device")
    }
    public func privacySensitive(_ sensitive: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            if sensitive && environment.redactionReasons.contains(.privacy) { environment.redactedDrawing = true }
        }, onUpdate: nil))
    }
    public func flipsForRightToLeftLayoutDirection(_ enabled: Bool) -> some View {
        ignored(self, "flipsForRightToLeftLayoutDirection", "a view of this release has no direction of its own: semanticContentAttribute is iOS 9, and the only direction there is the app-wide userInterfaceLayoutDirection of iOS 5")
    }
    public func interactionActivityTrackingTag(_ tag: String) -> some View {
        ignored(self, "interactionActivityTrackingTag", "activity tracking is a measurement a system does, iOS 10; this release has none, so a tag on a view has nothing to be counted in")
    }
    public func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> some View {
        ignored(self, "handlesExternalEvents", "scenes are iOS 13, and this release has one screen rather than scenes")
    }
    @available(iOS 8.0, *)
    public func userActivity(_ activityType: String, isActive: Bool = true, _ update: @escaping (NSUserActivity) -> Void) -> some View {
        ignored(self, "userActivity", "iOS 6 has no user activities")
    }
    @available(iOS 8.0, *)
    public func onContinueUserActivity(_ activityType: String, perform action: @escaping (NSUserActivity) -> Void) -> some View {
        ignored(self, "onContinueUserActivity", "iOS 6 has no user activities")
    }
    public func navigationDocument<D>(_ document: D) -> some View {
        ignored(self, "navigationDocument", "the document proxy of a navigation bar is iOS 13; a UINavigationBar of this release carries a title and its items")
    }
    public func previewDevice(_ value: PreviewDevice?) -> some View {
        ignored(self, "previewDevice", "a preview is a canvas of Xcode that is built on a machine with a newer system than the device has; nothing of it is drawn on the device, and the modifier says so in the log")
    }
    public func previewLayout(_ value: PreviewLayout) -> some View {
        ignored(self, "previewLayout", "a preview is a canvas of Xcode that is built on a machine with a newer system than the device has; nothing of it is drawn on the device, and the modifier says so in the log")
    }
    public func previewDisplayName(_ value: String?) -> some View {
        ignored(self, "previewDisplayName", "a preview is a canvas of Xcode that is built on a machine with a newer system than the device has; nothing of it is drawn on the device, and the modifier says so in the log")
    }
    public func previewInterfaceOrientation(_ value: InterfaceOrientation) -> some View {
        ignored(self, "previewInterfaceOrientation", "a preview is a canvas of Xcode that is built on a machine with a newer system than the device has; nothing of it is drawn on the device, and the modifier says so in the log")
    }
    public func statusBar(hidden: Bool) -> some View {
        statusBarHidden(hidden)
    }
    public func submitScope(_ isBlocking: Bool = true) -> some View {
        // a blocking scope is the return key of a field of several lines: it runs the submit action of the screen instead of
        // being a line of its own, which is what -textView:shouldChangeTextInRange:replacementText: is for
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.submitBlocksReturn = isBlocking }, onUpdate: nil))
    }
    public func digitalCrownRotation<V: BinaryFloatingPoint>(_ binding: Binding<V>) -> some View {
        ignored(self, "digitalCrownRotation", "the digital crown is a watch, and this release is not one; there is no crown to turn and no accessory to show")
    }
    public func horizontalRadioGroupLayout() -> some View {
        ignored(self, "horizontalRadioGroupLayout", "a radio group is a group of radio buttons, and the control of this release for a choice is a UIPickerView of a wheel or a segmented control in a table cell")
    }
    public func touchBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ignored(self, "touchBar", "a touch bar is a strip of a MacBook, and this release runs on a device with no such strip")
    }
    public func onLongTouchGesture(minimumDuration: Double = 0.5, perform action: @escaping () -> Void, onTouchingChanged: ((Bool) -> Void)? = nil) -> some View {
        ignored(self, "onLongTouchGesture", "the long touch of a remote belongs to tvOS; a long press of a finger is onLongPressGesture and does reach a recogniser that waits for the finger to stay")
    }
}
