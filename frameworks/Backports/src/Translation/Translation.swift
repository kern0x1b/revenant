import Foundation
import SwiftUI

@available(iOS 17.4, *)
public extension View {
    func translationPresentation(isPresented: Binding<Bool>, text: String, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top, replacementAction: ((String) -> Void)? = nil) -> some View {
        modifier(TranslationPresentationRefusal(isPresented: isPresented))
    }
}

@available(iOS 18.0, *)
public extension View {
    func translationTask(_ configuration: TranslationSession.Configuration?, action: @escaping (_ session: TranslationSession) async -> Void) -> some View {
        task(id: configuration) {
            guard let configuration = configuration else { return }
            await action(TranslationSession(source: configuration.source, target: configuration.target))
        }
    }

    func translationTask(source: Locale.Language? = nil, target: Locale.Language? = nil, action: @escaping (_ session: TranslationSession) async -> Void) -> some View {
        translationTask(TranslationSession.Configuration(source: source, target: target), action: action)
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
