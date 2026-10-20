struct Widget: Hashable {
    let id: Int
}

@inline(never)
func isHashable(_ x: Any) -> Bool {
    return x is Hashable
}

print(isHashable(Widget(id: 1)) ? "hashable" : "not-hashable")
