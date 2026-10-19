import UIKit
import CoreGraphics

public protocol DynamicViewContent: View {}

protocol EditableContent {
    var deleteAction: ((IndexSet) -> Void)? { get }
    var moveAction: ((IndexSet, Int) -> Void)? { get }
}

public struct _EditableForEach<Source: View>: View, PrimitiveView, DynamicViewContent {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let source: Source
    let onDelete: ((IndexSet) -> Void)?
    let onMove: ((IndexSet, Int) -> Void)?
    func makeNode(_ env: EnvironmentValues) -> Node {
        let node = ForEachNode()
        node.update(self, env)
        return node
    }
}

extension _EditableForEach: ForEachLike, EditableContent {
    var identifiedViews: [(AnyHashable, any View)] { (source as? ForEachLike)?.identifiedViews ?? [] }
    var deleteAction: ((IndexSet) -> Void)? { onDelete }
    var moveAction: ((IndexSet, Int) -> Void)? { onMove }
}

extension ForEach: DynamicViewContent where Content: View {}

extension DynamicViewContent {
    public func onDelete(perform action: ((IndexSet) -> Void)?) -> some DynamicViewContent {
        _EditableForEach(source: self, onDelete: action, onMove: (self as? EditableContent)?.moveAction)
    }
    public func onMove(perform action: ((IndexSet, Int) -> Void)?) -> some DynamicViewContent {
        _EditableForEach(source: self, onDelete: (self as? EditableContent)?.deleteAction, onMove: action)
    }
}

public struct EditButton: View {
    public init() {}
    public var body: some View {
        _EditButtonBody()
    }
}

struct _EditButtonBody: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = EditButtonNode(); n.update(self, env); return n }
}

// Where "is the screen being edited" lives: the \.editMode binding when the app gives one, the screen itself otherwise.
struct EditingAccess {
    let get: () -> Bool
    let set: (Bool) -> Void
}

func editingAccess(_ env: EnvironmentValues) -> EditingAccess? {
    if let binding = env.editMode {
        return EditingAccess(get: { binding.wrappedValue.isEditing }, set: { binding.wrappedValue = $0 ? .active : .inactive })
    }
    if let host = env.host {
        return EditingAccess(get: { host.isEditing }, set: { host.setEditing($0, animated: true) })
    }
    return nil
}

final class EditButtonNode: LayoutNode {
    let target = ControlTarget()
    var button: UIButton { uiView as! UIButton }
    var access: EditingAccess?
    weak var editingHost: _HostingViewController?

    init() {
        let control = UIButton(type: .roundedRect)
        super.init(view: control)
        control.addTarget(target, action: #selector(ControlTarget.fire), for: .touchUpInside)
        target.action = { [weak self] in
            guard let access = self?.access else { return }
            access.set(!access.get())
            self?.refreshTitle()
        }
    }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        access = editingAccess(env)
        if let host = env.host as? _HostingViewController, editingHost !== host {
            editingHost?.editingObservers[ObjectIdentifier(self)] = nil
            editingHost = host
            host.editingObservers[ObjectIdentifier(self)] = { [weak self] _ in self?.refreshTitle() }
        }
        refreshTitle()
    }

    override func dispose() {
        editingHost?.editingObservers[ObjectIdentifier(self)] = nil
        super.dispose()
    }

    func refreshTitle() {
        button.setTitle((access?.get() ?? false) ? "Done" : "Edit", for: .normal)
    }

    override func computeSize(_ p: ProposedSize) -> CGSize {
        let wanted = button.sizeThatFits(CGSize(width: infinity, height: infinity))
        return CGSize(width: min(wanted.width + 16, p.width ?? infinity), height: max(wanted.height, 30))
    }
}

final class RefreshTarget: NSObject {
    var action: (@Sendable () async -> Void)?
    @objc func fire(_ control: UIRefreshControl) {
        guard let action else { control.endRefreshing(); return }
        Task { @MainActor in
            await action()
            control.endRefreshing()
        }
    }
}

final class SearchDelegate: NSObject, UISearchBarDelegate {
    var changed: (String) -> Void = { _ in }
    var scopeChanged: (Int) -> Void = { _ in }
    var activeChanged: (Bool) -> Void = { _ in }
    var active = false
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { changed(searchText) }
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) { active = true; activeChanged(true) }
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) { active = false; activeChanged(false) }
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) { scopeChanged(selectedScope) }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
}

