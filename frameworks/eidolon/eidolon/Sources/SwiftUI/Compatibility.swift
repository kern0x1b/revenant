import UIKit
import CoreGraphics

public enum TextInputAutocapitalization { case never, words, sentences, characters }
public enum DynamicTypeSize: Comparable, CaseIterable { case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge }
public enum BlendMode: Int32, Hashable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion
    case hue, saturation, color, luminosity, sourceAtop, destinationOver, destinationOut, plusDarker, plusLighter
}
public struct ButtonBorderShape: Equatable {
    enum Kind: Equatable { case automatic, capsule, roundedRectangle(CGFloat?) }
    let kind: Kind
    public static let automatic = ButtonBorderShape(kind: .automatic)
    public static let capsule = ButtonBorderShape(kind: .capsule)
    public static let roundedRectangle = ButtonBorderShape(kind: .roundedRectangle(nil))
    public static func roundedRectangle(radius: CGFloat) -> ButtonBorderShape { ButtonBorderShape(kind: .roundedRectangle(radius)) }
}

struct InputSettings {
    var autocapitalization: UITextAutocapitalizationType?
    var autocorrection: UITextAutocorrectionType?
    var keyboard: UIKeyboardType?
    var onSubmit: (() -> Void)?
    var returnKey: UIReturnKeyType?
}

