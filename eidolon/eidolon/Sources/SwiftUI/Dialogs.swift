import UIKit
import CoreGraphics

struct DialogButton {
    var title: String
    var role: ButtonRole?
    var action: () -> Void
}

struct DialogSpec {
    var title: String
    var message: String?
    var buttons: [DialogButton]
}

// The buttons of a builder of actions, in the order they were written, with their roles.
func dialogButtons(_ view: any View) -> [DialogButton] {
    var found: [DialogButton] = []
    func walk(_ value: any View) {
        if let button = value as? ButtonLike {
            found.append(DialogButton(title: findText(button.buttonLabel)?.content ?? "", role: (value as? RoleButtonLike)?.buttonRole, action: button.buttonAction))
            return
        }
        if let group = value as? GroupView { group.childViews.forEach(walk) }
        if let modified = value as? ModifiedViewLike { walk(modified.modifiedContent) }
        if let wrapper = value as? WrappedView { walk(wrapper.wrapped) }
    }
    walk(view)
    return found
}

// All the text of a view, one line for each Text: the message of a dialog is a view but is drawn as plain text.
func dialogText(_ view: any View) -> String? {
    var lines: [String] = []
    func walk(_ value: any View) {
        if let text = value as? Text { lines.append(text.content); return }
        if let group = value as? GroupView { group.childViews.forEach(walk) }
        if let modified = value as? ModifiedViewLike { walk(modified.modifiedContent) }
        if let wrapper = value as? WrappedView { walk(wrapper.wrapped) }
    }
    walk(view)
    let text = lines.filter { !$0.isEmpty }.joined(separator: "\n")
    return text.isEmpty ? nil : text
}

enum DialogStyle { case alert, actionSheet }

struct DialogModifier: NodeModifier {
    let isPresented: Binding<Bool>
    let style: DialogStyle
    let spec: () -> DialogSpec?
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { DialogNode() }
}

// What a dialog looks like once it is shown, for a test that has no window to show it in.
@_spi(Probe) public struct _DialogDescription: Equatable {
    public var title: String
    public var message: String?
    public var buttons: [String]
    public var roles: [String]
    public var isAlert: Bool
    public var cancelIndex: Int?
    public var destructiveIndex: Int?
}

final class DialogNode: Node {
    nonisolated(unsafe) static var capture = false
    nonisolated(unsafe) static var captured: [DialogNode] = []

    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    let alertDelegate = AlertDelegate()
    let sheetDelegate = SheetDelegate()
    var alertShown: UIAlertView?
    var sheetShown: UIActionSheet?
    var described: _DialogDescription?
    var pressed: [() -> Void] = []
    var binding: Binding<Bool>?
    override var flattened: [LayoutNode] { child?.flattened ?? [] }

    var isShown: Bool { alertShown != nil || sheetShown != nil || described != nil }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! DialogModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        binding = modifier.isPresented
        if modifier.isPresented.wrappedValue && !isShown {
            guard let spec = modifier.spec() else { return }
            present(spec, style: modifier.style, host: env.host, binding: modifier.isPresented)
        } else if !modifier.isPresented.wrappedValue && isShown {
            dismiss()
        }
    }

    func present(_ spec: DialogSpec, style: DialogStyle, host: UIViewController?, binding: Binding<Bool>) {
        var buttons = spec.buttons
        if style == .alert {
            if buttons.isEmpty { buttons = [DialogButton(title: "OK", role: nil, action: {})] }
            // The cancel button goes first, which is where iOS 6 draws it beside another button.
            if let cancel = buttons.firstIndex(where: { $0.role == .cancel }), cancel != 0 {
                buttons.insert(buttons.remove(at: cancel), at: 0)
            }
            if buttons.contains(where: { $0.role == .destructive }) {
                _Unsupported.note("Button(role: .destructive) in an alert", "UIAlertView of iOS 6 has no destructive button style; the button looks like the others")
            }
        } else if !buttons.contains(where: { $0.role == .cancel }) {
            buttons.append(DialogButton(title: "Cancel", role: .cancel, action: {}))
        }
        let cancelIndex = buttons.firstIndex { $0.role == .cancel }
        let destructiveIndex = buttons.firstIndex { $0.role == .destructive }
        pressed = buttons.map(\.action)
        let finish: () -> Void = { [weak self] in
            self?.alertShown = nil
            self?.sheetShown = nil
            self?.described = nil
            binding.wrappedValue = false
        }
        if DialogNode.capture {
            described = _DialogDescription(title: spec.title, message: spec.message, buttons: buttons.map(\.title),
                                           roles: buttons.map { $0.role == .cancel ? "cancel" : $0.role == .destructive ? "destructive" : "default" },
                                           isAlert: style == .alert, cancelIndex: cancelIndex, destructiveIndex: destructiveIndex)
            alertDelegate.dismissed = finish
            DialogNode.captured.append(self)
            return
        }
        switch style {
        case .alert:
            alertDelegate.actions = pressed
            alertDelegate.dismissed = finish
            let alert = UIAlertView()
            alert.title = spec.title
            alert.message = spec.message
            alert.delegate = alertDelegate
            for button in buttons { alert.addButton(withTitle: button.title) }
            if let cancelIndex { alert.cancelButtonIndex = cancelIndex }
            alertShown = alert
            alert.show()
        case .actionSheet:
            guard let host else { return }
            sheetDelegate.actions = pressed
            sheetDelegate.dismissed = finish
            let sheet = UIActionSheet()
            sheet.title = [spec.title, spec.message].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            sheet.delegate = sheetDelegate
            for button in buttons { sheet.addButton(withTitle: button.title) }
            if let destructiveIndex { sheet.destructiveButtonIndex = destructiveIndex }
            if let cancelIndex { sheet.cancelButtonIndex = cancelIndex }
            sheetShown = sheet
            sheet.show(in: host.view)
        }
    }

    func dismiss() {
        if let alert = alertShown {
            alertShown = nil
            alert.dismiss(withClickedButtonIndex: alert.cancelButtonIndex, animated: true)
        }
        if let sheet = sheetShown {
            sheetShown = nil
            sheet.dismiss(withClickedButtonIndex: sheet.cancelButtonIndex, animated: true)
        }
        described = nil
    }

    // A test taps a button of a dialog that was captured.
    func press(_ index: Int) {
        guard index >= 0, index < pressed.count else { return }
        pressed[index]()
        alertDelegate.dismissed()
    }

    override func dispose() {
        dismiss()
        DialogNode.captured.removeAll { $0 === self }
        super.dispose()
    }

    override func mountContents() { child?.mount() }
}

