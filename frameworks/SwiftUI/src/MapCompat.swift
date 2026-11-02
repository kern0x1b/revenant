import Foundation

extension NSObject {
    func _mapSetFlag(_ key: String, _ value: Bool) {
        _mapSetValue(key, NSNumber(value: value))
    }

    func _mapSetValue(_ key: String, _ value: Any?) {
        let setter = NSSelectorFromString("set" + key.prefix(1).uppercased() + key.dropFirst() + ":")
        guard responds(to: setter) else { return }
        setValue(value, forKey: key)
    }
}
