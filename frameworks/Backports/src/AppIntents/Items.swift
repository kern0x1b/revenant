import Foundation

public struct IntentItem<Value> where Value: _IntentValue {
    public let value: Value.ValueType
    public let title: LocalizedStringResource
    public let subtitle: LocalizedStringResource?
    public let image: DisplayRepresentation.Image?

    public typealias Builder = IntentItemBuilder<Value>

    public init(_ value: Value.ValueType) {
        self.value = value
        self.title = RevenantLocalized.resource(RevenantIntentItemText.write(value))
        self.subtitle = nil
        self.image = nil
    }

    public init(_ value: Value.ValueType, title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil,
                image: DisplayRepresentation.Image? = nil) {
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.image = image
    }

    public var description: String { return RevenantLocalized.string(of: title) }
}

@resultBuilder
public enum IntentItemBuilder<Value> where Value: _IntentValue {
    public static func buildBlock() -> [IntentItem<Value>] { return [] }

    public static func buildBlock(_ items: IntentItem<Value>...) -> [IntentItem<Value>] { return items }

    public static func buildExpression(_ expression: IntentItem<Value>) -> IntentItem<Value> { return expression }

    public static func buildArray(_ items: [IntentItem<Value>]) -> [IntentItem<Value>] { return items }
}

enum RevenantIntentItemText {
    static func write(_ value: Any) -> String {
        if let describable = value as? CustomStringConvertible { return describable.description }
        if let localized = value as? any CustomLocalizedStringResourceConvertible {
            return RevenantLocalized.string(of: localized.localizedStringResource)
        }
        return String(describing: value)
    }
}

public struct IntentItemCollection<Item>: ResultsCollection where Item: _IntentValue {
    public typealias Result = Item


    public typealias Section = IntentItemSection<Item>

    public let promptLabel: LocalizedStringResource?
    public let usesIndexedCollation: Bool
    public let items: [Item.ValueType]
    public let sections: [IntentItemSection<Item>]

    public init(promptLabel: LocalizedStringResource? = nil, usesIndexedCollation: Bool = false,
                items: () -> [IntentItem<Item>]) {
        self.promptLabel = promptLabel
        self.usesIndexedCollation = usesIndexedCollation
        self.items = items().map { $0.value }
        self.sections = []
    }

    public init(promptLabel: LocalizedStringResource? = nil, usesIndexedCollation: Bool = false,
                items: [Item.ValueType]) {
        self.promptLabel = promptLabel
        self.usesIndexedCollation = usesIndexedCollation
        self.items = items
        self.sections = []
    }

    public init(promptLabel: LocalizedStringResource? = nil, usesIndexedCollation: Bool = false,
                sections: [IntentItemSection<Item>]) {
        self.promptLabel = promptLabel
        self.usesIndexedCollation = usesIndexedCollation
        self.items = sections.flatMap { $0.items }
        self.sections = sections
    }

    public static var empty: IntentItemCollection<Item> {
        return IntentItemCollection(promptLabel: nil, usesIndexedCollation: false, items: [])
    }
}

public struct IntentItemSection<Item> where Item: _IntentValue {
    public let title: LocalizedStringResource?
    public let subtitle: LocalizedStringResource?
    public let image: DisplayRepresentation.Image?
    public let items: [Item.ValueType]


    public typealias Builder = IntentItemSectionBuilder<Item>
    public init(_ title: LocalizedStringResource, items: () -> [IntentItem<Item>]) {
        self.title = title
        self.subtitle = nil
        self.image = nil
        self.items = items().map { $0.value }
    }

    public init(_ title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil,
                image: DisplayRepresentation.Image? = nil,
                items: () -> [IntentItem<Item>]) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.items = items().map { $0.value }
    }

    public init(_ title: LocalizedStringResource, items: [Item.ValueType]) {
        self.title = title
        self.subtitle = nil
        self.image = nil
        self.items = items
    }

    public init(items: [Item.ValueType]) {
        self.title = nil
        self.subtitle = nil
        self.image = nil
        self.items = items
    }

    public init(title: LocalizedStringResource, items: [Item.ValueType]) {
        self.title = title
        self.subtitle = nil
        self.image = nil
        self.items = items
    }

    public var description: String { return title.map { RevenantLocalized.string(of: $0) } ?? "" }

}

public struct IntentFile: Hashable, Sendable {
    public enum IntentFileError: Error, Hashable, Sendable {
        case failedToLoadFile
        case failedToLoadData

        public var errorCode: Int {
            switch self {
            case .failedToLoadFile: return 1
            case .failedToLoadData: return 2
            }
        }

        public var errorDomain: String { return "AppIntents.IntentFile" }