extension View {
    public func autocapitalization(_ style: UITextAutocapitalizationType) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.autocapitalization = style }, onUpdate: nil))
    }
    public func textInputAutocapitalization(_ style: TextInputAutocapitalization?) -> some View {
        let mapped: UITextAutocapitalizationType
        switch style {
        case .never: mapped = .none
        case .words: mapped = .words
        case .characters: mapped = .allCharacters
        default: mapped = .sentences
        }
        return autocapitalization(mapped)
    }
    public func disableAutocorrection(_ disable: Bool?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.autocorrection = (disable ?? false) ? .no : .yes }, onUpdate: nil))
    }
    public func autocorrectionDisabled(_ disable: Bool = true) -> some View { disableAutocorrection(disable) }
    public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.onSubmit = action }, onUpdate: nil))
    }

    public func textContentType(_ type: UITextContentType?) -> some View {
        ignored(self, "textContentType", "UITextContentType is iOS 12 and a UITextField of this release has no such trait; the keyboard of a field is chosen with .keyboardType")
    }

    public func keyboardType(_ type: UIKeyboardType) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.input.keyboard = type }, onUpdate: nil))
    }
    public func colorScheme(_ scheme: ColorScheme) -> some View { environment(\.colorScheme, scheme) }
    public func preferredColorScheme(_ scheme: ColorScheme?) -> some View { ignored(self, "preferredColorScheme", "this release has one appearance: every colour of the system and every sheet it puts up is the light one, and there is no second appearance to ask for — userInterfaceStyle is iOS 13") }
    public func controlSize(_ size: ControlSize) -> some View { environment(\.controlSize, size) }
    public func dynamicTypeSize(_ size: DynamicTypeSize) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.dynamicTypeSize = size
            environment.sizeCategory = ContentSizeCategory(size)
        }, onUpdate: nil))
    }
    public func dynamicTypeSize<T: RangeExpression>(_ range: T) -> some View where T.Bound == DynamicTypeSize {
        let inside = DynamicTypeSize.allCases.filter { range.contains($0) }
        let bounds = inside.isEmpty ? nil : inside.first!...inside.last!
        _Unsupported.note("dynamicTypeSize(range)", "the range limits the size the text of the subtree is drawn at; a view that reads \\.sizeCategory inside it still reads the category that was asked for")
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.dynamicTypeSizeRange = bounds }, onUpdate: nil))
    }
    public func drawingGroup(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear) -> some View {
        // the options are the same values `RasterizationOptions` carries, and the same two the layer of
        // iOS 6 has: a colour mode and an opaque flag are keys it has none of
        applyingToViews { view in
            view.layer.shouldRasterize = true
            var options = _RendererConfiguration.RasterizationOptions()
            options.colorMode = colorMode
            options.isOpaque = opaque
            options.applied(to: view.layer)
        }
    }
    public func edgesIgnoringSafeArea(_ edges: Edge.Set) -> some View { ignored(self, "edgesIgnoringSafeArea", "this release has no safe area to ignore: a screen is laid out below the status bar and below the navigation bar, and a UIViewController of iOS 6 has no way to be given edges to lay out under — the layout of an iOS 7 screen is not something the release can be asked for") }
    public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View { ignored(self, "ignoresSafeArea", "this release has no safe area to ignore: a screen is laid out below the status bar and below the navigation bar, and a UIViewController of iOS 6 has no way to be given edges to lay out under — the layout of an iOS 7 screen is not something the release can be asked for") }
    public func blendMode(_ mode: BlendMode) -> some View { ignored(self, "blendMode", "the blend is a compositing filter on the layer, and a layer of this release is not composited with one: of the filters the nineteen blend modes name, iOS 6.1.3 has CIMultiplyCompositing, CISourceAtopCompositing and CISourceOverCompositing, and a layer rendered with one of them over a black background comes out the colour of the layer, unblended (measured on the iPad 2, in _Probe.compositingFilterPaints)") }
    public func defersSystemGestures(on edges: Edge.Set) -> some View { ignored(self, "defersSystemGestures", "the edges of this release carry no system gesture: the interactive pop of the navigation bar and the pull of the notification centre are iOS 7 and iOS 8, so there is nothing for a view to be preferred over") }
    public func interactiveDismissDisabled(_ disabled: Bool = true) -> some View { ignored(self, "interactiveDismissDisabled", "a modal screen of this release is left with the buttons it has: there is no drag-to-dismiss of a sheet (that is iOS 13) for the modifier to turn off") }
    public func navigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View { ignored(self, "navigationBarTitleDisplayMode", "a UINavigationBar of this release centres its title and has no other style for it; the inline title is iOS 11") }
    public func persistentSystemOverlays(_ visibility: Visibility) -> some View { ignored(self, "persistentSystemOverlays", "the home indicator is iOS 11; the status bar is the only overlay a screen of this release has, and .statusBarHidden is what changes it") }
    public func redacted(reason: RedactionReasons) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.redactionReasons = environment.redactionReasons.union(reason)
            environment.redactedDrawing = !environment.redactionReasons.isEmpty
        }, onUpdate: nil))
    }
    public func unredacted() -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.redactionReasons = []
            environment.redactedDrawing = false
        }, onUpdate: nil))
    }
    public func symbolRenderingMode(_ mode: SymbolRenderingMode) -> some View { ignored(self, "symbolRenderingMode", "there are no SF Symbols on this release: the glyphs SymbolGlyphs draws are a fixed set with no palette and no levels to render them by") }
}

public struct SubmitTriggers: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1)
    public static let search = SubmitTriggers(rawValue: 2)
}

