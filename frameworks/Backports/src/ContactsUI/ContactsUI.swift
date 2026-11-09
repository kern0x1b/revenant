import Foundation
import SwiftUI

@available(iOS 18.0, *)
public extension View {
    func contactAccessPicker(isPresented: Binding<Bool>, completionHandler: @escaping ([String]) -> Void) -> some View {
        modifier(ContactAccessPickerRefusal(isPresented: isPresented))
    }
}

@available(iOS 18.0, *)
private struct ContactAccessPickerRefusal: ViewModifier {
    let isPresented: Binding<Bool>

    func body(content: Content) -> some View {
        content.onChange(of: isPresented.wrappedValue, initial: true) { _, presented in
            guard presented else { return }
            let line = "[ContactsUI] contactAccessPicker presents nothing: this OS grants access to all contacts or to none, so there is no selection to extend; the binding is cleared and the completion handler is not called\n"
            fputs(line, stderr)
            NSLog("%@", line)
            isPresented.wrappedValue = false
        }
    }
}
