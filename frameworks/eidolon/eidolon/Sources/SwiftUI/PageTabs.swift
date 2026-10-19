import UIKit

public protocol TabViewStyle {}
public struct DefaultTabViewStyle: TabViewStyle { public init() {} }

public struct PageTabViewStyle: TabViewStyle {
    /// Apple's is a struct with three constants, not an enum, so `.page(indexDisplayMode: .never)` reads
    /// the same either way but the declared shape is this one.
    public struct IndexDisplayMode: Hashable {
        let mode: Int
        init(_ mode: Int) { self.mode = mode }
        public static let automatic = IndexDisplayMode(0)
        public static let always = IndexDisplayMode(1)
        public static let never = IndexDisplayMode(2)
        public static func == (a: IndexDisplayMode, b: IndexDisplayMode) -> Bool { a.mode == b.mode }
        public func hash(into hasher: inout Hasher) { hasher.combine(mode) }
    }
    let indexDisplayMode: IndexDisplayMode
    public init(indexDisplayMode: IndexDisplayMode = .automatic) { self.indexDisplayMode = indexDisplayMode }
}

extension TabViewStyle where Self == DefaultTabViewStyle {
    public static var automatic: DefaultTabViewStyle { DefaultTabViewStyle() }
}
extension TabViewStyle where Self == PageTabViewStyle {
    public static var page: PageTabViewStyle { PageTabViewStyle() }
    public static func page(indexDisplayMode: PageTabViewStyle.IndexDisplayMode) -> PageTabViewStyle { PageTabViewStyle(indexDisplayMode: indexDisplayMode) }
}

public protocol IndexViewStyle {}
public struct PageIndexViewStyle: IndexViewStyle {
    public enum BackgroundDisplayMode { case automatic, always, interactive, never }
    let background: BackgroundDisplayMode
    public init(backgroundDisplayMode: BackgroundDisplayMode = .automatic) { background = backgroundDisplayMode }
}
extension IndexViewStyle where Self == PageIndexViewStyle {
    public static var page: PageIndexViewStyle { PageIndexViewStyle() }
    public static func page(backgroundDisplayMode: PageIndexViewStyle.BackgroundDisplayMode) -> PageIndexViewStyle { PageIndexViewStyle(backgroundDisplayMode: backgroundDisplayMode) }
}

struct PagingSettings {
    var showsIndex: PageTabViewStyle.IndexDisplayMode = .automatic
    var indexBackground: PageIndexViewStyle.BackgroundDisplayMode = .automatic
}

struct _BarTabs: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let source: TabViewLike
    func makeNode(_ env: EnvironmentValues) -> Node { let n = TabViewNode(); n.update(self, env); return n }
}

struct _PagedTabs: View, PrimitiveView {
    typealias Body = Never
    var body: Never { neverBody(Self.self) }
    let source: TabViewLike
    let settings: PagingSettings
    func makeNode(_ env: EnvironmentValues) -> Node { let n = PagedTabsNode(); n.update(self, env); return n }
}

final class PagingDelegate: NSObject, UIScrollViewDelegate {
    weak var node: PagedTabsNode?
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { node?.settle() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { node?.settle() }
    @objc func dotsChanged() { node?.dotsChanged() }
}

final class PagedTabsNode: LayoutNode {
    let pagingDelegate = PagingDelegate()
    let scroller = UIScrollView()
    let dots = UIPageControl()
    var pages: [Node] = []
    var source: TabViewLike?
    var showsDots = true

