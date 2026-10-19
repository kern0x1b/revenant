import UIKit
import ObjectiveC

struct DerivedAccessibility {
    var label: String?
    var value: String?
    var traits: UIAccessibilityTraits = .none
}

func deriveAccessibility(_ view: any View) -> DerivedAccessibility {
    if let toggle = view as? ToggleLike {
        return DerivedAccessibility(label: findText(toggle.toggleLabel)?.content, value: toggle.toggleBinding.wrappedValue ? "1" : "0", traits: .button)
    }
    if let slider = view as? SliderLike {
        let bounds = slider.sliderBounds
        let span = bounds.upperBound - bounds.lowerBound
        let fraction = span > 0 ? (slider.sliderValue - bounds.lowerBound) / span : 0
        return DerivedAccessibility(label: nil, value: "\(Int((fraction * 100).rounded()))%", traits: .adjustable)
    }
    if let stepper = view as? StepperLike {
        return DerivedAccessibility(label: findText(stepper.stepperLabel)?.content, value: nil, traits: .adjustable)
    }
    if let button = view as? ButtonLike {
        return DerivedAccessibility(label: findText(button.buttonLabel)?.content, value: nil, traits: .button)
    }
    if let text = view as? Text {
        return DerivedAccessibility(label: text.content, value: nil, traits: .staticText)
    }
    if let modified = view as? ModifiedViewLike { return deriveAccessibility(modified.modifiedContent) }
    if let wrapped = view as? WrappedView { return deriveAccessibility(wrapped.wrapped) }
    if let group = view as? GroupView {
        var merged = DerivedAccessibility()
        let parts = group.childViews.map(deriveAccessibility)
        let labels = parts.compactMap { $0.label }.filter { !$0.isEmpty }
        merged.label = labels.isEmpty ? nil : labels.joined(separator: ", ")
        merged.value = parts.compactMap { $0.value }.first
        merged.traits = UIAccessibilityTraits(rawValue: parts.reduce(0) { $0 | $1.traits.rawValue })
        return merged
    }
    return DerivedAccessibility()
}

func accessibilityScreenFrame(_ rect: CGRect, in view: UIView) -> CGRect {
    guard let window = view.window else { return view.convert(rect, to: nil) }
    return window.convert(view.convert(rect, to: window), to: nil)
}

// MARK: accessibilityRepresentation

struct RepresentationModifier: NodeModifier {
    let representation: any View
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { RepresentationNode() }
}

final class RepresentationNode: ContainerNode {
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        content = adopt(reconcile(content, m.modifiedContent, env))
        let derived = deriveAccessibility((m.modifierValue as! RepresentationModifier).representation)
        uiView.isAccessibilityElement = true
        uiView.accessibilityLabel = derived.label
        uiView.accessibilityValue = derived.value
        uiView.accessibilityTraits = derived.traits
    }
    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

// MARK: accessibilityChildren

final class _AccessibilityContainerView: UIView {
    var sources: [UIView] = []
    var elements: [UIAccessibilityElement] = []

    func refresh() {
        elements = sources.map { source in
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = source.accessibilityLabel
            element.accessibilityValue = source.accessibilityValue
            element.accessibilityHint = source.accessibilityHint
            element.accessibilityTraits = source.accessibilityTraits
            return element
        }
    }

    override func accessibilityElementCount() -> Int { elements.count }
    override func accessibilityElement(at index: Int) -> Any? {
        guard index >= 0 && index < elements.count else { return nil }
        elements[index].accessibilityFrame = accessibilityScreenFrame(sources[index].frame, in: self)
        return elements[index]
    }
    override func index(ofAccessibilityElement element: Any) -> Int {
        elements.firstIndex { $0 === element as AnyObject } ?? NSNotFound
    }
}

struct AccessibilityChildrenModifier: NodeModifier {
    let children: any View
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AccessibilityChildrenNode() }
}

