import UIKit
import CoreGraphics

public enum Axis { case horizontal, vertical }

struct ProposedSize: Equatable {
    var width: CGFloat?
    var height: CGFloat?
    static let unspecified = ProposedSize(width: nil, height: nil)
    subscript(axis: Axis) -> CGFloat? {
        get { axis == .horizontal ? width : height }
        set { if axis == .horizontal { width = newValue } else { height = newValue } }
    }
}

let infinity = CGFloat(1e9)

extension CGSize {
    subscript(axis: Axis) -> CGFloat {
        get { axis == .horizontal ? width : height }
        set { if axis == .horizontal { width = newValue } else { height = newValue } }
    }
}

class LayoutNode: Node {
    private(set) var uiView: UIView
    var stackAxis: Axis?
    var layoutPriority: Double = 0
    init(view: UIView) { uiView = view }
    func replaceView(_ view: UIView) { uiView = view }
    override var flattened: [LayoutNode] { [self] }
    private var sizeCache: [(proposal: ProposedSize, axis: Axis?, size: CGSize)] = []
    final func sizeThatFits(_ proposal: ProposedSize) -> CGSize {
        for entry in sizeCache where entry.proposal == proposal && entry.axis == stackAxis { LayoutCounters.hits += 1; return entry.size }
        LayoutCounters.misses += 1
        let size = computeSize(proposal)
        if sizeCache.count == 32 { sizeCache.removeFirst() }
        sizeCache.append((proposal, stackAxis, size))
        return size
    }
    func computeSize(_ proposal: ProposedSize) -> CGSize { .zero }
    var needsLayout = true
    func dropSizeCache() {
        sizeCache.removeAll(keepingCapacity: true)
        needsLayout = true
    }
    func layoutContents(_ size: CGSize) {}
    final func place(_ frame: CGRect) {
        let rounded = CGRect(x: round(frame.origin.x), y: round(frame.origin.y), width: round(frame.size.width), height: round(frame.size.height))
        // Size and centre, not `frame`: for a view with a transform the frame is the box of the transformed view, and
        // UIKit says setting it is undefined.
        let centre = CGPoint(x: rounded.midX, y: rounded.midY)
        let unmoved = uiView.bounds.size == rounded.size && uiView.center == centre
        if unmoved && !needsLayout { return }
        if !unmoved {
            uiView.bounds = CGRect(origin: uiView.bounds.origin, size: rounded.size)
            uiView.center = centre
        }
        needsLayout = false
        layoutContents(rounded.size)
    }
}

func syncSubviews(_ container: UIView, _ nodes: [LayoutNode]) {
    let wanted = nodes.map { $0.uiView }
    let animation = Updates.animationForFlush
    for v in container.subviews where !wanted.contains(where: { $0 === v }) {
        if let whole = Transitions.spec(for: v), let animation = whole.removal.animation ?? whole.animation ?? animation {
            let spec = whole.removal
            UIView.animate(withDuration: animation.playedDuration, delay: animation.delay, options: animation.once.options, animations: {
                spec.apply(v, entering: false)
            }, completion: { _ in
                spec.reset(v)
                v.removeFromSuperview()
            })
        } else {
            Transitions.forget(v)
            v.removeFromSuperview()
        }
    }
    for (i, v) in wanted.enumerated() {
        let isNew = v.superview !== container
        if isNew || container.subviews.firstIndex(where: { $0 === v }) != i {
            container.insertSubview(v, at: min(i, container.subviews.count))
        }
        if isNew, let spec = Transitions.spec(for: v), let animation = spec.animation ?? animation {
            spec.apply(v, entering: true)
            UIView.animate(withDuration: animation.playedDuration, delay: animation.delay, options: animation.once.options, animations: {
                spec.reset(v)
            }, completion: nil)
        }
    }
}

