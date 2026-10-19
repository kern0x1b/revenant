// The values a result hands back: an item, a collection of items, a section of them, a file, a
// person, a payment method and an amount of money.

import Foundation

/// A value a result hands on, shown with its own display representation.
public struct IntentItem<Value> where Value: _IntentValue {
    /// The value the item carries.
    public let value: Value.ValueType
    /// The title the item is shown with.
    public let title: LocalizedStringResource
    public let subtitle: LocalizedStringResource?
    public let image: DisplayRepresentation.Image?

    /// The builder of a list of items, which is what a result's collection is written with. It is the
    /// framework's own builder, reached through the file-scope one the initializers name: a nested
    /// builder of a generic type cannot be named as an attribute without its arguments.
    public typealias Builder = IntentItemBuilder<Value>

    public init(_ value: Value.ValueType) {
        self.value = value
        self.title = CharonLocalized.resource(CharonIntentItemText.write(value))
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

    /// What the item is described as, which is its own string.
    public var description: String { return CharonLocalized.string(of: title) }

    /// The builder of a list of items, which is what a result's collection is written with.
}

/// The builder of a list of items, which is what a result's collection is written with.
@resultBuilder
public enum IntentItemBuilder<Value> where Value: _IntentValue {
    public static func buildBlock() -> [IntentItem<Value>] { return [] }

    /// The framework's overload is **variadic** -- `buildBlock(_ items: AppIntents::IntentItem<Value>...)`
    /// (arm64e-apple-ios.swiftinterface:4954) -- and the port's took a single item, which is the
    /// difference the two-sided check found. A list is written as several items, so the caller
    /// shapes are `buildBlock(a, b, c)` and the empty `buildBlock()`.
    public static func buildBlock(_ items: IntentItem<Value>...) -> [IntentItem<Value>] { return items }

    public static func buildExpression(_ expression: IntentItem<Value>) -> IntentItem<Value> { return expression }

    public static func buildArray(_ items: [IntentItem<Value>]) -> [IntentItem<Value>] { return items }
}

/// Writing a value as the text a title is made of, which is what the release's own description gives.
enum CharonIntentItemText {
    static func write(_ value: Any) -> String {
        if let describable = value as? CustomStringConvertible { return describable.description }
        if let localized = value as? any CustomLocalizedStringResourceConvertible {
            return CharonLocalized.string(of: localized.localizedStringResource)
        }
        return String(describing: value)
    }
}

/// A list of items a result hands back, or a list of them in sections.
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

    /// A list with nothing in it, which is what a result with nothing to show returns.
    public static var empty: IntentItemCollection<Item> {
        return IntentItemCollection(promptLabel: nil, usesIndexedCollation: false, items: [])
    }
}

/// A section of a list of items a result hands back.
public struct IntentItemSection<Item> where Item: _IntentValue {
    public let title: LocalizedStringResource?
    public let subtitle: LocalizedStringResource?
    public let image: DisplayRepresentation.Image?
    public let items: [Item.ValueType]


    /// The builder of a list of sections, under the name the framework nests it by: the
    /// framework declares `IntentItemSection.Builder` as an enum inside the type
    /// (`arm64e-apple-macos.swiftinterface:5003-5007`), and this module keeps one builder and
    /// names it here the way `IntentItem.Builder` already is (`Items.swift:18`). A typealias
    /// and not a second declaration: it is the same `IntentItemSectionBuilder`, and the row
    /// the ledger carries is a name this module has to answer to.
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

    /// What the section is described as, which is its own title.
    public var description: String { return title.map { CharonLocalized.string(of: $0) } ?? "" }

}

/// A file a result hands back or an intent asks for: the bytes, or a file, with the name and the
/// content type the app gave.
public struct IntentFile: Hashable, Sendable {
    /// Why a file could not be read.
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

    /// The bytes of the file, when the app gave bytes.
    public let data: Data?
    /// The file, when the app gave one.
    public let fileURL: URL?
    /// The name the file is shown with.
    public let filename: String
    /// The content type of the file, which is the identifier the app named.
    public let type: String?
    /// Whether the framework removes the file when the run that made it ends.
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

    /// The content types the framework may write the file as, which is the type the app gave.
    public var availableContentTypes: [String] { return type.map { [$0] } ?? [] }

    /// A file of the given content type that the caller fills in. The framework's own declaration
    /// names only the content type (`IntentFile.data(contentType:)` in the ledger, the 26.2 row), so
    /// this is that shape: an empty file of the type, which the caller writes before it hands the
    /// file on. The form with the bytes is the one below, and is what a caller that already has them
    /// writes.
    public static func data(contentType: String) -> IntentFile {
        return IntentFile(data: Data(), filename: "file", type: contentType)
    }

    public static func data(contentType: String, filename: String = "file",
                            data: @escaping () throws -> Data) -> IntentFile {
        return IntentFile(data: (try? data()) ?? Data(), filename: filename, type: contentType)
    }

