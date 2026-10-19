import UIKit
import CoreGraphics

import UIKit
import CoreGraphics

/// Where a scroller may come to rest: the rectangle in its content's coordinates, and the point of
/// that rectangle the container aligns with.
public struct ScrollTarget: Hashable {
    public var rect: CGRect
    public var anchor: UnitPoint?
    public init() { rect = .zero; anchor = nil }
    public init(rect: CGRect, anchor: UnitPoint? = nil) { self.rect = rect; self.anchor = anchor }
    public static func == (a: ScrollTarget, b: ScrollTarget) -> Bool { a.rect == b.rect && a.anchor == b.anchor }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rect.origin.x); hasher.combine(rect.origin.y)
        hasher.combine(rect.size.width); hasher.combine(rect.size.height)
        hasher.combine(anchor)
    }
    public var hashValue: Int { var h = Hasher(); hash(into: &h); return h.finalize() }
}

/// What the behaviour is told when it is asked where to rest: the target it started from, how fast
/// the content is moving, how big everything is, and the environment of the scroller.
@dynamicMemberLookup
public struct ScrollTargetBehaviorContext {
    public var originalTarget: ScrollTarget = ScrollTarget()
    public var velocity: CGVector = .zero
    public var contentSize: CGSize = .zero
    public var containerSize: CGSize = .zero
    public var axes: Axis.Set = .vertical
    var environment = EnvironmentValues()
    public init() {}
    public subscript<T>(dynamicMember keyPath: KeyPath<EnvironmentValues, T>) -> T { environment[keyPath: keyPath] }
}

/// The properties a behaviour animates between two resting points, and the context it reads them from.
public struct ScrollTargetBehaviorProperties: Equatable {
    public var limitsScrolls: Bool
    public init() { limitsScrolls = true }
    public static func == (a: ScrollTargetBehaviorProperties, b: ScrollTargetBehaviorProperties) -> Bool {
        a.limitsScrolls == b.limitsScrolls
    }
}

public struct ScrollTargetBehaviorPropertiesContext {
    public var environment: EnvironmentValues = EnvironmentValues()
    public var axes: Axis.Set = .vertical
    public init() {}
}

public protocol ScrollTargetBehavior {
    typealias TargetContext = ScrollTargetBehaviorContext
    typealias Properties = ScrollTargetBehaviorProperties
    typealias PropertiesContext = ScrollTargetBehaviorPropertiesContext
    /// Moves `target` to where the scroller should rest. The scroller scrolls so that the target's
    /// rectangle sits at its anchor.
    func updateTarget(_ target: inout ScrollTarget, context: Self.TargetContext)
}

extension ScrollTargetBehavior {
    public func properties(context: PropertiesContext) -> Properties { Properties() }
}

public struct PagingScrollTargetBehavior: ScrollTargetBehavior {
    public init() {}
    public func updateTarget(_ target: inout ScrollTarget, context: ScrollTargetBehaviorContext) {
        let step = context.containerSize
        target.rect = CGRect(x: (target.rect.origin.x / max(step.width, 1)).rounded() * step.width,
                             y: (target.rect.origin.y / max(step.height, 1)).rounded() * step.height,
                             width: step.width, height: step.height)
        target.anchor = .topLeading
    }
    public func properties(context: ScrollTargetBehaviorPropertiesContext) -> ScrollTargetBehaviorProperties {
        var properties = ScrollTargetBehaviorProperties()
        properties.limitsScrolls = false
        return properties
    }
}