class ContainerNode: LayoutNode {
    var content: Node?
    var children: [LayoutNode] { content?.flattened ?? [] }
    override var disposableChildren: [Node] { content.map { [$0] } ?? [] }
    init() { super.init(view: UIView()) ; uiView.backgroundColor = .clear }
    init(container: UIView) { super.init(view: container) ; uiView.backgroundColor = .clear }
    override func mountContents() {
        let kids = children
        syncSubviews(uiView, kids)
        content?.mount()
    }
}

final class StackNode: ContainerNode {
    var axis: Axis = .vertical
    var spacing: CGFloat = 8
    var alignment: Int = 0
    var guide: StackGuide?

    func measure(_ available: CGSize?, _ proposal: ProposedSize) -> [CGSize] {
        let kids = children
        kids.forEach { $0.stackAxis = axis }
        let cross: Axis = axis == .horizontal ? .vertical : .horizontal
        guard let total = proposal[axis] else {
            return kids.map { kid in var p = ProposedSize.unspecified; p[cross] = proposal[cross]; return kid.sizeThatFits(p) }
        }
        var mins: [CGFloat] = [], flex: [CGFloat] = []
        for kid in kids {
            var lo = ProposedSize.unspecified; lo[axis] = 0; lo[cross] = proposal[cross]
            var hi = lo; hi[axis] = infinity
            let low = kid.sizeThatFits(lo)[axis]
            mins.append(low)
            flex.append(kid.sizeThatFits(hi)[axis] - low)
        }
        var remaining = total - spacing * CGFloat(max(0, kids.count - 1)) - mins.reduce(0, +)
        var sizes = [CGSize](repeating: .zero, count: kids.count)
        let order = kids.indices.sorted { left, right in
            if kids[left].layoutPriority != kids[right].layoutPriority {
                return kids[left].layoutPriority > kids[right].layoutPriority
            }
            return flex[left] < flex[right]
        }
        // Views that can take any room (spacers, frames of infinite width) come last and share what the others leave;
        // they do not dilute the share the others are offered, so a Text beside a Spacer gets its full width.
        let greedy = flex.map { $0 > 1e7 }
        var finiteLeft = greedy.filter { !$0 }.count
        var greedyLeft = greedy.count - finiteLeft
        for i in order {
            var p = ProposedSize.unspecified
            let divisor = greedy[i] ? greedyLeft : finiteLeft
            p[axis] = mins[i] + max(0, remaining / CGFloat(max(1, divisor)))
            p[cross] = proposal[cross]
            let s = kids[i].sizeThatFits(p)
            sizes[i] = s
            remaining -= max(0, s[axis] - mins[i])
            if greedy[i] { greedyLeft -= 1 } else { finiteLeft -= 1 }
        }
        return sizes
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let v = view as? VStackLike else { return }
        spacing = v.stackSpacing ?? 8
        alignment = v.stackAlignment
        guide = v.stackGuide
        content = adopt(reconcile(content, v.stackContent, env))
    }

    override func computeSize(_ proposal: ProposedSize) -> CGSize {
        let sizes = measure(nil, proposal)
        var result = CGSize.zero
        let cross: Axis = axis == .horizontal ? .vertical : .horizontal
        result[axis] = sizes.reduce(0) { $0 + $1[axis] } + spacing * CGFloat(max(0, sizes.count - 1))
        result[cross] = sizes.map { $0[cross] }.max() ?? 0
        if let guide, guide.custom || hasGuides(children, upTo: self) {
            result[cross] = alignedOffsets(children, sizes, guide, cross, upTo: self).extent
        }
        return result
    }

