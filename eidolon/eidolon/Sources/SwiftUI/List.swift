import UIKit
import CoreGraphics

func firstEditable(_ node: Node?) -> EditableContent? {
    guard let node else { return nil }
    if let forEach = node as? ForEachNode, let editable = forEach.source as? EditableContent { return editable }
    if let group = node as? GroupNode {
        for child in group.children { if let found = firstEditable(child) { return found } }
    }
    if let composite = node as? CompositeNode { return firstEditable(composite.child) }
    if let section = node as? SectionNode { return firstEditable(section.content) }
    return nil
}

func topLevel(_ node: Node?) -> [Node] {
    guard let node else { return [] }
    if let group = node as? GroupNode { return group.children.flatMap { topLevel($0) } }
    if let composite = node as? CompositeNode { return topLevel(composite.child) }
    if node is SectionNode { return [node] }
    return [node]
}

public protocol ListStyle {}
public struct PlainListStyle: ListStyle { public init() {} }
public struct GroupedListStyle: ListStyle { public init() {} }

final class SelectionBox {
    let current: () -> Set<AnyHashable>
    let choose: (AnyHashable) -> Void
    let clear: () -> Void
    init(current: @escaping () -> Set<AnyHashable>, choose: @escaping (AnyHashable) -> Void, clear: @escaping () -> Void) {
        self.current = current; self.choose = choose; self.clear = clear
    }
}

public struct List<SelectionValue, Content>: View, PrimitiveView where SelectionValue: Hashable, Content: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let content: Content
    var selection: SelectionBox? = nil
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ListNode(grouped: env.listStyleGrouped); n.update(self, env); return n }
}

extension List where SelectionValue == Never {
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public init<Data: RandomAccessCollection, ID: Hashable, Row: View>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Data.Element) -> Row) where Content == ForEach<Data, ID, Row> {
        self.init { ForEach(data, id: id, content: rowContent) }
    }

    public init<Data: RandomAccessCollection, Row: View>(_ data: Data, @ViewBuilder rowContent: @escaping (Data.Element) -> Row) where Content == ForEach<Data, Data.Element.ID, Row>, Data.Element: Identifiable {
        self.init { ForEach(data, content: rowContent) }
    }

    public init<Row: View>(_ data: Range<Int>, @ViewBuilder rowContent: @escaping (Int) -> Row) where Content == ForEach<Range<Int>, Int, Row> {
        self.init { ForEach(data, content: rowContent) }
    }
}

extension List {
    public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) {
        self.content = content()
        if let selection {
            self.selection = SelectionBox(current: { selection.wrappedValue.map { [AnyHashable($0)] } ?? [] },
                                          choose: { if let value = $0.base as? SelectionValue { selection.wrappedValue = value } },
                                          clear: { selection.wrappedValue = nil })
        }
    }
    public init(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> Content) {
        self.content = content()
        if let selection {
            self.selection = SelectionBox(current: { Set(selection.wrappedValue.map { AnyHashable($0) }) },
                                          choose: { value in
                                              guard let typed = value.base as? SelectionValue else { return }
                                              if selection.wrappedValue.contains(typed) { selection.wrappedValue.remove(typed) } else { selection.wrappedValue.insert(typed) }
                                          },
                                          clear: { selection.wrappedValue = [] })
        }
    }
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init(selection: selection) { ForEach(data, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, ID, RowContent> {
        self.init(selection: selection) { ForEach(data, id: id, content: rowContent) }
    }
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {
        self.init(selection: selection) { ForEach(data, content: rowContent) }
    }
}

protocol ListLike { var listContent: any View { get }; var listSelection: SelectionBox? { get } }
extension ListLike { var listSelection: SelectionBox? { nil } }
extension List: ListLike { var listContent: any View { content }; var listSelection: SelectionBox? { selection } }

public struct Section<Parent, Content, Footer> {
    let header: Parent
    let content: Content
    let footer: Footer
}

extension Section: View, PrimitiveView, SectionLike where Parent: View, Content: View, Footer: View {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    var sectionHeader: any View { header }
    var sectionContent: any View { content }
    var sectionFooter: any View { footer }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = SectionNode(); n.update(self, env); return n }
}

