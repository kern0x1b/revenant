//
//  SymbolVariants.swift
//  Eidolon — the variant of a symbol an Image or a Label is drawn with.
//
//  Taken from OpenSwiftUIProject/OpenSwiftUI, Sources/OpenSwiftUICore/View/Image/SymbolVariants.swift,
//  commit efa103755b95bd5a6ab42681a261c7cc66be6f75, MIT (Copyright (c) 2023-2025 Kyle-Ye). Its doc comments come with it.
//  Changed for this port: no availability macros, `package` is internal, the corner radius is a
//  CGFloat, `nonisolated` is dropped (there is no actor isolation here), and the name a variant
//  gives a symbol is what the glyph lookup asks for. Nothing was added: an earlier version of this port
//  carried `EnvironmentValues.symbolBackgroundCornerRadius` and `symbolsGrowToFitBackground`, which no
//  SDK declares and nothing read, and both are gone.
//
//
//  SymbolVariants.swift
//  OpenSwiftUICore
//
//  Audited for 6.5.4
//  Status: Complete
//  ID: 10D838C6E672964CE3DB0EADFD20CA25 (SwiftUICore)

import Foundation

public struct SymbolVariants: Hashable, Sendable {
    private struct Flags: OptionSet, Hashable {
        var rawValue: UInt8

        static var fill: Flags { .init(rawValue: 1 << 0) }

        static var slash: Flags { .init(rawValue: 1 << 1) }

        static var background: Flags { .init(rawValue: 1 << 2) }
    }

    private var flags: Flags

    internal enum Shape: Hashable {
        case circle
        case square
        case rectangle

        internal var suffix: String {
            switch self {
            case .circle: ".circle"
            case .square: ".square"
            case .rectangle: ".rectangle"
            }
        }
    }

    var shape: Shape?

    public static let none: SymbolVariants = .init(flags: [], shape: nil)

    public static let circle: SymbolVariants = .init(flags: [], shape: .circle)

    public static let square: SymbolVariants = .init(flags: [], shape: .square)

    public static let rectangle: SymbolVariants = .init(flags: [], shape: .rectangle)

    public var circle: SymbolVariants {
        SymbolVariants(flags: flags, shape: .circle)
    }

    public var square: SymbolVariants {
        SymbolVariants(flags: flags, shape: .square)
    }

    public var rectangle: SymbolVariants {
        SymbolVariants(flags: flags, shape: .rectangle)
    }

    public static let fill: SymbolVariants = .init(flags: [.fill], shape: nil)

    public var fill: SymbolVariants {
        SymbolVariants(flags: flags.union(.fill), shape: shape)
    }

        public static let background: SymbolVariants = .init(flags: [.background], shape: nil)

        public var background: SymbolVariants {
        SymbolVariants(flags: flags.union(.background), shape: shape)
    }

    public static let slash: SymbolVariants = .init(flags: [.slash], shape: nil)

    public var slash: SymbolVariants {
        SymbolVariants(flags: flags.union(.slash), shape: shape)
    }

    internal mutating func formUnion(_ other: SymbolVariants) {
        flags = flags.union(other.flags)
        shape = other.shape ?? shape
    }

    internal func _normalizedForNameLookup() -> SymbolVariants {
        guard flags.contains(.background) else { return self }
        var newFlags = flags
        newFlags.formSymmetricDifference(.fill)
        newFlags.remove(.background)
        return SymbolVariants(flags: newFlags, shape: nil)
    }

    public func contains(_ other: SymbolVariants) -> Bool {
        flags.contains(other.flags) && (shape == other.shape || other.shape == nil)
    }

    internal func shapeVariantName(name: String) -> String? {
        guard let shape else { return nil }
        return name + shape.suffix
    }
}

extension SymbolVariants.Shape {
    internal func path(in rect: CGRect, cornerRadius: CGFloat?) -> Path {
        switch self {
        case .circle:
            return Path(ellipseIn: rect)
        case .square, .rectangle:
            let radius: Double
            if let cornerRadius {
                radius = min(max(cornerRadius, 0), 0.5)
            } else {
                radius = 0.225
            }
            return Path(
                roundedRect: rect,
                cornerRadius: radius * min(rect.width, rect.height)
            )
        }
    }
}

extension View {

    public func symbolVariant(_ variant: SymbolVariants) -> some View {
        transformEnvironment(\.symbolVariants) {
            $0.formUnion(variant)
        }
    }
}

private struct SymbolVariantsKey: EnvironmentKey {
    static var defaultValue: SymbolVariants { .none }
}

private struct SymbolBackgroundCornerRadiusKey: EnvironmentKey {
    static var defaultValue: CGFloat? { nil }
}

private struct SymbolsGrowToFitBackgroundKey: EnvironmentKey {
    static var defaultValue: Bool { false }
}

extension EnvironmentValues {

    public var symbolVariants: SymbolVariants {
        get { self[SymbolVariantsKey.self] }
        set { self[SymbolVariantsKey.self] = newValue }
    }
}