        public var errorUserInfo: [String: String] {
            switch self {
            case .failedToLoadFile: return [NSLocalizedDescriptionKey: "the file could not be loaded"]
            case .failedToLoadData: return [NSLocalizedDescriptionKey: "the data could not be loaded"]
            }
        }


    }

    public let data: Data?
    public let fileURL: URL?
    public let filename: String
    public let type: String?
    public let removedOnCompletion: Bool

    public init(data: Data, filename: String, type: String? = nil) {
        self.data = data
        self.fileURL = nil
        self.filename = filename
        self.type = type
        self.removedOnCompletion = false
    }

    public init(fileURL: URL, filename: String? = nil, type: String? = nil) {
        self.data = nil
        self.fileURL = fileURL
        self.filename = filename ?? fileURL.lastPathComponent
        self.type = type
        self.removedOnCompletion = false
    }

    public var availableContentTypes: [String] { return type.map { [$0] } ?? [] }

    public static func data(contentType: String) -> IntentFile {
        return IntentFile(data: Data(), filename: "file", type: contentType)
    }

    public static func data(contentType: String, filename: String = "file",
                            data: @escaping () throws -> Data) -> IntentFile {
        return IntentFile(data: (try? data()) ?? Data(), filename: filename, type: contentType)
    }

    public static func file(contentType: String, destinationDirectory: URL? = nil) -> IntentFile {
        let directory = destinationDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = directory.appendingPathComponent("revenant-intent-file")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: Data()) }
        return IntentFile(fileURL: url, filename: url.lastPathComponent, type: contentType)
    }

    public static func file(contentType: String, destinationDirectory: URL? = nil,
                            fileHandler: (URL) throws -> Void) -> IntentFile {
        let directory = destinationDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = directory.appendingPathComponent("revenant-intent-file")
        try? fileHandler(url)
        return IntentFile(fileURL: url, filename: url.lastPathComponent, type: contentType)
    }

    public static func withFile(contentType: String, allowOpenInPlace: Bool = false,
                                fileHandler: (URL) throws -> Void) throws -> IntentFile {
        return try file(contentType: contentType, fileHandler: fileHandler)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decodeIfPresent(Data.self, forKey: .data)
        self.fileURL = try container.decodeIfPresent(URL.self, forKey: .fileURL)
        self.filename = try container.decode(String.self, forKey: .filename)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.removedOnCompletion = false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(fileURL, forKey: .fileURL)
        try container.encode(filename, forKey: .filename)
        try container.encodeIfPresent(type, forKey: .type)
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case fileURL
        case filename
        case type
    }

    public static func == (a: IntentFile, b: IntentFile) -> Bool {
        return a.data == b.data && a.fileURL == b.fileURL && a.filename == b.filename && a.type == b.type
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(filename)
        hasher.combine(type)
    }
}

extension IntentFile: DisplayRepresentable, _IntentValue {
    public typealias ValueType = IntentFile
    public typealias UnwrappedType = IntentFile
    public typealias Specification = EmptyResolverSpecification<IntentFile>

    public static var defaultResolverSpecification: Specification { return Specification() }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: RevenantLocalized.resource("File"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title)
    }

    public var title: LocalizedStringResource { return RevenantLocalized.resource(filename) }

    public var localizedStringResource: LocalizedStringResource { return title }
}

public struct IntentPerson: Hashable, Sendable, DisplayRepresentable, _IntentValue {
    public struct Handle: Hashable, Sendable, Codable {
        public enum Value: String, Hashable, Sendable, Codable {
            case phoneNumber
            case emailAddress
            case applicationDefined
        }

        public enum Label: String, Hashable, Sendable, Codable {
            case main
            case iPhone
            case mobile
            case home
            case work
            case school
            case other
            case homeFax
            case workFax
            case pager
            case custom
        }

        public let value: Value
        public let label: Label
        public let applicationDefined: String?

        public init(_ value: String, label: Label) {
            self.applicationDefined = value
            self.value = .applicationDefined
            self.label = label
        }

        public init(applicationDefined: String, label: Label) {
            self.applicationDefined = applicationDefined
            self.value = .applicationDefined
            self.label = label
        }

        public init(phoneNumber: String, label: Label) {
            self.applicationDefined = nil
            self.value = .phoneNumber
            self.label = label
        }

        public init(emailAddress: String, label: Label) {
            self.applicationDefined = nil
            self.value = .emailAddress
            self.label = label
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.applicationDefined = try container.decodeIfPresent(String.self, forKey: .applicationDefined)
            self.value = try container.decode(Value.self, forKey: .value)
            self.label = try container.decode(Label.self, forKey: .label)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .value)
            try container.encode(label, forKey: .label)
            try container.encodeIfPresent(applicationDefined, forKey: .applicationDefined)
        }

