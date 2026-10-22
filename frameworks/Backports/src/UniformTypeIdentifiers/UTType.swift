import Foundation
#if canImport(MobileCoreServices)
import MobileCoreServices
#else
import CoreServices
#endif

private let extensionClass = "public.filename-extension"
private let mimeClass = "public.mime-type"
private let dynamicPrefix = "dyn."
private let tagSpecificationKey = "UTTypeTagSpecification"
private let versionKey = "UTTypeVersion"
private let referenceURLKey = "UTTypeReferenceURL"

private func indexed(_ tags: (RevenantStandardType) -> [String]) -> [String: [String]] {
    var index: [String: [String]] = [:]
    for record in revenantStandardTypes {
        for tag in tags(record) {
            index[tag.lowercased(), default: []].append(record.identifier)
        }
    }
    return index
}

private let standardByExtension = indexed { $0.tags[extensionClass] ?? [] }
private let standardByMIMEType = indexed { $0.tags[mimeClass] ?? [] }

private let standardByIdentifier: [String: RevenantStandardType] = {
    var records: [String: RevenantStandardType] = [:]
    for record in revenantStandardTypes {
        records[record.identifier] = record
    }
    return records
}()

private func declaration(_ identifier: String) -> [String: Any]? {
    guard let dictionary = UTTypeCopyDeclaration(identifier as CFString)?.takeRetainedValue() else {
        return nil
    }
    return (dictionary as NSDictionary) as? [String: Any]
}

private func strings(_ value: Any?) -> [String] {
    if let text = value as? String {
        return [text]
    }
    return value as? [String] ?? []
}

private func systemTag(_ identifier: String, _ tagClass: String) -> String? {
    guard let tag = UTTypeCopyPreferredTagWithClass(identifier as CFString, tagClass as CFString)?.takeRetainedValue() else {
        return nil
    }
    return tag as String
}

private func systemTypes(tag: String, tagClass: String, conformingTo supertype: String?) -> [String] {
    guard let identifiers = UTTypeCreateAllIdentifiersForTag(tagClass as CFString, tag as CFString, supertype.map { $0 as CFString })?.takeRetainedValue() else {
        return []
    }
    return identifiers as? [String] ?? []
}

private func systemPreferred(tag: String, tagClass: String, conformingTo supertype: String?) -> String? {
    guard let identifier = UTTypeCreatePreferredIdentifierForTag(tagClass as CFString, tag as CFString, supertype.map { $0 as CFString })?.takeRetainedValue() else {
        return nil
    }
    return identifier as String
}

private func isKnown(_ identifier: String) -> Bool {
    if standardByIdentifier[identifier] != nil {
        return true
    }
    if identifier.hasPrefix(dynamicPrefix) {
        return identifier.count > dynamicPrefix.count
    }
    return declaration(identifier) != nil
}

public struct UTType: Sendable {
    public let identifier: String
    private let parents: [String]

    init(standard identifier: String) {
        self.identifier = identifier
        self.parents = []
    }

    private init(verified identifier: String, parents: [String]) {
        self.identifier = identifier
        self.parents = parents
    }

    public init?(_ identifier: String) {
        let name = identifier.lowercased()
        guard isKnown(name) else {
            return nil
        }
        self.init(verified: name, parents: [])
    }

    public init?(filenameExtension: String, conformingTo supertype: UTType = .data) {
        guard let type = UTType.preferred(tag: filenameExtension, tagClass: extensionClass, conformingTo: supertype) else {
            return nil
        }
        self = type
    }

    public init?(mimeType: String, conformingTo supertype: UTType = .data) {
        guard let type = UTType.preferred(tag: mimeType, tagClass: mimeClass, conformingTo: supertype) else {
            return nil
        }
        self = type
    }

    public init?(tag: String, tagClass: UTTagClass, conformingTo supertype: UTType?) {
        guard let type = UTType.preferred(tag: tag, tagClass: tagClass.rawValue, conformingTo: supertype) else {
            return nil
        }
        self = type
    }

    public init(exportedAs identifier: String, conformingTo parentType: UTType? = nil) {
        self.init(declaredInBundle: identifier, parentType: parentType)
    }

    public init(importedAs identifier: String, conformingTo parentType: UTType? = nil) {
        self.init(declaredInBundle: identifier, parentType: parentType)
    }

    private init(declaredInBundle identifier: String, parentType: UTType?) {
        let name = identifier.lowercased()
        let parents = UTType.bundleParents(of: name)
        if parents.isEmpty {
            self.init(verified: name, parents: [])
        } else {
            self.init(verified: name, parents: parents + (parentType.map { [$0.identifier] } ?? []))
        }
    }

    private static func bundleParents(of identifier: String) -> [String] {
        for key in ["UTExportedTypeDeclarations", "UTImportedTypeDeclarations"] {
            guard let declarations = Bundle.main.object(forInfoDictionaryKey: key) as? [[String: Any]] else {
                continue
            }
            for declaration in declarations where (declaration["UTTypeIdentifier"] as? String)?.lowercased() == identifier {
                return strings(declaration["UTTypeConformsTo"])
            }
        }
        return []
    }