    override func layoutContents(_ size: CGSize) {
        var proposal = ProposedSize.unspecified
        proposal.width = size.width
        proposal.height = size.height
        let sizes = measure(size, proposal)
        let cross: Axis = axis == .horizontal ? .vertical : .horizontal
        var position: CGFloat = 0
        var aligned: [CGFloat]?
        var start: CGFloat = 0
        if let guide, guide.custom || hasGuides(children, upTo: self) {
            let layout = alignedOffsets(children, sizes, guide, cross, upTo: self)
            aligned = layout.offsets
            let free = size[cross] - layout.extent
            start = alignment < 0 ? 0 : alignment > 0 ? free : free / 2
        }
        for (index, (kid, s)) in zip(children, sizes).enumerated() {
            var origin = CGPoint.zero
            let free = size[cross] - s[cross]
            let crossPos = aligned.map { start + $0[index] } ?? (alignment < 0 ? 0 : alignment > 0 ? free : free / 2)
            if axis == .horizontal { origin = CGPoint(x: position, y: crossPos) } else { origin = CGPoint(x: crossPos, y: position) }
            kid.place(CGRect(origin: origin, size: s))
            position += s[axis] + spacing
        }
    }
}

public struct VStack<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let alignment: HorizontalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = StackNode(); n.axis = .vertical; n.update(self, env); return n }
}

public struct HStack<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let alignment: VerticalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = StackNode(); n.axis = .horizontal; n.update(self, env); return n }
}


protocol VStackLike {
    var stackSpacing: CGFloat? { get }
    var stackAlignment: Int { get }
    var stackGuide: StackGuide { get }
    var stackContent: any View { get }
}

extension VStack: VStackLike {
    var stackSpacing: CGFloat? { spacing }
    var stackAlignment: Int { alignment.raw }
    var stackGuide: StackGuide { alignment.guide }
    var stackContent: any View { content }
}

extension HStack: VStackLike {
    var stackSpacing: CGFloat? { spacing }
    var stackAlignment: Int { alignment.raw }
    var stackGuide: StackGuide { alignment.guide }
    var stackContent: any View { content }
}

public struct Spacer: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public var minLength: CGFloat?
    public init(minLength: CGFloat? = nil) { self.minLength = minLength }
    func makeNode(_ env: EnvironmentValues) -> Node { SpacerNode(minLength: minLength ?? 8) }
}

final class SpacerNode: LayoutNode {
    var minLength: CGFloat
    init(minLength: CGFloat) { self.minLength = minLength; super.init(view: UIView()) }
    override func update(_ view: any View, _ env: EnvironmentValues) { super.update(view, env); minLength = (view as! Spacer).minLength ?? 8 }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        guard let axis = stackAxis else { return CGSize(width: p.width ?? 0, height: p.height ?? 0) }
        var s = CGSize.zero
        s[axis] = max(minLength, p[axis] ?? minLength)
        return s
    }
}

public enum Edge: Int8, CaseIterable {
    case top, leading, bottom, trailing

    public struct Set: OptionSet {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public init(_ edge: Edge) { self.init(rawValue: 1 << edge.rawValue) }
        public static let top = Set(.top)
        public static let leading = Set(.leading)
        public static let bottom = Set(.bottom)
        public static let trailing = Set(.trailing)
        public static let all = Set(rawValue: 0b1111)
        public static let horizontal = Set(rawValue: Set.leading.rawValue | Set.trailing.rawValue)
        public static let vertical = Set(rawValue: Set.top.rawValue | Set.bottom.rawValue)
    }
}

public struct EdgeInsets: Hashable {
    public var top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat
    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing
    }
}

final class PaddingNode: ContainerNode {
    var insets = EdgeInsets()
    var single: LayoutNode? { children.count == 1 ? children[0] : nil }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        let inner = ProposedSize(width: p.width.map { max(0, $0 - insets.leading - insets.trailing) },
                                 height: p.height.map { max(0, $0 - insets.top - insets.bottom) })
        let s = children.first?.sizeThatFits(inner) ?? .zero
        return CGSize(width: s.width + insets.leading + insets.trailing, height: s.height + insets.top + insets.bottom)
    }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: insets.leading, y: insets.top, width: size.width - insets.leading - insets.trailing, height: size.height - insets.top - insets.bottom))
    }
}

