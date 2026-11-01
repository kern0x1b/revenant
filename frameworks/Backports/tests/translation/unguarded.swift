import SwiftUI
import Translation

struct TranslatePresenter: View {
    let text: String
    @State private var isPresented = true

    var body: some View {
        Color.clear.translationPresentation(isPresented: $isPresented, text: text)
    }
}
