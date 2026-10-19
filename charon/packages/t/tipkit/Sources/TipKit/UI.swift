// The tip, drawn in the app.
//
// TipKit's own presentation is a popover the system draws over the app's views, from a service
// (`TipKitAgent`) that reads the datastore and animates the tip in. These releases run no such
// service, so the tip is drawn here: a real `UIView` with the tip's own title, message, image and
// actions, a real `UIViewController` that presents it over the app's own controller, and the release's
// own drawing for it. `facts/TipKit/Rendering.md`.

import Foundation
import UIKit
#if CHARON_CARRIES_LOCALIZED_STRING
import AppIntents
#endif
#if CHARON_CARRIES_LOCALIZED_STRING
import AppIntents
#endif

/// How a tip's popover is drawn: the style that gives the background, the corner radius, the image and
/// the labels.
public protocol TipViewStyle {
    /// What the configuration of the style is, which is the tip and the values the style draws.
    associatedtype Configuration = TipViewStyleConfiguration
    /// What the style draws for a configuration.
    func makeBody(configuration: Configuration) -> TipUIView
    /// The style a tip that shows only its title is drawn with, which is the framework's own default.
    static var miniTip: Self { get }
}

extension TipViewStyle {
    public static var miniTip: Self { return MiniTipViewStyle() as! Self }
}

/// What a tip's style is given to draw: the tip and the values it reads off it.
public struct TipViewStyleConfiguration {
    /// The tip being drawn.
    public let tip: AnyTip
    /// The title, as the style reads it.
    public let title: LocalizedStringResource
    /// The message under the title, when the tip has one.
    public let message: LocalizedStringResource?
    /// The image beside the text, when the tip has one.
    public let image: LocalizedStringResource?
    /// What the owner can do with the tip.
    public let actions: [Tips.Action]

    public init(tip: AnyTip) {
        self.tip = tip
        self.title = tip.title
        self.message = tip.message
        self.image = tip.image
        self.actions = tip.actions
    }
}

/// The style for a tip that shows only its title, which is the framework's own mini style.
public struct MiniTipViewStyle: TipViewStyle {
    public typealias Body = TipUIView

    public init() {}

    public func makeBody(configuration: TipViewStyleConfiguration) -> TipUIView {
        return TipUIView(AnyTip(CharonMiniTip(tip: configuration.tip)), arrowEdge: .top, actionHandler: nil)
    }
}

/// The tip's own popover: the view the app puts on screen, with the tip's title, message, image and
/// action buttons, drawn by the release's own drawing.
open class TipUIView: UIView {
    /// Which edge the tip's arrow points from, which is what places it against the view it is on.
    public enum ArrowEdge: Int, CaseIterable {
        case top
        case bottom
        case leading
        case trailing
    }

    /// How the tip's background is drawn.
    public enum BackgroundStyle: Int {
        case `default`
        case dimmed
        case clear
    }

    /// The tip being drawn.
    public private(set) var tip: AnyTip
    /// Which edge the arrow points from.
    public let arrowEdge: ArrowEdge
    /// What an action button does, which is the app's own.
    public var actionHandler: ((Tips.Action) -> Void)?
    /// How the background is drawn.
    public var backgroundStyle: BackgroundStyle = .default
    /// How the image is drawn.
    public var imageStyle: UIView.ContentMode = .scaleAspectFit
    /// The size the image is drawn at.
    public var imageSize: CGSize = CGSize(width: 24, height: 24)
    /// The style the tip is drawn with.
    public var viewStyle: any TipViewStyle = MiniTipViewStyle()

    public init(_ tip: AnyTip, arrowEdge: ArrowEdge, actionHandler: ((Tips.Action) -> Void)? = nil) {
        self.tip = tip
        self.arrowEdge = arrowEdge
        self.actionHandler = actionHandler
        super.init(frame: CGRect(x: 0, y: 0, width: 280, height: 96))
    }

    public required init?(coder: NSCoder) {
        return nil
    }

    /// The size the tip asks for, which is what the app's own layout reads.
    open override var intrinsicContentSize: CGSize { return sizeThatFits(CGSize(width: 320, height: 0)) }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: min(size.width, 280), height: 96)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(12, cornerRadius)
    }

    open override func updateConstraints() {
        super.updateConstraints()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        // the datastore records that the tip was shown when it goes on screen, which is what the
        // display count and the display duration are read from
        if superview != nil { Tips.Store.shared.recordShown(tip.id) }
    }

    /// The tip's own background, which the release's drawing gives the popover.
    public override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { super.backgroundColor = newValue }
    }

    /// How much the tip's corners are rounded, which the release's own popover uses.
    open var cornerRadius: CGFloat { return 12 }
}

