// Foundation's `LocalizedStringResource`, carried here for the API to be written in.
//
// Every title, description and dialog of AppIntents is a `LocalizedStringResource`: a key into a
// string table, a default value, a table, a locale and a bundle. The port's Foundation is the
// swift-5.4.3 overlay, which predates the type, and it belongs to the Foundation band
// (24 rows of `coordination/corpus/ledger/Foundation.tsv`, `missing`/`code`: `LocalizedStringResource`,
// `LocalizedStringResource.BundleDescription`, `CustomLocalizedStringResourceConvertible` and their
// members). AppIntents cannot be declared without it, so the module carries the type its own API is
// written in, and this file is the whole of it: when Foundation has the type, this file goes away and
// nothing else here changes, because the declarations name `LocalizedStringResource` unqualified.
//
// The semantics are the ones the header of iOS 16 gives: the resource is a key, and the value shown
// is `defaultValue` when the caller gave one and the key is not in the table, otherwise the string the
// key maps to in `table` of `bundle` for `locale`, otherwise the key itself.

import Foundation

/// A string that is localized: a key, the table to look it up in, a value to show when the key is not
/// there, the locale to look it up for and the bundle that holds the table.
///
/// `@unchecked Sendable` because the release's own `Locale` and `URL` are not `Sendable` in the
/// port's Foundation; the value type holds no mutable state, which is what the conformance is for.
public struct LocalizedStringResource: Hashable, Codable, CustomLocalizedStringResourceConvertible, @unchecked Sendable {
    /// Where the string table is found, the framework's own three cases: the running program's
    /// bundle, the bundle of a class, and the bundle at a URL.
    public enum BundleDescription: Sendable {
        case main
        case forClass(AnyClass)
        case atURL(URL)

        /// The bundle the case names, over the release's own `Bundle(for:)` and `Bundle(url:)`. The
        /// framework's own `BundleDescription` is `Sendable` and nothing else - a class, a main bundle
        /// and a URL are compared by the URL they name, which is what this does.
        public var url: URL {
            switch self {
            case .main: return Bundle.main.bundleURL
            case .forClass(let aClass): return Bundle(for: aClass).bundleURL
            case .atURL(let url): return url
            }
        }
    }

    public typealias Comment = StaticString

    /// The key this resource names.
    public var key: String
    /// The value to show when `key` is not in the table, when the caller gave one. The framework
    /// types it as `String.LocalizationValue`, which is a Foundation type this release's overlay
    /// predates and the Foundation band carries; here it is the text itself.
    public var defaultValue: String?
    /// The name of the string table, `nil` for the table the key itself names.
    public var table: String?
    /// The locale to look the key up for, the program's own unless the caller named one.
    public var locale: Locale
    /// The bundle the table is in, the program's own unless the caller named one.
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

    /// The framework's own convenience: a resource out of another one.
    public init(localized resource: LocalizedStringResource) {
        self = resource
    }

    /// The resource is its own localized string: what a `CustomLocalizedStringResourceConvertible`
    /// hands back is a resource, and here that is this one.
    public var localizedStringResource: LocalizedStringResource { return self }

    /// The value to show, in the order the type's own documentation gives: what the key maps to in the
    /// table for the locale, and the default value or the key when the table has no entry.
    public func localizedString() -> String {
        if let found = CharonLookup.localizedString(key: key, table: table, locale: locale, bundle: bundle) {
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

    /// The string interpolation of a resource: a literal with holes, each hole a resource of its own
    /// or a value written into the default value.
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

/// A type whose own string is a localized string, so that it can be a title or a description.
public protocol CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource { get }
}

extension String: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource { return LocalizedStringResource(self) }
}

/// The bundle lookup, in one place: `Bundle` is what the release has for a table, and an entry the
/// table does not hold comes back as the key, which is what makes the fallback the caller's own
/// default value.
enum CharonLookup {
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
