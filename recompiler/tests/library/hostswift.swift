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