extension Section where Parent == EmptyView, Footer == EmptyView, Content: View {
    public init(@ViewBuilder content: () -> Content) {
        self.init(header: EmptyView(), content: content(), footer: EmptyView())
    }
}

extension Section where Parent: View, Footer: View, Content: View {
    public init(header: Parent, footer: Footer, @ViewBuilder content: () -> Content) {
        self.init(header: header, content: content(), footer: footer)
    }
}

extension Section where Parent: View, Footer == EmptyView, Content: View {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {
        self.init(header: header(), content: content(), footer: EmptyView())
    }
    public init(header: Parent, @ViewBuilder content: () -> Content) {
        self.init(header: header, content: content(), footer: EmptyView())
    }
}

extension Section where Parent == Text, Footer == EmptyView, Content: View {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(header: Text(titleKey), content: content(), footer: EmptyView())
    }
}

protocol SectionLike {
    var sectionHeader: any View { get }
    var sectionContent: any View { get }
    var sectionFooter: any View { get }
}

final class SectionNode: Node {
    var content: Node?
    override var disposableChildren: [Node] { content.map { [$0] } ?? [] }
    var title: String?
    var footer: String?
    var prominent = false
    override var flattened: [LayoutNode] { content?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        guard let section = view as? SectionLike else { return }
        prominent = env.headerProminent
        title = findText(section.sectionHeader)?.content
        footer = findText(section.sectionFooter)?.content
        content = adopt(reconcile(content, section.sectionContent, env))
    }
    override func mountContents() { content?.mount() }
}

final class ListRow: ContainerNode {
    var destination: (any View)?
    var tag: AnyHashable?
    var traits = RowTraits()
    var cell: UITableViewCell?
    var separatorLine: UIView?
    var backgroundApplied = false
    override func computeSize(_ p: ProposedSize) -> CGSize {
        let s = children.first?.sizeThatFits(ProposedSize(width: p.width, height: nil)) ?? .zero
        return CGSize(width: p.width ?? s.width, height: s.height)
    }
    override func layoutContents(_ size: CGSize) {
        guard let kid = children.first else { return }
        let s = kid.sizeThatFits(ProposedSize(width: size.width, height: nil))
        kid.place(CGRect(x: 0, y: (size.height - s.height) / 2, width: size.width, height: s.height))
    }
}