    private static func preferred(tag: String, tagClass: String, conformingTo supertype: UTType?) -> UTType? {
        let value = tag.lowercased()
        guard !value.isEmpty, !value.hasPrefix(".") else {
            return nil
        }
        let candidates: [String]
        if tagClass == extensionClass {
            candidates = standardByExtension[value] ?? []
        } else if tagClass == mimeClass {
            candidates = standardByMIMEType[value] ?? []
        } else {
            candidates = []
        }
        for identifier in candidates {
            let type = UTType(standard: identifier)
            if supertype.map({ type.conforms(to: $0) }) ?? true {
                return type
            }
        }
        guard let identifier = systemPreferred(tag: value, tagClass: tagClass, conformingTo: supertype?.identifier) else {
            return nil
        }
        return UTType(verified: identifier, parents: [])
    }

    public static func types(tag: String, tagClass: UTTagClass, conformingTo supertype: UTType?) -> [UTType] {
        let value = tag.lowercased()
        guard !value.isEmpty else {
            return []
        }
        var identifiers: [String] = []
        if tagClass.rawValue == extensionClass {
            identifiers = standardByExtension[value] ?? []
        } else if tagClass.rawValue == mimeClass {
            identifiers = standardByMIMEType[value] ?? []
        }
        var types = identifiers.map { UTType(standard: $0) }.filter { type in
            supertype.map { type.conforms(to: $0) } ?? true
        }
        for identifier in systemTypes(tag: value, tagClass: tagClass.rawValue, conformingTo: supertype?.identifier) where !types.contains(where: { $0.identifier == identifier }) {
            types.append(UTType(verified: identifier, parents: []))
        }
        return types
    }

    public var localizedDescription: String? {
        if let record = standardByIdentifier[identifier] {
            return record.localizedDescription
        }
        return UTTypeCopyDescription(identifier as CFString)?.takeRetainedValue() as String?
    }

    public var preferredFilenameExtension: String? {
        if let record = standardByIdentifier[identifier] {
            return record.preferredExtension
        }
        return systemTag(identifier, extensionClass)
    }

    public var preferredMIMEType: String? {
        if let record = standardByIdentifier[identifier] {
            return record.preferredMIMEType
        }
        return systemTag(identifier, mimeClass)
    }

    public var version: Int? {
        if let record = standardByIdentifier[identifier] {
            return record.version
        }
        guard let value = declaration(identifier)?[versionKey] as? NSNumber else {
            return nil
        }
        return value.intValue
    }

    public var referenceURL: URL? {
        if let record = standardByIdentifier[identifier] {
            return record.referenceURL.flatMap { URL(string: $0) }
        }
        guard let value = declaration(identifier)?[referenceURLKey] as? String else {
            return nil
        }
        return URL(string: value)
    }

    public var isDynamic: Bool {
        identifier.hasPrefix(dynamicPrefix)
    }

    public var isDeclared: Bool {
        !isDynamic
    }

    public var isPublic: Bool {
        identifier.hasPrefix("public.")
    }

    public func conforms(to type: UTType) -> Bool {
        type.identifier == identifier || supertypeIdentifiers.contains(type.identifier)
    }

    public func isSupertype(of type: UTType) -> Bool {
        type != self && type.conforms(to: self)
    }

    public func isSubtype(of type: UTType) -> Bool {
        self != type && conforms(to: type)
    }

    public var supertypes: Set<UTType> {
        Set(supertypeIdentifiers.map { UTType(verified: $0, parents: []) })
    }

    private var supertypeIdentifiers: Set<String> {
        var result = Set<String>()
        var pending = parents + UTType.directSupertypes(of: identifier)
        while let next = pending.popLast() {
            if result.insert(next).inserted {
                pending += UTType.directSupertypes(of: next)
            }
        }
        return result
    }

    private static func directSupertypes(of identifier: String) -> [String] {
        if let record = standardByIdentifier[identifier] {
            return record.supertypes
        }
        if identifier.hasPrefix(dynamicPrefix) {
            return []
        }
        return strings(declaration(identifier)?[kUTTypeConformsToKey as String])
    }

    public var tags: [UTTagClass: [String]] {
        var result: [UTTagClass: [String]] = [:]
        if let record = standardByIdentifier[identifier] {
            for (key, values) in record.tags {
                result[UTTagClass(rawValue: key)] = values
            }
            return result
        }
        if let spec = declaration(identifier)?[tagSpecificationKey] as? [String: Any] {
            for (key, value) in spec {
                let values = strings(value)
                if !values.isEmpty {
                    result[UTTagClass(rawValue: key)] = values
                }
            }
        }
        return result
    }

    public var description: String {
        identifier
    }

    public var debugDescription: String {
        "UTType(\(identifier))"
    }
}

extension UTType: Equatable, Hashable {
    public static func == (lhs: UTType, rhs: UTType) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

extension UTType: Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }

    public init(from decoder: any Decoder) throws {
        let value: String
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            value = text
        } else {
            value = try decoder.container(keyedBy: UTTypeCodingKey.self).decode(String.self, forKey: .identifier)
        }
        guard let type = UTType(value) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "\(value) is not a known type identifier"))
        }
        self = type
    }
}

private enum UTTypeCodingKey: String, CodingKey {
    case identifier
}

public struct UTTagClass: RawRepresentable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static var filenameExtension: UTTagClass {
        UTTagClass(rawValue: extensionClass)
    }

    public static var mimeType: UTTagClass {
        UTTagClass(rawValue: mimeClass)
    }

    public var description: String {
        rawValue
    }

    public var debugDescription: String {
        "UTTagClass(\(rawValue))"
    }
}
