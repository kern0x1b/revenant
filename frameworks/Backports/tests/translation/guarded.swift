import SwiftUI
import Translation

@available(iOS 17.4, *)
struct TranslatePresenter: View {
    let text: String
    @State private var isPresented = true

    var body: some View {
        Color.clear.translationPresentation(isPresented: $isPresented, text: text)
    }
}
