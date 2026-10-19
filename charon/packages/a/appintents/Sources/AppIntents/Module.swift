import Foundation

enum CharonLocalized {
    static func resource(_ text: String) -> LocalizedStringResource {
        #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
        return LocalizedStringResource(stringLiteral: text)
        #else
        return LocalizedStringResource(text)
        #endif
    }

    static func resource(_ text: String, defaultValue: String) -> LocalizedStringResource {
        #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
        return LocalizedStringResource(stringLiteral: defaultValue)
        #else
        return LocalizedStringResource(text, defaultValue: defaultValue)
        #endif
    }

    static func string(of resource: LocalizedStringResource) -> String {
        #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
        return table(resource) ?? resource.key
        #else
        return table(resource) ?? resource.defaultValue ?? resource.key
        #endif
    }

    private static func bundle(_ description: LocalizedStringResource.BundleDescription) -> Bundle? {
        switch description {
        case .main: return Bundle.main
        case .forClass(let aClass): return Bundle(for: aClass)
        case .atURL(let url): return Bundle(path: url.path)
        @unknown default: return nil
        }
    }

    private static func table(_ resource: LocalizedStringResource) -> String? {
        guard let bundle = bundle(resource.bundle) else { return nil }
        let name = resource.table ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
        guard let name = name else { return nil }
        let found: String = bundle.localizedString(forKey: resource.key, value: "", table: name)
        return found.isEmpty ? nil : found
    }
}
