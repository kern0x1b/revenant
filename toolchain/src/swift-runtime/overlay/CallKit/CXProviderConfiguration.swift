@_exported import CallKit
import Foundation

extension CXProviderConfiguration {
    @nonobjc public var supportedHandleTypes: Set<CXHandle.HandleType> {
        get {
            return Set(__supportedHandleTypes.compactMap { CXHandle.HandleType(rawValue: $0.intValue) })
        }
        set {
            __supportedHandleTypes = Set(newValue.map { NSNumber(value: $0.rawValue) })
        }
    }
}
