import Foundation

public enum AttributeScopes {
    public struct SwiftUIAttributes {
        public static let font = FontAttribute.self
        public static let foregroundColor = ForegroundColorAttribute.self
        public static let backgroundColor = BackgroundColorAttribute.self
        public static let strikethroughStyle = StrikethroughStyleAttribute.self
        public static let underlineStyle = UnderlineStyleAttribute.self
        public static let kern = KerningAttribute.self
        public static let tracking = TrackingAttribute.self
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
    public static var swiftUI: SwiftUIAttributes.Type { SwiftUIAttributes.self }
}

extension AttributeScopes.SwiftUIAttributes {
    public static func key(of name: String) -> NSAttributedString.Key? {
        switch name {
        case FontAttribute.name: return .font
        case ForegroundColorAttribute.name: return .foregroundColor
        case BackgroundColorAttribute.name: return .backgroundColor
        case StrikethroughStyleAttribute.name: return .strikethroughStyle
        case UnderlineStyleAttribute.name: return .underlineStyle
        case KerningAttribute.name: return .kern
        case TrackingAttribute.name, BaselineOffsetAttribute.name: return nil
        default: return nil
        }
    }
}
