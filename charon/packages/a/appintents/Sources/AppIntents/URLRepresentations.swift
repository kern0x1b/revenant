// The URL forms of entities, enums and intents: the string a shortcut or a donation writes an
// identifier as, and what is read back from it.
//
// The framework's own URL for an entity is `<scheme>://<type>/<id>`, the scheme being the framework's
// own. On this port the scheme is the one the module's own identifiers carry, and reading one back
// gives the identifier it names - the same value the entity's `id` is, which is what the framework
// hands the app either way.

import Foundation

/// A type whose own parameter is written as a URL, which is how a shortcut hands a value on.
public protocol CustomURLRepresentationParameterConvertible {
    var urlRepresentationParameter: String { get }
}

/// An entity that has a URL of its own.
public protocol URLRepresentableEntity: AppEntity, CustomURLRepresentationParameterConvertible {
    associatedtype URLRepresentation
    var urlRepresentation: URLRepresentation { get }
}

/// An enum that has a URL of its own.
public protocol URLRepresentableEnum: AppEnum, CustomURLRepresentationParameterConvertible {
    associatedtype URLRepresentation
    var urlRepresentation: URLRepresentation { get }
}

/// An intent that has a URL of its own, which is how a widget or a shortcut names it.
public protocol URLRepresentableIntent: AppIntent {
    associatedtype URLRepresentation
    var urlRepresentation: URLRepresentation { get }
}

/// The URL of an entity, written as a string with a hole for the identifier.
public struct EntityURLRepresentation<Entity>: ExpressibleByStringInterpolation where Entity: AppEntity {
    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public init(stringLiteral value: String) {
        self.init(URL(string: value) ?? CharonURL.placeholder)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.url)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var identifier = ""
        fileprivate var url: URL { return CharonURL.make(path: identifier, query: literal) }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation(_ token: Token) {
            identifier = token.value
        }

        public mutating func appendInterpolation<T>(_ value: T) {
            identifier = String(describing: value)
        }

        /// What may stand in a URL where the identifier goes.
        public enum Token: Hashable {
            /// The entity's own identifier.
            case id

            /// The text the token stands for, which is the identifier the framework writes.
            public var value: String { return "id" }


        }
    }
}

/// The URL of one case of an enum, written as a string with a hole for the case's own value.
public struct EnumURLRepresentation<Enum>: ExpressibleByStringInterpolation where Enum: AppEnum {
    /// One case of an enum on its own, which is what an enum's own URL points at.
    public struct EnumSingleURLRepresentation: ExpressibleByStringInterpolation {
        public let url: URL

        public init(_ url: URL) {
            self.url = url
        }

        public init(stringLiteral value: String) {
            self.init(URL(string: value) ?? CharonURL.placeholder)
        }

        public init(stringInterpolation: StringInterpolation) {
            self.init(stringInterpolation.url)
        }

        public struct StringInterpolation: StringInterpolationProtocol {
            public typealias StringLiteralType = String

            fileprivate var literal = ""
            fileprivate var rawValue = ""
            fileprivate var url: URL { return CharonURL.make(path: rawValue, query: literal) }

            public init(literalCapacity: Int, interpolationCount: Int) {
                literal.reserveCapacity(literalCapacity)
            }

            public mutating func appendLiteral(_ literal: String) {
                self.literal += literal
            }

            public mutating func appendInterpolation(_ token: Token) {
                rawValue = token.value
            }

            /// What may stand in a URL where the case's own value goes.
            public enum Token: Hashable {
                /// The case's own raw value.
                case rawValue

                /// The text the token stands for, which is the raw value the case is written as.
                public var value: String { return "rawValue" }


            }
        }
    }

    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public init(stringLiteral value: String) {
        self.init(URL(string: value) ?? CharonURL.placeholder)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.url)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var rawValue = ""
        fileprivate var url: URL { return CharonURL.make(path: rawValue, query: literal) }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation(_ token: Token) {
            rawValue = token.value
        }

        public mutating func appendInterpolation<T>(_ value: T) {
            rawValue = String(describing: value)
        }

        /// What may stand in a URL where the case's own value goes.
        public enum Token: Hashable {
            /// The case's own raw value.
            case rawValue

            /// The text the token stands for, which is the raw value the case is written as.
            public var value: String { return "rawValue" }


        }
    }
}

/// The URL of an intent, written as a string with a hole for the intent's own name.
public struct IntentURLRepresentation<Intent>: ExpressibleByStringInterpolation where Intent: AppIntent {
    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public init(stringLiteral value: String) {
        self.init(URL(string: value) ?? CharonURL.placeholder)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.url)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var url: URL { return CharonURL.make(path: literal, query: "") }

        public init(literalCapacity: Int, interpolationCount: Int) {
            literal.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.literal += literal
        }

        public mutating func appendInterpolation<T>(_ value: T) {
            literal += String(describing: value)
        }
    }
}

/// The scheme and the form the module's own URLs take: `appintents://<path>` with the literal parts
/// of the string as the query, which is what the framework's own form is with its scheme.
public enum CharonURL {
    /// The scheme every URL the module builds carries.
    public static let scheme = "appintents"

    /// The URL a string with a hole in it stands for.
    public static func make(path: String, query: String) -> URL {
        var text = "\(scheme)://\(path)"
        let literal = query.trimmingCharacters(in: CharacterSet(charactersIn: "/?#"))
        if !literal.isEmpty { text += "?\(literal)" }
        return URL(string: text) ?? placeholder
    }

    /// The URL a caller gets when the string it wrote is not one, which never traps.
    public static let placeholder = URL(string: "\(scheme)://")!

    /// The handler that opens a URL. There is no LaunchServices on these releases to ask, so this is
    /// the port's own seam: a caller that wants a URL opened installs it, and one that does not gets
    /// the open recorded and nothing else.
    public static var handler: ((URL) -> Bool)?

    /// Open a URL, which is what `OpenURLIntent.perform()` does.
    public static func open(_ url: URL) {
        _ = handler?(url)
    }

    /// The identifier a URL of the module's own form names, which is the path with the scheme taken
    /// off and the literal parts dropped.
    public static func identifier(from url: URL) -> String {
        guard url.scheme == scheme else { return url.absoluteString }
        var path = url.path
        if path.hasPrefix("/") { path = String(path.dropFirst()) }
        return url.query.map { "\(path)?\($0)" } ?? path
    }
}
