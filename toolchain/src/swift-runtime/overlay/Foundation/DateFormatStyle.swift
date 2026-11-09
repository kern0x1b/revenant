import Foundation

public protocol FormatStyle<FormatInput, FormatOutput>: Codable, Hashable {
    associatedtype FormatInput
    associatedtype FormatOutput

    func format(_ value: FormatInput) -> FormatOutput
    func locale(_ locale: Locale) -> Self
}

extension FormatStyle {
    public func locale(_ locale: Locale) -> Self {
        return self
    }
}

public struct FormatStyleCapitalizationContext: Codable, Hashable, Sendable {
    fileprivate enum Option: Int, Codable, Hashable, Sendable {
        case unknown = 0
        case standalone = 1
        case listItem = 2
        case beginningOfSentence = 3
        case middleOfSentence = 4
    }

    fileprivate let option: Option

    fileprivate init(option: Option) {
        self.option = option
    }

    public static let unknown = FormatStyleCapitalizationContext(option: .unknown)
    public static let standalone = FormatStyleCapitalizationContext(option: .standalone)
    public static let listItem = FormatStyleCapitalizationContext(option: .listItem)
    public static let beginningOfSentence = FormatStyleCapitalizationContext(option: .beginningOfSentence)
    public static let middleOfSentence = FormatStyleCapitalizationContext(option: .middleOfSentence)

    fileprivate var formattingContext: Formatter.Context {
        switch option {
        case .unknown: return .unknown
        case .standalone: return .standalone
        case .listItem: return .listItem
        case .beginningOfSentence: return .beginningOfSentence
        case .middleOfSentence: return .middleOfSentence
        }
    }
}

extension Date {
    public struct FormatStyle: Codable, Hashable, Sendable {
        public struct DateStyle: Codable, Hashable, Sendable {
            fileprivate let rawValue: Int

            fileprivate init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public static let omitted = DateStyle(rawValue: 0)
            public static let numeric = DateStyle(rawValue: 1)
            public static let abbreviated = DateStyle(rawValue: 2)
            public static let long = DateStyle(rawValue: 3)
            public static let complete = DateStyle(rawValue: 4)

            fileprivate var skeleton: String {
                switch rawValue {
                case 1: return "yMd"
                case 2: return "yMMMd"
                case 3: return "yMMMMd"
                case 4: return "yMMMMEEEEd"
                default: return ""
                }
            }
        }

        public struct TimeStyle: Codable, Hashable, Sendable {
            fileprivate let rawValue: Int

            fileprivate init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public static let omitted = TimeStyle(rawValue: 0)
            public static let shortened = TimeStyle(rawValue: 1)
            public static let standard = TimeStyle(rawValue: 2)
            public static let complete = TimeStyle(rawValue: 3)

            fileprivate var skeleton: String {
                switch rawValue {
                case 1: return "jmm"
                case 2: return "jmmss"
                case 3: return "jmmssz"
                default: return ""
                }
            }
        }

        public var locale: Locale
        public var timeZone: TimeZone
        public var calendar: Calendar
        public var capitalizationContext: FormatStyleCapitalizationContext
        fileprivate var dateStyle: DateStyle
        fileprivate var timeStyle: TimeStyle

        public init(date: DateStyle? = nil, time: TimeStyle? = nil, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            if date == nil && time == nil {
                self.dateStyle = .numeric
                self.timeStyle = .shortened
            } else {
                self.dateStyle = date ?? .omitted
                self.timeStyle = time ?? .omitted
            }
            self.locale = locale
            self.calendar = calendar
            self.timeZone = timeZone
            self.capitalizationContext = capitalizationContext
        }

        public func format(_ value: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.formattingContext = capitalizationContext.formattingContext
            formatter.dateFormat = pattern()
            return formatter.string(from: value)
        }

        private func patternLocaleIdentifier() -> String {
            let parts = locale.identifier.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
            var keywords = parts.count > 1 ? parts[1].split(separator: ";").filter { !$0.hasPrefix("calendar=") }.map(String.init) : []
            keywords.append("calendar=" + calendar.identifier.icuCalendarKeyword)
            return String(parts[0]) + "@" + keywords.joined(separator: ";")
        }

