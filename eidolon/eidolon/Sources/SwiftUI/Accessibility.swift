import UIKit
import CoreGraphics

struct ApplyModifier: NodeModifier {
    let apply: (UIView) -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ApplyNode() }
}

final class ApplyNode: ContainerNode {
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        content = adopt(reconcile(content, m.modifiedContent, env))
        (m.modifierValue as! ApplyModifier).apply(uiView)
        for kid in children { (m.modifierValue as! ApplyModifier).apply(kid.uiView) }
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

public struct AccessibilityTraits: OptionSet {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let isButton = AccessibilityTraits(rawValue: UIAccessibilityTraits.button.rawValue)
    public static let isHeader = AccessibilityTraits(rawValue: UIAccessibilityTraits.header.rawValue)
    public static let isSelected = AccessibilityTraits(rawValue: UIAccessibilityTraits.selected.rawValue)
    public static let isImage = AccessibilityTraits(rawValue: UIAccessibilityTraits.image.rawValue)
    public static let isLink = AccessibilityTraits(rawValue: UIAccessibilityTraits.link.rawValue)
    public static let isStaticText = AccessibilityTraits(rawValue: UIAccessibilityTraits.staticText.rawValue)
    public static let isSearchField = AccessibilityTraits(rawValue: UIAccessibilityTraits.searchField.rawValue)
    public static let playsSound = AccessibilityTraits(rawValue: UIAccessibilityTraits.playsSound.rawValue)
    public static let updatesFrequently = AccessibilityTraits(rawValue: UIAccessibilityTraits.updatesFrequently.rawValue)
    public static let isSummaryElement = AccessibilityTraits(rawValue: UIAccessibilityTraits.summaryElement.rawValue)
    public static let allowsDirectInteraction = AccessibilityTraits(rawValue: UIAccessibilityTraits.allowsDirectInteraction.rawValue)
    public static let causesPageTurn = AccessibilityTraits(rawValue: UIAccessibilityTraits.causesPageTurn.rawValue)
    public static let isModal = AccessibilityTraits(rawValue: UIAccessibilityTraits.none.rawValue)
}

extension View {
    func applyingToViews(_ apply: @escaping (UIView) -> Void) -> some View {
        _ModifiedView(content: self, modifier: ApplyModifier(apply: apply))
    }

    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> some View {
        applyingToViews { $0.accessibilityLabel = String(label) }
    }
    public func accessibilityValue(_ value: Text) -> some View {
        applyingToViews { $0.accessibilityValue = value.content }
    }
    public func accessibilityValue<S: StringProtocol>(_ value: S) -> some View {
        applyingToViews { $0.accessibilityValue = String(value) }
    }
    public func accessibilityHint(_ hint: Text) -> some View {
        applyingToViews { $0.accessibilityHint = hint.content }
    }
    public func accessibilityHint<S: StringProtocol>(_ hint: S) -> some View {
        applyingToViews { $0.accessibilityHint = String(hint) }
    }
    public func accessibilityIdentifier<S: StringProtocol>(_ identifier: S) -> some View {
        applyingToViews { $0.accessibilityIdentifier = String(identifier) }
    }
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        applyingToViews { $0.accessibilityTraits = UIAccessibilityTraits(rawValue: $0.accessibilityTraits.rawValue | traits.rawValue) }
    }
    public func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        applyingToViews { $0.accessibilityTraits = UIAccessibilityTraits(rawValue: $0.accessibilityTraits.rawValue & ~traits.rawValue) }
    }
    public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View {
        applyingToViews { $0.isAccessibilityElement = true }
    }
    public func accessibilityShowsLargeContentViewer() -> some View {
        ignored(self, "accessibilityShowsLargeContentViewer", "the large content viewer is iOS 13; VoiceOver of iOS 6 reads the label of a view and nothing more of it")
    }
    public func accessibilityIgnoresInvertColors(_ active: Bool = true) -> some View {
        ignored(self, "accessibilityIgnoresInvertColors", "a view that keeps its colours is isAccessibilityIgnoresInvertColors, iOS 11; UIAccessibility of this release has invert-colours as one setting for the whole screen")
    }
    public func accessibilityRespondsToUserInteraction(_ responds: Bool = true) -> some View {
        ignored(self, "accessibilityRespondsToUserInteraction", "the flag is isAccessibilityRespondsToUserInteraction, iOS 13; an element of this release is either an element or it is not, and it takes touches as a view does")
    }
    public func accessibilityInputLabels<S: StringProtocol>(_ labels: [S]) -> some View {
        ignored(self, "accessibilityInputLabels", "input labels are for Voice Control, which is iOS 13; this release has no voice control to name a view for")
    }
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> some View {
        accessibilityAddTraits(.isHeader)
    }
    public func accessibilityAction(named name: Text, _ handler: @escaping () -> Void) -> some View {
        ignored(self, "accessibilityAction", "a custom action is UIAccessibilityCustomAction, iOS 8; the accessibility of this release answers activation, increment, decrement and scroll, and VoiceOver of iOS 6 double-taps the view itself")
    }
}

public struct AccessibilityChildBehavior {
    public static let ignore = AccessibilityChildBehavior()
    public static let contain = AccessibilityChildBehavior()
    public static let combine = AccessibilityChildBehavior()
}

public enum AccessibilityHeadingLevel { case unspecified, h1, h2, h3, h4, h5, h6 }

struct ActivationPointModifier: NodeModifier {
    let point: UnitPoint
    var absolute: CGPoint? = nil
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ActivationPointNode() }
}

final class ActivationPointNode: ContainerNode {
    var point = UnitPoint.center
    var absolute: CGPoint?
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        point = (m.modifierValue as! ActivationPointModifier).point
        absolute = (m.modifierValue as! ActivationPointModifier).absolute
        content = adopt(reconcile(content, m.modifiedContent, env))
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let local = absolute ?? CGPoint(x: size.width * point.x, y: size.height * point.y)
        let onScreen = uiView.window.map { uiView.convert(local, to: $0) } ?? uiView.convert(local, to: nil)
        uiView.accessibilityActivationPoint = onScreen
        for kid in children { kid.uiView.accessibilityActivationPoint = onScreen }
    }
}

extension View {
    public func accessibilityActivationPoint(_ point: UnitPoint) -> some View {
        _ModifiedView(content: self, modifier: ActivationPointModifier(point: point))
    }
    public func accessibilityActivationPoint(_ point: CGPoint) -> some View {
        _ModifiedView(content: self, modifier: ActivationPointModifier(point: .center, absolute: point))
    }
}
