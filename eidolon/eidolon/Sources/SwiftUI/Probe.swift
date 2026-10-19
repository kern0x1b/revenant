import UIKit
import CoreGraphics
import CoreImage

@_spi(Probe) public final class _Probe {
    let host: _HostingViewController
    public init(_ view: any View, width: CGFloat, height: CGFloat) {
        host = _HostingViewController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
    public func flush() {
        Updates.flush()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
    public var bodyEvaluations: Int {
        var total = 0
        func walk(_ n: Node) {
            if let c = n as? CompositeNode {
                total += c.bodyCount
                if let child = c.child { walk(child) }
            }
            if let g = n as? GroupNode { g.children.forEach(walk) }
            if let c = n as? ContainerNode, let content = c.content { walk(content) }
            if let e = n as? EnvironmentNode, let child = e.child { walk(child) }
            if let a = n as? AppearNode, let child = a.child { walk(child) }
            if let l = n as? ListNode {
                if let content = l.content { walk(content) }
            }
        }
        if let r = host.root { walk(r) }
        return total
    }
    public var hostView: UIView { host.view }
    public static var measurements: (computed: Int, cached: Int) { (LayoutCounters.misses, LayoutCounters.hits) }
    public static var phaseSeconds: (render: Double, mount: Double, layout: Double) {
        (LayoutCounters.renderTime, LayoutCounters.mountTime, LayoutCounters.layoutTime)
    }

    public var navigationDepth: Int {
        var found: UINavigationController?
        func walk(_ c: UIViewController) {
            if let n = c as? UINavigationController { found = found ?? n }
            c.children.forEach(walk)
        }
        walk(host)
        return found?.viewControllers.count ?? 0
    }

    public enum GestureEvent {
        case tap(CGPoint)
        case pressDown, pressRecognized, pressUp
        case drag(CGSize, ended: Bool)
        case pinch(CGFloat, ended: Bool)
        case rotate(Double, ended: Bool)
    }

    var gestureNodes: [GestureNode] {
        var found: [GestureNode] = []
        func walk(_ n: Node) {
            if let g = n as? GestureNode { found.append(g) }
            n.disposableChildren.forEach(walk)
        }
        if let r = host.root { walk(r) }
        return found
    }

    public var gestureCount: Int { gestureNodes.count }

    // The animations of shapes and effects are driven by a display link; a test drives them with a clock of its own.
    // The fallback that finds a view's fields by Mirror, checked against the runtime's own reflection on the same value.
    public static func useMirrorReflection(_ on: Bool) {
#if !REV_NO_FIELD_REFLECTION
        FieldReflection.forceMirror = on
#endif
    }

    public static func mirrorReflectionAgrees<V: View>(_ view: V) -> Bool {
#if REV_NO_FIELD_REFLECTION
        return true
#else
        let fast = runtimeFields(V.self), slow = FieldReflection.mirrorFields(view, of: V.self)
        return fast.count == slow.count && zip(fast, slow).allSatisfy { $0.offset == $1.offset && $0.type == $1.type }
#endif
    }

    public static func observationTracking(_ on: Bool) {
#if !REV_NO_FIELD_REFLECTION
        CompositeNode.tracksObservation = on
#endif
    }

    // What the table's delegate answers for a row's swipe, as the backports would ask it.
    public func swipeConfiguration(row: Int, leading: Bool) -> AnyObject? {
        var table: UITableView?
        func walk(_ v: UIView) { if table == nil, let t = v as? UITableView { table = t }; v.subviews.forEach(walk) }
        walk(hostView)
        guard let table, let delegate = table.delegate as? NSObject else { return nil }
        let selector = NSSelectorFromString(leading ? "tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:"
                                                    : "tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:")
        guard delegate.responds(to: selector) else { return nil }
        return delegate.perform(selector, with: table, with: IndexPath(row: row, section: 0) as NSIndexPath)?.takeUnretainedValue()
    }

    // Where the hand-over of swipe actions stands, for a phone: are the classes there, and do they answer the factory selectors.
    public static func swipeBridgeState() -> String {
        let action = NSClassFromString("UIContextualAction") as? NSObject.Type
        let configuration = NSClassFromString("UISwipeActionsConfiguration") as? NSObject.Type
        let makeAction = NSSelectorFromString("contextualActionWithStyle:title:handler:")
        let makeConfiguration = NSSelectorFromString("configurationWithActions:")
        var image = "?"
        var info = Dl_info()
        if let method = class_getInstanceMethod(UITableView.self, NSSelectorFromString("setDelegate:")),
           dladdr(unsafeBitCast(method_getImplementation(method), to: UnsafeRawPointer.self), &info) != 0, let name = info.dli_fname {
            image = String(cString: name)
        }
        let installer = objc_getClass("CharonSwipeInstaller") != nil
        let installs = UITableView.instancesRespond(to: NSSelectorFromString("charon_installSwipeActions"))
        return "installerClass=\(installer) tableInstallMethod=\(installs) setDelegateIn=\(image) "
            + "available=\(SwipeActionsBridge.available) action=\(action != nil) configuration=\(configuration != nil) "
            + "controllerResponds=\(ListController.instancesRespond(to: NSSelectorFromString("tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:"))) queries=\(ListController.swipeQueries) "
            + "makeAction=\(action?.responds(to: makeAction) ?? false) makeConfiguration=\(configuration?.responds(to: makeConfiguration) ?? false)"
    }

    // The recognisers on every table in a window, for a phone: does the swipe facade of the backports show among them?
    public static func tableRecognizers(in root: UIView) -> String {
        var found: [String] = []
        func walk(_ v: UIView) {
            if let table = v as? UITableView {
                found.append((table.gestureRecognizers ?? []).map { "\(type(of: $0))(delegate \($0.delegate.map { String(describing: type(of: $0)) } ?? "nil"))" }.joined(separator: ","))
            }
            v.subviews.forEach(walk)
        }
        walk(root)
        return found.joined(separator: " | ")
    }

    public static func useVirtualClock() {
        ValueAnimator.manual = true
        ValueAnimator.clock = { 0 }
    }

    public static func advanceAnimations(to seconds: Double) {
        ValueAnimator.clock = { seconds }
        ValueAnimator.tickAll()
    }

    public static var runningAnimations: Int { ValueAnimator.active.count }

    // What the recognisers would deliver, so a test can drive a gesture without a finger.
    public func send(_ event: GestureEvent, toGesture index: Int = 0) {
        let nodes = gestureNodes
        guard index < nodes.count else { return }
        let raw: RawGestureEvent
        switch event {
        case .tap(let point): raw = .tap(point)
        case .pressDown: raw = .pressDown
        case .pressRecognized: raw = .pressRecognized
        case .pressUp: raw = .pressUp
        case .drag(let translation, let ended):
            let start = CGPoint(x: 50, y: 50)
            let location = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
            raw = .drag(DragGesture.Value(time: Date(), location: location, startLocation: start, translation: translation,
                                          velocity: .zero, predictedEndLocation: location, predictedEndTranslation: translation),
                        ended ? .ended : .changed)
        case .pinch(let scale, let ended): raw = .pinch(scale, ended ? .ended : .changed)
        case .rotate(let radians, let ended): raw = .rotate(Angle(radians: radians), ended ? .ended : .changed)
        }
        nodes[index].target.inject(raw)
    }

    public func gestureAccepts(_ point: CGPoint) -> Bool {
        var found: GestureNode?
        func walk(_ n: Node) {
            if let g = n as? GestureNode { found = found ?? g; return }
            n.disposableChildren.forEach(walk)
        }
        if let r = host.root { walk(r) }
        guard let gesture = found else { return false }
        return gesture.target.accepts(gesture.uiView.convert(point, from: host.view))
    }

    var listNode: ListNode? {
        var found: ListNode?
        func walk(_ n: Node) {
            if let l = n as? ListNode { found = found ?? l }
            if let c = n as? CompositeNode, let child = c.child { walk(child) }
            if let g = n as? GroupNode { g.children.forEach(walk) }
            if let c = n as? ContainerNode, let content = c.content { walk(content) }
            if let e = n as? EnvironmentNode, let child = e.child { walk(child) }
            if let a = n as? AppearNode, let child = a.child { walk(child) }
        }
        if let r = host.root { walk(r) }
        return found
    }

    public func isHidden(_ index: Int) -> Bool {
        var found: [UIView] = []
        func walk(_ v: UIView) {
            if v.subviews.isEmpty { found.append(v) } else { v.subviews.forEach(walk) }
        }
        host.view.subviews.forEach(walk)
        guard index < found.count else { return false }
        var view: UIView? = found[index]
        while let current = view {
            if current.isHidden { return true }
            view = current.superview
        }
        return false
    }

    public var rowCount: Int { listNode?.rows.count ?? 0 }
    public var sectionCount: Int { listNode?.sections.count ?? 0 }
    public var sectionTitles: [String] { listNode?.sections.map { $0.title ?? "" } ?? [] }
    public var rowCounts: [Int] { listNode?.sections.map { $0.rows.count } ?? [] }

    public var scrollContentHeight: CGFloat {
        var found: CGFloat = 0
        func walk(_ v: UIView) {
            if let scroller = v as? UIScrollView, found == 0 { found = scroller.contentSize.height }
            v.subviews.forEach(walk)
        }
        walk(host.view)
        return found
    }

    public func rowHeight(_ index: Int) -> CGFloat {
        guard let list = listNode, index < list.rows.count else { return 0 }
        let table = list.uiView as! UITableView
        return table.delegate!.tableView!(table, heightForRowAt: IndexPath(row: index, section: 0))
    }

    public func rowEditing(_ index: Int) -> (delete: Bool, move: Bool, title: String?) {
        guard let list = listNode, index < list.rows.count else { return (false, false, nil) }
        let table = list.uiView as! UITableView
        let path = IndexPath(row: index, section: 0)
        let controller = list.controller
        return (controller.tableView(table, editingStyleForRowAt: path) == .delete,
                controller.tableView(table, canMoveRowAt: path),
                controller.tableView(table, titleForDeleteConfirmationButtonForRowAt: path))
    }

    public func commitDelete(_ index: Int) {
        guard let list = listNode else { return }
        let table = list.uiView as! UITableView
        list.controller.tableView(table, commit: .delete, forRowAt: IndexPath(row: index, section: 0))
    }

    public static func openURL(_ url: URL) -> Bool { OpenURLHandlers.deliver(url) }
    public static func text(_ key: LocalizedStringKey) -> String { key.text }

    public func rowBadge(_ index: Int) -> String? {
        guard let list = listNode, index < list.rows.count else { return nil }
        return list.rows[index].traits.badge
    }

    // What stands between a row and the row below it: the table's own hairline, or the line the row draws over it - and
    // what colour that line is.
    public func rowSeparator(_ index: Int) -> (rowLine: Bool, coversTheTables: Bool, colour: UIColor?) {
        guard let list = listNode, let table = list.uiView as? UITableView, index < list.rows.count else { return (false, false, nil) }
        let row = list.rows[index]
        _ = table.dataSource!.tableView(table, cellForRowAt: IndexPath(row: index, section: 0))
        guard let cell = row.cell, let line = row.separatorLine, line.superview === cell else { return (false, false, nil) }
        // what is behind the line, read from the cell itself rather than from the row's traits: a check that asks the same
        // expression the implementation uses proves nothing
        let behind = cell.backgroundColor ?? table.backgroundColor
        return (true, line.backgroundColor?.isEqual(behind) ?? false, line.backgroundColor)
    }

    // The size a text is drawn at under a size category, as the screen works it out: what a font modifier and a category
    // between them add up to. The headless tests cannot draw text, so this is where the size itself is read.
    // What the screen drew of a filtered view: the pixel at a point of the picture the filter produced. The headless tests
    // cannot draw text but they can read a picture, so this is where a colour filter is checked.
    public func filteredPicture(_ index: Int = 0) -> UIImage? {
        var pictures: [UIImage] = []
        func walk(_ v: UIView) {
            if let image = v as? UIImageView, let picture = image.image { pictures.append(picture) }
            v.subviews.forEach(walk)
        }
        walk(host.view)
        return pictures.indices.contains(index) ? pictures[index] : nil
    }

    public func filteredPixel(_ index: Int = 0, at point: CGPoint? = nil) -> (r: Int, g: Int, b: Int, a: Int)? {
        guard let cgImage = filteredPicture(index)?.cgImage else { return nil }
        let at = point ?? CGPoint(x: cgImage.width / 2, y: cgImage.height / 2)
        guard let cropped = cgImage.cropping(to: CGRect(x: at.x, y: at.y, width: 1, height: 1)) else { return nil }
        var bytes = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]), Int(bytes[3]))
    }

    // What stands under a point of the screen, for a picture that lies over the content: the touches must still reach it.
    public func hitViewName(at point: CGPoint) -> String? {
        let hit = host.view.hitTest(point, with: nil)
        return hit.map { "\(type(of: $0))" }
    }

    // Which of the two spellings of a Core Image context this release answers: Swift gives +[CIContext
    // contextWithOptions:] and -[CIContext initWithOptions:] the same name, and only one of them is in iOS 6's Core Image.
    public static func coreImageContextSpellings() -> String {
        let classFactory = (CIContext.self as AnyObject).responds(to: NSSelectorFromString("contextWithOptions:"))
        let instanceInit = CIContext.instancesRespond(to: NSSelectorFromString("initWithOptions:"))
        let plainInit = CIContext.instancesRespond(to: NSSelectorFromString("init"))
        return "class factory \(classFactory), initWithOptions \(instanceInit), init \(plainInit)"
    }

    // Which of the Core Image filters these modifiers are built on this release has.
    // What each render of a filtered view was given and what came out of it, for a device where the picture has to be
    // looked at rather than only measured.
    public static nonisolated(unsafe) var tracesFilterRenders = false
    public static nonisolated(unsafe) var filterRenders = 0
    static func tracedFilterRender(_ line: String) {
        guard tracesFilterRenders else { return }
        filterRenders += 1
        fputs("[probe] filter \(line)\n", stderr)
    }

    public static func coreImageFilters() -> [String] {
        let wanted = ["CIColorControls", "CIColorMatrix", "CIColorInvert", "CILuminanceToAlpha", "CIHueRotate", "CIGaussianBlur"]
        return wanted.filter { CIFilter(name: $0) != nil }
    }

    // The colour a row's cell is painted in, as the table itself would answer for it.
    public func rowCellColour(_ index: Int) -> UIColor? {
        guard let list = listNode, let table = list.uiView as? UITableView, index < list.rows.count else { return nil }
        let cell = table.dataSource!.tableView(table, cellForRowAt: IndexPath(row: index, section: 0))
        return cell.backgroundColor ?? table.backgroundColor
    }

    // Which of these classes this release has, and which of these selectors one of its classes answers: the reason a
    // modifier is declared absent has to be a measurement, so a test can name what it measured and the answer stays pinned.
    public static func releaseClasses(_ names: [String]) -> [String] { names.filter { NSClassFromString($0) != nil } }
    public static func releaseAnswers(_ selectors: [String], on className: String) -> [String] {
        guard let cls = NSClassFromString(className) as? NSObject.Type else { return [] }
        return selectors.filter { cls.instancesRespond(to: NSSelectorFromString($0)) }
    }

    // The menu a long press put up, and what each of its items does: the release's own action sheet, read by title.
    public static var shownMenu: [String] { ContextMenuKeeper.shown }
    public static func pressMenuItem(_ index: Int) {
        let actions = ContextMenuKeeper.shared.delegate.actions
        if index >= 0 && index < actions.count { actions[index]() }
    }

    // What a blocking .submitScope does to the return key of a field of several lines. The editor itself cannot be
    // built in the headless process - a UITextView sets a font, and a font traps it - so the question is put to the
    // delegate's own decision, and the scope a screen sets is read from the environment a view of that screen sees.
    // What a payload is copied as, as the copy does it: the pasteboard of a session that has none is not the question.
    public static func copiedText(_ payload: [String]) -> String { pasteboardText(payload) }

    public static func returnKeyBlocked(_ text: String, blocking: Bool) -> Bool {
        TextEditorDelegate.blocked(text, blocking: blocking)
    }

    // What the share sheet of the release would be given for a payload: its items, and what they are.
    public static func sharedItems<T>(_ payload: [T]) -> [String] {
        activityItems(payload).map { item in
            if let url = item as? URL { return url.absoluteString }
            if let image = item as? UIImage { return "image \(image.size.width)x\(image.size.height)" }
            return "\(item)"
        }
    }

    // The background of a screen this one presented, which is what .presentationBackground paints it in. The screen is
    // the one the engine put up, read from its own node: a sheet presented with no window to present it in is not the
    // host's presentedViewController, and the engine knows of it either way.
    public var presentedBackground: UIColor? {
        var found: SheetNode?
        func look(_ n: Node) {
            if let sheet = n as? SheetNode, found == nil { found = sheet }
            n.disposableChildren.forEach(look)
        }
        if let root = host.root { look(root) }
        return found?.presented?.view?.backgroundColor
    }

    // Whether CoreAnimation of this release lays a compositing filter over a layer as it draws. The layer is red and the
    // background behind it black, so a filter that mixes the two changes the pixel and a filter that is not applied leaves
    // it red: the answer is the picture and not the setting.
    public static func compositingFilterPaints(_ name: String) -> String {
        guard let filter = CIFilter(name: name) else { return "absent" }
        let size = CGSize(width: 4, height: 4)
        var red = [UInt8](repeating: 0, count: 4)
        red[0] = 255; red[3] = 255
        let space = CGColorSpaceCreateDeviceRGB()
        guard let source = CGContext(data: &red, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                     space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage() else { return "no image" }
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        layer.contents = source
        layer.backgroundColor = UIColor.black.cgColor
        filter.setValue(CIImage(image: UIImage(cgImage: source)), forKey: "inputImage")
        layer.compositingFilter = filter
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cg = out?.cgImage, let cropped = cg.cropping(to: CGRect(x: 1, y: 1, width: 1, height: 1)) else { return "no picture" }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let read = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                   space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return "no read" }
        read.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return "\(name): \(pixel[0]),\(pixel[1]),\(pixel[2])"
    }

    // What a .submitScope set for the views inside it: the environment key is internal state, an app has no business
    // reading it, and a text editor cannot be built in the headless process at all (a UITextView sets a font, and a font
    // traps it), so the node the scope made is what a test asks.
    public static func submitScopeSet<V: View>(_ view: V, width: CGFloat = 60, height: CGFloat = 60) -> Bool {
        let probe = _Probe(view, width: width, height: height)
        var found: Bool?
        func look(_ node: Node) {
            if found == nil, node.env.submitBlocksReturn { found = true }
            node.disposableChildren.forEach(look)
        }
        if let root = probe.host.root { look(root) }
        return found ?? false
    }

    // The label the engine drew for a view that carries an attributed string: where the attributes of a SwiftUI text are
    // observed, on the string the screen actually drew.
    public func drawnLabel() -> UILabel? {
        var found: UILabel?
        func walk(_ v: UIView) {
            if let label = v as? UILabel, found == nil, label.attributedText != nil { found = label }
            v.subviews.forEach(walk)
        }
        walk(host.view)
        return found
    }

    /// The value under a key of the string the screen drew, for the key an attribute's name is (nil when this release
    /// has no such key, which is the answer for the attributes it cannot carry).
    public func drawnAttribute(_ name: String) -> Any? {
        guard let key = AttributeScopes.SwiftUIAttributes.key(of: name), let text = drawnLabel()?.attributedText else { return nil }
        return (text.attributes(at: 0, effectiveRange: nil) as NSDictionary)[key] as Any
    }

    public static func textSize(_ size: CGFloat, _ typeSize: DynamicTypeSize, _ range: ClosedRange<DynamicTypeSize>? = nil) -> CGFloat {
        var environment = EnvironmentValues()
        environment.sizeCategory = ContentSizeCategory(typeSize)
        environment.dynamicTypeSizeRange = range
        return environment.scaledSize(size)
    }

    public func selectRow(_ index: Int) {
        guard let list = listNode else {
            var table: UITableView?
            func walk(_ v: UIView) { if let t = v as? UITableView { table = table ?? t }; v.subviews.forEach(walk) }
            walk(host.view)
            if let table { table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: index, section: 0)) }
            return
        }
        let table = list.uiView as! UITableView
        var remaining = index
        for (section, group) in list.sections.enumerated() {
            if remaining < group.rows.count {
                list.controller.tableView(table, didSelectRowAt: IndexPath(row: remaining, section: section))
                return
            }
            remaining -= group.rows.count
        }
    }

    public var tableBackgroundCleared: Bool {
        guard let table = listNode?.uiView as? UITableView else { return false }
        return table.backgroundView == nil && table.backgroundColor == .clear
    }

    public func dump() -> String {
        var lines: [String] = []
        func walk(_ v: UIView, _ depth: Int) {
            var f = v.frame
            // The wheel of a picker is a table of a hundred thousand rows, and UIKit scrolls it to the revolution nearest to the
            // clock (the same date puts a row 12 rows further down when it is read at another hour, and a month wheel does the
            // same with the month), so a row is printed where it is in the window the wheel shows, not at its offset in the table,
            // and the rows of a wheel are listed from the bottom of the window up (see below), not in the order they were made in.
            if let table = v.superview as? UITableView, NSStringFromClass(type(of: v)) == "UIPickerTableViewWrapperCell" {
                f.origin.y -= table.contentOffset.y
            }
            var extra = ""
            if let l = v as? UILabel { extra = " \"\(l.text ?? "")\"" }
            if let b = v as? UIButton { extra = " button \"\(b.title(for: .normal) ?? "")\"" }
            if let s = v as? UISwitch { extra = " switch on=\(s.isOn)" }
            if let t = v as? UITextField { extra = " field \"\(t.text ?? "")\" placeholder=\"\(t.placeholder ?? "")\"" }
            if let t = v as? UITableView {
                var parts: [String] = []
                for section in 0..<t.numberOfSections {
                    let title = t.dataSource?.tableView?(t, titleForHeaderInSection: section) ?? ""
                    parts.append("\(title.isEmpty ? "-" : title):\(t.numberOfRows(inSection: section))")
                }
                extra = " table sections=[\(parts.joined(separator: " "))]"
            }
            lines.append(String(repeating: "  ", count: depth) + "\(type(of: v)) (\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.size.width)),\(Int(f.size.height)))\(extra)")
            var subviews = v.subviews
            if NSStringFromClass(type(of: v)) == "UIPickerTableView" {
                // the order the rows were made in is the history of the scrolling: the rows go from the bottom of the window up, the rest as it was
                let rows = subviews.filter { NSStringFromClass(type(of: $0)) == "UIPickerTableViewWrapperCell" }
                subviews = rows.sorted { $0.frame.origin.y > $1.frame.origin.y } + subviews.filter { !rows.contains($0) }
            }
            for sub in subviews { walk(sub, depth + 1) }
        }
        walk(host.view, 0)
        return lines.joined(separator: "\n")
    }
    public func texts() -> [String] {
        var out: [String] = []
        func walk(_ v: UIView) {
            if let l = v as? UILabel, let t = l.text, !t.isEmpty { out.append(t) }
            if let b = v as? UIButton, let t = b.title(for: .normal), !t.isEmpty { out.append("[\(t)]") }
            for sub in v.subviews { walk(sub) }
        }
        walk(host.view)
        return out
    }
    public func cellTexts() -> [String] {
        var out: [String] = []
        func walk(_ v: UIView) {
            if let table = v as? UITableView {
                for row in 0..<table.numberOfRows(inSection: 0) {
                    let cell = table.dataSource!.tableView(table, cellForRowAt: IndexPath(row: row, section: 0))
                    var texts: [String] = []
                    func inner(_ x: UIView) {
                        if let l = x as? UILabel, let t = l.text, !t.isEmpty { texts.append(t) }
                        if let b = x as? UIButton, let t = b.title(for: .normal), !t.isEmpty { texts.append("[\(t)]") }
                        if let s = x as? UISwitch { texts.append("switch=\(s.isOn)") }
                        x.subviews.forEach(inner)
                    }
                    inner(cell)
                    out.append("row \(row) h=\(Int(table.delegate!.tableView!(table, heightForRowAt: IndexPath(row: row, section: 0)))): " + texts.joined(separator: " | "))
                }
            }
            for sub in v.subviews { walk(sub) }
        }
        walk(host.view)
        return out
    }
}

public func _flushTransactions() { Updates.flush() }
