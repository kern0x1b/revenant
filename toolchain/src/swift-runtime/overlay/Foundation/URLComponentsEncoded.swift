import Foundation

extension URLComponents {
    public var encodedHost: String? {
        get { return _handle.map { $0.encodedHost } }
        set { _applyMutation { $0.encodedHost = newValue } }
    }

    public init?(string: String, encodingInvalidCharacters: Bool) {
        guard let result = NSURLComponents(string: string, encodingInvalidCharacters: encodingInvalidCharacters) else {
            return nil
        }
        _handle = _MutableHandle(adoptingReference: result)
    }
}

extension URL {
    public init?(string: String, encodingInvalidCharacters: Bool) {
        guard let result = NSURL(string: string, encodingInvalidCharacters: encodingInvalidCharacters) else {
            return nil
        }
        self = result as URL
    }
}