struct ListDecorationModifier: NodeModifier {
    let refresh: (@Sendable () async -> Void)?
    let searchText: Binding<String>?
    let searchPrompt: String?
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { ListDecorationNode() }
}

final class ListDecorationNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    let refreshTarget = RefreshTarget()
    let searchDelegate = SearchDelegate()
    var refreshControl: UIRefreshControl?
    var searchBar: UISearchBar?
    var suggestions: _HostingViewController?
    override var flattened: [LayoutNode] { child?.flattened ?? [] }

    var standalone = false

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! ListDecorationModifier
        if let binding = modifier.searchText {
            searchDelegate.activeChanged = { [weak self] _ in self?.searchActivityChanged(binding) }
        }
        if standalone, let binding = modifier.searchText {
            child = adopt(reconcile(child, standaloneSearch(m.modifiedContent, binding, modifier.searchPrompt, env), env))
            return
        }
        var inner = env
        inner.isSearching = searchDelegate.active
        if let refresh = modifier.refresh { inner.refresh = RefreshAction(action: refresh) }
        if let binding = modifier.searchText {
            inner.dismissSearch = DismissSearchAction(action: { [weak self] in
                self?.searchBar?.resignFirstResponder()
                binding.wrappedValue = ""
            })
        }
        child = adopt(reconcile(child, m.modifiedContent, inner))
        guard let table = tableView() else {
            if let binding = modifier.searchText {
                standalone = true
                child = adopt(reconcile(child, standaloneSearch(m.modifiedContent, binding, modifier.searchPrompt, env), env))
            }
            return
        }
        if let refresh = modifier.refresh {
            refreshTarget.action = refresh
            if refreshControl == nil {
                let control = UIRefreshControl()
                control.addTarget(refreshTarget, action: #selector(RefreshTarget.fire(_:)), for: .valueChanged)
                table.addSubview(control)
                refreshControl = control
            }
        }
        if let binding = modifier.searchText {
            searchDelegate.changed = { binding.wrappedValue = $0 }
            if searchBar == nil {
                let bar = UISearchBar()
                bar.delegate = searchDelegate
                bar.placeholder = modifier.searchPrompt ?? "Search"
                bar.sizeToFit()
                table.tableHeaderView = bar
                searchBar = bar
            }
            if searchBar?.text != binding.wrappedValue { searchBar?.text = binding.wrappedValue }
            if let bar = searchBar { applyScopes(bar, searchDelegate, env) }
            showSuggestions(table, binding, env)
        }
    }

    func searchActivityChanged(_ binding: Binding<String>) {
        var node: Node? = parent
        while let current = node, !(current is CompositeNode) { node = current.parent }
        (node as? CompositeNode)?.invalidate()
    }

    func completion(_ binding: Binding<String>) -> (String) -> Void {
        { [weak self] text in
            binding.wrappedValue = text
            self?.searchBar?.text = text
            self?.searchBar?.resignFirstResponder()
        }
    }

    func suggestionsList(_ env: EnvironmentValues, _ binding: Binding<String>) -> (any View)? {
        guard searchDelegate.active, let make = env.searchSuggestions else { return nil }
        let content = make()
        if content is EmptyView { return nil }
        let complete = completion(binding)
        return withEnvironment(List { AnyView(content) }) { $0.searchComplete = complete; $0.searchSuggestions = nil }
    }

    func showSuggestions(_ table: UITableView, _ binding: Binding<String>, _ env: EnvironmentValues) {
        guard let list = suggestionsList(env, binding), let bar = searchBar else {
            suggestions?.view.removeFromSuperview()
            suggestions = nil
            table.isScrollEnabled = true
            return
        }
        let host = suggestions ?? _HostingViewController(rootView: list)
        host.setRootView(list, env: env)
        suggestions = host
        table.setContentOffset(.zero, animated: false)
        table.isScrollEnabled = false
        let top = bar.frame.maxY
        host.view.frame = CGRect(x: 0, y: top, width: table.bounds.size.width, height: max(0, table.bounds.size.height - top))
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if host.view.superview !== table { table.addSubview(host.view) }
        host.view.setNeedsLayout()
    }

    func standaloneSearch(_ content: any View, _ text: Binding<String>, _ prompt: String?, _ env: EnvironmentValues) -> any View {
        let active = searchDelegate.active
        let shown: any View = suggestionsList(env, text) ?? withEnvironment(AnyView(content)) { $0.isSearching = active }
        return VStack(spacing: 0) {
            _SearchField(text: text, prompt: prompt, scope: env.searchScope, delegate: searchDelegate).frame(maxWidth: .infinity)
            AnyView(shown).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    func tableView() -> UITableView? {
        for node in flattened {
            if let table = node.uiView as? UITableView { return table }
        }
        return nil
    }

    override func mountContents() { child?.mount() }
}

extension View {
    public func refreshable(action: @escaping @Sendable () async -> Void) -> some View {
        _ModifiedView(content: self, modifier: ListDecorationModifier(refresh: action, searchText: nil, searchPrompt: nil))
    }
    public func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil) -> some View {
        _ModifiedView(content: self, modifier: ListDecorationModifier(refresh: nil, searchText: text, searchPrompt: prompt?.content))
    }
    public func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey) -> some View {
        _ModifiedView(content: self, modifier: ListDecorationModifier(refresh: nil, searchText: text, searchPrompt: prompt.text))
    }
    @_disfavoredOverload
    public func searchable<S: StringProtocol>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: S) -> some View {
        _ModifiedView(content: self, modifier: ListDecorationModifier(refresh: nil, searchText: text, searchPrompt: String(prompt)))
    }
    public func listRowBackground<V: View>(_ view: V?) -> some View {
        if let view, !(view is Color) {
            _Unsupported.note("listRowBackground(view)", "a row of a UITableView takes a colour behind it; a view that is not a colour is not drawn")
        }
        let color = (view as? Color)?.uiColor
        return _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.background = color }))
    }

    public func listRowInsets(_ insets: EdgeInsets?) -> some View {
        padding(insets ?? EdgeInsets())
    }

    public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View {
        // a UITableView of this release draws its hairline under the row and none above it, so the top edge of the
        // argument asks for nothing that is not already so
        if !edges.contains(.bottom) { _Unsupported.note("listRowSeparator(edges:)", "a table of iOS 6 draws no line above a row, so a request for the top edge alone is what the release already does") }
        return _ModifiedView(content: self, modifier: RowTraitModifier(apply: { $0.separator = visibility }))
    }
}

