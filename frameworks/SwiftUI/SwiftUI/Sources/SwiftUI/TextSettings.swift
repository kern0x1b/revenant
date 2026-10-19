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

import Foundation

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

    public static let automatic: TypesettingLanguage = .init(storage: .automatic)

    public static func explicit(_ language: String) -> TypesettingLanguage {
        .init(storage: .explicit(language, .modifyFont))
    }
}

extension TypesettingLanguage {
    static let contentAware: TypesettingLanguage = .init(storage: .contentAware)
}

extension Text {

        public struct Scale: Sendable, Hashable {
        internal enum Storage: UInt8, Hashable, Sendable {
            case `default`
            case secondary
        }

        internal var storage: Text.Scale.Storage

        internal init(storage: Text.Scale.Storage) {
            self.storage = storage
        }

        public static let `default`: Text.Scale = .init(storage: .default)

        public static let secondary: Text.Scale = .init(storage: .secondary)
    }
}

extension Text.Scale {
    static let secondaryRatio: Double = 12.0 / 17.0
}

extension View {
}

struct TextScaleKey: EnvironmentKey {
    static var defaultValue: Text.Scale? { nil }
}

extension EnvironmentValues {
    public var textScale: Text.Scale? {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

extension Text {
    public func typesettingLanguage(_ language: TypesettingLanguage, isEnabled: Bool = true) -> some View {
        ignored(self, "typesettingLanguage", "iOS 6 typesets in the system language and has no setting for it")
    }


    public func textVariant<V: TextVariantPreference>(_ preference: V) -> some View {
        ignored(self, "textVariant", "iOS 6 has no width variants of a text")
    }

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
    public func typesettingLanguage(_ language: TypesettingLanguage, isEnabled: Bool = true) -> some View {
        ignored(self, "typesettingLanguage", "iOS 6 typesets in the system language and has no setting for it")
    }

    public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { environment in
            if isEnabled { environment.textScale = scale }
        }, onUpdate: nil))
    }

    public func textVariant<V: TextVariantPreference>(_ preference: V) -> some View {
        ignored(self, "textVariant", "iOS 6 has no width variants of a text")
    }
}

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
    public struct WritingDirectionStrategy: Hashable {
        let name: String
        public static let layoutBased = WritingDirectionStrategy(name: "layoutBased")
        public static let contentBased = WritingDirectionStrategy(name: "contentBased")
        public static let `default` = WritingDirectionStrategy(name: "default")
    }

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
