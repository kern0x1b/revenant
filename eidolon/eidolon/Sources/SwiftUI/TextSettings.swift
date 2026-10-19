//
//  TextSettings.swift
//  Eidolon — the text settings SDK 26.2 added: what language a line is typeset in and what size a
//  variant of a text is drawn at.
//
//  The two types are taken from OpenSwiftUIProject/OpenSwiftUI (MIT, Copyright (c) 2023-2025 Kyle-Ye):
//  Sources/OpenSwiftUICore/View/Text/Typesetting/TypesettingLanguage.swift ("Status: Complete", ID
//  E539E054FF6DF2E95534C4C9F8C35428) and Sources/OpenSwiftUICore/View/Text/Text/Text+Scale.swift
//  ("Status: Complete"), commit efa103755b95bd5a6ab42681a261c7cc66be6f75.
//  Changed for this port: no availability macros, `package` is internal, and a language is named by its
//  identifier because the Foundation this port carries has no `Locale.Language`. Everything below
//  `TypesettingLanguage` is the glue: the modifiers that take these, which Apple's 26.2 interface
//  declares and which are journalled, because iOS 6 draws text with the one system font it has.
//
import Foundation

private let _kCTTextScaleAttributeName = "NSTextScale"
private let _kCTTextScaleSecondary = "NSTextScaleSecondary"

//
//  TypesettingLanguage.swift
//  OpenSwiftUICore
//
//  Audited for 6.5.4
//  Status: Complete
//  ID: E539E054FF6DF2E95534C4C9F8C35428 (SwiftUICore)

import Foundation

// MARK: - TypesettingLanguage

/// Defines how typesetting language is determined for text.
///
/// Use a modifier like ``View/typesettingLanguage(_:isEnabled:)``
/// to specify the typesetting language.
public struct TypesettingLanguage: Sendable, Equatable {
    internal struct Flags: OptionSet {
        internal var rawValue: UInt8

        internal init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        internal static let modifyFont: TypesettingLanguage.Flags = .init(rawValue: 1 << 0)
    }

    internal enum Storage: Equatable {
        case automatic
        case contentAware
        case explicit(String, TypesettingLanguage.Flags)
    }

    internal var storage: TypesettingLanguage.Storage

    /// Automatic language behavior.
    ///
    /// When determining the language to use for typesetting the current UI
    /// language and preferred languages will be considered. For example, if
    /// the current UI locale is for English and Thai is included in the
    /// preferred languages then line heights will be taller to accommodate the
    /// taller glyphs used by Thai.
    public static let automatic: TypesettingLanguage = .init(storage: .automatic)

    /// Use explicit language.
    ///
    /// An explicit language will be used for typesetting. For example, if used
    /// with Thai language the line heights will be as tall as needed to
    /// accommodate Thai.
    ///
    /// - Parameters:
    ///   - language: The language to use for typesetting.
    /// - Returns: A `TypesettingLanguage`.
    public static func explicit(_ language: String) -> TypesettingLanguage {
        .init(storage: .explicit(language, .modifyFont))
    }
}

extension TypesettingLanguage {
    /// Upstream keeps this behind `@_spi(Private)`, and Apple declares no such member in 16.4 or 26.2
    /// (`SwiftUICore.swiftinterface:8758-8762` has `automatic`, `explicit(_:)` and `==` only), so it is
    /// internal here: a form the content itself chooses the language of, which nothing in this port uses.
    static let contentAware: TypesettingLanguage = .init(storage: .contentAware)
}

extension Text {

    /// Defines text scales
    ///
    /// Text scale provides a way to pick a logical text scale
    /// relative to the base font which is used.
        public struct Scale: Sendable, Hashable {
        internal enum Storage: UInt8, Hashable, Sendable {
            case `default`
            case secondary
        }

        internal var storage: Text.Scale.Storage

        internal init(storage: Text.Scale.Storage) {
            self.storage = storage
        }

        /// Defines default text scale
        ///
        /// When specified uses the default text scale.
        public static let `default`: Text.Scale = .init(storage: .default)

        /// Defines secondary text scale
        ///
        /// When specified a uses a secondary text scale.
        public static let secondary: Text.Scale = .init(storage: .secondary)
    }
}

extension Text.Scale {
    /// iOS 6 has no `NSTextScaleSecondary`, and what the attribute is for is the smaller text beside a
    /// larger one — the unit of a price. The release's own smaller label is caption 1 at 12 points
    /// against body's 17 (`apple-backports/facts/UIKit/UIFontTextStyles.md:18,20`), so that ratio is what
    /// a secondary run is drawn at.
    static let secondaryRatio: Double = 12.0 / 17.0
}

// MARK: - View + textScale

extension View {

    /// Applies a text scale to text in the view.
    ///
    /// - Parameters:
    ///   - scale: The text scale to apply.
    ///   - isEnabled: If true the text scale is applied; otherwise text scale
    ///     is unchanged.
    /// - Returns: A view with the specified text scale applied.
}

// MARK: - TextScaleKey

struct TextScaleKey: EnvironmentKey {
    static var defaultValue: Text.Scale? { nil }
}