public struct ViewAlignedScrollTargetBehavior: ScrollTargetBehavior {
    public struct LimitBehavior {
        let stopsAtBoundaries: Bool
        let limit: Int?
        init(stopsAtBoundaries: Bool, limit: Int?) { self.stopsAtBoundaries = stopsAtBoundaries; self.limit = limit }
        public static var automatic: LimitBehavior { LimitBehavior(stopsAtBoundaries: true, limit: nil) }
        public static var always: LimitBehavior { LimitBehavior(stopsAtBoundaries: true, limit: nil) }
        public static var alwaysByOne: LimitBehavior { LimitBehavior(stopsAtBoundaries: true, limit: 1) }
        public static var alwaysByFew: LimitBehavior { LimitBehavior(stopsAtBoundaries: true, limit: 2) }
        public static var never: LimitBehavior { LimitBehavior(stopsAtBoundaries: false, limit: nil) }
    }
    let limitBehavior: LimitBehavior
    public let anchor: UnitPoint?
    public init(limitBehavior: LimitBehavior = .automatic) {
        self.limitBehavior = limitBehavior; anchor = nil
    }
    public init(limitBehavior: LimitBehavior, anchor: UnitPoint?) {
        self.limitBehavior = limitBehavior; self.anchor = anchor
    }
    public init(anchor: UnitPoint?) {
        limitBehavior = .automatic; self.anchor = anchor
    }
    public func updateTarget(_ target: inout ScrollTarget, context: ScrollTargetBehaviorContext) {
        target.anchor = anchor ?? target.anchor
    }
    public func properties(context: ScrollTargetBehaviorPropertiesContext) -> ScrollTargetBehaviorProperties {
        var properties = ScrollTargetBehaviorProperties()
        properties.limitsScrolls = limitBehavior.stopsAtBoundaries
        return properties
    }
}

extension ScrollTargetBehavior where Self == PagingScrollTargetBehavior {
    public static var paging: Self { PagingScrollTargetBehavior() }
}

extension ScrollTargetBehavior where Self == ViewAlignedScrollTargetBehavior {
    public static func viewAligned(limitBehavior: ViewAlignedScrollTargetBehavior.LimitBehavior) -> Self {
        ViewAlignedScrollTargetBehavior(limitBehavior: limitBehavior)
    }
    public static func viewAligned(limitBehavior: ViewAlignedScrollTargetBehavior.LimitBehavior, anchor: UnitPoint?) -> Self {
        ViewAlignedScrollTargetBehavior(limitBehavior: limitBehavior, anchor: anchor)
    }
    public static func viewAligned(anchor: UnitPoint?) -> Self {
        ViewAlignedScrollTargetBehavior(anchor: anchor)
    }
}

public struct AnyScrollTargetBehavior: ScrollTargetBehavior {
    public var base: any ScrollTargetBehavior
    public init(_ base: some ScrollTargetBehavior) { self.base = base }
    public func updateTarget(_ target: inout ScrollTarget, context: ScrollTargetBehaviorContext) {
        base.updateTarget(&target, context: context)
    }
    public func properties(context: ScrollTargetBehaviorPropertiesContext) -> ScrollTargetBehaviorProperties {
        base.properties(context: context)
    }
}

/// What a scroll anchor is for: where the content starts, where it stays when its size changes, and
/// what a view is aligned against.
public struct ScrollAnchorRole: Hashable {
    let name: String
    public static var initialOffset: ScrollAnchorRole { ScrollAnchorRole(name: "initialOffset") }
    public static var sizeChanges: ScrollAnchorRole { ScrollAnchorRole(name: "sizeChanges") }
    public static var alignment: ScrollAnchorRole { ScrollAnchorRole(name: "alignment") }
}

public struct ScrollPhase: Equatable, Hashable {
    public enum Phase { case idle, tracking, interacting, decelerating, animating }
    public let phase: Phase
    public init(_ phase: Phase) { self.phase = phase }
    public var isScrolling: Bool { phase != .idle }
    public static func == (a: ScrollPhase, b: ScrollPhase) -> Bool { a.phase == b.phase }
    public func hash(into hasher: inout Hasher) { hasher.combine(phase) }
    public var hashValue: Int { var h = Hasher(); hash(into: &h); return h.finalize() }
    public var debugDescription: String { "ScrollPhase(\(phase))" }
}

public struct ScrollPhaseChangeContext {
    public var velocity: CGVector
    public init() { velocity = .zero }
}

