import UIKit
import CoreGraphics

public struct GridItem: Equatable {
    public enum Size: Equatable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity)
        case adaptive(minimum: CGFloat, maximum: CGFloat = .infinity)
    }
    public var size: Size
    public var spacing: CGFloat?
    public var alignment: Alignment?
    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {
        self.size = size; self.spacing = spacing; self.alignment = alignment
    }
}

public struct LazyVGrid<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let columns: [GridItem]
    let alignment: HorizontalAlignment
    let spacing: CGFloat?
    let content: Content
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil,
                pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.columns = columns; self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = GridNode(vertical: true); n.update(self, env); return n }
}

public struct LazyHGrid<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let rows: [GridItem]
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content
    public init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil,
                pinnedViews: PinnedScrollableViews = [], @ViewBuilder content: () -> Content) {
        self.rows = rows; self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = GridNode(vertical: false); n.update(self, env); return n }
}

protocol GridLike {
    var gridItems: [GridItem] { get }
    var gridSpacing: CGFloat? { get }
    var gridContent: any View { get }
}

extension LazyVGrid: GridLike {
    var gridItems: [GridItem] { columns }
    var gridSpacing: CGFloat? { spacing }
    var gridContent: any View { content }
}

extension LazyHGrid: GridLike {
    var gridItems: [GridItem] { rows }
    var gridSpacing: CGFloat? { spacing }
    var gridContent: any View { content }
}

final class GridNode: ContainerNode {
    let vertical: Bool
    var items: [GridItem] = []
    var spacing: CGFloat = 8

    init(vertical: Bool) {
        self.vertical = vertical
        super.init()
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let grid = view as? GridLike else { return }
        items = grid.gridItems
        spacing = grid.gridSpacing ?? 8
        content = adopt(reconcile(content, grid.gridContent, env))
    }

    // An adaptive item becomes as many tracks as fit in the room it is given; the other items are one track each.
    func tracks(_ available: CGFloat) -> [CGFloat] {
        guard !items.isEmpty else { return [] }
        var fixedTotal: CGFloat = 0
        var flexibleCount = 0
        for item in items {
            switch item.size {
            case .fixed(let value): fixedTotal += value
            case .flexible, .adaptive: flexibleCount += 1
            }
        }
        let room = max(0, available - spacing * CGFloat(items.count - 1) - fixedTotal)
        let share = flexibleCount == 0 ? 0 : room / CGFloat(flexibleCount)
        var sizes: [CGFloat] = []
        for item in items {
            switch item.size {
            case .fixed(let value):
                sizes.append(value)
            case .flexible(let minimum, let maximum):
                sizes.append(min(max(share, minimum), maximum.isFinite ? maximum : share))
            case .adaptive(let minimum, let maximum):
                let count = max(1, Int(((share + spacing) / (minimum + spacing)).rounded(.down)))
                let each = (share - spacing * CGFloat(count - 1)) / CGFloat(count)
                sizes += [CGFloat](repeating: min(max(each, minimum), maximum.isFinite ? maximum : each), count: count)
            }
        }
        return sizes
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let available = (vertical ? p.width : p.height) ?? 320
        let sizes = tracks(available)
        guard !sizes.isEmpty else { return .zero }
        let kids = children
        var main: CGFloat = 0
        var index = 0
        while index < kids.count {
            var lineExtent: CGFloat = 0
            for track in sizes.indices where index + track < kids.count {
                let kid = kids[index + track]
                let proposal = vertical ? ProposedSize(width: sizes[track], height: nil) : ProposedSize(width: nil, height: sizes[track])
                let size = kid.sizeThatFits(proposal)
                lineExtent = max(lineExtent, vertical ? size.height : size.width)
            }
            main += lineExtent + spacing
            index += sizes.count
        }
        main = max(0, main - spacing)
        let cross = sizes.reduce(0, +) + spacing * CGFloat(sizes.count - 1)
        return vertical ? CGSize(width: p.width ?? cross, height: main) : CGSize(width: main, height: p.height ?? cross)
    }

    override func layoutContents(_ size: CGSize) {
        let available = vertical ? size.width : size.height
        let sizes = tracks(available)
        guard !sizes.isEmpty else { return }
        let kids = children
        var offsets: [CGFloat] = []
        var running: CGFloat = 0
        for value in sizes {
            offsets.append(running)
            running += value + spacing
        }
        var index = 0
        var mainOffset: CGFloat = 0
        while index < kids.count {
            var lineExtent: CGFloat = 0
            for track in sizes.indices where index + track < kids.count {
                let kid = kids[index + track]
                let proposal = vertical ? ProposedSize(width: sizes[track], height: nil) : ProposedSize(width: nil, height: sizes[track])
                let wanted = kid.sizeThatFits(proposal)
                let frame = vertical
                    ? CGRect(x: offsets[track], y: mainOffset, width: sizes[track], height: wanted.height)
                    : CGRect(x: mainOffset, y: offsets[track], width: wanted.width, height: sizes[track])
                kid.place(frame)
                lineExtent = max(lineExtent, vertical ? wanted.height : wanted.width)
            }
            mainOffset += lineExtent + spacing
            index += sizes.count
        }
    }
}