        private enum CodingKeys: String, CodingKey {
            case value
            case label
            case applicationDefined
        }
    }

    public enum Identifier: String, Hashable, Sendable, Codable {
        case contact
        case applicationDefined
        case unknown
    }

    public enum Name: String, Hashable, Sendable, Codable {
        case displayName
        case components
        case unknown
    }

    public enum ParameterMode: String, Hashable, Sendable, Codable {
        case contact
        case email
        case phone
        case emailOrPhone

        public init?(rawValue: String) {
            self.init(rawValue: rawValue)
        }
    }

    public let identifier: Identifier
    public let name: Name
    public let handle: Handle?
    public let aliases: [String]
    public let isMe: Bool
    public let image: DisplayRepresentation.Image?

    public init(identifier: Identifier, name: Name, handle: Handle? = nil, aliases: [String] = [],
                isMe: Bool = false, image: DisplayRepresentation.Image? = nil) {
        self.identifier = identifier
        self.name = name
        self.handle = handle
        self.aliases = aliases
        self.isMe = isMe
        self.image = image
    }

    public init(handle: Handle) {
        self.init(identifier: .applicationDefined, name: .unknown, handle: handle)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(Identifier.self, forKey: .identifier)
        self.name = try container.decode(Name.self, forKey: .name)
        self.handle = try container.decodeIfPresent(Handle.self, forKey: .handle)
        self.aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        self.isMe = try container.decodeIfPresent(Bool.self, forKey: .isMe) ?? false
        self.image = nil
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(handle, forKey: .handle)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(isMe, forKey: .isMe)
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case handle
        case aliases
        case isMe
    }

    public static func == (a: IntentPerson, b: IntentPerson) -> Bool {
        return a.identifier == b.identifier && a.name == b.name && a.handle == b.handle && a.aliases == b.aliases
            && a.isMe == b.isMe
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(name)
        hasher.combine(handle)
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: RevenantLocalized.resource("Person"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title, image: image)
    }

    public var title: LocalizedStringResource {
        return RevenantLocalized.resource(handle?.applicationDefined ?? name.rawValue)
    }

    public var localizedStringResource: LocalizedStringResource { return title }

    public typealias ValueType = IntentPerson
    public typealias UnwrappedType = IntentPerson
    public typealias Specification = EmptyResolverSpecification<IntentPerson>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

public struct IntentPaymentMethod: Sendable, DisplayRepresentable, _IntentValue {
    public enum PaymentType: String, Hashable, Sendable {
        case unknown
        case debit
        case credit
        case prepaid
        case store
        case bank
        case applePay
        case savings
        case checking
        case brokerage
    }

    public let paymentType: PaymentType
    public let name: String
    public let identificationHint: String?
    public let icon: DisplayRepresentation.Image?

    public init(type: PaymentType, name: String, identificationHint: String? = nil,
                icon: DisplayRepresentation.Image? = nil) {
        self.paymentType = type
        self.name = name
        self.identificationHint = identificationHint
        self.icon = icon
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: RevenantLocalized.resource("Payment Method"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title, image: icon)
    }

    public var title: LocalizedStringResource { return RevenantLocalized.resource(name) }

    public var localizedStringResource: LocalizedStringResource { return title }

    public typealias ValueType = IntentPaymentMethod
    public typealias UnwrappedType = IntentPaymentMethod
    public typealias Specification = EmptyResolverSpecification<IntentPaymentMethod>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

public struct IntentCurrencyAmount: Equatable, Hashable, Sendable, DisplayRepresentable, _IntentValue {
    public let amount: Decimal
    public let currencyCode: String

    public init(amount: Decimal, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode
    }

    public static func == (a: IntentCurrencyAmount, b: IntentCurrencyAmount) -> Bool {
        return a.amount == b.amount && a.currencyCode == b.currencyCode
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(amount)
        hasher.combine(currencyCode)
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: RevenantLocalized.resource("Currency Amount"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title)
    }

    public var title: LocalizedStringResource { return RevenantLocalized.resource(currencyCode) }

    public var localizedStringResource: LocalizedStringResource { return title }

    public typealias ValueType = IntentCurrencyAmount
    public typealias UnwrappedType = IntentCurrencyAmount
    public typealias Specification = EmptyResolverSpecification<IntentCurrencyAmount>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

@resultBuilder
public enum IntentItemSectionBuilder<Item> where Item: _IntentValue {
    public static func buildBlock() -> [IntentItemSection<Item>] { return [] }

    public static func buildBlock(_ sections: IntentItemSection<Item>...) -> [IntentItemSection<Item>] {
        return sections
    }

    public static func buildBlock(_ items: IntentItem<Item>...) -> [IntentItemSection<Item>] {
        return [IntentItemSection(items: items.map { $0.value })]
    }
}
