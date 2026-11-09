import Foundation

let moments: [(String, Date)] = [
    ("epoch", Date(timeIntervalSince1970: 0)),
    ("afternoon", Date(timeIntervalSince1970: 1_794_000_000 + 3 * 3600 + 7 * 60 + 5)),
    ("midnight", Date(timeIntervalSince1970: 1_794_052_800)),
    ("noon", Date(timeIntervalSince1970: 1_794_096_000)),
    ("leap", Date(timeIntervalSince1970: 1_709_164_799)),
    ("old", Date(timeIntervalSince1970: -2_000_000_000)),
    ("far", Date(timeIntervalSince1970: 4_100_000_000)),
]

let zones = ["UTC", "America/Los_Angeles", "Asia/Kolkata", "Pacific/Auckland"]
let locales = ["en_US", "en_GB", "de_DE", "fr_FR", "ja_JP", "ru_RU", "zh_CN", "es_ES", "he_IL", "th_TH", "hi_IN", "pt_BR", "tr_TR", "uk_UA", "it_IT", "nl_NL", "pl_PL", "sv_SE"]

let dateStyles: [(String, Date.FormatStyle.DateStyle)] = [("omitted", .omitted), ("numeric", .numeric), ("abbreviated", .abbreviated), ("long", .long), ("complete", .complete)]
let timeStyles: [(String, Date.FormatStyle.TimeStyle)] = [("omitted", .omitted), ("shortened", .shortened), ("standard", .standard), ("complete", .complete)]

for id in locales {
    let locale = Locale(identifier: id)
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = locale
    for zoneName in zones {
        let zone = TimeZone(identifier: zoneName)!
        for (momentName, moment) in moments {
            for (dateName, dateStyle) in dateStyles {
                for (timeName, timeStyle) in timeStyles {
                    if dateName == "omitted" && timeName == "omitted" {
                        continue
                    }
                    let style = Date.FormatStyle(date: dateStyle, time: timeStyle, locale: locale, calendar: calendar, timeZone: zone)
                    print(id, zoneName, momentName, dateName, timeName, style.format(moment).debugDescription)
                }
            }
        }
    }
}

let sample = Date(timeIntervalSince1970: 1_794_000_000 + 3 * 3600 + 7 * 60 + 5)
let zone = TimeZone(identifier: "America/Los_Angeles")!
for id in ["en_US", "de_DE", "ja_JP", "ru_RU"] {
    let locale = Locale(identifier: id)
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = locale
    let empty = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: zone)
    let dateOnly = Date.FormatStyle(date: .abbreviated, locale: locale, calendar: calendar, timeZone: zone)
    let timeOnly = Date.FormatStyle(time: .standard, locale: locale, calendar: calendar, timeZone: zone)
    print("partial", id, empty.format(sample).debugDescription, dateOnly.format(sample).debugDescription, timeOnly.format(sample).debugDescription)
}

let contexts: [(String, FormatStyleCapitalizationContext)] = [("unknown", .unknown), ("standalone", .standalone), ("listItem", .listItem), ("beginningOfSentence", .beginningOfSentence), ("middleOfSentence", .middleOfSentence)]
for id in ["es_ES", "pt_BR", "ca_ES", "nl_NL", "it_IT", "en_US", "de_DE", "fr_FR", "tr_TR"] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: id)
    for (name, context) in contexts {
        let style = Date.FormatStyle(date: .complete, locale: Locale(identifier: id), calendar: calendar, timeZone: zone, capitalizationContext: context)
        print("context", id, name, style.format(sample).debugDescription)
    }
}

let other = Locale(identifier: "de_DE")
var otherCalendar = Calendar(identifier: .gregorian)
otherCalendar.locale = other
let base = Date.FormatStyle(date: .long, time: .shortened, locale: Locale(identifier: "en_US"), calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC")!)
var zoned = base
zoned.timeZone = zone
var buddhist = base
buddhist.calendar = Calendar(identifier: .buddhist)
var sentence = base
sentence.capitalizationContext = .beginningOfSentence
print("modifiers", base.format(sample).debugDescription, base.locale(other).format(sample).debugDescription, zoned.format(sample).debugDescription, buddhist.format(sample).debugDescription, sentence.format(sample).debugDescription)
var calendared = base
calendared.calendar = otherCalendar
print("modifierFields", base.locale(other).locale.identifier, zoned.timeZone.identifier, calendared.calendar.identifier, sentence.capitalizationContext == .beginningOfSentence, base == base, base == base.locale(other), base == zoned)

let calendars: [(String, Calendar.Identifier)] = [("buddhist", .buddhist), ("japanese", .japanese), ("roc", .republicOfChina), ("hebrew", .hebrew), ("islamicCivil", .islamicCivil), ("persian", .persian), ("indian", .indian), ("iso8601", .iso8601)]
for (name, identifier) in calendars {
    for id in ["en_US", "th_TH", "ja_JP"] {
        var calendar = Calendar(identifier: identifier)
        calendar.locale = Locale(identifier: id)
        let style = Date.FormatStyle(date: .long, time: .standard, locale: Locale(identifier: id), calendar: calendar, timeZone: zone)
        print("calendar", name, id, style.format(sample).debugDescription)
    }
}

print("formattedDateTime", sample.formatted(date: .abbreviated, time: .standard).debugDescription == Date.FormatStyle(date: .abbreviated, time: .standard).format(sample).debugDescription)
print("formattedDefault", sample.formatted().debugDescription == Date.FormatStyle(date: .numeric, time: .shortened).format(sample).debugDescription)
print("formattedStyle", sample.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "fr_FR"), calendar: Calendar(identifier: .gregorian), timeZone: zone)).debugDescription)
print("formattedDateTime", sample.formatted(.dateTime).debugDescription == Date.FormatStyle().format(sample).debugDescription)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
func json<T: Encodable>(_ value: T) -> String {
    return String(decoding: try! encoder.encode(value), as: UTF8.self)
}
print("styles", dateStyles.map { json($0.1) }.joined(separator: " "), timeStyles.map { json($0.1) }.joined(separator: " "), contexts.map { json($0.1) }.joined(separator: " "))
let decoder = JSONDecoder()
print("decoded", try decoder.decode(Date.FormatStyle.DateStyle.self, from: Data(#"{"rawValue":3}"#.utf8)) == .long, try decoder.decode(Date.FormatStyle.TimeStyle.self, from: Data(#"{"rawValue":2}"#.utf8)) == .standard, try decoder.decode(FormatStyleCapitalizationContext.self, from: Data(#"{"option":3}"#.utf8)) == .beginningOfSentence)
print("identity", Date.FormatStyle.DateStyle.long == .long, Date.FormatStyle.DateStyle.long == .complete, Date.FormatStyle.TimeStyle.standard.hashValue == Date.FormatStyle.TimeStyle.standard.hashValue, Set<Date.FormatStyle.DateStyle>([.long, .long, .numeric]).count)
