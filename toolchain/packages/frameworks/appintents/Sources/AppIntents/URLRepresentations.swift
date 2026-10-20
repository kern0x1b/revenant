import Foundation

public protocol CustomURLRepresentationParameterConvertible {
    var urlRepresentationParameter: String { get }
}

public protocol URLRepresentableEntity: AppEntity, CustomURLRepresentationParameterConvertible {
    associatedtype URLRepresentation
    var urlRepresentation: URLRepresentation { get }
}

public protocol URLRepresentableEnum: AppEnum, CustomURLRepresentationParameterConvertible {
    associatedtype URLRepresentation
    var urlRepresentation: URLRepresentation { get }
}

public protocol URLRepresentableIntent: AppIntent {
    associatedtype URLRepresentation
    var urlRepresentation: URLRepresentation { get }
}

public struct EntityURLRepresentation<Entity>: ExpressibleByStringInterpolation where Entity: AppEntity {
    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public init(stringLiteral value: String) {
        self.init(URL(string: value) ?? RevenantURL.placeholder)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.url)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var identifier = ""
        fileprivate var url: URL { return RevenantURL.make(path: identifier, query: literal) }

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

        public enum Token: Hashable {
            case id

            public var value: String { return "id" }


        }
    }
}

public struct EnumURLRepresentation<Enum>: ExpressibleByStringInterpolation where Enum: AppEnum {
    public struct EnumSingleURLRepresentation: ExpressibleByStringInterpolation {
        public let url: URL

        public init(_ url: URL) {
            self.url = url
        }

        public init(stringLiteral value: String) {
            self.init(URL(string: value) ?? RevenantURL.placeholder)
        }

        public init(stringInterpolation: StringInterpolation) {
            self.init(stringInterpolation.url)
        }

        public struct StringInterpolation: StringInterpolationProtocol {
            public typealias StringLiteralType = String

            fileprivate var literal = ""
            fileprivate var rawValue = ""
            fileprivate var url: URL { return RevenantURL.make(path: rawValue, query: literal) }

            public init(literalCapacity: Int, interpolationCount: Int) {
                literal.reserveCapacity(literalCapacity)
            }

            public mutating func appendLiteral(_ literal: String) {
                self.literal += literal
            }

            public mutating func appendInterpolation(_ token: Token) {
                rawValue = token.value
            }

            public enum Token: Hashable {
                case rawValue

                public var value: String { return "rawValue" }


            }
        }
    }

    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public init(stringLiteral value: String) {
        self.init(URL(string: value) ?? RevenantURL.placeholder)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.url)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var rawValue = ""
        fileprivate var url: URL { return RevenantURL.make(path: rawValue, query: literal) }

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

        public enum Token: Hashable {
            case rawValue

            public var value: String { return "rawValue" }


        }
    }
}

public struct IntentURLRepresentation<Intent>: ExpressibleByStringInterpolation where Intent: AppIntent {
    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public init(stringLiteral value: String) {
        self.init(URL(string: value) ?? RevenantURL.placeholder)
    }

    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.url)
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        fileprivate var literal = ""
        fileprivate var url: URL { return RevenantURL.make(path: literal, query: "") }

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

public enum RevenantURL {
    public static let scheme = "appintents"

    public static func make(path: String, query: String) -> URL {
        var text = "\(scheme)://\(path)"
        let literal = query.trimmingCharacters(in: CharacterSet(charactersIn: "/?#"))
        if !literal.isEmpty { text += "?\(literal)" }
        return URL(string: text) ?? placeholder
    }

    public static let placeholder = URL(string: "\(scheme)://")!

    public static var handler: ((URL) -> Bool)?

    public static func open(_ url: URL) {
        _ = handler?(url)
    }

    public static func identifier(from url: URL) -> String {
        guard url.scheme == scheme else { return url.absoluteString }
        var path = url.path
        if path.hasPrefix("/") { path = String(path.dropFirst()) }
        return url.query.map { "\(path)?\($0)" } ?? path
    }
}