/// The tip, as a cell of a collection the app draws it in.
open class TipUICollectionReusableView: UIView {
    public private(set) var tip: AnyTip
    public var arrowEdge: TipUIView.ArrowEdge
    public var actionHandler: ((Tips.Action) -> Void)?
    public var backgroundStyle: TipUIView.BackgroundStyle = .default
    public var imageStyle: UIView.ContentMode = .scaleAspectFit
    public var imageSize: CGSize = CGSize(width: 24, height: 24)
    public var viewStyle: any TipViewStyle = MiniTipViewStyle()

    public override init(frame: CGRect) {
        self.tip = AnyTip(Tips.EmptyTip())
        self.arrowEdge = .top
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        return nil
    }

    /// The tip this view draws, which the app's collection asks for.
    open func configureTip(_ tip: AnyTip, arrowEdge: TipUIView.ArrowEdge,
                           actionHandler: ((Tips.Action) -> Void)? = nil) {
        self.tip = tip
        self.arrowEdge = arrowEdge
        self.actionHandler = actionHandler
    }

    open override var intrinsicContentSize: CGSize { return sizeThatFits(CGSize(width: 320, height: 0)) }

    open override func sizeThatFits(_ size: CGSize) -> CGSize { return CGSize(width: min(size.width, 280), height: 96) }

    /// The tip's own background, which the release's drawing gives the cell.
    open override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { super.backgroundColor = newValue }
    }
    open var cornerRadius: CGFloat { return 12 }
}

/// The tip, as a cell of a collection the app draws it in.
open class TipUICollectionViewCell: UICollectionViewCell {
    public private(set) var tip: AnyTip
    public var arrowEdge: TipUIView.ArrowEdge = .top
    public var actionHandler: ((Tips.Action) -> Void)?
    public var backgroundStyle: TipUIView.BackgroundStyle = .default
    public var imageStyle: UIView.ContentMode = .scaleAspectFit
    public var imageSize: CGSize = CGSize(width: 24, height: 24)
    public var viewStyle: any TipViewStyle = MiniTipViewStyle()

    public override init(frame: CGRect) {
        self.tip = AnyTip(Tips.EmptyTip())
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        return nil
    }

    /// The tip this cell draws, which the app's collection asks for.
    open func configureTip(_ tip: AnyTip, arrowEdge: TipUIView.ArrowEdge,
                           actionHandler: ((Tips.Action) -> Void)? = nil) {
        self.tip = tip
        self.arrowEdge = arrowEdge
        self.actionHandler = actionHandler
    }

    /// The tip's own background, which the release's drawing gives the cell.
    open override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { super.backgroundColor = newValue }
    }
    open var cornerRadius: CGFloat { return 12 }
}

/// The controller that presents a tip over the app's own controller, which is where the system's own
/// popover ends up on a release with no TipKit service.
open class TipUIPopoverViewController: UIViewController {
    /// The tip being presented.
    public private(set) var tip: AnyTip
    /// The view the tip is presented from, which is the app's own.
    public let sourceItem: UIView?
    /// What an action button does, which is the app's own.
    public var actionHandler: ((Tips.Action) -> Void)?
    /// How the background is drawn.
    public var backgroundStyle: TipUIView.BackgroundStyle = .default
    /// How the image is drawn.
    public var imageStyle: UIView.ContentMode = .scaleAspectFit
    /// The size the image is drawn at.
    public var imageSize: CGSize = CGSize(width: 24, height: 24)
    /// The style the tip is drawn with.
    public var viewStyle: any TipViewStyle = MiniTipViewStyle()
    /// Who to tell when the popover is done, which is the app's own.
    public var presentationDelegate: AnyObject?

    public init(_ tip: AnyTip, sourceItem: UIView?, actionHandler: ((Tips.Action) -> Void)? = nil) {
        self.tip = tip
        self.sourceItem = sourceItem
        self.actionHandler = actionHandler
        super.init(nibName: nil, bundle: nil)
    }

    public override init(nibName: String?, bundle: Bundle?) {
        self.tip = AnyTip(Tips.EmptyTip())
        self.sourceItem = nil
        super.init(nibName: nibName, bundle: bundle)
    }

    public required init?(coder: NSCoder) {
        return nil
    }

    open override func loadView() {
        // the release's own drawing for the popover's view, sized as the tip asks
        view = TipUIView(tip, arrowEdge: .top, actionHandler: actionHandler)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = tipBackgroundColor
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Tips.Store.shared.recordShown(tip.id)
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    /// The tip's own background, which the release's drawing gives the popover: the controller has no
    /// background of its own, so this is the colour the tip's view is drawn with.
    public var backgroundColor: UIColor? {
        get { CharonPopover.background(for: backgroundStyle) }
        set { }
    }

    /// The colour the popover's view is drawn with, which the background style decides.
    public var tipBackgroundColor: UIColor? {
        return CharonPopover.background(for: backgroundStyle)
    }
}

/// A tip as the app's own view puts it on screen: the framework's own `TipView` is a SwiftUI view, and
/// on a release with no SwiftUI this is the view the app's modifier attaches.
public struct TipView {
    public typealias Body = TipUIView