    init() {
        super.init(view: UIView())
        scroller.isPagingEnabled = true
        scroller.showsHorizontalScrollIndicator = false
        pagingDelegate.node = self
        scroller.delegate = pagingDelegate
        uiView.addSubview(scroller)
        uiView.addSubview(dots)
        dots.addTarget(pagingDelegate, action: #selector(PagingDelegate.dotsChanged), for: .valueChanged)
    }

    override var disposableChildren: [Node] { pages }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let paged = view as! _PagedTabs
        source = paged.source
        let children = paged.source.tabChildren
        var next: [Node] = []
        for (index, child) in children.enumerated() {
            next.append(adopt(reconcile(index < pages.count ? pages[index] : nil, child, env)))
        }
        for old in pages.dropFirst(children.count) { old.dispose() }
        pages = next
        dots.numberOfPages = pages.count
        switch paged.settings.showsIndex {
        case .never: showsDots = false
        case .always: showsDots = true
        default: showsDots = pages.count > 1
        }
        dots.isHidden = !showsDots
        dots.pageIndicatorTintColor = UIColor(white: 0.75, alpha: 1)
        dots.currentPageIndicatorTintColor = UIColor(white: 0.3, alpha: 1)
        dots.backgroundColor = paged.settings.indexBackground == .always ? UIColor(white: 0, alpha: 0.25) : .clear
        mount()
        if let index = paged.source.tabSelectedIndex, index < pages.count, index != dots.currentPage {
            dots.currentPage = index
            scroller.setContentOffset(CGPoint(x: CGFloat(index) * scroller.bounds.size.width, y: 0), animated: Updates.animationForFlush != nil)
        }
    }

    override func mountContents() {
        syncSubviews(scroller, pages.flatMap { $0.flattened })
        pages.forEach { $0.mount() }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }

    override func layoutContents(_ size: CGSize) {
        scroller.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        for (index, page) in pages.enumerated() {
            for item in page.flattened {
                item.place(CGRect(x: CGFloat(index) * size.width, y: 0, width: size.width, height: size.height))
            }
        }
        scroller.contentSize = CGSize(width: size.width * CGFloat(pages.count), height: size.height)
        scroller.contentOffset = CGPoint(x: CGFloat(dots.currentPage) * size.width, y: 0)
        dots.frame = CGRect(x: 0, y: size.height - 36, width: size.width, height: 36)
    }

    var currentPage: Int {
        let width = max(scroller.bounds.size.width, 1)
        return max(0, min(pages.count - 1, Int((scroller.contentOffset.x + width / 2) / width)))
    }

    func settle() {
        let page = currentPage
        dots.currentPage = page
        source?.tabSelect(page)
    }

    func dotsChanged() {
        scroller.setContentOffset(CGPoint(x: CGFloat(dots.currentPage) * scroller.bounds.size.width, y: 0), animated: true)
        source?.tabSelect(dots.currentPage)
    }
}

extension View {
    public func tabViewStyle<S: TabViewStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            if let page = style as? PageTabViewStyle {
                var settings = environment.paging ?? PagingSettings()
                settings.showsIndex = page.indexDisplayMode
                environment.paging = settings
            } else {
                environment.paging = nil
            }
        }, onUpdate: nil))
    }
    public func indexViewStyle<S: IndexViewStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            guard let page = style as? PageIndexViewStyle, var settings = environment.paging else { return }
            settings.indexBackground = page.background
            environment.paging = settings
        }, onUpdate: nil))
    }
}

/// What a tab bar's content is: content that yields tabs, all of one tab value, with a body that is
/// more of the same. Apple's is the same shape, with a primary associated type and the constraint that
/// a body carries the tab value its content does. Two of Apple's members are left out on purpose:
/// `_identifiedView` is internal to Apple and nothing dispatches it here, and `_TabContentBodyAdaptor`
/// exists only to view that internal requirement, so a declared one would be a shell.
public protocol TabContent {
    associatedtype TabValue: Hashable
    associatedtype Body: TabContent where Body.TabValue == Self.TabValue
    var body: Self.Body { get }
}

/// The tabs a content yields, in order. A list of them is itself tab content of the same value, which is
/// what makes the body recursive without a cast.
/// One tab: the view that stands for it and the value that names it, or nothing when the content did
/// not name one. A tab with no value is matched the way an untagged page already is here, by position.
public struct _TabContentRow {
    public let value: AnyHashable?
    public let view: any View
    init(value: AnyHashable?, view: any View) { self.value = value; self.view = view }
}