public struct ScrollGeometry: Equatable {
    public var contentOffset: CGPoint = .zero
    public var contentSize: CGSize = .zero
    public var contentInsets: EdgeInsets = EdgeInsets()
    public var containerSize: CGSize = .zero
    public var visibleRect: CGRect = .zero
    public var bounds: CGRect = .zero
    public init() {}
    public static func == (a: ScrollGeometry, b: ScrollGeometry) -> Bool {
        a.contentOffset == b.contentOffset && a.contentSize == b.contentSize
            && a.contentInsets == b.contentInsets && a.containerSize == b.containerSize
            && a.visibleRect == b.visibleRect && a.bounds == b.bounds
    }
    public var debugDescription: String {
        "offset \(contentOffset.x),\(contentOffset.y) content \(contentSize.width)x\(contentSize.height)"
    }
}

public struct ScrollPosition: Equatable {
    public var id: AnyHashable?
    public var anchor: UnitPoint?
    public var edge: Edge?
    public var point: UnitPoint?
    public var x: CGFloat?
    public var y: CGFloat?
    public private(set) var isPositionedByUser = false
    let idType: AnyHashable.Type?

    public init() { idType = nil }
    public init(id: AnyHashable, anchor: UnitPoint? = nil) {
        self.id = id; self.anchor = anchor; idType = AnyHashable.self
    }
    public init(idType: AnyHashable.Type) { self.idType = idType }
    public init(idType: AnyHashable.Type, edge: Edge) { self.idType = idType; self.edge = edge }
    public init(idType: AnyHashable.Type, point: UnitPoint) { self.idType = idType; self.point = point }
    public init(idType: AnyHashable.Type, x: CGFloat) { self.idType = idType; self.x = x }
    public init(idType: AnyHashable.Type, y: CGFloat) { self.idType = idType; self.y = y }
    public init(idType: AnyHashable.Type, x: CGFloat, y: CGFloat) { self.idType = idType; self.x = x; self.y = y }

    public subscript<T: Hashable>(idType: T.Type) -> T? {
        get { id as? T }
        set { id = newValue }
    }
    public var viewID: AnyHashable? { id }
    public func viewID<T: Hashable>(type: T.Type) -> T? { id as? T }

    public mutating func scrollTo(edge: Edge) { clear(); self.edge = edge }
    public mutating func scrollTo(id: AnyHashable, anchor: UnitPoint? = nil) {
        clear(); self.id = id; self.anchor = anchor
    }
    public mutating func scrollTo(point: UnitPoint) { clear(); self.point = point }
    public mutating func scrollTo(x: CGFloat) { clear(); self.x = x }
    public mutating func scrollTo(y: CGFloat) { clear(); self.y = y }
    public mutating func scrollTo(x: CGFloat, y: CGFloat) { clear(); self.x = x; self.y = y }

    mutating func clear() {
        id = nil; anchor = nil; edge = nil; point = nil; x = nil; y = nil; isPositionedByUser = false
    }
    mutating func placed(at offset: CGPoint, in content: CGSize, viewport: CGSize) {
        id = nil; anchor = nil; edge = nil
        x = content.width > viewport.width ? offset.x : nil
        y = content.height > viewport.height ? offset.y : nil
        if x == nil && y == nil { point = UnitPoint(x: 0, y: 0) }
        isPositionedByUser = true
    }

    public static func == (lhs: ScrollPosition, rhs: ScrollPosition) -> Bool {
        lhs.id == rhs.id && lhs.anchor == rhs.anchor && lhs.edge == rhs.edge
            && lhs.point == rhs.point && lhs.x == rhs.x && lhs.y == rhs.y
    }
}

struct ScrollPositionRequest {
    var binding: Binding<ScrollPosition>
    var anchor: UnitPoint?
}

struct ScrollAnchors: Equatable {
    var initialOffset = UnitPoint.top
    var sizeChanges = UnitPoint.top
    var alignment = UnitPoint.leading
}

