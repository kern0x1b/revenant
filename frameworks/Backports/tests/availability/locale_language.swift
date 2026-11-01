import Foundation

enum LocaleLanguageUse {
    static func measurementSystem(_ locale: Locale) -> String {
        if #available(iOS 16, tvOS 16, *) {
            let measurementSystems = [
                Locale.MeasurementSystem.us: "us",
                Locale.MeasurementSystem.uk: "uk",
                Locale.MeasurementSystem.metric: "metric"
            ]
            return measurementSystems[locale.measurementSystem] ?? "metric"
        }
        return locale.usesMetricSystem ? "metric" : "us"
    }

    static func fields(_ identifier: String) -> [String: Any?] {
        let languageLocale = Locale(identifier: identifier)
        if #available(iOS 16, tvOS 16, *) {
            return [
                "languageCode": languageLocale.language.languageCode?.identifier,
                "languageScriptCode": languageLocale.language.script?.identifier,
                "languageRegionCode": languageLocale.region?.identifier,
                "textDirection": languageLocale.language.characterDirection == .rightToLeft ? "rtl" : "ltr",
            ]
        }
        return [:]
    }
}