/// The tabs a content yields, as the builder hands them to a TabView. A `_TabContentList` names each of
/// its rows; anything else that is tab content is one tab it names itself, and a plain view is a tab with
/// no name, which is what a TabView over plain views has always been.
func tabContentRows(_ content: any TabContent) -> [_TabContentRow] {
    if let list = content as? any TabContentNaming { return list.namedRows }
    return [_TabContentRow(value: nil, view: AnyView(EmptyView()))]
}

/// One tab content wrapped so a list of tabs can be held together whatever their types are.
public struct AnyTabContent<TabValue: Hashable>: TabContent {
    public typealias TabValue = TabValue
    public typealias Body = AnyTabContent<TabValue>
    let content: any TabContent
    public init<C: TabContent>(_ content: C) where C.TabValue == TabValue { self.content = content }
    public var body: AnyTabContent<TabValue> { self }
    var namedRows: [_TabContentRow] { tabContentRows(content) }
}

/// The label a tab shows when the app does not write one: the release's own tab bar item.
public struct DefaultTabLabel: View, PrimitiveView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let text: String
    let image: String?
    init(text: String, image: String?) { self.text = text; self.image = image }
    func makeNode(_ env: EnvironmentValues) -> Node { EmptyView().makeNode(env) }
}

/// The tabs, in order, each with the view it stands for and the value that names it. This is what
/// `ForEach` of tab content is: one tab per element, named by the element.
struct _TabContentList<Element: Hashable>: TabContent, TabContentNaming {
    public typealias TabValue = AnyHashable
    public typealias Body = _TabContentList<Element>
    let elements: [Element]
    let view: (Element) -> AnyView
    let named: (Element) -> AnyHashable
    public init(_ elements: [Element], view: @escaping (Element) -> AnyView, named: @escaping (Element) -> AnyHashable) {
        self.elements = elements; self.view = view; self.named = named
    }
    public var body: _TabContentList<Element> { self }
    var namedRows: [_TabContentRow] {
        elements.map { _TabContentRow(value: named($0), view: view($0)) }
    }
    public var rows: [(value: AnyHashable, view: AnyView)] { elements.map { (named($0), view($0)) } }
}

protocol TabContentNaming {
    var namedRows: [_TabContentRow] { get }
}

@resultBuilder
public struct TabContentBuilder<TabValue: Hashable> {
    public typealias Content = [_TabContentRow]
    public static func buildExpression<C: TabContent>(_ content: C) -> [_TabContentRow] where C.TabValue == TabValue {
        tabContentRows(content)
    }
    /// A TabView's selection may be an optional of what its tabs carry, and then the tabs are of the
    /// wrapped value: `TabView(selection: $mailbox) { ForEach(mailboxes) { ... } }` selects on a `Mailbox`.
    @_disfavoredOverload
    public static func buildExpression<C: TabContent, V: Hashable>(_ content: C) -> [_TabContentRow]
        where C.TabValue == V, TabValue == V? { tabContentRows(content) }
    /// The builder of a TabView with no selection carries no tab value of its own, so it takes tab content of
    /// any value -- which is what `TabView { ForEach(mailboxes) { ... } }` is: the tabs name themselves.
    @_disfavoredOverload
    public static func buildExpression<C: TabContent>(_ content: C) -> [_TabContentRow] where TabValue == Never {
        tabContentRows(content)
    }
    public static func buildExpression<C: View>(_ content: C) -> [_TabContentRow] {
        [_TabContentRow(value: nil, view: AnyView(content))]
    }

    public static func buildBlock(_ content: [_TabContentRow]...) -> [_TabContentRow] { content.flatMap { $0 } }
    public static func buildIf(_ content: [_TabContentRow]?) -> [_TabContentRow]? { content }
    public static func buildEither(first: [_TabContentRow]) -> [_TabContentRow] { first }
    public static func buildEither(second: [_TabContentRow]) -> [_TabContentRow] { second }
    public static func buildLimitedAvailability(_ content: [_TabContentRow]) -> [_TabContentRow] { content }
}