public enum Visibility { case automatic, visible, hidden }

struct SearchScopeSetting {
    let titles: [String]
    let tags: [AnyHashable]
    let selection: () -> AnyHashable
    let select: (AnyHashable) -> Void
}

func applyScopes(_ bar: UISearchBar, _ delegate: SearchDelegate, _ env: EnvironmentValues) {
    guard let scope = env.searchScope else {
        if bar.showsScopeBar { bar.showsScopeBar = false; bar.scopeButtonTitles = nil; bar.sizeToFit() }
        return
    }
    if bar.scopeButtonTitles ?? [] != scope.titles {
        bar.scopeButtonTitles = scope.titles
        bar.showsScopeBar = true
        bar.sizeToFit()
    }
    if let index = scope.tags.firstIndex(of: scope.selection()), bar.selectedScopeButtonIndex != index {
        bar.selectedScopeButtonIndex = index
    }
    delegate.scopeChanged = { index in if index < scope.tags.count { scope.select(scope.tags[index]) } }
}

struct _SearchField: UIViewRepresentable {
    let text: Binding<String>
    let prompt: String?
    let scope: SearchScopeSetting?
    let delegate: SearchDelegate
    func makeCoordinator() -> SearchDelegate { delegate }
    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.delegate = context.coordinator
        bar.placeholder = prompt ?? "Search"
        bar.sizeToFit()
        return bar
    }
    func updateUIView(_ bar: UISearchBar, context: Context) {
        let binding = text
        context.coordinator.changed = { binding.wrappedValue = $0 }
        if bar.text != text.wrappedValue { bar.text = text.wrappedValue }
        var env = context.environment
        env.searchScope = scope
        applyScopes(bar, context.coordinator, env)
    }
}

