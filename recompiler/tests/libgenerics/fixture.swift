import Foundation

@inline(never) func line(_ text: String) {
    print(text)
    fflush(nil)
}

@inline(never) func report(_ name: String, _ passed: Bool) {
    line((passed ? "ok " : "FAIL ") + name)
}

@objc(LibGenerics) public final class LibGenerics: NSObject {
    @objc public func stepDictionary() {
        var names = [String: String]()
        names["a"] = "alpha"
        names["b"] = "beta"
        report("dictionary.string", names.count == 2 && names["b"] == "beta")
    }
}