final class AccessibilityChildrenNode: ContainerNode {
    var tree: Node?
    var container: _AccessibilityContainerView { uiView as! _AccessibilityContainerView }
    override var disposableChildren: [Node] { (content.map { [$0] } ?? []) + (tree.map { [$0] } ?? []) }

    override init() { super.init(container: _AccessibilityContainerView()) }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        content = adopt(reconcile(content, m.modifiedContent, env))
        let children = (m.modifierValue as! AccessibilityChildrenModifier).children
        tree = adopt(reconcile(tree, VStack(spacing: 0) { AnyView(children) }, env))
        tree?.mount()
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        children.first?.place(bounds)
        guard let root = tree?.flattened.first else { return }
        root.place(bounds)
        container.sources = accessibleViews([root.uiView]).map { source in
            let frame = source.convert(source.bounds, to: root.uiView)
            let proxy = UIView(frame: frame)
            proxy.accessibilityLabel = source.accessibilityLabel
            proxy.accessibilityValue = source.accessibilityValue
            proxy.accessibilityHint = source.accessibilityHint
            proxy.accessibilityTraits = source.accessibilityTraits
            return proxy
        }
        container.refresh()
    }
}

func accessibleViews(_ roots: [UIView]) -> [UIView] {
    var found: [UIView] = []
    func walk(_ view: UIView) {
        if view.isHidden || view.accessibilityElementsHidden { return }
        if view.isAccessibilityElement { found.append(view); return }
        view.subviews.forEach(walk)
    }
    roots.forEach(walk)
    return found
}

// MARK: accessibilitySortPriority

private nonisolated(unsafe) var sortPriorityKey: UInt8 = 0