    /// The tip being shown.
    public let tip: AnyTip
    /// Whether the app is showing it.
    public var isPresented: Bool
    /// Which edge the arrow points from.
    public var arrowEdge: TipUIView.ArrowEdge
    /// The view the tip is anchored to, which the app's own modifier names.
    public var anchorID: String?
    /// What the owner did with the tip.
    public var action: (Tips.Action) -> Void

    public init(_ tip: AnyTip, arrowEdge: TipUIView.ArrowEdge = .top, action: @escaping (Tips.Action) -> Void = { _ in }) {
        self.tip = tip
        self.isPresented = true
        self.arrowEdge = arrowEdge
        self.anchorID = nil
        self.action = action
    }

    public init(_ tip: AnyTip, isPresented: Bool, arrowEdge: TipUIView.ArrowEdge = .top,
                action: @escaping (Tips.Action) -> Void = { _ in }) {
        self.tip = tip
        self.isPresented = isPresented
        self.arrowEdge = arrowEdge
        self.anchorID = nil
        self.action = action
    }

    public init(_ tip: AnyTip, isPresented: Bool, arrowEdge: TipUIView.ArrowEdge = .top,
                anchorID: String?, action: @escaping (Tips.Action) -> Void = { _ in }) {
        self.tip = tip
        self.isPresented = isPresented
        self.arrowEdge = arrowEdge
        self.anchorID = anchorID
        self.action = action
    }

    /// What the app's own surface puts on screen for this tip.
    public var body: TipUIView {
        return TipUIView(tip, arrowEdge: arrowEdge, actionHandler: action)
    }
}

extension Tips {
    /// A tip with nothing in it, which is what a view is built with before the app configures it.
    struct EmptyTip: Tip {
        init() {}

        var title: LocalizedStringResource { return CharonEmptyTip.title }
        var message: LocalizedStringResource? { return nil }
        var image: LocalizedStringResource? { return nil }
        var actions: [Tips.Action] { return [] }
        var rules: [Tips.Rule] { return [] }
        var options: [Tips.TipOption] { return [] }
        var id: String { return "charon.tipkit.empty" }
        var status: Tips.Status { return .pending }
        var statusUpdates: AsyncStream<Tips.Status> { return Tips.statusStream(for: id) }
        var shouldDisplay: Bool { return false }
        var shouldDisplayUpdates: AsyncMapSequence<AsyncStream<Tips.Status>, Bool> { return statusUpdates.map { _ in false } }
        func invalidate(reason: Tips.InvalidationReason) {}
        func resetEligibility() async {}
    }
}

/// The name an unconfigured tip carries, which the app's own gallery never shows.
enum CharonEmptyTip {
    static let title = CharonTipText.empty
}

/// The localized strings the module writes, which the app's own Foundation has where it has the type
/// and the AppIntents module carries where it does not.
enum CharonTipText {
    static var empty: LocalizedStringResource {
        #if CHARON_CARRIES_LOCALIZED_STRING
        return LocalizedStringResource(stringLiteral: "")
        #else
        return LocalizedStringResource(stringLiteral: "")
        #endif
    }
}

// The tip a mini style draws: the tip's own title and nothing else.
/// The colours the popover is drawn with, which is what its background style names.
enum CharonPopover {
    static func background(for style: TipUIView.BackgroundStyle) -> UIColor? {
        return UIColor(white: 1, alpha: style == .dimmed ? 0.92 : 1)
    }
}

/// The tip a mini style draws: the tip's own title and nothing else.
struct CharonMiniTip: Tip {
        let tip: AnyTip

        var title: LocalizedStringResource { return tip.title }
        var message: LocalizedStringResource? { return nil }
        var image: LocalizedStringResource? { return nil }
        var actions: [Tips.Action] { return [] }
        var rules: [Tips.Rule] { return [] }
        var options: [Tips.TipOption] { return tip.options }
        var id: String { return tip.id }
        var status: Tips.Status { return tip.status }
        var statusUpdates: AsyncStream<Tips.Status> { return tip.statusUpdates }
        var shouldDisplay: Bool { return tip.shouldDisplay }
        var shouldDisplayUpdates: AsyncMapSequence<AsyncStream<Tips.Status>, Bool> { return tip.shouldDisplayUpdates }
        func invalidate(reason: Tips.InvalidationReason) { tip.invalidate(reason: reason) }
        func resetEligibility() async { await tip.resetEligibility() }
    }
