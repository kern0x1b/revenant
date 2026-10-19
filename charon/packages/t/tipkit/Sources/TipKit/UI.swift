import Foundation
import UIKit
#if CHARON_CARRIES_LOCALIZED_STRING
import AppIntents
#endif
#if CHARON_CARRIES_LOCALIZED_STRING
import AppIntents
#endif

public protocol TipViewStyle {
    associatedtype Configuration = TipViewStyleConfiguration
    func makeBody(configuration: Configuration) -> TipUIView
    static var miniTip: Self { get }
}

extension TipViewStyle {
    public static var miniTip: Self { return MiniTipViewStyle() as! Self }
}

public struct TipViewStyleConfiguration {
    public let tip: AnyTip
    public let title: LocalizedStringResource
    public let message: LocalizedStringResource?
    public let image: LocalizedStringResource?
    public let actions: [Tips.Action]

    public init(tip: AnyTip) {
        self.tip = tip
        self.title = tip.title
        self.message = tip.message
        self.image = tip.image
        self.actions = tip.actions
    }
}

public struct MiniTipViewStyle: TipViewStyle {
    public typealias Body = TipUIView

    public init() {}

    public func makeBody(configuration: TipViewStyleConfiguration) -> TipUIView {
        return TipUIView(AnyTip(CharonMiniTip(tip: configuration.tip)), arrowEdge: .top, actionHandler: nil)
    }
}

open class TipUIView: UIView {
    public enum ArrowEdge: Int, CaseIterable {
        case top
        case bottom
        case leading
        case trailing
    }

    public enum BackgroundStyle: Int {
        case `default`
        case dimmed
        case clear
    }

    public private(set) var tip: AnyTip
    public let arrowEdge: ArrowEdge
    public var actionHandler: ((Tips.Action) -> Void)?
    public var backgroundStyle: BackgroundStyle = .default
    public var imageStyle: UIView.ContentMode = .scaleAspectFit
    public var imageSize: CGSize = CGSize(width: 24, height: 24)
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
        if superview != nil { Tips.Store.shared.recordShown(tip.id) }
    }

    public override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { super.backgroundColor = newValue }
    }

    open var cornerRadius: CGFloat { return 12 }
}

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

    open func configureTip(_ tip: AnyTip, arrowEdge: TipUIView.ArrowEdge,
                           actionHandler: ((Tips.Action) -> Void)? = nil) {
        self.tip = tip
        self.arrowEdge = arrowEdge
        self.actionHandler = actionHandler
    }

    open override var intrinsicContentSize: CGSize { return sizeThatFits(CGSize(width: 320, height: 0)) }

    open override func sizeThatFits(_ size: CGSize) -> CGSize { return CGSize(width: min(size.width, 280), height: 96) }

    open override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { super.backgroundColor = newValue }
    }
    open var cornerRadius: CGFloat { return 12 }
}

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

    open func configureTip(_ tip: AnyTip, arrowEdge: TipUIView.ArrowEdge,
                           actionHandler: ((Tips.Action) -> Void)? = nil) {
        self.tip = tip
        self.arrowEdge = arrowEdge
        self.actionHandler = actionHandler
    }

    open override var backgroundColor: UIColor? {
        get { super.backgroundColor }
        set { super.backgroundColor = newValue }
    }
    open var cornerRadius: CGFloat { return 12 }
}

open class TipUIPopoverViewController: UIViewController {
    public private(set) var tip: AnyTip
    public let sourceItem: UIView?
    public var actionHandler: ((Tips.Action) -> Void)?
    public var backgroundStyle: TipUIView.BackgroundStyle = .default
    public var imageStyle: UIView.ContentMode = .scaleAspectFit
    public var imageSize: CGSize = CGSize(width: 24, height: 24)
    public var viewStyle: any TipViewStyle = MiniTipViewStyle()
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

    public var backgroundColor: UIColor? {
        get { CharonPopover.background(for: backgroundStyle) }
        set { }
    }

    public var tipBackgroundColor: UIColor? {
        return CharonPopover.background(for: backgroundStyle)
    }
}

public struct TipView {
    public typealias Body = TipUIView

    public let tip: AnyTip
    public var isPresented: Bool
    public var arrowEdge: TipUIView.ArrowEdge
    public var anchorID: String?
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

    public var body: TipUIView {
        return TipUIView(tip, arrowEdge: arrowEdge, actionHandler: action)
    }
}

extension Tips {
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

enum CharonEmptyTip {
    static let title = CharonTipText.empty
}

enum CharonTipText {
    static var empty: LocalizedStringResource {
        #if CHARON_CARRIES_LOCALIZED_STRING
        return LocalizedStringResource(stringLiteral: "")
        #else
        return LocalizedStringResource(stringLiteral: "")
        #endif
    }
}

enum CharonPopover {
    static func background(for style: TipUIView.BackgroundStyle) -> UIColor? {
        return UIColor(white: 1, alpha: style == .dimmed ? 0.92 : 1)
    }
}

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