    /// The file the intent hands on, written by the caller's own handler into a file the framework
    /// names. The row the framework's own declaration carries is `file(contentType:)`, so the
    /// destination and the handler are the ones a caller passes after it.
    /// A file of the given content type, at a URL the caller writes to. The framework's own
    /// declaration names the content type and the directory and no handler
    /// (`IntentFile.file(contentType:destinationDirectory:)` in the ledger, the 26.2 row): the file
    /// is *at* that URL, so this is the same path the form below computes, and the caller fills it
    /// in. The file is created there, so a caller that writes to it writes to a file that exists.
    public static func file(contentType: String, destinationDirectory: URL? = nil) -> IntentFile {
        let directory = destinationDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = directory.appendingPathComponent("charon-intent-file")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: Data()) }
        return IntentFile(fileURL: url, filename: url.lastPathComponent, type: contentType)
    }

    public static func file(contentType: String, destinationDirectory: URL? = nil,
                            fileHandler: (URL) throws -> Void) -> IntentFile {
        let directory = destinationDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = directory.appendingPathComponent("charon-intent-file")
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
        return TypeDisplayRepresentation(name: CharonLocalized.resource("File"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title)
    }

    public var title: LocalizedStringResource { return CharonLocalized.resource(filename) }

    public var localizedStringResource: LocalizedStringResource { return title }
}

/// A person a parameter carries: a name, a handle, and what the app knows about the person.
public struct IntentPerson: Hashable, Sendable, DisplayRepresentable, _IntentValue {
    /// A handle of a person: what it is and what it is for.
    public struct Handle: Hashable, Sendable, Codable {
        /// What a handle is, which the framework's own labels name.
        public enum Value: String, Hashable, Sendable, Codable {
            case phoneNumber
            case emailAddress
            case applicationDefined
        }

        /// What a handle is for, which the framework's own labels name.
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

        /// What the handle is, which the app named.
        public let value: Value
        /// What the handle is for, which the app named.
        public let label: Label
        /// What the handle is, when the app named its own kind of handle.
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

    /// What is known about a person.
    public enum Identifier: String, Hashable, Sendable, Codable {
        case contact
        case applicationDefined
        case unknown
    }

    /// Which parts of a person's name are known.
    public enum Name: String, Hashable, Sendable, Codable {
        case displayName
        case components
        case unknown
    }

    /// How a person parameter is asked for.
    public enum ParameterMode: String, Hashable, Sendable, Codable {
        case contact
        case email
        case phone
        case emailOrPhone

        public init?(rawValue: String) {
            self.init(rawValue: rawValue)
        }
    }

    /// What is known about the person.
    public let identifier: Identifier
    /// Which parts of the name are known.
    public let name: Name
    /// The handle the person is reached by.
    public let handle: Handle?
    /// The other names the person is known by.
    public let aliases: [String]
    /// Whether the person is the owner of the device.
    public let isMe: Bool
    /// The picture of the person.
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
        return TypeDisplayRepresentation(name: CharonLocalized.resource("Person"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title, image: image)
    }

    public var title: LocalizedStringResource {
        return CharonLocalized.resource(handle?.applicationDefined ?? name.rawValue)
    }

    public var localizedStringResource: LocalizedStringResource { return title }

    public typealias ValueType = IntentPerson
    public typealias UnwrappedType = IntentPerson
    public typealias Specification = EmptyResolverSpecification<IntentPerson>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

/// A way of paying, which an intent carries and a confirmation shows.
public struct IntentPaymentMethod: Sendable, DisplayRepresentable, _IntentValue {
    /// What kind of payment it is.
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

    /// What kind of payment it is.
    public let paymentType: PaymentType
    /// The name the payment method is shown with.
    public let name: String
    /// What the app shows the user to tell the method apart.
    public let identificationHint: String?
    /// The picture of the method.
    public let icon: DisplayRepresentation.Image?

    public init(type: PaymentType, name: String, identificationHint: String? = nil,
                icon: DisplayRepresentation.Image? = nil) {
        self.paymentType = type
        self.name = name
        self.identificationHint = identificationHint
        self.icon = icon
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: CharonLocalized.resource("Payment Method"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title, image: icon)
    }

    public var title: LocalizedStringResource { return CharonLocalized.resource(name) }

    public var localizedStringResource: LocalizedStringResource { return title }

    public typealias ValueType = IntentPaymentMethod
    public typealias UnwrappedType = IntentPaymentMethod
    public typealias Specification = EmptyResolverSpecification<IntentPaymentMethod>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

/// An amount of money in a currency, which an intent carries and a confirmation shows.
public struct IntentCurrencyAmount: Equatable, Hashable, Sendable, DisplayRepresentable, _IntentValue {
    /// The amount, in the currency's own unit.
    public let amount: Decimal
    /// The currency, as the ISO code the app named.
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
        return TypeDisplayRepresentation(name: CharonLocalized.resource("Currency Amount"))
    }

    public var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: title)
    }

    public var title: LocalizedStringResource { return CharonLocalized.resource(currencyCode) }

    public var localizedStringResource: LocalizedStringResource { return title }

    public typealias ValueType = IntentCurrencyAmount
    public typealias UnwrappedType = IntentCurrencyAmount
    public typealias Specification = EmptyResolverSpecification<IntentCurrencyAmount>

    public static var defaultResolverSpecification: Specification { return Specification() }
}

/// The builder of a list of sections, which is what a collection is written with.
@resultBuilder
public enum IntentItemSectionBuilder<Item> where Item: _IntentValue {
    public static func buildBlock() -> [IntentItemSection<Item>] { return [] }

    /// Both variadic overloads the framework declares for a section builder
    /// (arm64e-apple-ios.swiftinterface:5005-5006): a list of sections, and a list of the items
    /// inside one.
    public static func buildBlock(_ sections: IntentItemSection<Item>...) -> [IntentItemSection<Item>] {
        return sections
    }

    public static func buildBlock(_ items: IntentItem<Item>...) -> [IntentItemSection<Item>] {
        return [IntentItemSection(items: items.map { $0.value })]
    }
}