        private func pattern() -> String {
            let skeleton = dateStyle.skeleton + timeStyle.skeleton
            if let best = icuBestPattern(skeleton: skeleton, localeIdentifier: patternLocaleIdentifier()) {
                return best
            }
            return DateFormatter.dateFormat(fromTemplate: skeleton, options: 0, locale: locale) ?? skeleton
        }

        public func locale(_ locale: Locale) -> FormatStyle {
            var copy = self
            copy.locale = locale
            return copy
        }

    }

    public func formatted(date: FormatStyle.DateStyle, time: FormatStyle.TimeStyle) -> String {
        return FormatStyle(date: date, time: time).format(self)
    }

    public func formatted() -> String {
        return FormatStyle(date: .numeric, time: .shortened).format(self)
    }

}

extension Equatable where Self == Date {
    public func formatted<F: FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Date {
        return format.format(self)
    }
}

extension Date.FormatStyle: FormatStyle {
    public typealias FormatInput = Date
    public typealias FormatOutput = String
}

extension FormatStyle where Self == Date.FormatStyle {
    public static var dateTime: Date.FormatStyle {
        return Date.FormatStyle()
    }
}

extension Calendar.Identifier {
    fileprivate var icuCalendarKeyword: String {
        switch self {
        case .gregorian: return "gregorian"
        case .buddhist: return "buddhist"
        case .chinese: return "chinese"
        case .coptic: return "coptic"
        case .ethiopicAmeteMihret: return "ethiopic"
        case .ethiopicAmeteAlem: return "ethiopic-amete-alem"
        case .hebrew: return "hebrew"
        case .iso8601: return "iso8601"
        case .indian: return "indian"
        case .islamic: return "islamic"
        case .islamicCivil: return "islamic-civil"
        case .islamicTabular: return "islamic-tbla"
        case .islamicUmmAlQura: return "islamic-umalqura"
        case .japanese: return "japanese"
        case .persian: return "persian"
        case .republicOfChina: return "roc"
        @unknown default: return "gregorian"
        }
    }
}

private typealias ICUPatternGeneratorOpen = @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> OpaquePointer?
private typealias ICUPatternGeneratorBestPattern = @convention(c) (OpaquePointer, UnsafePointer<UInt16>, Int32, UInt32, UnsafeMutablePointer<UInt16>, Int32, UnsafeMutablePointer<Int32>) -> Int32
private typealias ICUPatternGeneratorClose = @convention(c) (OpaquePointer) -> Void

private func icuFunction<T>(_ name: String, as type: T.Type) -> T {
    guard let library = dlopen("/usr/lib/libicucore.dylib", RTLD_LAZY), let symbol = dlsym(library, name) else {
        fatalError("libicucore does not export \(name)")
    }
    return unsafeBitCast(symbol, to: type)
}

private let icuPatternGeneratorOpen = icuFunction("udatpg_open", as: ICUPatternGeneratorOpen.self)
private let icuPatternGeneratorBestPattern = icuFunction("udatpg_getBestPatternWithOptions", as: ICUPatternGeneratorBestPattern.self)
private let icuPatternGeneratorClose = icuFunction("udatpg_close", as: ICUPatternGeneratorClose.self)

private let icuMatchHourMinuteSecondLength: UInt32 = (1 << 11) | (1 << 12) | (1 << 13)

private func icuBestPattern(skeleton: String, localeIdentifier: String) -> String? {
    var status: Int32 = 0
    guard let generator = icuPatternGeneratorOpen(localeIdentifier, &status), status <= 0 else {
        return nil
    }
    defer {
        icuPatternGeneratorClose(generator)
    }
    let input = Array(skeleton.utf16)
    var output = [UInt16](repeating: 0, count: 256)
    let length = Int(icuPatternGeneratorBestPattern(generator, input, Int32(input.count), icuMatchHourMinuteSecondLength, &output, Int32(output.count), &status))
    guard status <= 0, length > 0, length < output.count else {
        return nil
    }
    return String(decoding: output[..<length], as: UTF16.self)
}
