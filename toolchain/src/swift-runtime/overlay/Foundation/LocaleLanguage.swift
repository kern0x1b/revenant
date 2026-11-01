import Foundation

extension Locale {
    public struct LanguageCode: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }

        public init(stringLiteral value: String) {
            self.identifier = value
        }

        public init(from decoder: any Decoder) throws {
            self.identifier = try decoder.singleValueContainer().decode(String.self)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(identifier)
        }
    }

    public struct Script: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }

        public init(stringLiteral value: String) {
            self.identifier = value
        }

        public init(from decoder: any Decoder) throws {
            self.identifier = try decoder.singleValueContainer().decode(String.self)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(identifier)
        }
    }

    public struct Region: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        public let identifier: String

        public init(_ identifier: String) {
            self.identifier = identifier
        }

        public init(stringLiteral value: String) {
            self.identifier = value
        }

        public init(from decoder: any Decoder) throws {
            self.identifier = try decoder.singleValueContainer().decode(String.self)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(identifier)
        }
    }

    public struct Language: Hashable, Codable, Sendable {
        public struct Components: Hashable, Codable, Sendable {
            public var languageCode: LanguageCode?
            public var script: Script?
            public var region: Region?

            private enum CodingKeys: String, CodingKey {
                case languageCode = "languageCode"
                case script = "script"
                case region = "region"
            }

            public init(languageCode: LanguageCode? = nil, script: Script? = nil, region: Region? = nil) {
                self.languageCode = languageCode
                self.script = script
                self.region = region
            }
        }

        private let parts: Components

        public init(components: Components) {
            self.parts = Language.completed(components)
        }

        public init(languageCode: LanguageCode? = nil, script: Script? = nil, region: Region? = nil) {
            self.parts = Language.completed(Components(languageCode: languageCode, script: script, region: region))
        }

        public init(identifier: String) {
            self.parts = Language.completed(Language.components(of: identifier))
        }

        public var languageCode: LanguageCode? {
            return parts.languageCode
        }

        public var script: Script? {
            return parts.script
        }

        public var region: Region? {
            return parts.region
        }

        public var characterDirection: LanguageDirection {
            return Locale.characterDirection(forLanguage: parts.languageCode?.identifier ?? "")
        }

        public var lineLayoutDirection: LanguageDirection {
            return Locale.lineDirection(forLanguage: parts.languageCode?.identifier ?? "")
        }

        private enum CodingKeys: String, CodingKey {
            case components
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.parts = try container.decode(Components.self, forKey: .components)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(parts, forKey: .components)
        }

        private static func completed(_ components: Components) -> Components {
            guard components.script == nil, let code = components.languageCode, !code.identifier.isEmpty else {
                return components
            }
            var result = components
            result.script = likelyScript(language: code.identifier, region: components.region?.identifier)
            return result
        }

        private static func likelyScript(language: String, region: String?) -> Script? {
            let input = region.map { language + "_" + $0 } ?? language
            guard let maximal = likelySubtags(input) else {
                return nil
            }
            return maximal.split(separator: "_").dropFirst().first(where: { $0.count == 4 }).map { Script(String($0)) }
        }

        private static func likelySubtags(_ locale: String) -> String? {
            var output = [CChar](repeating: 0, count: 256)
            var status: Int32 = 0
            let length = Int(icuAddLikelySubtags(locale, &output, Int32(output.count), &status))
            guard status <= 0, length > 0, length < output.count else {
                return nil
            }
            return String(decoding: output[..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }

        private static func components(of identifier: String) -> Components {
            let base = identifier.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
            var subtags = base.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
            var result = Components()
            if let first = subtags.first, first.count >= 2, first.count <= 3, first.allSatisfy({ $0.isASCII && $0.isLetter }) {
                result.languageCode = LanguageCode(first.lowercased())
                subtags.removeFirst()
            }
            for subtag in subtags {
                if subtag.count == 1 {
                    break
                }
                if result.script == nil && result.region == nil && subtag.count == 4 && subtag.allSatisfy({ $0.isASCII && $0.isLetter }) {
                    result.script = Script(subtag.prefix(1).uppercased() + subtag.dropFirst().lowercased())
                } else if result.region == nil && isRegionSubtag(subtag) {
                    result.region = Region(subtag.uppercased())
                }
            }
            return result
        }

        private static func isRegionSubtag(_ subtag: String) -> Bool {
            if subtag.count == 2 {
                return subtag.allSatisfy({ $0.isASCII && $0.isLetter })
            }
            return subtag.count == 3 && subtag.allSatisfy({ $0.isASCII && $0.isNumber })
        }
    }

    public enum MeasurementSystem: Hashable, Sendable, CustomDebugStringConvertible {
        case metric
        case uk
        case us

        public var debugDescription: String {
            switch self {
            case .metric: return "metric"
            case .uk: return "uksystem"
            case .us: return "ussystem"
            }
        }
    }

    public var language: Language {
        return Language(identifier: identifier)
    }

    public var region: Region? {
        return language.region
    }

    public var measurementSystem: MeasurementSystem {
        switch (self as NSLocale).object(forKey: NSLocale.Key.measurementSystem) as? String {
        case "U.S."?:
            return .us
        case "U.K."?:
            return .uk
        default:
            return .metric
        }
    }
}

private typealias ICULikelySubtags = @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<CChar>, Int32, UnsafeMutablePointer<Int32>) -> Int32

private let icuAddLikelySubtags: ICULikelySubtags = {
    guard let library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY), let symbol = dlsym(library, "uloc_addLikelySubtags") else {
        fatalError("libicucore does not export uloc_addLikelySubtags")
    }
    return unsafeBitCast(symbol, to: ICULikelySubtags.self)
}()
