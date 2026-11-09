import Foundation

let identifiers = [
    "en_US", "en-US", "en", "en_GB", "fr_FR", "de-DE", "ar_EG", "he", "fa_IR", "ur_PK",
    "zh-Hant-TW", "zh_Hans_CN", "sr-Latn-RS", "es-419", "pt_BR", "en_US_POSIX",
    "en-us", "ZH-hant-tw", "fr-CA-u-ca-gregory", "de-u-co-phonebk", "en@currency=USD",
    "und", "", "en-GB-oxendict", "sw-KE", "ja-JP-u-hc-h12",
]

for identifier in identifiers {
    let language = Locale.Language(identifier: identifier)
    print("language", identifier, language.languageCode?.identifier ?? "nil",
          language.script?.identifier ?? "nil", language.region?.identifier ?? "nil",
          language.characterDirection == .rightToLeft, language.lineLayoutDirection == .topToBottom)
    let locale = Locale(identifier: identifier)
    print("locale", identifier, locale.language.languageCode?.identifier ?? "nil",
          locale.language.script?.identifier ?? "nil", locale.region?.identifier ?? "nil",
          locale.measurementSystem)
}

let components = Locale.Language.Components(languageCode: "ar", script: "Arab", region: "EG")
let built = Locale.Language(components: components)
print("components", built.languageCode?.identifier ?? "nil", built.script?.identifier ?? "nil", built.region?.identifier ?? "nil")
let inferred = Locale.Language(components: Locale.Language.Components(languageCode: "he"))
print("inferred", inferred.languageCode?.identifier ?? "nil", inferred.script?.identifier ?? "nil", inferred.region?.identifier ?? "nil")
let direct = Locale.Language(languageCode: "he", script: nil, region: "IL")
print("direct", direct.languageCode?.identifier ?? "nil", direct.script?.identifier ?? "nil", direct.region?.identifier ?? "nil", direct.characterDirection == .rightToLeft)
print("equal", Locale.Language(identifier: "en-US") == Locale.Language(identifier: "en_US"), Locale.Language(identifier: "en") == Locale.Language(identifier: "en-US"))

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(Locale.Language(identifier: "zh-Hant-TW"))
print("json", String(decoding: data, as: UTF8.self))
let decoded = try JSONDecoder().decode(Locale.Language.self, from: data)
print("decoded", decoded == Locale.Language(identifier: "zh-Hant-TW"))

print("ids", Locale.LanguageCode("en").identifier, Locale.Script("Latn").identifier, Locale.Region("US").identifier)
print("literals", ("en" as Locale.LanguageCode).identifier, ("Cyrl" as Locale.Script).identifier, ("RU" as Locale.Region).identifier)
print("systems", Locale.MeasurementSystem.metric == .metric, Locale.MeasurementSystem.us != .uk)
let allSystems = Locale.MeasurementSystem.measurementSystems
print("systemlist", allSystems.map { $0.identifier }, allSystems.map { "\($0)" })
print("systemcompare", Locale.MeasurementSystem("METRIC") == .metric, Locale.MeasurementSystem("METRIC").identifier, ("ussystem" as Locale.MeasurementSystem) == .us, Locale.MeasurementSystem("Foo-Bar") == Locale.MeasurementSystem("foo-bar"))
let systemJSON = try encoder.encode(allSystems)
print("systemjson", String(decoding: systemJSON, as: UTF8.self), try JSONDecoder().decode([Locale.MeasurementSystem].self, from: systemJSON) == allSystems)
print("systemset", Set<Locale.MeasurementSystem>([.metric, "METRIC", "Metric", .us]).count)
var mutatedSystem = Locale.MeasurementSystem.metric
mutatedSystem.identifier = "ussystem"
print("systemmutate", mutatedSystem == .us, mutatedSystem.hashValue == Locale.MeasurementSystem.us.hashValue)
switch Locale(identifier: "en_GB").measurementSystem {
case .metric: print("systemswitch metric")
case .us: print("systemswitch us")
default: print("systemswitch other")
}
let overlong = Locale.Language(languageCode: Locale.LanguageCode(String(repeating: "q", count: 300)))
print("overlong", overlong.languageCode?.identifier.count ?? -1, overlong.script?.identifier ?? "nil", overlong.region?.identifier ?? "nil")

for identifier in identifiers {
    let language = Locale.Language(identifier: identifier)
    print("identifier", identifier, language.maximalIdentifier, language.minimalIdentifier)
}
let partial: [Locale.Language] = [
    Locale.Language(languageCode: nil, script: "Hant", region: nil),
    Locale.Language(languageCode: nil, script: nil, region: "JP"),
    Locale.Language(languageCode: "zh", script: nil, region: "SG"),
    Locale.Language(languageCode: nil, script: nil, region: nil),
    Locale.Language(languageCode: "und", script: "Arab", region: nil),
    overlong,
]
for language in partial {
    print("partial", language.languageCode?.identifier ?? "nil", language.script?.identifier ?? "nil", language.region?.identifier ?? "nil", language.maximalIdentifier, language.minimalIdentifier)
}
let equivalents = [("en", "en-US"), ("en-US", "en-Latn-US"), ("zh-Hant", "zh-TW"), ("zh-Hant-TW", "zh-Hant"), ("en-GB", "en-AU"), ("en", "fr"), ("sr", "sr-Cyrl"), ("sr", "sr-Latn"), ("pt", "pt-PT"), ("pt-BR", "pt-PT"), ("en-US", "en-CA"), ("", "")]
for (first, second) in equivalents {
    print("equivalent", first, second, Locale.Language(identifier: first).isEquivalent(to: Locale.Language(identifier: second)))
}
for identifier in ["zh-Hant-TW", "en", "und", "", "en_US_POSIX", "fr-CA-u-ca-gregory", "sr-Latn-RS"] {
    let parsed = Locale.Language.Components(identifier: identifier)
    print("parsed", identifier, parsed.languageCode?.identifier ?? "nil", parsed.script?.identifier ?? "nil", parsed.region?.identifier ?? "nil")
    let taken = Locale.Language.Components(language: Locale.Language(identifier: identifier))
    print("taken", identifier, taken.languageCode?.identifier ?? "nil", taken.script?.identifier ?? "nil", taken.region?.identifier ?? "nil")
}