public struct Grid<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let alignment: Alignment
    let horizontalSpacing: CGFloat?
    let verticalSpacing: CGFloat?
    let content: Content
    public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.horizontalSpacing = horizontalSpacing; self.verticalSpacing = verticalSpacing; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TableGridNode(); n.update(self, env); return n }
}

protocol TableGridLike {
    var gridAlignment: Alignment { get }
    var gridSpacing: (CGFloat, CGFloat) { get }
    var gridContent: any View { get }
}

extension Grid: TableGridLike {
    var gridAlignment: Alignment { alignment }
    var gridSpacing: (CGFloat, CGFloat) { (horizontalSpacing ?? 8, verticalSpacing ?? 8) }
    var gridContent: any View { content }
}

public struct GridRow<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let alignment: VerticalAlignment?
    let content: Content
    public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.content = content()
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = GridRowNode(); n.update(self, env); return n }
}

protocol GridRowLike {
    var rowAlignment: VerticalAlignment? { get }
    var rowContent: any View { get }
}

extension GridRow: GridRowLike {
    var rowAlignment: VerticalAlignment? { alignment }
    var rowContent: any View { content }
}

final class GridRowNode: Node {
    var child: Node?
    var alignment: VerticalAlignment?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let row = view as! GridRowLike
        alignment = row.rowAlignment
        child = adopt(reconcile(child, row.rowContent, env))
    }
    override func mountContents() { child?.mount() }
}

struct GridCellSettings {
    var columns = 1
    var anchor: UnitPoint?
    var unsized: Axis.Set = []
    var columnAlignment: HorizontalAlignment?
}

struct GridCellModifier: NodeModifier {
    let apply: (inout GridCellSettings) -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { GridCellNode() }
}

final class GridCellNode: Node {
    var child: Node?
    var apply: (inout GridCellSettings) -> Void = { _ in }
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        apply = (m.modifierValue as! GridCellModifier).apply
        child = adopt(reconcile(child, m.modifiedContent, env))
    }
    override func mountContents() { child?.mount() }
}

struct GridCell {
    let node: LayoutNode
    let settings: GridCellSettings
    var column = 0
}

struct GridLine {
    var cells: [GridCell]
    let fullWidth: Bool
    let alignment: VerticalAlignment?
}