final class FrameNode: ContainerNode {
    var width: CGFloat?, height: CGFloat?, maxWidth: CGFloat?, maxHeight: CGFloat?
    var minWidth: CGFloat?, minHeight: CGFloat?
    var alignment = 0
    var fixed = false
    var vertical = 0
    var fixedAxes: Axis.Set = [.horizontal, .vertical]

    override func computeSize(_ p: ProposedSize) -> CGSize {
        var inner = ProposedSize(width: width ?? (maxWidth != nil ? p.width.map { min($0, maxWidth!) } : p.width),
                                 height: height ?? (maxHeight != nil ? p.height.map { min($0, maxHeight!) } : p.height))
        if fixed && fixedAxes.contains(.horizontal) { inner.width = nil }
        if fixed && fixedAxes.contains(.vertical) { inner.height = nil }
        let s = children.first?.sizeThatFits(inner) ?? .zero
        var w = width ?? s.width, h = height ?? s.height
        if let m = maxWidth, width == nil { w = min(m, max(s.width, p.width ?? s.width)) }
        if let m = maxHeight, height == nil { h = min(m, max(s.height, p.height ?? s.height)) }
        if let m = minWidth { w = max(w, m) }
        if let m = minHeight { h = max(h, m) }
        return CGSize(width: w, height: h)
    }
    override func layoutContents(_ size: CGSize) {
        guard let kid = children.first else { return }
        let s = kid.sizeThatFits(ProposedSize(width: size.width, height: size.height))
        let w = min(s.width, size.width), h = min(s.height, size.height)
        let x = alignment < 0 ? 0 : alignment > 0 ? size.width - w : (size.width - w) / 2
        let y = vertical < 0 ? 0 : vertical > 0 ? size.height - h : (size.height - h) / 2
        kid.place(CGRect(x: x, y: y, width: w, height: h))
    }
}

public struct ZStack<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let alignment: Alignment, content: Content
    public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ZStackNode(); n.update(self, env); return n }
}

public struct Alignment: Equatable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment
    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal; self.vertical = vertical
    }
    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

final class ZStackNode: ContainerNode {
    var alignment = Alignment.center
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let z = view as? ZStackLike else { return }
        alignment = z.stackAlignment
        content = adopt(reconcile(content, z.stackContent, env))
    }
    override func computeSize(_ p: ProposedSize) -> CGSize {
        var size = CGSize.zero
        for kid in children {
            let s = kid.sizeThatFits(p)
            size.width = max(size.width, s.width)
            size.height = max(size.height, s.height)
        }
        return size
    }
    override func layoutContents(_ size: CGSize) {
        for kid in children {
            let s = kid.sizeThatFits(ProposedSize(width: size.width, height: size.height))
            let x = alignment.horizontal.raw < 0 ? 0 : alignment.horizontal.raw > 0 ? size.width - s.width : (size.width - s.width) / 2
            let y = alignment.vertical.raw < 0 ? 0 : alignment.vertical.raw > 0 ? size.height - s.height : (size.height - s.height) / 2
            kid.place(CGRect(x: x, y: y, width: s.width, height: s.height))
        }
    }
}

protocol ZStackLike {
    var stackAlignment: Alignment { get }
    var stackContent: any View { get }
}

extension ZStack: ZStackLike {
    var stackAlignment: Alignment { alignment }
    var stackContent: any View { content }
}

public struct ScrollView<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public var axes: Axis.Set
    public var showsIndicators: Bool
    public var content: Content
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.axes = axes; self.showsIndicators = showsIndicators; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ScrollNode(); n.update(self, env); return n }
}

extension Axis {
    public struct Set: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1)
        public static let vertical = Set(rawValue: 2)
    }
}

protocol ScrollViewLike {
    var scrollAxes: Axis.Set { get }
    var scrollIndicators: Bool { get }
    var scrollContent: any View { get }
}

extension ScrollView: ScrollViewLike {
    var scrollAxes: Axis.Set { axes }
    var scrollIndicators: Bool { showsIndicators }
    var scrollContent: any View { content }
}

