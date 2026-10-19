import UIKit
import CoreGraphics

public struct ProposedViewSize: Equatable {
    public var width: CGFloat?
    public var height: CGFloat?
    public static let unspecified = ProposedViewSize(width: nil, height: nil)
    public static let zero = ProposedViewSize(width: 0, height: 0)
    public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)
    public init(width: CGFloat?, height: CGFloat?) { self.width = width; self.height = height }
    public init(_ size: CGSize) { width = size.width; height = size.height }
    public func replacingUnspecifiedDimensions(by size: CGSize = CGSize(width: 10, height: 10)) -> CGSize {
        CGSize(width: width ?? size.width, height: height ?? size.height)
    }
    var proposal: ProposedSize {
        ProposedSize(width: width.map { $0.isFinite ? $0 : SwiftUI.infinity },
                     height: height.map { $0.isFinite ? $0 : SwiftUI.infinity })
    }
}

public struct LayoutSubview: Equatable {
    let node: LayoutNode
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { node.sizeThatFits(proposal.proposal) }
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions {
        let size = sizeThatFits(proposal)
        return ViewDimensions(width: size.width, height: size.height)
    }
    public var priority: Double { node.layoutPriority }
    public func place(at position: CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {
        let size = sizeThatFits(proposal)
        let origin = CGPoint(x: position.x - size.width * anchor.x, y: position.y - size.height * anchor.y)
        node.place(CGRect(origin: origin, size: size))
    }
    // the subview behind a LayoutSubview is the node it was made from, so that is what tells two of them apart
    public var containerValues: ContainerValues { ContainerValues.collect(from: node) }
    public static func == (a: LayoutSubview, b: LayoutSubview) -> Bool { a.node === b.node }
}

public struct LayoutSubviews: RandomAccessCollection {
    var items: [LayoutSubview]
    let direction: LayoutDirection
    public var layoutDirection: LayoutDirection { direction }
    public var startIndex: Int { items.startIndex }
    public var endIndex: Int { items.endIndex }
    public subscript(index: Int) -> LayoutSubview { items[index] }
    public subscript(bounds: Range<Int>) -> LayoutSubviews {
        LayoutSubviews(items: Array(items[bounds]), direction: direction)
    }
    public subscript<S: Sequence>(indices: S) -> LayoutSubviews where S.Element == Int {
        LayoutSubviews(items: indices.map { items[$0] }, direction: direction)
    }
    public static func == (lhs: LayoutSubviews, rhs: LayoutSubviews) -> Bool { lhs.items == rhs.items }
}

public protocol Layout: Animatable {
    static var layoutProperties: LayoutProperties { get }
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews
    func makeCache(subviews: LayoutSubviews) -> Cache
    func updateCache(_ cache: inout Cache, subviews: LayoutSubviews)
    func spacing(subviews: LayoutSubviews, cache: inout Cache) -> ViewSpacing
    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Cache) -> CGSize
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Cache)
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Cache) -> CGFloat?
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Cache) -> CGFloat?
}

extension Layout where Cache == Void {
    public func makeCache(subviews: LayoutSubviews) -> Void { () }
}

extension Layout {
    public static var layoutProperties: LayoutProperties { LayoutProperties() }
    public func updateCache(_ cache: inout Cache, subviews: LayoutSubviews) { cache = makeCache(subviews: subviews) }
    public func spacing(subviews: LayoutSubviews, cache: inout Cache) -> ViewSpacing { ViewSpacing() }
    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Cache) -> CGFloat? { nil }
    public func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Cache) -> CGFloat? { nil }
}

extension Layout {
    public func callAsFunction<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        _LayoutView(layout: self, content: content())
    }
}

public struct _LayoutView<L: Layout, Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let layout: L
    let content: Content
    func makeNode(_ env: EnvironmentValues) -> Node { let n = CustomLayoutNode<L>(); n.update(self, env); return n }
}

protocol LayoutViewLike {
    var layoutContent: any View { get }
}

extension _LayoutView: LayoutViewLike {
    var layoutContent: any View { content }
}

protocol ExplicitAlignmentProvider {
    func explicitGuide(key: String, size: CGSize) -> CGFloat?
}