final class ListController: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var node: ListNode?

    func numberOfSections(in tableView: UITableView) -> Int { node?.sections.count ?? 0 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let node, section < node.sections.count else { return nil }
        return node.sections[section].title
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let node, node.prominence[section] == true, let title = node.sections[section].title else { return nil }
        // the header is text of the section, so it is drawn at the size the section's own size category means
        let scale = node.sectionTextScales[section]
        let holder = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 44 * scale))
        let label = UILabel(frame: CGRect(x: 20, y: 8, width: tableView.bounds.size.width - 40, height: 28 * scale))
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: 22 * scale)
        label.backgroundColor = .clear
        label.textColor = UIColor(red: 0.3, green: 0.34, blue: 0.42, alpha: 1)
        label.shadowColor = .white
        label.shadowOffset = CGSize(width: 0, height: 1)
        holder.addSubview(label)
        return holder
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let node, section < node.sections.count, node.prominence[section] == true, node.sections[section].title != nil else {
            return UITableView.automaticDimension
        }
        return 44 * (node.sectionTextScales.isEmpty ? 1 : node.sectionTextScales[min(section, node.sectionTextScales.count - 1)])
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let node, section < node.sections.count else { return nil }
        return node.sections[section].footer
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let node, section < node.sections.count else { return 0 }
        return node.sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let node, let row = node.row(at: indexPath) else { return UITableViewCell(style: .default, reuseIdentifier: nil) }
        let cell = row.cell ?? UITableViewCell(style: .default, reuseIdentifier: nil)
        row.cell = cell
        configure(cell, row, node)
        row.mount()
        if row.uiView.superview !== cell.contentView { cell.contentView.addSubview(row.uiView) }
        return cell
    }
    func configure(_ cell: UITableViewCell, _ row: ListRow, _ node: ListNode) {
        // a colour behind the row; a clear one takes away the white card a row of a grouped table is drawn on
        if let color = row.traits.background {
            cell.backgroundColor = color
            var alpha: CGFloat = 1
            color.getWhite(nil, alpha: &alpha)
            if alpha == 0 { cell.backgroundView = UIView(); cell.backgroundView?.backgroundColor = .clear }
            row.backgroundApplied = true
        } else if row.backgroundApplied {
            cell.backgroundColor = nil
            cell.backgroundView = nil
            row.backgroundApplied = false
        }
        cell.accessoryType = row.destination != nil ? .disclosureIndicator : .none
        cell.accessoryView = row.traits.badge.map { badgeView($0, row.content?.env.textSizeFactor ?? 1) }
        cell.selectionStyle = row.destination != nil || node.selection != nil ? .blue : .none
        applySeparator(cell, row)
        if let selection = node.selection, let tag = row.tag, node.env.splitStage == nil {
            cell.accessoryType = selection.current().contains(tag) ? .checkmark : cell.accessoryType
        }
    }

    // The table of iOS 6 draws one hairline between every pair of rows, in the table's own colour, and a cell of that iOS
    // has no separator inset to shorten it. A row that hides the line, or gives it another colour, therefore covers it
    // with a line of its own - drawn where the release draws its: one point tall, at the bottom of the row, from one
    // edge of the cell to the other.
    func applySeparator(_ cell: UITableViewCell, _ row: ListRow) {
        let hiding = row.traits.separator == .hidden
        let tint = row.traits.separatorTint
        if !hiding && tint == nil {
            row.separatorLine?.removeFromSuperview()
            row.separatorLine = nil
            return
        }
        let line = row.separatorLine ?? {
            let view = UIView()
            view.isUserInteractionEnabled = false
            cell.addSubview(view)
            row.separatorLine = view
            return view
        }()
        // what the row hides the hairline with is what the hairline was drawn over: the row's own background, or the
        // table's where the row has none
        line.backgroundColor = tint ?? row.traits.background ?? cell.backgroundColor ?? node?.uiView.backgroundColor
        // one pixel of a line, where the release puts its own: the bottom of the cell, from one edge to the other
        let thickness = 1 / UIScreen.main.scale
        line.frame = CGRect(x: 0, y: max(0, cell.bounds.size.height - thickness), width: cell.bounds.size.width, height: thickness)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let minimum = node?.env.defaultMinListRowHeight ?? 44
        guard let node, let row = node.row(at: indexPath) else { return minimum }
        let width = tableView.bounds.size.width - node.insetWidth
        let height = max(minimum, row.sizeThatFits(ProposedSize(width: width, height: nil)).height + 22)
        node.measuredHeights[ObjectIdentifier(row)] = height
        return height
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let node, let row = node.row(at: indexPath) else { return }
        cell.layoutIfNeeded()
        applySeparator(cell, row)
        let bounds = cell.contentView.bounds
        row.place(CGRect(x: bounds.origin.x + 10, y: bounds.origin.y, width: bounds.size.width - 20, height: bounds.size.height))
    }
    func canDelete(_ indexPath: IndexPath) -> Bool {
        guard let node, let row = node.row(at: indexPath) else { return false }
        if let swipe = row.traits.trailingSwipe { return !swipe.isEmpty }
        return node.editable?.deleteAction != nil && row.traits.deleteDisabled != true
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        canDelete(indexPath) || self.tableView(tableView, canMoveRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        canDelete(indexPath) ? .delete : .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        canDelete(indexPath)
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        guard let swipe = node?.row(at: indexPath)?.traits.trailingSwipe, let first = swipe.first else { return "Delete" }
        return swipe.count == 1 ? first.title : "More"
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard let node, node.editable?.moveAction != nil else { return false }
        return node.row(at: indexPath)?.traits.moveDisabled != true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, let node else { return }
        if let swipe = node.row(at: indexPath)?.traits.trailingSwipe {
            tableView.setEditing(false, animated: true)
            if swipe.count == 1 { swipe[0].action() } else { SwipeMenu(swipe).show(in: tableView) }
            return
        }
        node.editable?.deleteAction?(IndexSet(integer: indexPath.row))
    }

    func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to destination: IndexPath) {
        node?.movedByTable = true
        node?.editable?.moveAction?(IndexSet(integer: source.row), destination.row)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let node, let row = node.row(at: indexPath) else { return }
        if let selection = node.selection, let tag = row.tag {
            selection.choose(tag)
            node.env.splitPush?(selection.clear)
            return
        }
        guard let destination = row.destination else { return }
        pushDestination(destination, from: node.env)
    }
}