extension _Probe {
    public static func captureDialogs(_ on: Bool) {
        DialogNode.capture = on
        DialogNode.captured = []
    }

    public static var shownDialog: _DialogDescription? { DialogNode.captured.last(where: { $0.described != nil })?.described }

    public static func pressDialogButton(_ index: Int) {
        DialogNode.captured.last(where: { $0.described != nil })?.press(index)
    }
}

// MARK: alerts

extension Alert.Button {
    var dialogButton: DialogButton {
        DialogButton(title: label, role: destructive ? .destructive : (cancel ? .cancel : nil), action: action)
    }
}

func alertSpec(_ alert: Alert) -> DialogSpec {
    DialogSpec(title: alert.title, message: alert.message, buttons: ([alert.primary] + (alert.secondary.map { [$0] } ?? [])).map(\.dialogButton))
}

func sheetSpec(_ sheet: ActionSheet) -> DialogSpec {
    DialogSpec(title: sheet.title, message: sheet.message, buttons: sheet.buttons.map(\.dialogButton))
}

extension View {
    func dialog(_ style: DialogStyle, isPresented: Binding<Bool>, spec: @escaping () -> DialogSpec?) -> some View {
        _ModifiedView(content: self, modifier: DialogModifier(isPresented: isPresented, style: style, spec: spec))
    }

