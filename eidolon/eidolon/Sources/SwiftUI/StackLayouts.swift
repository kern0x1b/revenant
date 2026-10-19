import UIKit
import CoreGraphics

func stackSizes(_ axis: Axis, _ spacing: CGFloat, _ proposal: ProposedViewSize, _ subviews: LayoutSubviews) -> [CGSize] {
    let cross: Axis = axis == .horizontal ? .vertical : .horizontal
    func proposed(_ along: CGFloat?) -> ProposedViewSize {
        axis == .horizontal ? ProposedViewSize(width: along, height: proposal.height) : ProposedViewSize(width: proposal.width, height: along)
    }
    let total = axis == .horizontal ? proposal.width : proposal.height
    guard let total, total.isFinite else { return subviews.map { $0.sizeThatFits(proposed(nil)) } }
    let mins = subviews.map { $0.sizeThatFits(proposed(0))[axis] }
    let flex = subviews.indices.map { subviews[$0].sizeThatFits(proposed(.infinity))[axis] - mins[$0] }
    var remaining = total - spacing * CGFloat(max(0, subviews.count - 1)) - mins.reduce(0, +)
    var sizes = [CGSize](repeating: .zero, count: subviews.count)
    let order = subviews.indices.sorted { a, b in
        subviews[a].priority != subviews[b].priority ? subviews[a].priority > subviews[b].priority : flex[a] < flex[b]
    }
    var left = subviews.count
    for i in order {
        let size = subviews[i].sizeThatFits(proposed(mins[i] + max(0, remaining / CGFloat(left))))
        sizes[i] = size
        remaining -= max(0, size[axis] - mins[i])
        left -= 1
    }
    _ = cross
    return sizes
}

public struct HStackLayout: Layout {
    public var alignment: VerticalAlignment
    public var spacing: CGFloat?
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let sizes = stackSizes(.horizontal, spacing ?? 8, proposal, subviews)
        return CGSize(width: sizes.reduce(0) { $0 + $1.width } + (spacing ?? 8) * CGFloat(max(0, sizes.count - 1)),
                      height: sizes.map { $0.height }.max() ?? 0)
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let sizes = stackSizes(.horizontal, spacing ?? 8, ProposedViewSize(bounds.size), subviews)
        let lines = sizes.map { alignment.defaultValue(ViewDimensions(width: $0.width, height: $0.height)) }
        let line = alignment.defaultValue(ViewDimensions(width: bounds.size.width, height: bounds.size.height))
        var x = bounds.origin.x
        for (index, size) in sizes.enumerated() {
            subviews[index].place(at: CGPoint(x: x, y: bounds.origin.y + line - lines[index]), proposal: ProposedViewSize(size))
            x += size.width + (spacing ?? 8)
        }
    }
}

public struct VStackLayout: Layout {
    public var alignment: HorizontalAlignment
    public var spacing: CGFloat?
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let sizes = stackSizes(.vertical, spacing ?? 8, proposal, subviews)
        return CGSize(width: sizes.map { $0.width }.max() ?? 0,
                      height: sizes.reduce(0) { $0 + $1.height } + (spacing ?? 8) * CGFloat(max(0, sizes.count - 1)))
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let sizes = stackSizes(.vertical, spacing ?? 8, ProposedViewSize(bounds.size), subviews)
        let lines = sizes.map { alignment.defaultValue(ViewDimensions(width: $0.width, height: $0.height)) }
        let line = alignment.defaultValue(ViewDimensions(width: bounds.size.width, height: bounds.size.height))
        var y = bounds.origin.y
        for (index, size) in sizes.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.origin.x + line - lines[index], y: y), proposal: ProposedViewSize(size))
            y += size.height + (spacing ?? 8)
        }
    }
}

public struct ZStackLayout: Layout {
    public var alignment: Alignment
    public init(alignment: Alignment = .center) { self.alignment = alignment }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(proposal) }
        return CGSize(width: sizes.map { $0.width }.max() ?? 0, height: sizes.map { $0.height }.max() ?? 0)
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let whole = ViewDimensions(width: bounds.size.width, height: bounds.size.height)
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(bounds.size))
            let d = ViewDimensions(width: size.width, height: size.height)
            let x = alignment.horizontal.defaultValue(whole) - alignment.horizontal.defaultValue(d)
            let y = alignment.vertical.defaultValue(whole) - alignment.vertical.defaultValue(d)
            subview.place(at: CGPoint(x: bounds.origin.x + x, y: bounds.origin.y + y), proposal: ProposedViewSize(size))
        }
    }
}

public protocol PreviewProvider {
    associatedtype Previews: View
    @ViewBuilder static var previews: Previews { get }
    static var platform: PreviewPlatform? { get }
}

extension PreviewProvider {
    public static var platform: PreviewPlatform? { nil }
}

public enum PreviewPlatform: Hashable { case iOS, macOS, tvOS, watchOS }

public protocol PreviewContextKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public protocol PreviewContext {
    subscript<Key: PreviewContextKey>(key: Key.Type) -> Key.Value { get }
}