struct ScrollObservers {
    var onGeometry: ((ScrollGeometry, ScrollGeometry) -> Void)?
    var onPhase: ((ScrollPhase, ScrollPhase, ScrollPhaseChangeContext) -> Void)?
    var lastGeometry: ScrollGeometry?
    var lastPhase: ScrollPhase = ScrollPhase(.idle)
}

extension View {
    public func scrollPosition(_ position: Binding<ScrollPosition>, anchor: UnitPoint? = nil) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            environment.scrollPosition = ScrollPositionRequest(binding: position, anchor: anchor)
        }, onUpdate: nil))
    }
    public func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            let wanted = id
            environment.scrollPosition = ScrollPositionRequest(
                binding: Binding(get: {
                    var position = ScrollPosition()
                    position.id = wanted.wrappedValue.map { AnyHashable($0) }
                    return position
                }, set: { position in
                    if let new = position.id { wanted.wrappedValue = new.base as? ID }
                }), anchor: anchor)
        }, onUpdate: nil))
    }
    public func defaultScrollAnchor(_ anchor: UnitPoint?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            var current = environment.scrollAnchors ?? ScrollAnchors()
            current.initialOffset = anchor ?? current.initialOffset
            environment.scrollAnchors = current
        }, onUpdate: nil))
    }
    public func defaultScrollAnchor(_ anchor: UnitPoint?, for role: ScrollAnchorRole) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            var current = environment.scrollAnchors ?? ScrollAnchors()
            switch role {
            case .initialOffset: current.initialOffset = anchor ?? current.initialOffset
            case .sizeChanges: current.sizeChanges = anchor ?? current.sizeChanges
            default: current.alignment = anchor ?? current.alignment
            }
            environment.scrollAnchors = current
        }, onUpdate: nil))
    }
    public func scrollClipDisabled(_ disabled: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.scrollClipDisabled = disabled }, onUpdate: nil))
    }
    public func scrollTargetLayout(isEnabled: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: ScrollTargetLayoutModifier(isEnabled: isEnabled))
    }
    public func scrollTargetBehavior(_ behavior: some ScrollTargetBehavior) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.scrollTarget = AnyScrollTargetBehavior(behavior) }, onUpdate: nil))
    }
    public func onScrollGeometryChange<T: Equatable>(for type: T.Type, of transform: @escaping (ScrollGeometry) -> T,
                                                     action: @escaping (T, T) -> Void) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            var observers = environment.scrollObservers ?? ScrollObservers()
            observers.onGeometry = { old, new in
                let before = transform(old), after = transform(new)
                if before != after { action(before, after) }
            }
            environment.scrollObservers = observers
        }, onUpdate: nil))
    }
    public func onScrollPhaseChange(_ action: @escaping (ScrollPhase, ScrollPhase) -> Void) -> some View {
        onScrollPhaseChange { old, new, _ in action(old, new) }
    }
    public func onScrollPhaseChange(_ action: @escaping (ScrollPhase, ScrollPhase, ScrollPhaseChangeContext) -> Void) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            var observers = environment.scrollObservers ?? ScrollObservers()
            observers.onPhase = action
            environment.scrollObservers = observers
        }, onUpdate: nil))
    }
}

struct ScrollTargetLayoutModifier: NodeModifier {
    let isEnabled: Bool
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ScrollTargetLayoutNode() }
}

final class ScrollTargetLayoutNode: Node {
    var child: Node?
    var isTargetLayout = false
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        isTargetLayout = (m.modifierValue as! ScrollTargetLayoutModifier).isEnabled
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

extension ScrollDismissesKeyboardMode: Equatable {}

extension GeometryProxy {
    public func bounds(of anchor: Anchor<CGRect>) -> CGRect? {
        guard let source = anchor.view, let target = node?.uiView else { return nil }
        return anchor.convert(anchor.measure(source.bounds), source, target)
    }
    // Nothing the system draws on iOS 6 has rounded corners, so no container has corner insets to report.
    public var containerCornerInsets: EdgeInsets { EdgeInsets() }
}
