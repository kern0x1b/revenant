import Foundation

extension UTType: _ObjectiveCBridgeable {
    public typealias _ObjectiveCType = UTTypeReference

    public func _bridgeToObjectiveC() -> UTTypeReference {
        return UTTypeReference(identifier)!
    }

    public static func _forceBridgeFromObjectiveC(_ source: UTTypeReference, result: inout UTType?) {
        result = UTType(importedAs: source.identifier)
    }

    public static func _conditionallyBridgeFromObjectiveC(_ source: UTTypeReference, result: inout UTType?) -> Bool {
        _forceBridgeFromObjectiveC(source, result: &result)
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: UTTypeReference?) -> UTType {
        var result: UTType?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}
