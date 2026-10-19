import Foundation

// The text a localized string shows. It is read from the resource's key and default value rather than
// from a method of the resource's own type, so that the module is the same whether the
// `LocalizedStringResource` in scope is the one this module carries (the port's Foundation overlay
// predates the type) or the one the platform's Foundation brings.
enum CharonLocalized {
    /// A resource of the app's own words, built the way the type in scope is built: the port's own
    /// type takes the string directly, the platform's takes it as a string literal.
    static func resource(_ text: String) -> LocalizedStringResource {
        #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
        return LocalizedStringResource(stringLiteral: text)
        #else
        return LocalizedStringResource(text)
        #endif
    }

    /// A resource with a key and a default value, which is what an interpolation builds. The
    /// platform's own type carries the default value inside its `LocalizationValue`, which its own
    /// initialiser takes, so a value with no table of its own is the resource the app wrote.
    static func resource(_ text: String, defaultValue: String) -> LocalizedStringResource {
        #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
        // the platform's own type has no initialiser that takes a separate default value - its
        // interpolation is `String.LocalizationValue`'s, which is not constructible from here - and
        // the words an interpolation writes are the resource either way
        return LocalizedStringResource(stringLiteral: defaultValue)
        #else
        return LocalizedStringResource(text, defaultValue: defaultValue)
        #endif
    }

    /// What is shown for a resource: what the string table has for the key, and the default value
    /// the caller wrote, or the key, which is what a table with no entry for it answers.
    static func string(of resource: LocalizedStringResource) -> String {
        #if CHARON_APPINTENTS_CARRIES_LOCALIZED_STRING
        // the platform's own type keeps its default value inside the resource and offers no
        // accessor for it, so what is shown here is the key: which is what the framework shows for a
        // key no table has, and what a caller that wrote a literal wrote anyway
        return table(resource) ?? resource.key
        #else
        return table(resource) ?? resource.defaultValue ?? resource.key
        #endif
    }

    /// The bundle a resource's own `BundleDescription` names. Both the type this module carries and
    /// the platform's are the same three cases, and each answers a `Bundle` here over the release's
    /// own - the type carries no `url` of its own, which is what the host differential found.
    private static func bundle(_ description: LocalizedStringResource.BundleDescription) -> Bundle? {
        switch description {
        case .main: return Bundle.main
        case .forClass(let aClass): return Bundle(for: aClass)
        case .atURL(let url): return Bundle(path: url.path)
        @unknown default: return nil
        }
    }

    /// What the string table the resource names has for its key, over the release's own
    /// `Bundle.localizedString(forKey:value:table:)`, which answers with an empty string for a key it
    /// has no entry for.
    private static func table(_ resource: LocalizedStringResource) -> String? {
        guard let bundle = bundle(resource.bundle) else { return nil }
        let name = resource.table ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
        guard let name = name else { return nil }
        let found: String = bundle.localizedString(forKey: resource.key, value: "", table: name)
        return found.isEmpty ? nil : found
    }
}