// The environment says whether an indicator is drawn; the view's own flag says so when the
// environment has nothing to say, and an axis the scroll view does not have draws nothing at all.
private func shown(_ visibility: Visibility, _ flag: Bool, _ axis: Axis.Set, _ axes: Axis.Set) -> Bool {
    guard axes.contains(axis) else { return false }
    switch visibility {
    case .visible: return true
    case .hidden: return false
    case .automatic: return flag
    }
}

private func bounces(_ behavior: ScrollBounceBehavior, _ was: Bool) -> Bool {
    switch behavior {
    case .automatic: return was
    case .always: return true
    case .basedOnSize: return false
    }
}

final class ScrollNode: ContainerNode {
    func scrollToTop() { scrollView.setContentOffset(.zero, animated: true) }

    var axes: Axis.Set = .vertical
    var scrollView: UIScrollView { uiView as! UIScrollView }
    private(set) var requested: ScrollPosition?
    private(set) var applied: ScrollPosition?
    var request: ScrollPositionRequest?
    var target: AnyScrollTargetBehavior?
    var anchors: ScrollAnchors?
    var restingTargets: [ScrollTarget] = []
    var observers: ScrollObservers?
    var phase: ScrollPhase = ScrollPhase(.idle)
    private var applying = false
    private var animatingTo: CGPoint?
    let scrollDelegate = ScrollNodeDelegate()

    override init() {
        super.init()
        let scroller = UIScrollView()
        scroller.backgroundColor = .clear
        replaceView(scroller)
        scrollDelegate.node = self
        scroller.delegate = scrollDelegate
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let s = view as? ScrollViewLike else { return }
        axes = s.scrollAxes
        scrollView.showsVerticalScrollIndicator = shown(env.verticalScrollIndicatorVisibility, s.scrollIndicators, .vertical, axes)
        scrollView.showsHorizontalScrollIndicator = shown(env.horizontalScrollIndicatorVisibility, s.scrollIndicators, .horizontal, axes)
        scrollView.alwaysBounceVertical = bounces(env.verticalScrollBounceBehavior, scrollView.alwaysBounceVertical)
        scrollView.alwaysBounceHorizontal = bounces(env.horizontalScrollBounceBehavior, scrollView.alwaysBounceHorizontal)

        scrollView.clipsToBounds = !env.scrollClipDisabled
        request = env.scrollPosition
        target = env.scrollTarget
        anchors = env.scrollAnchors
        observers = env.scrollObservers
        requested = env.scrollPosition?.binding.wrappedValue
        scrollView.isScrollEnabled = env.isScrollEnabled
        content = adopt(reconcile(content, s.scrollContent, env))
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        if env.isScrollEnabled { return CGSize(width: p.width ?? contentSize(p).width, height: p.height ?? contentSize(p).height) }
        let inner = contentSize(p)
        return CGSize(width: p.width ?? inner.width, height: p.height ?? inner.height)
    }

    func contentSize(_ p: ProposedSize) -> CGSize {
        var proposal = p
        if axes.contains(.vertical) { proposal.height = nil }
        if axes.contains(.horizontal) { proposal.width = nil }
        var size = CGSize.zero
        for kid in children {
            let s = kid.sizeThatFits(proposal)
            size.width = max(size.width, s.width)
            size.height += s.height
        }
        return size
    }

    override func layoutContents(_ size: CGSize) {
        let inner = contentSize(ProposedSize(width: size.width, height: size.height))
        var y: CGFloat = 0
        for kid in children {
            var proposal = ProposedSize(width: size.width, height: size.height)
            if axes.contains(.vertical) { proposal.height = nil }
            if axes.contains(.horizontal) { proposal.width = nil }
            let s = kid.sizeThatFits(proposal)
            kid.place(CGRect(x: 0, y: y, width: max(s.width, axes.contains(.horizontal) ? s.width : size.width), height: s.height))
            y += s.height
        }
        scrollView.contentSize = CGSize(width: max(inner.width, size.width), height: max(inner.height, size.height))
        collectTargets()
        reportGeometry()
        if applied == nil, let anchors { applyAnchors(anchors) }
        if let wanted = requested, wanted != applied, let offset = restingOffset(for: wanted) {
            apply(offset, wanted: wanted)
        }
    }

