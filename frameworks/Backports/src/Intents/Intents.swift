import Foundation

extension INParameter {
    @nonobjc public convenience init?<Root, Value>(keyPath: KeyPath<Root, Value>) {
        guard let parameterClass = Root.self as? AnyClass, let path = keyPath._kvcKeyPathString else {
            return nil
        }
        self.init(for: parameterClass, keyPath: path)
    }
}

public protocol _INIntentSetImageKeyPath {
}

extension _INIntentSetImageKeyPath {
    public func setImage<Value>(_ image: INImage?, forParameterNamed parameterName: KeyPath<Self, Value>) {
        guard let intent = self as? INIntent, let path = parameterName._kvcKeyPathString else {
            return
        }
        intent.__setImage(image, forParameterNamed: path)
    }

    public func image<Value>(forParameterNamed parameterName: KeyPath<Self, Value>) -> INImage? {
        guard let intent = self as? INIntent, let path = parameterName._kvcKeyPathString else {
            return nil
        }
        return intent.__image(forParameterNamed: path)
    }
}

extension INIntent: _INIntentSetImageKeyPath {
}

public protocol INIntentSetImageKeyPath: _INIntentSetImageKeyPath {
}

extension INIntent: INIntentSetImageKeyPath {
}

extension INCallRecord {
    @nonobjc convenience public init(identifier: String, dateCreated: Date? = nil, caller: INPerson? = nil, callRecordType: INCallRecordType = .unknown, callCapability: INCallCapability = .unknown, callDuration: Double? = nil, unseen: Bool? = nil, numberOfCalls: Int? = nil) {
        self.init(__identifier: identifier, dateCreated: dateCreated, caller: caller, callRecordType: callRecordType, callCapability: callCapability, callDuration: callDuration.map { NSNumber(value: $0) }, unseen: unseen.map { NSNumber(value: $0) }, numberOfCalls: numberOfCalls.map { NSNumber(value: $0) })
    }

    @available(iOS, obsoleted: 13.0)
    @nonobjc convenience public init(identifier: String, dateCreated: Date? = nil, caller: INPerson? = nil, callRecordType: INCallRecordType, callCapability: INCallCapability, callDuration: Double? = nil, unseen: Bool? = nil) {
        self.init(__identifier: identifier, dateCreated: dateCreated, caller: caller, callRecordType: callRecordType, callCapability: callCapability, callDuration: callDuration.map { NSNumber(value: $0) }, unseen: unseen.map { NSNumber(value: $0) })
    }

    @nonobjc final public var callDuration: Double? {
        return __callDuration?.doubleValue
    }

    @nonobjc final public var unseen: Bool? {
        return __unseen?.boolValue
    }

    @nonobjc final public var numberOfCalls: Int? {
        return __numberOfCalls?.intValue
    }
}

extension INSearchCallHistoryIntent {
    @nonobjc convenience public init(dateCreated: INDateComponentsRange? = nil, recipient: INPerson? = nil, callCapabilities: INCallCapabilityOptions, callTypes: INCallRecordTypeOptions, unseen: Bool? = nil) {
        self.init(__dateCreated: dateCreated, recipient: recipient, callCapabilities: callCapabilities, callTypes: callTypes, unseen: unseen.map { NSNumber(value: $0) })
    }

    @nonobjc final public var unseen: Bool? {
        return __unseen?.boolValue
    }
}
