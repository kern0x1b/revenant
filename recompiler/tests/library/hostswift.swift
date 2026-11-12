// The host's own Swift code, built for the host's own libswiftCore. It makes what Swift boxes and bridges at an Objective-C
// boundary: a value that is no object, an Array and a String as objects. host.m looks at their classes, and at the names of
// the Swift runtime's classes, before the library loads and again after it has run.

// With BRIDGING the Foundation overlay is imported, so that an Array and a String become an NSArray and an NSString;
// without it Swift boxes them, as it boxes every value that is no object.
#if BRIDGING
import Foundation
#endif

struct Pair {
    var first: Int
    var second: Int
}

@_cdecl("rch_make_box")
public func makeBox(_ seed: Int) -> UnsafeMutableRawPointer {
    let box = Pair(first: seed, second: 2) as AnyObject
    return Unmanaged.passRetained(box).toOpaque()
}

@_cdecl("rch_make_array")
public func makeArray(_ seed: Int) -> UnsafeMutableRawPointer {
    let items: [Any] = [seed, "item-\(seed)", Pair(first: seed, second: 3)]
    return Unmanaged.passRetained(items as AnyObject).toOpaque()
}

@_cdecl("rch_make_string")
public func makeString(_ seed: Int) -> UnsafeMutableRawPointer {
    let text = "host-\(seed)-h\u{e9}llo"
    return Unmanaged.passRetained(text as AnyObject).toOpaque()
}