final class TableGridNode: ContainerNode {
    var alignment = Alignment.center
    var spacing: (CGFloat, CGFloat) = (8, 8)

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let grid = view as! TableGridLike
        alignment = grid.gridAlignment
        spacing = grid.gridSpacing
        content = adopt(reconcile(content, grid.gridContent, env))
    }

    func lines() -> [GridLine] {
        var result: [GridLine] = []
        var lastRow: GridRowNode?
        for item in children {
            var settings = GridCellSettings()
            var chain: [GridCellNode] = []
            var row: GridRowNode?
            var current: Node? = item
            while let node = current, node !== self {
                if let cell = node as? GridCellNode, row == nil { chain.append(cell) }
                if let found = node as? GridRowNode { row = found; break }
                current = node.parent
            }
            for cell in chain.reversed() { cell.apply(&settings) }
            if let row {
                if lastRow === row, !result.isEmpty {
                    result[result.count - 1].cells.append(GridCell(node: item, settings: settings))
                } else {
                    result.append(GridLine(cells: [GridCell(node: item, settings: settings)], fullWidth: false, alignment: row.alignment))
                }
                lastRow = row
            } else {
                result.append(GridLine(cells: [GridCell(node: item, settings: settings)], fullWidth: true, alignment: nil))
                lastRow = nil
            }
        }
        for index in result.indices where !result[index].fullWidth {
            var column = 0
            for cellIndex in result[index].cells.indices {
                result[index].cells[cellIndex].column = column
                column += max(1, result[index].cells[cellIndex].settings.columns)
            }
        }
        return result
    }

    func columnWidths(_ lines: [GridLine], _ available: CGFloat?) -> [CGFloat] {
        let count = lines.filter { !$0.fullWidth }.map { $0.cells.reduce(0) { $0 + max(1, $1.settings.columns) } }.max() ?? 0
        var widths = [CGFloat](repeating: 0, count: count)
        var flexible = [Bool](repeating: false, count: count)
        let unspecified = ProposedSize.unspecified
        for line in lines where !line.fullWidth {
            for cell in line.cells where cell.settings.columns <= 1 && !cell.settings.unsized.contains(.horizontal) {
                widths[cell.column] = max(widths[cell.column], cell.node.sizeThatFits(unspecified).width)
                if cell.node.sizeThatFits(ProposedSize(width: infinity, height: nil)).width > cell.node.sizeThatFits(unspecified).width + 0.5 {
                    flexible[cell.column] = true
                }
            }
        }
        for line in lines where !line.fullWidth {
            for cell in line.cells where cell.settings.columns > 1 && !cell.settings.unsized.contains(.horizontal) {
                let range = cell.column..<min(count, cell.column + cell.settings.columns)
                let have = range.reduce(0) { $0 + widths[$1] } + spacing.0 * CGFloat(range.count - 1)
                let need = cell.node.sizeThatFits(unspecified).width
                if need > have { for c in range { widths[c] += (need - have) / CGFloat(range.count) } }
            }
        }
        if let available, count > 0 {
            let total = widths.reduce(0, +) + spacing.0 * CGFloat(count - 1)
            let stretch = flexible.enumerated().filter { $0.element }.map { $0.offset }
            if total < available, !stretch.isEmpty {
                for c in stretch { widths[c] += (available - total) / CGFloat(stretch.count) }
            }
        }
        return widths
    }

    func measure(_ proposal: ProposedSize) -> (lines: [GridLine], widths: [CGFloat], heights: [CGFloat], width: CGFloat) {
        let all = lines()
        let widths = columnWidths(all, proposal.width)
        let columnsWidth = widths.reduce(0, +) + spacing.0 * CGFloat(max(0, widths.count - 1))
        var heights: [CGFloat] = []
        for line in all {
            if line.fullWidth {
                heights.append(line.cells[0].node.sizeThatFits(ProposedSize(width: columnsWidth > 0 ? columnsWidth : proposal.width, height: nil)).height)
            } else {
                heights.append(line.cells.filter { !$0.settings.unsized.contains(.vertical) }.map { cell -> CGFloat in
                    let span = cell.column..<min(widths.count, cell.column + max(1, cell.settings.columns))
                    let width = span.reduce(0) { $0 + widths[$1] } + spacing.0 * CGFloat(max(0, span.count - 1))
                    return cell.node.sizeThatFits(ProposedSize(width: width, height: nil)).height
                }.max() ?? 0)
            }
        }
        let fullWidest = all.filter { $0.fullWidth }.map { $0.cells[0].node.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = max(columnsWidth, widths.isEmpty ? fullWidest : 0)
        return (all, widths, heights, width)
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let m = measure(p)
        return CGSize(width: m.width, height: m.heights.reduce(0, +) + spacing.1 * CGFloat(max(0, m.heights.count - 1)))
    }

    override func layoutContents(_ size: CGSize) {
        let m = measure(ProposedSize(width: size.width, height: size.height))
        var starts: [CGFloat] = []
        var x: CGFloat = 0
        for width in m.widths { starts.append(x); x += width + spacing.0 }
        var y: CGFloat = 0
        for (index, line) in m.lines.enumerated() {
            let height = m.heights[index]
            for cell in line.cells {
                let area: CGRect
                if line.fullWidth {
                    area = CGRect(x: 0, y: y, width: size.width, height: height)
                } else {
                    let span = cell.column..<min(m.widths.count, cell.column + max(1, cell.settings.columns))
                    guard let first = span.first else { continue }
                    let width = span.reduce(0) { $0 + m.widths[$1] } + spacing.0 * CGFloat(max(0, span.count - 1))
                    area = CGRect(x: starts[first], y: y, width: width, height: height)
                }
                var wanted = cell.node.sizeThatFits(ProposedSize(width: area.size.width, height: area.size.height))
                if cell.settings.unsized.contains(.horizontal) { wanted.width = area.size.width }
                if cell.settings.unsized.contains(.vertical) { wanted.height = area.size.height }
                wanted.width = min(wanted.width, area.size.width)
                wanted.height = min(wanted.height, area.size.height)
                let fx: CGFloat, fy: CGFloat
                if let anchor = cell.settings.anchor {
                    fx = anchor.x; fy = anchor.y
                } else {
                    let horizontal = cell.settings.columnAlignment ?? columnAlignment(m.lines, cell.column) ?? alignment.horizontal
                    let vertical = line.alignment ?? alignment.vertical
                    fx = horizontal.raw < 0 ? 0 : horizontal.raw > 0 ? 1 : 0.5
                    fy = vertical.raw < 0 ? 0 : vertical.raw > 0 ? 1 : 0.5
                }
                cell.node.place(CGRect(x: area.origin.x + (area.size.width - wanted.width) * fx,
                                       y: area.origin.y + (area.size.height - wanted.height) * fy,
                                       width: wanted.width, height: wanted.height))
            }
            y += height + spacing.1
        }
    }

    func columnAlignment(_ lines: [GridLine], _ column: Int) -> HorizontalAlignment? {
        for line in lines where !line.fullWidth {
            for cell in line.cells where cell.column == column {
                if let alignment = cell.settings.columnAlignment { return alignment }
            }
        }
        return nil
    }
}

