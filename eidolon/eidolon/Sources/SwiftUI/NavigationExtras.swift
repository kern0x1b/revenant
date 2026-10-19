import UIKit
import CoreGraphics

func findAction(_ view: any View) -> (() -> Void)? {
    if let button = view as? ButtonLike { return button.buttonAction }
    if let group = view as? GroupView {
        for child in group.childViews { if let action = findAction(child) { return action } }
    }
    if let modified = view as? ModifiedViewLike { return findAction(modified.modifiedContent) }
    if let wrapper = view as? WrappedView { return findAction(wrapper.wrapped) }
    return nil
}

public struct ActionSheet {
    let title: String
    let message: String?
    let buttons: [Alert.Button]
    public init(title: Text, message: Text? = nil, buttons: [Alert.Button] = [.cancel()]) {
        self.title = title.content
        self.message = message?.content
        self.buttons = buttons
    }
}

final class SheetDelegate: NSObject, UIActionSheetDelegate {
    var actions: [() -> Void] = []
    var dismissed: () -> Void = {}
    func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        if buttonIndex >= 0 && buttonIndex < actions.count { actions[buttonIndex]() }
        dismissed()
    }
}

extension View {
    public func navigationBarItems<L: View, T: View>(leading: L, trailing: T) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(entries: { barEntries(leading, .navigationBarLeading) + barEntries(trailing, .navigationBarTrailing) }))
    }
    public func navigationBarItems<L: View>(leading: L) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(entries: { barEntries(leading, .navigationBarLeading) }))
    }
    public func navigationBarItems<T: View>(trailing: T) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(entries: { barEntries(trailing, .navigationBarTrailing) }))
    }
    @_disfavoredOverload
    public func toolbar<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        _ModifiedView(content: self, modifier: BarItemsModifier(entries: { barEntries(content(), .automatic) }))
    }
    public func navigationBarHidden(_ hidden: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { env in
            env.host?.navigationController?.setNavigationBarHidden(hidden, animated: false)
        }))
    }
    public func navigationBarBackButtonHidden(_ hidden: Bool) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { _ in }, onUpdate: { env in
            env.host?.navigationItem.hidesBackButton = hidden
        }))
    }
    public func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
    public func sheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        let isPresented = Binding<Bool>(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
        return sheet(isPresented: isPresented, onDismiss: onDismiss) {
            AnyView(item.wrappedValue.map { AnyView(content($0)) } ?? AnyView(EmptyView()))
        }
    }
}

extension NavigationLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: Destination, isActive: Binding<Bool>) {
        self.init(destination: destination, isActive: isActive) { Text(titleKey) }
    }
    public init<V: Hashable>(_ titleKey: LocalizedStringKey, destination: Destination, tag: V, selection: Binding<V?>) {
        self.init(destination: destination, tag: tag, selection: selection) { Text(titleKey) }
    }
}