final class CustomLayoutNode<L: Layout>: ContainerNode, LayoutContainer, ExplicitAlignmentProvider {
    var layout: L? { journey.shown }
    var cache: L.Cache?
    lazy var journey = Journey<L> { [unowned self] in
        self.refreshCache()
        self.invalidateLayout()
        self.env.host?.view.setNeedsLayout()
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        if let generic = view as? LayoutViewLike {
            content = adopt(reconcile(content, generic.layoutContent, env))
        }
        guard let new = Mirror(reflecting: view).children.first(where: { $0.label == "layout" })?.value as? L else { return }
        journey.retarget(new, animation: Updates.animationForFlush ?? env.animation)
        if let axis = L.layoutProperties.stackOrientation { children.forEach { $0.stackAxis = axis } }
        refreshCache()
    }

    var subviews: LayoutSubviews { LayoutSubviews(items: children.map { LayoutSubview(node: $0) }, direction: env.layoutDirection) }

    // The layout is asked for its cache once and told when its inputs change, as SwiftUI does, not once per pass.
    func refreshCache() {
        guard let layout, var current = cache else { return }
        layout.updateCache(&current, subviews: subviews)
        cache = current
    }

    func ensureCache(_ layout: L, _ list: LayoutSubviews) {
        if cache == nil { cache = layout.makeCache(subviews: list) }
    }

    override func dispose() {
        journey.dispose()
        super.dispose()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        guard let layout else { return .zero }
        let list = subviews
        ensureCache(layout, list)
        return layout.sizeThatFits(proposal: ProposedViewSize(width: p.width, height: p.height), subviews: list, cache: &cache!)
    }

    override func layoutContents(_ size: CGSize) {
        guard let layout else { return }
        let list = subviews
        ensureCache(layout, list)
        layout.placeSubviews(in: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                             proposal: ProposedViewSize(width: size.width, height: size.height),
                             subviews: list, cache: &cache!)
    }

    func explicitGuide(key: String, size: CGSize) -> CGFloat? {
        guard let layout else { return nil }
        let list = subviews
        ensureCache(layout, list)
        let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let proposal = ProposedViewSize(width: size.width, height: size.height)
        let id = String(key.dropFirst(2))
        if key.hasPrefix("h:") {
            return layout.explicitAlignment(of: HorizontalAlignment(raw: 0, id: id), in: bounds, proposal: proposal, subviews: list, cache: &cache!)
        }
        return layout.explicitAlignment(of: VerticalAlignment(raw: 0, id: id), in: bounds, proposal: proposal, subviews: list, cache: &cache!)
    }
}

public struct AnyLayout: Layout {
    let base: any Layout
    public init<L: Layout>(_ layout: L) { base = layout }
    public func makeCache(subviews: LayoutSubviews) -> Void { () }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Void) -> CGSize {
        sizeThatFitsErased(base, proposal, subviews)
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Void) {
        placeErased(base, bounds, proposal, subviews)
    }
    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Void) -> CGFloat? {
        explicitErased(base, horizontal: guide, bounds, proposal, subviews)
    }
    public func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Void) -> CGFloat? {
        explicitErased(base, vertical: guide, bounds, proposal, subviews)
    }
    public func spacing(subviews: LayoutSubviews, cache: inout Void) -> ViewSpacing {
        spacingErased(base, subviews)
    }
    public var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        set {}
    }
}

func explicitErased<L: Layout>(_ layout: L, horizontal guide: HorizontalAlignment, _ bounds: CGRect, _ proposal: ProposedViewSize, _ subviews: LayoutSubviews) -> CGFloat? {
    var cache = layout.makeCache(subviews: subviews)
    return layout.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
}

func explicitErased<L: Layout>(_ layout: L, vertical guide: VerticalAlignment, _ bounds: CGRect, _ proposal: ProposedViewSize, _ subviews: LayoutSubviews) -> CGFloat? {
    var cache = layout.makeCache(subviews: subviews)
    return layout.explicitAlignment(of: guide, in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
}

func spacingErased<L: Layout>(_ layout: L, _ subviews: LayoutSubviews) -> ViewSpacing {
    var cache = layout.makeCache(subviews: subviews)
    return layout.spacing(subviews: subviews, cache: &cache)
}

func sizeThatFitsErased<L: Layout>(_ layout: L, _ proposal: ProposedViewSize, _ subviews: LayoutSubviews) -> CGSize {
    var cache = layout.makeCache(subviews: subviews)
    return layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
}

func placeErased<L: Layout>(_ layout: L, _ bounds: CGRect, _ proposal: ProposedViewSize, _ subviews: LayoutSubviews) {
    var cache = layout.makeCache(subviews: subviews)
    layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
}