final class ScrollProxyBox {
    weak var reader: Node?
}

public struct ScrollViewProxy {
    let box: ScrollProxyBox
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {
        guard let reader = box.reader, let target = findIdentified(AnyHashable(id), in: reader) else { return }
        scroll(to: target, anchor: anchor, animated: Updates.pendingAnimation != nil)
    }
}

func findIdentified(_ id: AnyHashable, in node: Node) -> LayoutNode? {
    if let identity = node as? IdentityNode, identity.id == id { return identity.flattened.first }
    if let each = node as? ForEachNode, let match = each.children.first(where: { $0.0 == id }) { return match.1.flattened.first }
    for child in node.childNodes {
        if let found = findIdentified(id, in: child) { return found }
    }
    return nil
}

func scroll(to target: LayoutNode, anchor: UnitPoint?, animated: Bool) {
    var current = target.parent
    while let node = current {
        if let list = node as? ListNode, let index = list.rows.firstIndex(where: { $0.content === target || (target.isDescendant(of: $0)) }) {
            var section = 0, row = index
            for (i, group) in list.sections.enumerated() {
                if row < group.rows.count { section = i; break }
                row -= group.rows.count
            }
            let position: UITableView.ScrollPosition
            switch anchor {
            case .some(let a) where a.y <= 0.25: position = .top
            case .some(let a) where a.y >= 0.75: position = .bottom
            case .some: position = .middle
            case .none: position = .none
            }
            (list.uiView as! UITableView).scrollToRow(at: IndexPath(row: row, section: section), at: position, animated: animated)
            return
        }
        if let scroller = node as? ScrollNode {
            let view = scroller.scrollView
            let rect = target.uiView.convert(target.uiView.bounds, to: view)
            guard let anchor else {
                view.scrollRectToVisible(rect, animated: animated)
                return
            }
            let visible = view.bounds.size
            var offset = CGPoint(x: rect.origin.x + rect.size.width * anchor.x - visible.width * anchor.x,
                                 y: rect.origin.y + rect.size.height * anchor.y - visible.height * anchor.y)
            offset.x = max(0, min(offset.x, view.contentSize.width - visible.width))
            offset.y = max(0, min(offset.y, view.contentSize.height - visible.height))
            view.setContentOffset(offset, animated: animated)
            return
        }
        current = node.parent
    }
}

public struct ScrollViewReader<Content: View>: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    public var content: (ScrollViewProxy) -> Content
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) { self.content = content }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ScrollReaderNode(); n.update(self, env); return n }
}

protocol ScrollReaderLike {
    func readerContent(_ proxy: ScrollViewProxy) -> any View
}

extension ScrollViewReader: ScrollReaderLike {
    func readerContent(_ proxy: ScrollViewProxy) -> any View { content(proxy) }
}

final class ScrollReaderNode: Node {
    let box = ScrollProxyBox()
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let reader = view as? ScrollReaderLike else { return }
        box.reader = self
        child = adopt(reconcile(child, reader.readerContent(ScrollViewProxy(box: box)), env))
    }
    override func mountContents() { child?.mount() }
}

extension View {
    public func gridCellColumns(_ count: Int) -> some View {
        _ModifiedView(content: self, modifier: GridCellModifier(apply: { $0.columns = count }))
    }
    public func gridCellAnchor(_ anchor: UnitPoint) -> some View {
        _ModifiedView(content: self, modifier: GridCellModifier(apply: { $0.anchor = anchor }))
    }
    public func gridCellUnsizedAxes(_ axes: Axis.Set) -> some View {
        _ModifiedView(content: self, modifier: GridCellModifier(apply: { $0.unsized = axes }))
    }
    public func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View {
        _ModifiedView(content: self, modifier: GridCellModifier(apply: { $0.columnAlignment = guide }))
    }
}