extension EnvironmentValues {
    /// The size a variant of a text is drawn at. iOS 6 has one font and no variants of it, so a view
    /// that sets it is journalled and the text is drawn at the size the font has.
    public var textScale: Text.Scale? {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

// MARK: - the modifiers Apple's 26.2 interface declares, in the glue to iOS 6

extension Text {
    /// The language a line is typeset in. iOS 6 typesets in the system language with the one system
    /// font, and has no setting for either.

    public func typesettingLanguage(_ language: TypesettingLanguage, isEnabled: Bool = true) -> some View {
        ignored(self, "typesettingLanguage", "iOS 6 typesets in the system language and has no setting for it")
    }


    /// A width variant of a text. The 26.2 API is over a preference, not a variant: the type is
    /// `TextVariantPreference`, with `FixedTextVariant` and `SizeDependentTextVariant` as its two
    /// conformers. iOS 6's one font is the only variant there is.
    public func textVariant<V: TextVariantPreference>(_ preference: V) -> some View {
        ignored(self, "textVariant", "iOS 6 has no width variants of a text")
    }

    /// What VoiceOver reads of this text. The four attributes are in the canon this port runs on
    /// (`apple-backports/UIKit/UIAccessibilitySpeechAttributes.m` and the two siblings), but the
    /// release's VoiceOver reads none of them off an attributed string — see
    /// `apple-backports/facts/UIKit/UIAccessibilitySpeechAttributes.md`.
    public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> some View {
        ignored(self, "speechAlwaysIncludesPunctuation", "the VoiceOver of iOS 6 reads no speech attribute off an attributed string")
    }

    public func speechSpellsOutCharacters(_ value: Bool = true) -> some View {
        ignored(self, "speechSpellsOutCharacters", "the VoiceOver of iOS 6 reads no speech attribute off an attributed string")
    }

    public func speechAdjustedPitch(_ value: Double) -> some View {
        ignored(self, "speechAdjustedPitch", "the VoiceOver of iOS 6 reads no speech attribute off an attributed string")
    }

    public func speechAnnouncementsQueued(_ value: Bool = true) -> some View {
        ignored(self, "speechAnnouncementsQueued", "the VoiceOver of iOS 6 reads no speech attribute off an attributed string")
    }
}

extension View {
    /// The `View` half of the three settings, which Apple's 26.2 declares on `View` and not on `Text`.

    public func typesettingLanguage(_ language: TypesettingLanguage, isEnabled: Bool = true) -> some View {
        ignored(self, "typesettingLanguage", "iOS 6 typesets in the system language and has no setting for it")
    }

    /// The size a run is drawn at: `.secondary` is the release's own smaller label, caption 1 against
    /// body — 12/17, from `apple-backports/facts/UIKit/UIFontTextStyles.md:18,20`.
    public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            if isEnabled { environment.textScale = scale }
        }, onUpdate: nil))
    }

    public func textVariant<V: TextVariantPreference>(_ preference: V) -> some View {
        ignored(self, "textVariant", "iOS 6 has no width variants of a text")
    }
}

/// What a variant of a text is chosen by: a fixed one, or one that follows the size of the view.
public protocol TextVariantPreference {
    var _preference: _TextVariantPreference<Self> { get }
}

public struct _TextVariantPreference<Preference>: Hashable where Preference: TextVariantPreference {}

public struct FixedTextVariant: TextVariantPreference {
    public init() {}
    public var _preference: _TextVariantPreference<FixedTextVariant> { _TextVariantPreference() }
}

public struct SizeDependentTextVariant: TextVariantPreference {
    public init() {}
    public var _preference: _TextVariantPreference<SizeDependentTextVariant> { _TextVariantPreference() }
}

extension TextVariantPreference where Self == FixedTextVariant {
    public static var fixed: FixedTextVariant { FixedTextVariant() }
}

extension TextVariantPreference where Self == SizeDependentTextVariant {
    public static var sizeDependent: SizeDependentTextVariant { SizeDependentTextVariant() }
}

extension Text {
    /// How a run's writing direction is decided: by the layout, by the run's own content, or by the
    /// system default. iOS 6's `NSParagraphStyle` decides it by the writing direction of the script.
    public struct WritingDirectionStrategy: Hashable {
        let name: String
        public static let layoutBased = WritingDirectionStrategy(name: "layoutBased")
        public static let contentBased = WritingDirectionStrategy(name: "contentBased")
        public static let `default` = WritingDirectionStrategy(name: "default")
    }

    /// How a line of a multi-line text is aligned: by the layout, by the writing direction, or by the
    /// system default.
    public struct AlignmentStrategy: Hashable {
        let name: String
        public static let layoutBased = AlignmentStrategy(name: "layoutBased")
        public static let writingDirectionBased = AlignmentStrategy(name: "writingDirectionBased")
        public static let `default` = AlignmentStrategy(name: "default")
    }
}

extension View {
    public func writingDirection(strategy: Text.WritingDirectionStrategy) -> some View {
        ignored(self, "writingDirection", "iOS 6 decides a run's writing direction from its script, and has no setting for it")
    }

    public func multilineTextAlignment(strategy: Text.AlignmentStrategy) -> some View {
        ignored(self, "multilineTextAlignment", "iOS 6 aligns a line by the paragraph style, and has no strategy for it")
    }
}