final class ListNode: LayoutNode {
    let controller = ListController()
    var content: Node?
    var rows: [ListRow] = []
    var sections: [(title: String?, footer: String?, rows: [ListRow])] = []
    // the factor the text of a section is drawn at, which is the size category of that section's own environment
    var sectionTextScales: [CGFloat] = []
    var editable: EditableContent?
    var selection: SelectionBox?
    var prominence: [Int: Bool] = [:]
    let grouped: Bool
    var insetWidth: CGFloat { grouped ? 60 : 40 }
    init(grouped: Bool) {
        self.grouped = grouped
        super.init(view: UITableView(frame: .zero, style: grouped ? .grouped : .plain))
        controller.node = self
        ListController.registerSwipeActions()
        let table = uiView as! UITableView
        table.dataSource = controller
        table.delegate = controller
        // the swipe actions of the backports attach when a delegate is set after their library loaded; asking again is harmless
        let install = NSSelectorFromString("charon_installSwipeActions")
        if table.responds(to: install) { table.perform(install) }
    }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        var inner = env
        inner.list = self
        let table = uiView as! UITableView
        if env.scrollBackgroundHidden {
            table.backgroundView = nil
            table.backgroundColor = .clear
        }
        selection = (view as! ListLike).listSelection
        content = adopt(reconcile(content, (view as! ListLike).listContent, inner))
        syncRows()
        editing = editingAccess(env)
        if let host = env.host as? _HostingViewController, editingHost !== host {
            editingHost?.editingObservers[ObjectIdentifier(self)] = nil
            editingHost = host
            host.editingObservers[ObjectIdentifier(self)] = { [weak self] animated in self?.applyEditing(animated) }
        }
        applyEditing(false)
    }

    var editing: EditingAccess?
    weak var editingHost: _HostingViewController?

    func applyEditing(_ animated: Bool) {
        guard let want = editing?.get() else { return }
        let table = uiView as! UITableView
        if table.isEditing != want { table.setEditing(want, animated: animated) }
    }

    override func dispose() {
        editingHost?.editingObservers[ObjectIdentifier(self)] = nil
        super.dispose()
    }

    func row(at indexPath: IndexPath) -> ListRow? {
        guard indexPath.section < sections.count else { return nil }
        let rows = sections[indexPath.section].rows
        return indexPath.row < rows.count ? rows[indexPath.row] : nil
    }

    // Rows are matched by the node they show, so a row keeps its cell when the list around it changes, and what was
    // inserted, removed or moved is animated by the table; anything structural beyond that reloads it.
    var movedByTable = false
    var measuredHeights: [ObjectIdentifier: CGFloat] = [:]

    func syncRows() {
        editable = firstEditable(content)
        let table = uiView as! UITableView
        let previousSections = sections
        var byContent: [ObjectIdentifier: ListRow] = [:]
        for row in rows { if let content = row.content { byContent[ObjectIdentifier(content)] = row } }
        func take(_ item: LayoutNode) -> ListRow {
            let row = byContent.removeValue(forKey: ObjectIdentifier(item)) ?? ListRow()
            row.content = item
            row.destination = (item as? NavigationLinkNode)?.destination
            row.traits = rowTraits(item, upTo: self)
            row.tag = rowTag(item, upTo: self)
            return row
        }
        var groups: [(title: String?, footer: String?, rows: [ListRow])] = []
        var scales: [CGFloat] = []
        prominence = [:]
        var loose: [ListRow] = []
        for node in topLevel(content) {
            if let section = node as? SectionNode {
                if !loose.isEmpty { groups.append((nil, nil, loose)); scales.append(env.textSizeFactor); loose = [] }
                groups.append((section.title, section.footer, section.flattened.map(take)))
                scales.append(section.env.textSizeFactor)
                prominence[groups.count - 1] = section.prominent
            } else {
                loose.append(contentsOf: node.flattened.map(take))
            }
        }
        if !loose.isEmpty || groups.isEmpty { groups.append((nil, nil, loose)); scales.append(env.textSizeFactor) }
        if scales.count < groups.count { scales.append(contentsOf: [CGFloat](repeating: 1, count: groups.count - scales.count)) }
        sectionTextScales = scales
        sections = groups
        rows = groups.flatMap { $0.rows }

        let sameSections = previousSections.count == groups.count
            && zip(previousSections, groups).allSatisfy { $0.title == $1.title && $0.footer == $1.footer }
        let hadRows = previousSections.contains { !$0.rows.isEmpty }
        if movedByTable {
            movedByTable = false
            return
        }
        guard sameSections, hadRows, table.window != nil || table.superview != nil else {
            table.reloadData()
            return
        }
        var deletions: [IndexPath] = [], insertions: [IndexPath] = []
        for (section, pair) in zip(previousSections, groups).enumerated() {
            let change = ListRowDiff.between(pair.0.rows, pair.1.rows)
            deletions += change.deleted.map { IndexPath(row: $0, section: section) }
            insertions += change.inserted.map { IndexPath(row: $0, section: section) }
            // a row that moved shows in a new cell, so that no cell is on the way out and the way in at once
            for index in change.inserted where change.deleted.contains(where: { previousSections[section].rows[$0] === pair.1.rows[index] }) {
                pair.1.rows[index].cell = nil
            }
        }
        if deletions.isEmpty && insertions.isEmpty {
            controller.refreshVisible(table, self)
            return
        }
        let animation: UITableView.RowAnimation = UIView.areAnimationsEnabled ? .fade : .none
        table.beginUpdates()
        table.deleteRows(at: deletions, with: animation)
        table.insertRows(at: insertions, with: animation)
        table.endUpdates()
        controller.refreshVisible(table, self)
    }
    func traitsChanged() {
        for row in rows { if let item = row.content { row.traits = rowTraits(item, upTo: self) } }
    }
    override func mountContents() { content?.mount() }
    override var disposableChildren: [Node] { content.map { [$0] } ?? [] }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
}