    // The resting offset of every target the content marks with `scrollTargetLayout`, in this scroller's coordinates.
    private func collectTargets() {
        var found: [ScrollTarget] = []
        for kid in children { walkTargets(kid, into: &found) }
        restingTargets = found
    }

    private func walkTargets(_ node: Node, into found: inout [ScrollTarget]) {
        if node is ScrollTargetLayoutNode {
            let inner = node.flattened
            if inner.isEmpty || node.childNodes.isEmpty {
                if let view = inner.first?.uiView {
                    found.append(ScrollTarget(rect: view.convert(view.bounds, to: scrollView), anchor: request?.anchor))
                }
            } else {
                for child in node.childNodes { walkTargets(child, into: &found) }
            }
            return
        }
        for child in node.childNodes { walkTargets(child, into: &found) }
    }

    /// The geometry and the phase as SwiftUI reports them: from the scroller itself, whenever either moved.
    private func reportGeometry() {
        guard var stored = observers else { return }
        let view = scrollView
        var current = ScrollGeometry()
        current.contentOffset = view.contentOffset
        current.contentSize = view.contentSize
        current.containerSize = view.bounds.size
        current.visibleRect = CGRect(origin: view.contentOffset, size: view.bounds.size)
        current.bounds = CGRect(origin: .zero, size: view.bounds.size)
        if let last = stored.lastGeometry, last != current, let action = stored.onGeometry { action(last, current) }
        stored.lastGeometry = current
        stored.lastPhase = phase
        observers = stored
    }

    private func restingOffset(for position: ScrollPosition) -> CGPoint? {
        let view = scrollView
        let limit = CGSize(width: max(0, view.contentSize.width - view.bounds.size.width),
                           height: max(0, view.contentSize.height - view.bounds.size.height))
        var offset = view.contentOffset
        if let id = position.id, let target = findIdentified(id, in: self) {
            let rect = target.uiView.convert(target.uiView.bounds, to: view)
            let anchor = position.anchor ?? request?.anchor ?? .top
            offset = CGPoint(x: rect.origin.x + rect.size.width * anchor.x - view.bounds.size.width * anchor.x,
                             y: rect.origin.y + rect.size.height * anchor.y - view.bounds.size.height * anchor.y)
        } else if let edge = position.edge {
            switch edge {
            case .top, .leading: offset = .zero
            case .bottom: offset = CGPoint(x: offset.x, y: limit.height)
            case .trailing: offset = CGPoint(x: limit.width, y: offset.y)
            }
        } else if let point = position.point {
            offset = CGPoint(x: point.x * limit.width, y: point.y * limit.height)
        } else {
            if let x = position.x { offset.x = x }
            if let y = position.y { offset.y = y }
        }
        return CGPoint(x: min(max(0, offset.x), limit.width), y: min(max(0, offset.y), limit.height))
    }

    private func applyAnchors(_ anchors: ScrollAnchors) {
        let view = scrollView
        let limit = CGSize(width: max(0, view.contentSize.width - view.bounds.size.width),
                           height: max(0, view.contentSize.height - view.bounds.size.height))
        move(to: CGPoint(x: anchors.alignment.x * limit.width, y: anchors.initialOffset.y * limit.height))
        applied = requested ?? ScrollPosition()
    }

    private func apply(_ offset: CGPoint, wanted: ScrollPosition) {
        applied = wanted
        move(to: offset)
    }

