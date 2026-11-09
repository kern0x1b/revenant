import CoreFoundation
import CoreVideo

public protocol CMAttachmentBearerProtocol {
    var attachments: CMAttachmentBearerAttachments { get }
    func propagateAttachments<T>(to destination: T) where T: CMAttachmentBearerProtocol
}

public struct CMAttachmentBearerAttachments {
    @nonexhaustive
    public enum Value {
        case shouldNotPropagate(Any)
        case shouldPropagate(Any)

        public var value: Any {
            switch self {
            case .shouldNotPropagate(let value), .shouldPropagate(let value):
                return value
            }
        }

        public var mode: CMAttachmentBearerAttachments.Mode {
            switch self {
            case .shouldNotPropagate:
                return .shouldNotPropagate
            case .shouldPropagate:
                return .shouldPropagate
            }
        }
    }

    @nonexhaustive
    public enum Mode: CMAttachmentMode {
        case shouldNotPropagate = 0
        case shouldPropagate = 1
    }

    let bearer: CFTypeRef

    init(bearer: CFTypeRef) {
        self.bearer = bearer
    }

    public subscript(key: String) -> Value? {
        get {
            var mode = CMAttachmentMode(kCMAttachmentMode_ShouldNotPropagate)
            guard let value = CMGetAttachment(bearer, key: key as CFString, attachmentModeOut: &mode) else {
                return nil
            }
            switch Mode(rawValue: mode) {
            case .shouldPropagate?:
                return .shouldPropagate(value)
            default:
                return .shouldNotPropagate(value)
            }
        }
        set {
            guard let newValue = newValue else {
                CMRemoveAttachment(bearer, key: key as CFString)
                return
            }
            CMSetAttachment(bearer, key: key as CFString, value: newValue.value as AnyObject,
                            attachmentMode: newValue.mode.rawValue)
        }
    }

    public func removeAll() {
        CMRemoveAllAttachments(bearer)
    }

    public var nonPropagated: [String: Any] {
        return copy(.shouldNotPropagate)
    }

    public var propagated: [String: Any] {
        return copy(.shouldPropagate)
    }

    public func merge(_ attachments: [String: Any], mode: Mode) {
        CMSetAttachments(bearer, attachments: attachments as CFDictionary, attachmentMode: mode.rawValue)
    }

    private func copy(_ mode: Mode) -> [String: Any] {
        guard let dictionary = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: bearer,
                                                             attachmentMode: mode.rawValue) else {
            return [:]
        }
        return (dictionary as NSDictionary) as? [String: Any] ?? [:]
    }
}

extension CMBlockBuffer: CMAttachmentBearerProtocol {
    public var attachments: CMAttachmentBearerAttachments {
        get { return CMAttachmentBearerAttachments(bearer: self) }
        _modify {
            var attachments = CMAttachmentBearerAttachments(bearer: self)
            yield &attachments
        }
    }

    public func propagateAttachments<T>(to destination: T) where T: CMAttachmentBearerProtocol {
        CMPropagateAttachments(self, destination: destination.attachments.bearer)
    }
}

extension CMSampleBuffer: CMAttachmentBearerProtocol {
    public var attachments: CMAttachmentBearerAttachments {
        get { return CMAttachmentBearerAttachments(bearer: self) }
        _modify {
            var attachments = CMAttachmentBearerAttachments(bearer: self)
            yield &attachments
        }
    }

    public func propagateAttachments<T>(to destination: T) where T: CMAttachmentBearerProtocol {
        CMPropagateAttachments(self, destination: destination.attachments.bearer)
    }
}

extension CVBuffer: CMAttachmentBearerProtocol {
    public var attachments: CMAttachmentBearerAttachments {
        get { return CMAttachmentBearerAttachments(bearer: self) }
        _modify {
            var attachments = CMAttachmentBearerAttachments(bearer: self)
            yield &attachments
        }
    }

    public func propagateAttachments<T>(to destination: T) where T: CMAttachmentBearerProtocol {
        CMPropagateAttachments(self, destination: destination.attachments.bearer)
    }
}