public enum ColorRenderingMode { case nonLinear, linear, extendedLinear }
public struct SafeAreaRegions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let all = SafeAreaRegions(rawValue: 7)
    public static let container = SafeAreaRegions(rawValue: 1)
    public static let keyboard = SafeAreaRegions(rawValue: 2)
}
public struct ViewDimensions {
    public let width: CGFloat
    public let height: CGFloat
    var explicit: [String: CGFloat] = [:]
    init(width: CGFloat, height: CGFloat) { self.width = width; self.height = height }
    public subscript(guide: HorizontalAlignment) -> CGFloat {
        explicit["h:" + guide.id] ?? guide.defaultValue(ViewDimensions(width: width, height: height))
    }
    public subscript(guide: VerticalAlignment) -> CGFloat {
        explicit["v:" + guide.id] ?? guide.defaultValue(ViewDimensions(width: width, height: height))
    }
    public subscript(explicit guide: HorizontalAlignment) -> CGFloat? { explicit["h:" + guide.id] }
    public subscript(explicit guide: VerticalAlignment) -> CGFloat? { explicit["v:" + guide.id] }
}
public enum Prominence { case standard, increased }
public struct RedactionReasons: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let placeholder = RedactionReasons(rawValue: 1)
    public static let privacy = RedactionReasons(rawValue: 2)
}
public enum SubmitLabel { case done, go, send, join, route, search, `return`, next, `continue` }
public enum HorizontalEdge { case leading, trailing }
public enum SymbolRenderingMode { case monochrome, multicolor, hierarchical, palette }
public struct AnyTransition {
    var storage = TransitionSpec()
    public static let identity = AnyTransition()
    public static let opacity = AnyTransition(storage: TransitionSpec(fades: true, scale: nil, offset: nil))
    public static let scale = AnyTransition(storage: TransitionSpec(fades: false, scale: 0.1, offset: nil))
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition {
        AnyTransition(storage: TransitionSpec(fades: false, scale: scale, offset: nil))
    }
    public static let slide = AnyTransition.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    public static func move(edge: Edge) -> AnyTransition {
        let offset: CGSize
        switch edge {
        case .leading: offset = CGSize(width: -320, height: 0)
        case .trailing: offset = CGSize(width: 320, height: 0)
        case .top: offset = CGSize(width: 0, height: -480)
        case .bottom: offset = CGSize(width: 0, height: 480)
        }
        return AnyTransition(storage: TransitionSpec(fades: false, scale: nil, offset: offset))
    }
    public static func offset(_ offset: CGSize) -> AnyTransition {
        AnyTransition(storage: TransitionSpec(fades: false, scale: nil, offset: offset))
    }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition {
        offset(CGSize(width: x, height: y))
    }
    // The old view is pushed out of the edge the new one came in by, as a stack of cards is.
    public static func push(from edge: Edge) -> AnyTransition {
        let opposite: Edge
        switch edge {
        case .leading: opposite = .trailing
        case .trailing: opposite = .leading
        case .top: opposite = .bottom
        case .bottom: opposite = .top
        }
        return .asymmetric(insertion: .move(edge: edge), removal: .move(edge: opposite))
    }
    public func combined(with other: AnyTransition) -> AnyTransition {
        var merged = storage
        if other.storage.fades { merged.fades = true }
        merged.scale = merged.scale ?? other.storage.scale
        merged.offset = merged.offset ?? other.storage.offset
        return AnyTransition(storage: merged)
    }
    public func animation(_ animation: Animation?) -> AnyTransition {
        var copy = self
        copy.storage.animation = animation
        return copy
    }
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition {
        var spec = insertion.storage
        spec.removals = [removal.storage]
        return AnyTransition(storage: spec)
    }
}
public enum NavigationBarItem {
    public enum TitleDisplayMode { case automatic, inline, large }
}

extension Text {
    public enum TruncationMode { case head, middle, tail }
}

extension View {
    public func truncationMode(_ mode: Text.TruncationMode) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            switch mode {
            case .head: environment.truncation = .byTruncatingHead
            case .middle: environment.truncation = .byTruncatingMiddle
            case .tail: environment.truncation = .byTruncatingTail
            }
        }, onUpdate: nil))
    }

    public func scrollDisabled(_ disabled: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.isScrollEnabled = !disabled }, onUpdate: nil))
            .applyingToViews { view in
                if let scroller = view as? UIScrollView { scroller.isScrollEnabled = !disabled }
            }
    }

    public func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View {
        applyingToViews { view in
            guard let scroller = view as? UIScrollView else { return }
            let shown = visibility != .hidden && visibility != .never
            if axes.contains(.vertical) { scroller.showsVerticalScrollIndicator = shown }
            if axes.contains(.horizontal) { scroller.showsHorizontalScrollIndicator = shown }
        }
    }

    public func allowsTightening(_ flag: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.allowsTightening = flag }, onUpdate: nil))
    }
}
