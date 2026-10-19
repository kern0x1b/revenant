import Foundation

public protocol DisplayRepresentable: InstanceDisplayRepresentable, TypeDisplayRepresentable {}

public protocol TypeDisplayRepresentable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { get }
}

public protocol InstanceDisplayRepresentable: CustomLocalizedStringResourceConvertible {
    var displayRepresentation: DisplayRepresentation { get }

    var localizedStringResource: LocalizedStringResource { get }
}

extension InstanceDisplayRepresentable {
    public var localizedStringResource: LocalizedStringResource {
        return displayRepresentation.title
    }
}

public protocol CaseDisplayRepresentable: CustomLocalizedStringResourceConvertible, CaseIterable, Hashable {
    static var caseDisplayRepresentations: [DisplayRepresentation] { get }
    var localizedStringResource: LocalizedStringResource { get }
}

public protocol StaticDisplayRepresentable: CaseDisplayRepresentable, TypeDisplayRepresentable {}

public struct TypeDisplayRepresentation: ExpressibleByStringLiteral {
    public typealias NumericFormat = LocalizedStringResource

    public var name: LocalizedStringResource
    public var numericFormat: LocalizedStringResource?
    public var synonyms: [LocalizedStringResource]

    public init(name: LocalizedStringResource, numericFormat: LocalizedStringResource? = nil) {
        self.name = name
        self.numericFormat = numericFormat
        self.synonyms = []
    }

    public init(name: LocalizedStringResource, numericFormat: LocalizedStringResource? = nil,
                synonyms: [LocalizedStringResource] = []) {
        self.name = name
        self.numericFormat = numericFormat
        self.synonyms = synonyms
    }

    public init(_ name: LocalizedStringResource) {
        self.init(name: name)
    }

    public init(stringLiteral value: String) {
        self.init(name: CharonLocalized.resource(value))
    }

    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String
}

public struct DisplayRepresentation: ExpressibleByStringLiteral, Equatable {
    public var title: LocalizedStringResource
    public var subtitle: LocalizedStringResource?
    public var image: Image?
    public var synonyms: [LocalizedStringResource]

    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: Image? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.synonyms = []
    }

    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: Image? = nil,
                synonyms: [LocalizedStringResource] = []) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.synonyms = synonyms
    }

    public init(stringLiteral value: String) {
        self.init(title: CharonLocalized.resource(value))
    }

    public struct Image: Equatable {
        public enum DisplayStyle: Hashable, Sendable {
            case `default`
            case circular
        }

        let data: Data?
        let isTemplate: Bool
        let displayStyle: DisplayStyle
        let url: URL?
        let width: Int?
        let height: Int?

        public init(data: Data, isTemplate: Bool? = nil) {
            self.data = data
            self.isTemplate = isTemplate ?? true
            self.displayStyle = .default
            self.url = nil
            self.width = nil
            self.height = nil
        }

        public init(data: Data, isTemplate: Bool? = nil, displayStyle: DisplayStyle) {
            self.data = data
            self.isTemplate = isTemplate ?? true
            self.displayStyle = displayStyle
            self.url = nil
            self.width = nil
            self.height = nil
        }

        public init(named name: String, isTemplate: Bool? = nil) {
            self.init(data: Data(name.utf8), isTemplate: isTemplate)
        }

        public init(named name: String, isTemplate: Bool? = nil, displayStyle: DisplayStyle) {
            self.init(data: Data(name.utf8), isTemplate: isTemplate, displayStyle: displayStyle)
        }

        public init(systemName: String, isTemplate: Bool? = nil) {
            self.init(data: Data(systemName.utf8), isTemplate: isTemplate)
        }

        public init(url: URL, isTemplate: Bool? = nil) {
            self.data = nil
            self.isTemplate = isTemplate ?? true
            self.displayStyle = .default
            self.url = url
            self.width = nil
            self.height = nil
        }

        public init(url: URL, isTemplate: Bool? = nil, displayStyle: DisplayStyle) {
            self.data = nil
            self.isTemplate = isTemplate ?? true
            self.displayStyle = displayStyle
            self.url = url
            self.width = nil
            self.height = nil
        }

        public init(url: URL, width: Int, height: Int, isTemplate: Bool? = nil) {
            self.data = nil
            self.isTemplate = isTemplate ?? true
            self.displayStyle = .default
            self.url = url
            self.width = width
            self.height = height
        }

        public init(url: URL, width: Int, height: Int, isTemplate: Bool? = nil, displayStyle: DisplayStyle) {
            self.data = nil
            self.isTemplate = isTemplate ?? true
            self.displayStyle = displayStyle
            self.url = url
            self.width = width
            self.height = height
        }

        var systemName: String? { return data.flatMap { String(data: $0, encoding: .utf8) } }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.data = try container.decodeIfPresent(Data.self, forKey: .data)
            self.isTemplate = try container.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? true
            self.displayStyle = .default
            self.url = try container.decodeIfPresent(URL.self, forKey: .url)
            self.width = try container.decodeIfPresent(Int.self, forKey: .width)
            self.height = try container.decodeIfPresent(Int.self, forKey: .height)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(data, forKey: .data)
            try container.encode(isTemplate, forKey: .isTemplate)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encodeIfPresent(width, forKey: .width)
            try container.encodeIfPresent(height, forKey: .height)
        }

        private enum CodingKeys: String, CodingKey {
            case data
            case isTemplate
            case url
            case width
            case height
        }

        public static func == (a: Image, b: Image) -> Bool {
            return a.data == b.data && a.isTemplate == b.isTemplate && a.displayStyle == b.displayStyle
                && a.url == b.url && a.width == b.width && a.height == b.height
        }
    }

    public static func == (lhs: DisplayRepresentation, rhs: DisplayRepresentation) -> Bool {
        return lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.image == rhs.image
    }
}

extension TypeDisplayRepresentable {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: CharonLocalized.resource(CharonNames.simple(Self.self)))
    }
}

extension CaseDisplayRepresentable {
    public var localizedStringResource: LocalizedStringResource {
        return CharonLocalized.resource(String(describing: self))
    }

    public static var caseDisplayRepresentations: [DisplayRepresentation] {
        return allCases.map { DisplayRepresentation(title: CharonLocalized.resource(String(describing: $0))) }
    }
}
