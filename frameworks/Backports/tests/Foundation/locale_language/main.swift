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
