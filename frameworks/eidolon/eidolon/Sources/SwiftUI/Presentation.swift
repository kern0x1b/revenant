import UIKit
import CoreGraphics

// What a presented screen asked to be painted in, and the node that carries it: the modifier is applied inside the content
// of the sheet, so the sheet finds the value by the same walk a list finds the traits of a row by.
struct PresentationBackgroundModifier: NodeModifier {
    let color: UIColor?
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { PresentationBackgroundNode() }
}

final class PresentationBackgroundNode: Node {
    var child: Node?
    var color: UIColor?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        color = (m.modifierValue as! PresentationBackgroundModifier).color
        var inner = env
        inner.presentationBackground = color
        child = adopt(reconcile(child, m.modifiedContent, inner))
    }
    override func mountContents() { child?.mount() }
}

func presentationBackground(of node: Node?) -> UIColor? {
    var found: UIColor?
    func look(_ current: Node) {
        if found == nil, let asked = current as? PresentationBackgroundNode { found = asked.color }
        if found == nil {
            for child in current.disposableChildren { look(child) }
        }
    }
    if let node { look(node) }
    return found
}

struct SheetModifier: NodeModifier {
    let isPresented: Binding<Bool>
    let content: () -> any View
    var onDismiss: (() -> Void)? = nil
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { SheetNode() }
}

final class SheetNode: Node {
    var child: Node?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    var presented: _HostingViewController?
    override var flattened: [LayoutNode] { child?.flattened ?? [] }

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let sheet = m.modifierValue as! SheetModifier
        child = adopt(reconcile(child, m.modifiedContent, env))
        let wants = sheet.isPresented.wrappedValue
        if wants && presented == nil, let host = env.host {
            let controller = _HostingViewController(rootView: EmptyView())
            var inner = env
            let binding = sheet.isPresented
            inner.presentationMode = Binding(
                get: { PresentationMode(dismissAction: { binding.wrappedValue = false }, isPresented: true) },
                set: { _ in })
            controller.setRootView(sheet.content(), env: inner)
            presented = controller
            // The content of a sheet may ask for the background of the screen it is shown on. The content belongs to the
            // screen, so it is the screen's own tree that is asked, and the screen is asked for its view first so that the
            // content is in it: a sheet presented where there is no window to present it in is still the screen the
            // engine put up.
            let screen = controller.view
            if let background = presentationBackground(of: controller.root) { screen?.backgroundColor = background }
            host.present(controller, animated: true, completion: nil)
        } else if !wants, let controller = presented {
            presented = nil
            let done = sheet.onDismiss
            controller.dismiss(animated: true, completion: { done?() })
        } else if wants, let controller = presented {
            controller.setRootView(sheet.content(), env: env)
        }
    }

    override func mountContents() { child?.mount() }
}

public struct Alert {
    let title: String
    let message: String?
    let primary: Button
    let secondary: Button?

    public struct Button {
        let label: String
        let action: () -> Void
        let cancel: Bool
        var destructive = false
        public static func `default`(_ label: Text, action: (() -> Void)? = nil) -> Button {
            Button(label: label.content, action: action ?? {}, cancel: false)
        }
        public static func cancel(_ label: Text, action: (() -> Void)? = nil) -> Button {
            Button(label: label.content, action: action ?? {}, cancel: true)
        }
        public static func cancel(_ action: (() -> Void)? = nil) -> Button {
            Button(label: "Cancel", action: action ?? {}, cancel: true)
        }
        public static func destructive(_ label: Text, action: (() -> Void)? = nil) -> Button {
            Button(label: label.content, action: action ?? {}, cancel: false, destructive: true)
        }
    }

    public init(title: Text, message: Text? = nil, dismissButton: Button? = nil) {
        self.title = title.content
        self.message = message?.content
        primary = dismissButton ?? .cancel(Text("OK"))
        secondary = nil
    }

    public init(title: Text, message: Text? = nil, primaryButton: Button, secondaryButton: Button) {
        self.title = title.content
        self.message = message?.content
        primary = primaryButton
        secondary = secondaryButton
    }
}

final class AlertDelegate: NSObject, UIAlertViewDelegate {
    var actions: [() -> Void] = []
    var dismissed: () -> Void = {}
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if buttonIndex >= 0 && buttonIndex < actions.count { actions[buttonIndex]() }
        dismissed()
    }
}

extension View {
    public func sheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        _ModifiedView(content: self, modifier: SheetModifier(isPresented: isPresented, content: { content() }, onDismiss: onDismiss))
    }
}