    func itemBinding<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }

    public func alert(isPresented: Binding<Bool>, content: @escaping () -> Alert) -> some View {
        dialog(.alert, isPresented: isPresented) { alertSpec(content()) }
    }

    public func alert<Item: Identifiable>(item: Binding<Item?>, content: @escaping (Item) -> Alert) -> some View {
        dialog(.alert, isPresented: itemBinding(item)) { item.wrappedValue.map { alertSpec(content($0)) } }
    }

    public func actionSheet(isPresented: Binding<Bool>, content: @escaping () -> ActionSheet) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { sheetSpec(content()) }
    }

    public func actionSheet<Item: Identifiable>(item: Binding<Item?>, content: @escaping (Item) -> ActionSheet) -> some View {
        dialog(.actionSheet, isPresented: itemBinding(item)) { item.wrappedValue.map { sheetSpec(content($0)) } }
    }

    // The title of an alert or a dialog can be given as a key, a string or a Text.
    public func alert<A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A) -> some View {
        dialog(.alert, isPresented: isPresented) { DialogSpec(title: titleKey.text, message: nil, buttons: dialogButtons(actions())) }
    }
    public func alert<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A) -> some View {
        dialog(.alert, isPresented: isPresented) { DialogSpec(title: String(title), message: nil, buttons: dialogButtons(actions())) }
    }
    public func alert<A: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A) -> some View {
        dialog(.alert, isPresented: isPresented) { DialogSpec(title: title.content, message: nil, buttons: dialogButtons(actions())) }
    }

    public func alert<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A, @ViewBuilder message: @escaping () -> M) -> some View {
        dialog(.alert, isPresented: isPresented) { DialogSpec(title: titleKey.text, message: dialogText(message()), buttons: dialogButtons(actions())) }
    }
    public func alert<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A, @ViewBuilder message: @escaping () -> M) -> some View {
        dialog(.alert, isPresented: isPresented) { DialogSpec(title: String(title), message: dialogText(message()), buttons: dialogButtons(actions())) }
    }
    public func alert<A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A, @ViewBuilder message: @escaping () -> M) -> some View {
        dialog(.alert, isPresented: isPresented) { DialogSpec(title: title.content, message: dialogText(message()), buttons: dialogButtons(actions())) }
    }

    public func alert<T, A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A) -> some View {
        dialog(.alert, isPresented: isPresented) { data.map { DialogSpec(title: titleKey.text, message: nil, buttons: dialogButtons(actions($0))) } }
    }
    public func alert<S: StringProtocol, T, A: View>(_ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A) -> some View {
        dialog(.alert, isPresented: isPresented) { data.map { DialogSpec(title: String(title), message: nil, buttons: dialogButtons(actions($0))) } }
    }
    public func alert<T, A: View>(_ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A) -> some View {
        dialog(.alert, isPresented: isPresented) { data.map { DialogSpec(title: title.content, message: nil, buttons: dialogButtons(actions($0))) } }
    }

    public func alert<T, A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A, @ViewBuilder message: @escaping (T) -> M) -> some View {
        dialog(.alert, isPresented: isPresented) { data.map { DialogSpec(title: titleKey.text, message: dialogText(message($0)), buttons: dialogButtons(actions($0))) } }
    }
    public func alert<S: StringProtocol, T, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A, @ViewBuilder message: @escaping (T) -> M) -> some View {
        dialog(.alert, isPresented: isPresented) { data.map { DialogSpec(title: String(title), message: dialogText(message($0)), buttons: dialogButtons(actions($0))) } }
    }
    public func alert<T, A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A, @ViewBuilder message: @escaping (T) -> M) -> some View {
        dialog(.alert, isPresented: isPresented) { data.map { DialogSpec(title: title.content, message: dialogText(message($0)), buttons: dialogButtons(actions($0))) } }
    }

    public func alert<E: LocalizedError, A: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: @escaping () -> A) -> some View {
        dialog(.alert, isPresented: isPresented) { error.map { DialogSpec(title: $0.errorDescription ?? "", message: nil, buttons: dialogButtons(actions())) } }
    }
    public func alert<E: LocalizedError, A: View, M: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: @escaping (E) -> A, @ViewBuilder message: @escaping (E) -> M) -> some View {
        dialog(.alert, isPresented: isPresented) { error.map { DialogSpec(title: $0.errorDescription ?? "", message: dialogText(message($0)), buttons: dialogButtons(actions($0))) } }
    }

    // MARK: confirmation dialogs

    func confirmation(_ title: String, _ visibility: Visibility, _ message: String?, _ buttons: [DialogButton]) -> DialogSpec {
        DialogSpec(title: visibility == .visible ? title : "", message: message, buttons: buttons)
    }

    public func confirmationDialog<A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { confirmation(titleKey.text, titleVisibility, nil, dialogButtons(actions())) }
    }
    public func confirmationDialog<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { confirmation(String(title), titleVisibility, nil, dialogButtons(actions())) }
    }
    public func confirmationDialog<A: View>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { confirmation(title.content, titleVisibility, nil, dialogButtons(actions())) }
    }

    public func confirmationDialog<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A, @ViewBuilder message: @escaping () -> M) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { confirmation(titleKey.text, titleVisibility, dialogText(message()), dialogButtons(actions())) }
    }
    public func confirmationDialog<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A, @ViewBuilder message: @escaping () -> M) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { confirmation(String(title), titleVisibility, dialogText(message()), dialogButtons(actions())) }
    }
    public func confirmationDialog<A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A, @ViewBuilder message: @escaping () -> M) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { confirmation(title.content, titleVisibility, dialogText(message()), dialogButtons(actions())) }
    }

    public func confirmationDialog<T, A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { data.map { confirmation(titleKey.text, titleVisibility, nil, dialogButtons(actions($0))) } }
    }
    public func confirmationDialog<S: StringProtocol, T, A: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { data.map { confirmation(String(title), titleVisibility, nil, dialogButtons(actions($0))) } }
    }
    public func confirmationDialog<T, A: View>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { data.map { confirmation(title.content, titleVisibility, nil, dialogButtons(actions($0))) } }
    }

    public func confirmationDialog<T, A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A, @ViewBuilder message: @escaping (T) -> M) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { data.map { confirmation(titleKey.text, titleVisibility, dialogText(message($0)), dialogButtons(actions($0))) } }
    }
    public func confirmationDialog<S: StringProtocol, T, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A, @ViewBuilder message: @escaping (T) -> M) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { data.map { confirmation(String(title), titleVisibility, dialogText(message($0)), dialogButtons(actions($0))) } }
    }
    public func confirmationDialog<T, A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A, @ViewBuilder message: @escaping (T) -> M) -> some View {
        dialog(.actionSheet, isPresented: isPresented) { data.map { confirmation(title.content, titleVisibility, dialogText(message($0)), dialogButtons(actions($0))) } }
    }

    // MARK: presentations by item

    public func fullScreenCover<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item, onDismiss: onDismiss, content: content)
    }

    public func popover<Item: Identifiable, Content: View>(item: Binding<Item?>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item, content: content)
    }
}