    // A scroll the app asked for is not the user's own scrolling, so the delegate must not report it back.
    private func move(to offset: CGPoint) {
        let animated = Updates.pendingAnimation != nil
        applying = true
        animatingTo = animated ? offset : nil
        scrollView.setContentOffset(offset, animated: animated)
        applying = false
    }

    // What the user did to the scroller itself goes back into the binding, as SwiftUI reports it.
    func userScrolled(to offset: CGPoint) {
        guard !applying, animatingTo == nil, let request else { return }
        var position = request.binding.wrappedValue
        position.placed(at: offset, in: scrollView.contentSize, viewport: scrollView.bounds.size)
        guard position != applied else { return }
        applied = position
        requested = position
        request.binding.wrappedValue = position
    }

    func animationSettled() { animatingTo = nil }

    func phaseChanged(to next: ScrollPhase.Phase) {
        let updated = ScrollPhase(next)
        guard updated != phase else { return }
        let old = phase
        phase = updated
        guard let observers, let action = observers.onPhase else { return }
        var context = ScrollPhaseChangeContext()
        context.velocity = scrollVelocity
        action(old, updated, context)
    }

    func settleOnTarget() {
        guard let target, !restingTargets.isEmpty else { return }
        let view = scrollView
        var context = ScrollTargetBehaviorContext()
        context.originalTarget = nearestTarget(to: view.contentOffset) ?? ScrollTarget()
        context.velocity = scrollVelocity
        context.contentSize = view.contentSize
        context.containerSize = view.bounds.size
        context.axes = axes
        var wanted = context.originalTarget
        target.updateTarget(&wanted, context: context)
        guard let offset = offset(for: wanted), offset != view.contentOffset else { return }
        move(to: offset)
        userScrolled(to: offset)
    }

    private var scrollVelocity: CGVector {
        let pan = scrollView.panGestureRecognizer
        let velocity = pan.velocity(in: scrollView)
        return axes.contains(.horizontal) ? CGVector(dx: velocity.x, dy: 0) : CGVector(dx: 0, dy: velocity.y)
    }

    private func nearestTarget(to offset: CGPoint) -> ScrollTarget? {
        restingTargets.min {
            let a = $0.rect.origin, b = $1.rect.origin
            return (a.x - offset.x) * (a.x - offset.x) + (a.y - offset.y) * (a.y - offset.y)
                < (b.x - offset.x) * (b.x - offset.x) + (b.y - offset.y) * (b.y - offset.y)
        }
    }

    private func offset(for target: ScrollTarget) -> CGPoint? {
        let view = scrollView
        let limit = CGSize(width: max(0, view.contentSize.width - view.bounds.size.width),
                           height: max(0, view.contentSize.height - view.bounds.size.height))
        let anchor = target.anchor ?? .topLeading
        let raw = CGPoint(x: target.rect.origin.x + target.rect.size.width * anchor.x - view.bounds.size.width * anchor.x,
                          y: target.rect.origin.y + target.rect.size.height * anchor.y - view.bounds.size.height * anchor.y)
        return CGPoint(x: min(max(0, raw.x), limit.width), y: min(max(0, raw.y), limit.height))
    }
}

final class ScrollNodeDelegate: NSObject, UIScrollViewDelegate {
    weak var node: ScrollNode?
    func scrollViewDidScroll(_ scrollView: UIScrollView) { node?.userScrolled(to: scrollView.contentOffset) }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { node?.phaseChanged(to: .tracking) }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        node?.phaseChanged(to: .animating)
        node?.settleOnTarget()
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        node?.phaseChanged(to: .animating)
        node?.settleOnTarget()
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        node?.animationSettled()
        node?.settleOnTarget()
    }
}

enum LayoutCounters {
    nonisolated(unsafe) static var hits = 0
    nonisolated(unsafe) static var misses = 0
    nonisolated(unsafe) static var renderTime = 0.0
    nonisolated(unsafe) static var mountTime = 0.0
    nonisolated(unsafe) static var layoutTime = 0.0

}
