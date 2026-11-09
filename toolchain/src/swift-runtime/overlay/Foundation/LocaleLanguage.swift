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

            public init(identifier: String) {
                self = Language.components(of: identifier)
            }

            public init(language: Language) {
                self = language.parts
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
            let code = components.languageCode?.identifier ?? ""
            guard components.script == nil, !code.isEmpty || components.region != nil else {
                return components
            }
            var result = components
            result.script = likelyScript(language: code.isEmpty ? "und" : code, region: components.region?.identifier)
            return result
        }

        private static func likelyScript(language: String, region: String?) -> Script? {
            let input = region.map { language + "_" + $0 } ?? language
            guard let maximal = likelySubtags(input) else {
                return nil
            }
            return maximal.split(separator: "_").dropFirst().first(where: { $0.count == 4 }).map { Script(String($0)) }
        }

        private static func transformed(_ locale: String, by function: ICULocaleTransform) -> String? {
            var output = [CChar](repeating: 0, count: 256)
            var status: Int32 = 0
            let length = Int(function(locale, &output, Int32(output.count), &status))
            guard status <= 0, length > 0, length < output.count else {
                return nil
            }
            return String(decoding: output[..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }

        private static func likelySubtags(_ locale: String) -> String? {
            return transformed(locale, by: icuAddLikelySubtags)
        }

        private static func joined(_ found: Components, by separator: String) -> String {
            return [found.languageCode?.identifier, found.script?.identifier, found.region?.identifier]
                .compactMap({ $0 }).joined(separator: separator)
        }

        private func identifier(transformedBy function: ICULocaleTransform) -> String {
            guard parts.languageCode != nil || parts.script != nil || parts.region != nil else {
                return ""
            }
            let input = Language.joined(Components(languageCode: parts.languageCode ?? "und", script: parts.script, region: parts.region), by: "_")
            guard let output = Language.transformed(input, by: function) else {
                return Language.joined(parts, by: "-")
            }
            return Language.joined(Language.components(of: output), by: "-")
        }

        public var maximalIdentifier: String {
            return identifier(transformedBy: icuAddLikelySubtags)
        }

        public var minimalIdentifier: String {
            return identifier(transformedBy: icuMinimizeSubtags)
        }

        public func isEquivalent(to language: Language) -> Bool {
            return maximalIdentifier == language.maximalIdentifier
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

    public struct MeasurementSystem: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomDebugStringConvertible {
        public var identifier: String

        public static let metric = MeasurementSystem("metric")
        public static let us = MeasurementSystem("ussystem")
        public static let uk = MeasurementSystem("uksystem")

        public static var measurementSystems: [MeasurementSystem] {
            return [.metric, .us, .uk]
        }

        public init(_ identifier: String) {
            self.identifier = identifier
        }

        public init(stringLiteral value: String) {
            self.identifier = value
        }

        public init(from decoder: any Decoder) throws {
            self.identifier = try decoder.singleValueContainer().decode(String.self)
        }

        public var debugDescription: String {
            return identifier
        }

        public static func == (lhs: MeasurementSystem, rhs: MeasurementSystem) -> Bool {
            return lhs.identifier.lowercased() == rhs.identifier.lowercased()
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(identifier.lowercased())
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(identifier)
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

private typealias ICULocaleTransform = @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<CChar>, Int32, UnsafeMutablePointer<Int32>) -> Int32

private func icuLocaleTransform(_ name: String) -> ICULocaleTransform {
    guard let library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY), let symbol = dlsym(library, name) else {
        fatalError("libicucore does not export \(name)")
    }
    return unsafeBitCast(symbol, to: ICULocaleTransform.self)
}

private let icuAddLikelySubtags = icuLocaleTransform("uloc_addLikelySubtags")

private let icuMinimizeSubtags = icuLocaleTransform("uloc_minimizeSubtags")
