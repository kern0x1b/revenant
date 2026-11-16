import Foundation

struct HostFailure: Error {
    var number: Int
}

@_cdecl("rcsdk_host_swift")
public func hostSwift(_ seed: Int) -> Int {
    let locale = Locale(identifier: "en_US")
    let data = Data([1, 2, 3, UInt8(truncatingIfNeeded: seed)])
    let url = URL(string: "https://example.com/\(data.count)")
    let error = HostFailure(number: seed) as NSError
    let info: [String: Any] = ["seed": seed, "text": locale.identifier]
    let object = info as NSDictionary
    return locale.identifier.count + (url?.absoluteString.count ?? 0) + error.code + object.count
}