func badgeView(_ text: String, _ scale: CGFloat = 1) -> UIView {
    let label = UILabel()
    label.text = text
    label.font = UIFont.boldSystemFont(ofSize: 14 * scale)
    label.textColor = .white
    label.textAlignment = .center
    label.backgroundColor = UIColor(red: 0.55, green: 0.6, blue: 0.7, alpha: 1)
    label.layer.cornerRadius = 10
    label.clipsToBounds = true
    let size = label.sizeThatFits(CGSize(width: 200, height: 20))
    label.frame = CGRect(x: 0, y: 0, width: max(24, size.width + 14), height: 20 * scale)
    return label
}

func rowTag(_ item: Node, upTo list: Node) -> AnyHashable? {
    var current: Node? = item
    while let node = current, node !== list {
        if let tagged = node as? TagNode { return tagged.tag }
        if let each = node.parent as? ForEachNode, let match = each.children.first(where: { $0.1 === node }) { return match.0 }
        current = node.parent
    }
    return nil
}

enum ListRowDiff {
    // Rows in both lists that keep their order stay; the rest are deleted from the old list and inserted in the new one.
    static func between(_ old: [ListRow], _ new: [ListRow]) -> (deleted: [Int], inserted: [Int]) {
        var oldIndex: [ObjectIdentifier: Int] = [:]
        for (index, row) in old.enumerated() { oldIndex[ObjectIdentifier(row)] = index }
        var common: [(new: Int, old: Int)] = []
        for (index, row) in new.enumerated() { if let before = oldIndex[ObjectIdentifier(row)] { common.append((index, before)) } }
        // the longest run of common rows that is in the same order in both lists is what stays where it is
        var tails: [Int] = [], tailIndex: [Int] = [], parent = [Int](repeating: -1, count: common.count)
        for (position, pair) in common.enumerated() {
            var low = 0, high = tails.count
            while low < high { let mid = (low + high) / 2; if tails[mid] < pair.old { low = mid + 1 } else { high = mid } }
            if low == tails.count { tails.append(pair.old); tailIndex.append(position) } else { tails[low] = pair.old; tailIndex[low] = position }
            parent[position] = low > 0 ? tailIndex[low - 1] : -1
        }
        var keptOld = Set<Int>(), keptNew = Set<Int>()
        var at = tailIndex.last ?? -1
        while at >= 0 { keptOld.insert(common[at].old); keptNew.insert(common[at].new); at = parent[at] }
        return ((0..<old.count).filter { !keptOld.contains($0) }, (0..<new.count).filter { !keptNew.contains($0) })
    }
}

