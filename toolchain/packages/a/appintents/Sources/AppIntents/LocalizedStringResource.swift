import Foundation

public struct LocalizedStringResource: Hashable, Codable, CustomLocalizedStringResourceConvertible, @unchecked Sendable {
    public enum BundleDescription: Sendable {
        case main
        case forClass(AnyClass)
        case atURL(URL)

        public var url: URL {
            switch self {
            case .main: return Bundle.main.bundleURL
            case .forClass(let aClass): return Bundle(for: aClass).bundleURL
            case .atURL(let url): return url
            }
        }
    }

    public typealias Comment = StaticString

    public var key: String
    public var defaultValue: String?
    public var table: String?
    public var locale: Locale
    public var bundle: BundleDescription

    public init(key: String) {
        self.key = key
        self.defaultValue = nil
        self.table = nil
        self.locale = .current
        self.bundle = .main
    }

    public init(_ keyAndValue: String, defaultValue: String? = nil, table: String? = nil,
                locale: Locale = .current, bundle: BundleDescription = .main, comment: Comment? = nil) {
        self.key = keyAndValue
        self.defaultValue = defaultValue
        self.table = table
        self.locale = locale
        self.bundle = bundle
    }

    public init(_ keyAndValue: String, table: String? = nil, locale: Locale = .current,
                bundle: BundleDescription = .main, comment: Comment? = nil) {
        self.init(keyAndValue, defaultValue: nil, table: table, locale: locale, bundle: bundle, comment: comment)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(stringInterpolation: StringInterpolation) {
        self = stringInterpolation.value
    }

    public init(localized resource: LocalizedStringResource) {
        self = resource
    }

    public var localizedStringResource: LocalizedStringResource { return self }

    public func localizedString() -> String {
        if let found = RevenantLookup.localizedString(key: key, table: table, locale: locale, bundle: bundle) {
            return found
        }
        return defaultValue ?? key
    }

    public var description: String { return localizedString() }

    public static func == (lhs: LocalizedStringResource, rhs: LocalizedStringResource) -> Bool {
        return lhs.key == rhs.key && lhs.defaultValue == rhs.defaultValue && lhs.table == rhs.table
            && lhs.locale == rhs.locale && lhs.bundle.url == rhs.bundle.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(defaultValue)
        hasher.combine(table)
        hasher.combine(locale)
        hasher.combine(bundle.url)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
        try container.encodeIfPresent(table, forKey: .table)
        try container.encode(locale, forKey: .locale)
        try container.encode(bundle.url, forKey: .bundle)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try container.decode(String.self, forKey: .key))
        self.defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
        self.table = try container.decodeIfPresent(String.self, forKey: .table)
        self.locale = try container.decode(Locale.self, forKey: .locale)
        self.bundle = BundleDescription.atURL(try container.decode(URL.self, forKey: .bundle))
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case defaultValue
        case table
        case locale
        case bundle
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var value = LocalizedStringResource(key: "")

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
            flush()
        }

        public mutating func appendInterpolation(_ resource: LocalizedStringResource) {
            literal += resource.localizedString()
            flush()
        }

        public mutating func appendInterpolation(_ value: String) {
            literal += value
            flush()
        }

        public mutating func appendInterpolation(_ value: any CustomLocalizedStringResourceConvertible) {
            literal += value.localizedStringResource.localizedString()
            flush()
        }

        public mutating func appendInterpolation(_ value: Int) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: Int8) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: Int16) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: Int32) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: Int64) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: UInt) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: UInt8) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: UInt16) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: UInt32) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation(_ value: UInt64) { appendInterpolation(String(value)) }
        public mutating func appendInterpolation<T>(_ value: T) { appendInterpolation(String(describing: value)) }

        private mutating func flush() {
            value = LocalizedStringResource(literal, defaultValue: literal)
        }
    }
}

public protocol CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource { get }
}

extension String: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource { return LocalizedStringResource(self) }
}

enum RevenantLookup {
    static func localizedString(key: String, table: String?, locale: Locale?,
                                bundle: LocalizedStringResource.BundleDescription?) -> String? {
        guard let description = bundle else { return nil }
        guard let target = Bundle(path: description.url.path) else { return nil }
        let name = table ?? (target.localizedInfoDictionary?["CFBundleName"] as? String)
        guard let name = name else { return nil }
        let found: String = target.localizedString(forKey: key, value: "", table: name)
        return found == "" ? nil : found
    }
}
