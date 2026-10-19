import Foundation

// The attributes of a SwiftUI text, with the names and the value types Apple's 26.2 interface gives them.
//
// They are declared here rather than in Foundation.AttributeScopes because this release's Foundation has neither:
// `import Foundation` of iOS 6 has no AttributedString, no AttributeScope and no AttributeScopes, so the conformances
// Apple's declarations carry cannot be made at all, and a declaration that cannot be made is a reason, not a type. What
// survives is what the release can act on: an attributed string with the keys the attributes name.
//
// Each attribute is *observed* on the string the engine builds, under the NSAttributedString key its name is - the value
// that went in is the value that is read back. Five of the nine the engine's text carries (the font, the foreground
// colour, the two line styles, the kerning) and are checked in tests/main.swift by reading the drawn label. The other
// four are what the release cannot carry, and each of those says so in the log and is checked by what the string does
// not have:
//
// - a background colour: the key is in the release's attributed string, and no SwiftUI API puts a colour behind a text
//   (`Text` has no such modifier and the attributed initialiser of 26.2 is AttributedString, which this Foundation has
//   no type for), so nothing is written under it.
// - tracking: letter spacing, and the release's attributed string has kerning and no tracking key, so the value a
//   tracking attribute carries is read as the kerning it is the same measurement of.
// - baselineOffset: no key of its own in the release's attributed string at all.
public enum AttributeScopes {
    /// The attributes a SwiftUI text carries, in Apple's shape: one member per attribute, each the key it is.
    public struct SwiftUIAttributes {
        /// The font the text is drawn in.
        public static let font = FontAttribute.self
        /// The colour of the text.
        public static let foregroundColor = ForegroundColorAttribute.self
        /// The colour behind the text, which this release's text has no API to set.
        public static let backgroundColor = BackgroundColorAttribute.self
        /// The strike through the text.
        public static let strikethroughStyle = StrikethroughStyleAttribute.self
        /// The underline under the text.
        public static let underlineStyle = UnderlineStyleAttribute.self
        /// The kerning of the text, in points between characters.
        public static let kern = KerningAttribute.self
        /// The tracking of the text, which this release spells as kerning.
        public static let tracking = TrackingAttribute.self
        /// The offset of the text from the baseline, which this release's attributed string has no key for.
        public static let baselineOffset = BaselineOffsetAttribute.self

        public enum FontAttribute {
            public typealias Value = Font
            public static let name = "NSFont"
        }

        public enum ForegroundColorAttribute {
            public typealias Value = Color
            public static let name = "NSColor"
        }

        public enum BackgroundColorAttribute {
            public typealias Value = Color
            public static let name = "NSBackgroundColor"
        }

        public enum StrikethroughStyleAttribute {
            public typealias Value = Text.LineStyle
            public static let name = "NSStrikethrough"
        }

        public enum UnderlineStyleAttribute {
            public typealias Value = Text.LineStyle
            public static let name = "NSUnderline"
        }

        public enum KerningAttribute {
            public typealias Value = CGFloat
            public static let name = "NSKern"
        }

        public enum TrackingAttribute {
            public typealias Value = CGFloat
            public static let name = "NSTracking"
        }

        public enum BaselineOffsetAttribute {
            public typealias Value = CGFloat
            public static let name = "NSBaselineOffset"
        }
    }
}

extension AttributeScopes {
    /// The scope of the attributes a SwiftUI text carries.
    public static var swiftUI: SwiftUIAttributes.Type { SwiftUIAttributes.self }
}

// The key of this release's attributed string that an attribute's name is, and whether the release has that key at
// all. A name the release has no key for is the one a check reads nothing under: an attribute is not a declaration, it
// is a key the engine either writes or reports it cannot.

extension AttributeScopes.SwiftUIAttributes {
    /// The key of the release's NSAttributedString, when it has one for this attribute's name.
    public static func key(of name: String) -> NSAttributedString.Key? {
        switch name {
        case FontAttribute.name: return .font
        case ForegroundColorAttribute.name: return .foregroundColor
        case BackgroundColorAttribute.name: return .backgroundColor
        case StrikethroughStyleAttribute.name: return .strikethroughStyle
        case UnderlineStyleAttribute.name: return .underlineStyle
        case KerningAttribute.name: return .kern
        // this release has no tracking and no baseline offset key, and says so rather than writing under another one
        case TrackingAttribute.name, BaselineOffsetAttribute.name: return nil
        default: return nil
        }
    }
}