extension ListController {
    func refreshVisible(_ table: UITableView, _ node: ListNode) {
        for path in table.indexPathsForVisibleRows ?? [] {
            guard let cell = table.cellForRow(at: path), let row = node.row(at: path) else { continue }
            configure(cell, row, node)
        }
        // the table measures its rows again only when one of them changed size
        var resized = false
        for path in table.indexPathsForVisibleRows ?? [] {
            guard let row = node.row(at: path), let before = node.measuredHeights[ObjectIdentifier(row)] else { continue }
            if abs(tableView(table, heightForRowAt: path) - before) > 0.5 { resized = true }
        }
        if resized { table.beginUpdates(); table.endUpdates() }
    }
}

// The editable forms: a row is written against the element's own binding, so an edit, a delete and a
// move reach the collection the app holds. Apple's shapes and constraints, from the 26.2 interface.
extension List {
    private static func setBox<V: Hashable>(_ binding: Binding<Set<V>?>) -> SelectionBox {
        SelectionBox(current: { binding.wrappedValue.map { Set($0.map { AnyHashable($0) }) } ?? [] },
                     choose: { value in
                         guard var current = binding.wrappedValue, let typed = value.base as? V else { return }
                         if current.contains(typed) { current.remove(typed) } else { current.insert(typed) }
                         binding.wrappedValue = current
                     },
                     clear: { binding.wrappedValue = [] })
    }
    private static func setBox<V: Hashable>(_ binding: Binding<Set<V>>) -> SelectionBox {
        SelectionBox(current: { Set(binding.wrappedValue.map { AnyHashable($0) }) },
                     choose: { value in
                         guard let typed = value.base as? V else { return }
                         if binding.wrappedValue.contains(typed) { binding.wrappedValue.remove(typed) } else { binding.wrappedValue.insert(typed) }
                     },
                     clear: { binding.wrappedValue = [] })
    }
    private static func optionalBox<V: Hashable>(_ binding: Binding<V?>) -> SelectionBox {
        SelectionBox(current: { binding.wrappedValue.map { [AnyHashable($0)] } ?? [] },
                     choose: { if let value = $0.base as? V { binding.wrappedValue = value } },
                     clear: { binding.wrappedValue = nil })
    }
}