/// The tabs a content yields, as the views a TabView shows: each one tagged with the value that names
/// it, which is what `TabViewNode`'s own walk already reads to match a selection to a page.
public struct _TabContentRows: View, PrimitiveView, GroupView {
    public typealias Body = Never
    public var body: Never { neverBody(Self.self) }
    let rows: [_TabContentRow]
    init(rows: [_TabContentRow]) { self.rows = rows }
    // each tab is tagged with the value that names it, which is what TabViewNode's own walk already reads
    var childViews: [any View] { rows.map { $0.view } }

}

extension TabView {
    /// A binding whose own value is an optional is left to the initialiser below, which builds over what it
    /// selects on rather than over the optional.
    @_disfavoredOverload
    public init(selection: Binding<SelectionValue>, @TabContentBuilder<SelectionValue> content: () -> [_TabContentRow])
        where Content == _TabContentRows {
        self.selection = selection; self.content = _TabContentRows(rows: content())
    }
    /// The same, when the selection is an optional: the builder is over what it selects on, so the tabs are
    /// of that value and the binding may hold nothing.
    public init(selection: Binding<SelectionValue?>, @TabContentBuilder<SelectionValue> content: () -> [_TabContentRow])
        where Content == _TabContentRows {
        var last = selection.wrappedValue
        let lifted = Binding<SelectionValue>(get: { last! },
                                              set: { last = $0; selection.wrappedValue = $0 })
        self.selection = lifted
        self.content = _TabContentRows(rows: content())
    }
    public init(@TabContentBuilder<Never> content: () -> [_TabContentRow])
        where SelectionValue == Never, Content == _TabContentRows {
        self.selection = nil; self.content = _TabContentRows(rows: content())
    }
}

// A ForEach over tab content: the collection is the tabs, and each element's content is the tab for
// that element. This is the initialiser an app writes, and the one Apple's ForEach has for tab values;
// the view initialisers above take a View, which tab content is not.
extension ForEach where Content: TabContent {
    public init<Data: RandomAccessCollection>(_ data: Data, id: KeyPath<Data.Element, ID>,
                                              content: @escaping (Data.Element) -> Content) {
        self.init(data, id: id, content: content)
    }
    public init<Data: RandomAccessCollection>(_ data: Data,
                                              content: @escaping (Data.Element) -> Content)
        where Data.Element: Identifiable, ID == Data.Element.ID {
        self.init(data, id: \.id, content: content)
    }
}

/// A ForEach of tab content is the tabs, one per element, named by the element -- which is what a
/// TabView reads, and what makes a tab's value the element's own.
extension ForEach: TabContent, TabContentNaming where Content: TabContent {
    public typealias TabValue = Content.TabValue
    public typealias Body = AnyTabContent<Content.TabValue>
    public var body: AnyTabContent<Content.TabValue> { AnyTabContent(self) }
    var namedRows: [_TabContentRow] {
        let factory = content
        return data.map { element in
            let tab = factory(element)
            let named = (tab as? any TabContentNaming)?.namedRows.first
            let value = named?.value ?? AnyHashable(ObjectIdentifier(element as AnyObject))
            let view = (tab as? any TabContentNaming)?.namedRows.first?.view ?? AnyView(EmptyView())
            return _TabContentRow(value: value, view: view)
        }
    }
}

// The two rows Apple's frozen interface prints for an anchor's hashing. `==` and `hash(into:)` are
// declared in TextModifiers.swift, where the anchor's own equality lives; `hashValue` follows them here so
// the three are declared rather than derived, as they are for a frozen type.
extension Anchor where Value: Hashable {
    public var hashValue: Int { var hasher = Hasher(); hash(into: &hasher); return hasher.finalize() }
}

/// What a tab is for, which is what a bar that adapts between a sidebar and a bar reads.
public struct TabRole: Hashable {
    let name: String
    public static var search: TabRole { TabRole(name: "search") }
    public static var `default`: TabRole { TabRole(name: "default") }
}

/// A tab, with the value that names it written in the tab itself. A tab bar on iOS 6 shows a bar and has
/// no sidebar, so a role is carried and the bar has nowhere to sort by it: the tab's value is what a
/// selection matches, and the title and image are what the bar shows, which is the release's own bar item.
public struct Tab<Value, Content, Label> {
    let title: String
    let image: String?
    let role: TabRole?
    let value: Value
    let content: Content
    let label: Label?
}