extension View {
    public func searchScopes<V: Hashable, S: View>(_ scope: Binding<V>, @ViewBuilder scopes: () -> S) -> some View {
        let tagged = taggedViews(scopes())
        let setting = SearchScopeSetting(titles: tagged.map { findText($0.1)?.content ?? "\($0.0)" },
                                         tags: tagged.map { $0.0 },
                                         selection: { AnyHashable(scope.wrappedValue) },
                                         select: { if let value = $0.base as? V { scope.wrappedValue = value } })
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.searchScope = setting }, onUpdate: nil))
    }
    public func searchSuggestions<S: View>(@ViewBuilder _ suggestions: () -> S) -> some View {
        let content = suggestions()
        return _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.searchSuggestions = { content } }, onUpdate: nil))
    }
    public func searchCompletion(_ completion: String) -> some View {
        _SearchCompletion(content: self, completion: completion)
    }
    public func searchable<S: View>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
                                    @ViewBuilder suggestions: () -> S) -> some View {
        searchable(text: text, placement: placement, prompt: prompt).searchSuggestions(suggestions)
    }
    public func searchable<S: View>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
                                    @ViewBuilder suggestions: () -> S) -> some View {
        searchable(text: text, placement: placement, prompt: prompt).searchSuggestions(suggestions)
    }
    @_disfavoredOverload
    public func searchable<V: View, S: StringProtocol>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: S,
                                                       @ViewBuilder suggestions: () -> V) -> some View {
        searchable(text: text, placement: placement, prompt: prompt).searchSuggestions(suggestions)
    }
}

struct _SearchCompletion<Content: View>: View {
    let content: Content
    let completion: String
    @Environment(\.searchComplete) var complete
    var body: some View {
        Button(action: { complete?(completion) }) { content }.buttonStyle(.plain)
    }
}

final class AccessibleActionView: UIView {
    var adjust: ((AccessibilityAdjustmentDirection) -> Void)?
    var scroll: ((Edge) -> Void)?
    override func accessibilityIncrement() { adjust?(.increment) }
    override func accessibilityDecrement() { adjust?(.decrement) }
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard let scroll else { return false }
        switch direction {
        case .up: scroll(.top)
        case .down: scroll(.bottom)
        case .left: scroll(.leading)
        case .right: scroll(.trailing)
        default: return false
        }
        return true
    }
}

struct AccessibleActionModifier: NodeModifier {
    let adjust: ((AccessibilityAdjustmentDirection) -> Void)?
    let scroll: ((Edge) -> Void)?
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AccessibleActionNode() }
}

final class AccessibleActionNode: LayoutNode {
    var content: Node?
    var children: [LayoutNode] { content?.flattened ?? [] }
    override var disposableChildren: [Node] { content.map { [$0] } ?? [] }
    var actionView: AccessibleActionView { uiView as! AccessibleActionView }
    init() { super.init(view: AccessibleActionView()) }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! AccessibleActionModifier
        actionView.adjust = modifier.adjust ?? actionView.adjust
        actionView.scroll = modifier.scroll ?? actionView.scroll
        actionView.isAccessibilityElement = true
        if modifier.adjust != nil { actionView.accessibilityTraits.insert(.adjustable) }
        content = adopt(reconcile(content, m.modifiedContent, env))
        if actionView.accessibilityLabel == nil, let text = children.first.flatMap({ accessibleText($0.uiView) }) {
            actionView.accessibilityLabel = text
        }
    }
    override func mountContents() {
        syncSubviews(uiView, children)
        content?.mount()
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

func accessibleText(_ view: UIView) -> String? {
    if let label = view as? UILabel { return label.text }
    if let text = view.accessibilityLabel { return text }
    for sub in view.subviews { if let found = accessibleText(sub) { return found } }
    return nil
}

extension View {
    public func accessibilityAdjustableAction(_ handler: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View {
        _ModifiedView(content: self, modifier: AccessibleActionModifier(adjust: handler, scroll: nil))
    }
    public func accessibilityScrollAction(_ handler: @escaping (Edge) -> Void) -> some View {
        _ModifiedView(content: self, modifier: AccessibleActionModifier(adjust: nil, scroll: handler))
    }
    public func defaultWheelPickerItemHeight(_ height: CGFloat) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.wheelRowHeight = height }, onUpdate: nil))
    }
    public func headerProminence(_ prominence: Prominence) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.headerProminent = prominence == .increased }, onUpdate: nil))
    }
    public func listItemTint(_ tint: Color?) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.tint = tint?.uiColor ?? $0.tint }, onUpdate: nil))
    }
}
