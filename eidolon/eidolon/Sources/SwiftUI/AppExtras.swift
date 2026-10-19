import UIKit
import CoreGraphics

@propertyWrapper
public struct UIApplicationDelegateAdaptor<DelegateType: NSObject & UIApplicationDelegate>: DynamicProperty, DynamicPropertyInstaller {
    public private(set) var wrappedValue: DelegateType

    public init(_ delegateType: DelegateType.Type = DelegateType.self) {
        if let existing = AppRuntime.customDelegate as? DelegateType {
            wrappedValue = existing
        } else {
            let made = DelegateType()
            AppRuntime.customDelegate = made
            wrappedValue = made
        }
    }

    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {}
}

public struct PasteButton: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let onPaste: ([String]) -> Void
    public init(supportedContentTypes: [String] = [], payloadAction: @escaping ([String]) -> Void) {
        onPaste = payloadAction
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = PasteButtonNode(); n.update(self, env); return n }
}

final class PasteButtonNode: LayoutNode {
    let target = ControlTarget()
    var button: UIButton { uiView as! UIButton }

    init() {
        let control = UIButton(type: .roundedRect)
        super.init(view: control)
        control.setTitle("Paste", for: .normal)
        control.addTarget(target, action: #selector(ControlTarget.fire), for: .touchUpInside)
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let paste = view as? PasteButton else { return }
        let action = paste.onPaste
        target.action = {
            let board = UIPasteboard.general
            var payload: [String] = []
            if let text = board.string { payload.append(text) }
            action(payload)
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let wanted = button.sizeThatFits(CGSize(width: infinity, height: infinity))
        return CGSize(width: min(max(wanted.width + 24, 72), p.width ?? infinity), height: max(wanted.height, 37))
    }
}

public protocol GeometryEffect: ViewModifier, Animatable {
    func effectValue(size: CGSize) -> ProjectionTransform
}

public protocol AnimatableModifier: ViewModifier, Animatable {}

public struct SubscriptionView<PublisherType: Publisher, Content: View>: View where PublisherType.Failure == Never {
    let content: Content
    let publisher: PublisherType
    let action: (PublisherType.Output) -> Void
    public init(content: Content, publisher: PublisherType, action: @escaping (PublisherType.Output) -> Void) {
        self.content = content; self.publisher = publisher; self.action = action
    }
    public var body: some View {
        content.onReceive(publisher, perform: action)
    }
}

public struct ImagePaint: ShapeStyle {
    public var image: Image
    public var sourceRect: CGRect
    public var scale: CGFloat
    public init(image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) {
        self.image = image; self.sourceRect = sourceRect; self.scale = scale
    }
    public var _uiColor: UIColor? {
        (image.stored ?? UIImage(named: image.name)).map { UIColor(patternImage: $0) }
    }
}

public struct ContextMenu<MenuItems: View> {
    let items: MenuItems
    public init(@ViewBuilder menuItems: () -> MenuItems) { items = menuItems() }
}

public struct EventModifiers: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let capsLock = EventModifiers(rawValue: 1)
    public static let shift = EventModifiers(rawValue: 2)
    public static let control = EventModifiers(rawValue: 4)
    public static let option = EventModifiers(rawValue: 8)
    public static let command = EventModifiers(rawValue: 16)
    public static let numericPad = EventModifiers(rawValue: 32)
    public static let all = EventModifiers(rawValue: 63)
}

public struct EditActions<Data>: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static var delete: EditActions<Data> { EditActions(rawValue: 1) }
    public static var move: EditActions<Data> { EditActions(rawValue: 2) }
    public static var all: EditActions<Data> { EditActions(rawValue: 3) }
}

public struct ContentShapeKinds: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let interaction = ContentShapeKinds(rawValue: 1)
    public static let dragPreview = ContentShapeKinds(rawValue: 2)
    public static let contextMenuPreview = ContentShapeKinds(rawValue: 4)
    public static let hoverEffect = ContentShapeKinds(rawValue: 8)
}

public struct ScenePadding: Equatable {
    public static let minimum = ScenePadding()
    public static let navigationBar = ScenePadding()
}


public enum TimelineScheduleMode { case normal, lowFrequency }

public struct ExplicitTimelineSchedule<Entries: Sequence>: TimelineSchedule where Entries.Element == Date {
    let dates: Entries
    public init(_ dates: Entries) { self.dates = dates }
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries { dates }
}

extension TimelineSchedule {
    public static func explicit<S: Sequence>(_ dates: S) -> ExplicitTimelineSchedule<S> where Self == ExplicitTimelineSchedule<S> { ExplicitTimelineSchedule(dates) }
}

public struct SearchSuggestionsPlacement: Equatable {
    public static let automatic = SearchSuggestionsPlacement()
    public static let menu = SearchSuggestionsPlacement()
    public static let content = SearchSuggestionsPlacement()
}

public struct SearchScopeActivation {
    public static let automatic = SearchScopeActivation()
    public static let onTextEntry = SearchScopeActivation()
    public static let onSearchPresentation = SearchScopeActivation()
}

public struct AccessibilityActionKind: Equatable {
    let name: String
    init(kind: String) { name = kind }
    public static let `default` = AccessibilityActionKind(kind: "default")
    public static let escape = AccessibilityActionKind(kind: "escape")
    public static let magicTap = AccessibilityActionKind(kind: "magicTap")
    public init(named name: Text) { self.name = name.content }
}

public struct AccessibilitySystemRotor {
    public static func links() -> AccessibilitySystemRotor { AccessibilitySystemRotor() }
    public static func headings() -> AccessibilitySystemRotor { AccessibilitySystemRotor() }
}
