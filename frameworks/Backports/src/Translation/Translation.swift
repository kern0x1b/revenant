import Foundation
import SwiftUI

@available(iOS 17.4, *)
public extension View {
    func translationPresentation(isPresented: Binding<Bool>, text: String, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top, replacementAction: ((String) -> Void)? = nil) -> some View {
        modifier(TranslationPresentationRefusal(isPresented: isPresented))
    }
}

@available(iOS 17.4, *)
private struct TranslationPresentationRefusal: ViewModifier {
    let isPresented: Binding<Bool>

    func body(content: Content) -> some View {
        content.onChange(of: isPresented.wrappedValue, initial: true) { _, presented in
            guard presented else { return }
            let line = "[Translation] translationPresentation presents nothing: this OS has no translation service, so the binding is cleared and the replacement action is not called\n"
            fputs(line, stderr)
            NSLog("%@", line)
            isPresented.wrappedValue = false
        }
    }
}