extension Tab: TabContent, TabContentNaming where Value: Hashable, Content: View, Label: View {
    public typealias TabValue = Value
    public typealias Body = AnyTabContent<Value>
    public var body: AnyTabContent<Value> { AnyTabContent(self) }
    var namedRows: [_TabContentRow] { [_TabContentRow(value: AnyHashable(value), view: AnyView(content))] }
}

extension Tab where Label == DefaultTabLabel, Value: Hashable, Content: View {
    public init<S: StringProtocol>(_ title: S, image: String? = nil, value: Value,
                                   @ViewBuilder content: () -> Content) {
        self.init(title: String(title), image: image, role: nil, value: value, content: content(), label: nil)
    }
    public init<S: StringProtocol>(_ title: S, image: String? = nil, value: Value, role: TabRole?,
                                   @ViewBuilder content: () -> Content) {
        self.init(title: String(title), image: image, role: role, value: value, content: content(), label: nil)
    }
    public init(_ titleKey: LocalizedStringKey, image: String? = nil, value: Value,
                @ViewBuilder content: () -> Content) {
        self.init(title: titleKey.text, image: image, role: nil, value: value, content: content(), label: nil)
    }
    public init<S: StringProtocol>(_ title: S, systemImage: String, value: Value,
                                   @ViewBuilder content: () -> Content) {
        self.init(title: String(title), image: systemImage, role: nil, value: value, content: content(), label: nil)
    }
    public init<S: StringProtocol>(_ title: S, systemImage: String, value: Value, role: TabRole?,
                                   @ViewBuilder content: () -> Content) {
        self.init(title: String(title), image: systemImage, role: role, value: value, content: content(), label: nil)
    }
    public init(_ titleKey: LocalizedStringKey, systemImage: String, value: Value,
                @ViewBuilder content: () -> Content) {
        self.init(title: titleKey.text, image: systemImage, role: nil, value: value, content: content(), label: nil)
    }
    /// The value is optional, so `Tab("Inbox", value: .inbox)` fills in the tab's own value type.
    public init<S: StringProtocol, T: Hashable>(_ title: S, image: String? = nil, value: T,
                                                @ViewBuilder content: () -> Content)
        where Value == T? {
        self.init(title: String(title), image: image, role: nil, value: value, content: content(), label: nil)
    }
    public init<S: StringProtocol, T: Hashable>(_ title: S, image: String? = nil, value: T, role: TabRole?,
                                                @ViewBuilder content: () -> Content)
        where Value == T? {
        self.init(title: String(title), image: image, role: role, value: value, content: content(), label: nil)
    }
    public init<S: StringProtocol, T: Hashable>(_ title: S, systemImage: String, value: T,
                                                @ViewBuilder content: () -> Content)
        where Value == T? {
        self.init(title: String(title), image: systemImage, role: nil, value: value, content: content(), label: nil)
    }
    public init<S: StringProtocol, T: Hashable>(_ title: S, systemImage: String, value: T, role: TabRole?,
                                                @ViewBuilder content: () -> Content)
        where Value == T? {
        self.init(title: String(title), image: systemImage, role: role, value: value, content: content(), label: nil)
    }
}

extension Tab where Value: Hashable, Content: View {
    /// The label is a view the app writes, as Apple's is when it is not the default one.
    public init(_ title: String, image: String? = nil, value: Value, @ViewBuilder label: () -> Label,
                @ViewBuilder content: () -> Content) {
        self.init(title: title, image: image, role: nil, value: value, content: content(), label: label())
    }
    public init(_ title: String, systemImage: String, value: Value, @ViewBuilder label: () -> Label,
                @ViewBuilder content: () -> Content) {
        self.init(title: title, image: systemImage, role: nil, value: value, content: content(), label: label())
    }
    public init(_ title: String, image: String? = nil, value: Value, role: TabRole?,
                @ViewBuilder label: () -> Label, @ViewBuilder content: () -> Content) {
        self.init(title: title, image: image, role: role, value: value, content: content(), label: label())
    }
}
