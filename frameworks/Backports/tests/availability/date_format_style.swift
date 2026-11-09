import Foundation

enum DateFormatStyleUse {
    @available(iOS 15.0, *)
    static func accessibilityLabel(_ date: Date?) -> String {
        return "Photo \(date?.formatted(date: .abbreviated, time: .standard) ?? "")"
    }

    @available(iOS 15.0, *)
    static func styles(_ date: Date, locale: Locale) -> [String] {
        var style = Date.FormatStyle(date: .complete, time: .shortened, locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0)!, capitalizationContext: .beginningOfSentence)
        style.locale = locale
        return [
            date.formatted(),
            date.formatted(date: .numeric, time: .omitted),
            date.formatted(date: .long, time: .complete),
            date.formatted(style),
            date.formatted(.dateTime.locale(locale)),
            style.locale(locale).format(date),
        ]
    }
}