extension List {
    public init<C, R>(_ data: Binding<C>, selection: Binding<Set<SelectionValue>?>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R)
        where Content == ForEach<IndexedIdentifierCollection<C, C.Element.ID>, C.Element.ID, EditableCollectionContent<R, C>>,
              C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, C.Element: Identifiable, C.Index: Hashable, R: View {
        var collection = IndexedIdentifierCollection<C, C.Element.ID>(items: indexed(data.wrappedValue, id: \.id))

        self.init(content: ForEach(data: collection, id: \.id) { EditableCollectionContent(content: rowContent(elementBinding(data, $0.index))) })
        if selection != nil { self.selection = List.setBox(selection) }
    }
    public init<C, ID, R>(_ data: Binding<C>, selection: Binding<Set<SelectionValue>?>, id: KeyPath<C.Element, ID>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R)
        where Content == ForEach<IndexedIdentifierCollection<C, ID>, ID, EditableCollectionContent<R, C>>,
              C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, C.Element: Identifiable, C.Index: Hashable, ID: Hashable, R: View {
        var collection = IndexedIdentifierCollection<C, ID>(items: indexed(data.wrappedValue, id: id))

        self.init(content: ForEach(data: collection, id: \.id) { EditableCollectionContent(content: rowContent(elementBinding(data, $0.index))) })
        if selection != nil { self.selection = List.setBox(selection) }
    }
    public init<C, R>(_ data: Binding<C>, selection: Binding<SelectionValue?>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R)
        where Content == ForEach<IndexedIdentifierCollection<C, C.Element.ID>, C.Element.ID, EditableCollectionContent<R, C>>,
              C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, C.Element: Identifiable, C.Index: Hashable, R: View {
        var collection = IndexedIdentifierCollection<C, C.Element.ID>(items: indexed(data.wrappedValue, id: \.id))

        self.init(content: ForEach(data: collection, id: \.id) { EditableCollectionContent(content: rowContent(elementBinding(data, $0.index))) })
        if selection != nil { self.selection = List.optionalBox(selection) }
    }
    public init<C, ID, R>(_ data: Binding<C>, selection: Binding<SelectionValue?>, id: KeyPath<C.Element, ID>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R)
        where Content == ForEach<IndexedIdentifierCollection<C, ID>, ID, EditableCollectionContent<R, C>>,
              C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, C.Element: Identifiable, C.Index: Hashable, ID: Hashable, R: View {
        var collection = IndexedIdentifierCollection<C, ID>(items: indexed(data.wrappedValue, id: id))

        self.init(content: ForEach(data: collection, id: \.id) { EditableCollectionContent(content: rowContent(elementBinding(data, $0.index))) })
        if selection != nil { self.selection = List.optionalBox(selection) }
    }
}

// A list with nothing selected takes its rows under the empty selection, as SwiftUI writes it.
extension List where SelectionValue == Never {
    public init<C, ID, R>(_ data: Binding<C>, id: KeyPath<C.Element, ID>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R)
        where Content == ForEach<IndexedIdentifierCollection<C, ID>, ID, EditableCollectionContent<R, C>>,
              C: MutableCollection & RandomAccessCollection, C.Element: Identifiable, C.Index: Hashable, ID: Hashable, R: View {
        let collection = IndexedIdentifierCollection<C, ID>(items: indexed(data.wrappedValue, id: id))
        self.init(content: ForEach(data: collection, id: \.id) { EditableCollectionContent(content: rowContent(elementBinding(data, $0.index))) })
    }
    public init<C, ID, R>(_ data: Binding<C>, editActions: EditActions<C>, id: KeyPath<C.Element, ID>, @ViewBuilder rowContent: @escaping (Binding<C.Element>) -> R)
        where Content == ForEach<IndexedIdentifierCollection<C, ID>, ID, EditableCollectionContent<R, C>>,
              C: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, C.Element: Identifiable, C.Index: Hashable, ID: Hashable, R: View {
        var collection = IndexedIdentifierCollection<C, ID>(items: indexed(data.wrappedValue, id: id))
        if editActions.contains(.delete) { collection.deleteHook = { data.wrappedValue.remove(atOffsets: $0) } }
        if editActions.contains(.move) { collection.moveHook = { data.wrappedValue.move(fromOffsets: $0, toOffset: $1) } }
        self.init(content: ForEach(data: collection, id: \.id) { EditableCollectionContent(content: rowContent(elementBinding(data, $0.index))) })
    }
}
