import UIKit

// The search field of iOS 6 has no tokens, so they are shown as a row of chips above it: each one is what `token`
// makes of an element, with a cross that removes it; the suggested tokens show while the field is being used, and a
// tap on one moves it into the tokens.
struct _TokenStrip<C: RandomAccessCollection & RangeReplaceableCollection, T: View>: View where C.Element: Identifiable {
    let tokens: Binding<C>
    let suggested: Binding<C>?
    let token: (C.Element) -> T
    @Environment(\.isSearching) var isSearching

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !tokens.wrappedValue.isEmpty { row(Array(tokens.wrappedValue), removable: true) }
            if let suggested, isSearching, !suggested.wrappedValue.isEmpty { row(Array(suggested.wrappedValue), removable: false) }
        }
    }

    func row(_ elements: [C.Element], removable: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(elements) { element in
                    HStack(spacing: 4) {
                        token(element)
                        if removable {
                            Button { remove(element) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(removable ? Color(white: 0.85) : Color(white: 0.93), cornerRadius: 10)
                    .onTapGesture { if !removable { add(element) } }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 30)
    }

    func remove(_ element: C.Element) {
        var current = tokens.wrappedValue
        if let index = current.firstIndex(where: { $0.id == element.id }) { current.remove(at: index) }
        tokens.wrappedValue = current
    }

    func add(_ element: C.Element) {
        guard !tokens.wrappedValue.contains(where: { $0.id == element.id }) else { return }
        tokens.wrappedValue.append(element)
    }
}

extension View {
    private func withTokens<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        tokens: Binding<C>, suggested: Binding<C>?, @ViewBuilder token: @escaping (C.Element) -> T
    ) -> some View where C.Element: Identifiable {
        _ = SearchFieldNote.once
        return VStack(spacing: 0) {
            _TokenStrip(tokens: tokens, suggested: suggested, token: token)
            self
        }
    }

    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
        @ViewBuilder token: @escaping (C.Element) -> T
    ) -> some View where C.Element: Identifiable {
        withTokens(tokens: tokens, suggested: nil, token: token).searchable(text: text, placement: placement, prompt: prompt)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
        @ViewBuilder token: @escaping (C.Element) -> T
    ) -> some View where C.Element: Identifiable {
        withTokens(tokens: tokens, suggested: nil, token: token).searchable(text: text, placement: placement, prompt: prompt)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View, S: StringProtocol>(
        text: Binding<String>, tokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: S,
        @ViewBuilder token: @escaping (C.Element) -> T
    ) -> some View where C.Element: Identifiable {
        withTokens(tokens: tokens, suggested: nil, token: token).searchable(text: text, placement: placement, prompt: prompt)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil,
        @ViewBuilder token: @escaping (C.Element) -> T
    ) -> some View where C.Element: Identifiable {
        withTokens(tokens: tokens, suggested: suggestedTokens, token: token).searchable(text: text, placement: placement, prompt: prompt)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey,
        @ViewBuilder token: @escaping (C.Element) -> T
    ) -> some View where C.Element: Identifiable {
        withTokens(tokens: tokens, suggested: suggestedTokens, token: token).searchable(text: text, placement: placement, prompt: prompt)
    }
    public func searchable<C: RandomAccessCollection & RangeReplaceableCollection, T: View, S: StringProtocol>(
        text: Binding<String>, tokens: Binding<C>, suggestedTokens: Binding<C>, placement: SearchFieldPlacement = .automatic, prompt: S,
        @ViewBuilder token: @escaping (C.Element) -> T
    ) -> some View where C.Element: Identifiable {
        withTokens(tokens: tokens, suggested: suggestedTokens, token: token).searchable(text: text, placement: placement, prompt: prompt)
    }
}

enum SearchFieldNote {
    static let once: Void = {
        _Unsupported.note("searchable(tokens:)", "the search field of iOS 6 has no tokens; they are shown as a row of chips above it")
    }()
}