extension UIView {
    var _accessibilitySortPriority: Double? {
        get { (objc_getAssociatedObject(self, &sortPriorityKey) as? NSNumber)?.doubleValue }
        set { objc_setAssociatedObject(self, &sortPriorityKey, newValue.map { NSNumber(value: $0) }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

final class _HostRootView: UIView {
    struct Entry { let element: NSObject; let priority: Double; let frame: CGRect }

    func orderedElements() -> [NSObject]? {
        var entries: [Entry] = []
        var prioritised = false
        func walk(_ view: UIView, _ inherited: Double) {
            if view.isHidden || view.alpha < 0.01 || view.accessibilityElementsHidden { return }
            let own = view._accessibilitySortPriority
            if own != nil { prioritised = true }
            let priority = own ?? inherited
            if view.isAccessibilityElement {
                entries.append(Entry(element: view, priority: priority, frame: view.convert(view.bounds, to: self)))
                return
            }
            let count = view.accessibilityElementCount()
            if count > 0 && count != NSNotFound {
                for index in 0..<count {
                    if let element = view.accessibilityElement(at: index) as? NSObject {
                        let frame = (element as? UIView).map { $0.convert($0.bounds, to: self) } ?? convert(element.accessibilityFrame, from: nil)
                        entries.append(Entry(element: element, priority: priority, frame: frame))
                    }
                }
                return
            }
            view.subviews.forEach { walk($0, priority) }
        }
        subviews.forEach { walk($0, 0) }
        guard prioritised else { return nil }
        return entries.enumerated().sorted { a, b in
            if a.element.priority != b.element.priority { return a.element.priority > b.element.priority }
            if a.element.frame.minY != b.element.frame.minY { return a.element.frame.minY < b.element.frame.minY }
            if a.element.frame.minX != b.element.frame.minX { return a.element.frame.minX < b.element.frame.minX }
            return a.offset < b.offset
        }.map { $0.element.element }
    }

    override func accessibilityElementCount() -> Int {
        orderedElements()?.count ?? super.accessibilityElementCount()
    }
    override func accessibilityElement(at index: Int) -> Any? {
        guard let ordered = orderedElements() else { return super.accessibilityElement(at: index) }
        return index >= 0 && index < ordered.count ? ordered[index] : nil
    }
    override func index(ofAccessibilityElement element: Any) -> Int {
        guard let ordered = orderedElements() else { return super.index(ofAccessibilityElement: element) }
        return ordered.firstIndex { $0 === element as AnyObject } ?? NSNotFound
    }
}

// MARK: accessibilityFocused

private nonisolated(unsafe) var focusHandlerKey: UInt8 = 0

final class AccessibilityFocusHandler: NSObject {
    let changed: (Bool) -> Void
    init(_ changed: @escaping (Bool) -> Void) { self.changed = changed }
}

enum AccessibilityFocusHook {
    static var installed = false
    static func install() {
        guard !installed else { return }
        installed = true
        hook(#selector(NSObject.accessibilityElementDidBecomeFocused), true)
        hook(#selector(NSObject.accessibilityElementDidLoseFocus), false)
    }
    private static func hook(_ selector: Selector, _ focused: Bool) {
        guard let method = class_getInstanceMethod(UIView.self, selector) else { return }
        typealias Original = @convention(c) (AnyObject, Selector) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let block: @convention(block) (UIView) -> Void = { view in
            original(view, selector)
            (objc_getAssociatedObject(view, &focusHandlerKey) as? AccessibilityFocusHandler)?.changed(focused)
        }
        class_replaceMethod(UIView.self, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }
}

struct AccessibilityFocusModifier: NodeModifier {
    let isFocused: () -> Bool
    let focusChanged: (Bool) -> Void
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AccessibilityFocusNode() }
}

final class AccessibilityFocusNode: ContainerNode {
    var wasFocused = false
    var handler: AccessibilityFocusHandler?
    var wantsFocus = false

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! AccessibilityFocusModifier
        content = adopt(reconcile(content, m.modifiedContent, env))
        AccessibilityFocusHook.install()
        handler = AccessibilityFocusHandler { [weak self] focused in
            self?.wasFocused = focused
            modifier.focusChanged(focused)
        }
        let focused = modifier.isFocused()
        wantsFocus = focused && !wasFocused
        wasFocused = focused
        attach()
    }

    override func mountContents() {
        super.mountContents()
        attach()
    }

    func attach() {
        let candidates = [uiView] + accessibleViews(children.map { $0.uiView })
        for candidate in candidates {
            objc_setAssociatedObject(candidate, &focusHandlerKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        guard wantsFocus, candidates.count > 1 || uiView.isAccessibilityElement else { return }
        wantsFocus = false
        let element = candidates.count > 1 ? candidates[1] : uiView
        DispatchQueue.main.async { UIAccessibility.post(notification: .layoutChanged, argument: element) }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }
    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }
}

extension View {
    public func accessibilityRepresentation<V: View>(@ViewBuilder representation: () -> V) -> some View {
        _ModifiedView(content: self, modifier: RepresentationModifier(representation: representation()))
    }
    public func accessibilityChildren<Content: View>(@ViewBuilder children: () -> Content) -> some View {
        _ModifiedView(content: self, modifier: AccessibilityChildrenModifier(children: children()))
    }
    public func accessibilitySortPriority(_ priority: Double) -> some View {
        applyingToViews { $0._accessibilitySortPriority = priority }
    }
    public func accessibilityFocused(_ binding: AccessibilityFocusState<Bool>.Binding) -> some View {
        _ModifiedView(content: self, modifier: AccessibilityFocusModifier(isFocused: { binding.wrappedValue },
                                                                          focusChanged: { binding.wrappedValue = $0 }))
    }
    public func accessibilityFocused<Value: Hashable>(_ binding: AccessibilityFocusState<Value>.Binding, equals value: Value) -> some View {
        _ModifiedView(content: self, modifier: AccessibilityFocusModifier(isFocused: { binding.wrappedValue == value }, focusChanged: { focused in
            if focused { binding.wrappedValue = value } else if binding.wrappedValue == value, let cleared = (Value.self as? _OptionalLike.Type)?._none as? Value { binding.wrappedValue = cleared }
        }))
    }
}

protocol _OptionalLike { static var _none: Self { get } }
extension Optional: _OptionalLike { static var _none: Self { nil } }
