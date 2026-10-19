// corpus/swiftconformance: a control for runtime/bridge.m's _dyld_register_func_for_add_image
// bridge (coordination/crutches.md would carry this if it were a crutch -- it is not, this is the
// native fix). Widget's conformance to Hashable is a __swift5_proto record in THIS image, findable
// only if something told the Swift runtime this image exists and read its sections -- exactly what
// the bridge now does for every guest image, since nothing else ever "loads" one at run time.
struct Widget: Hashable {
    let id: Int
}

@inline(never)
func isHashable(_ x: Any) -> Bool {
    return x is Hashable
}

print(isHashable(Widget(id: 1)) ? "hashable" : "not-hashable")
