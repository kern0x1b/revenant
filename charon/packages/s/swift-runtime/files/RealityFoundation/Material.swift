// Materials: what an entity is painted with, and the textures it is painted with.
//
// A material is a value. The parameters are stored as they are given — a colour, a number, or
// a texture — and the renderer reads them; this module does not shade anything itself, because
// shading is the renderer's and this port has none until the rendering round.

import simd
import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#else
import AppKit
/// The colour a material takes. This port is iOS, where it is `UIColor`; a host build has no
/// UIKit and `NSColor` stands in for it, which is what RealityKit uses on macOS, so that the
/// same sources can be differential-tested there.
public typealias UIColor = NSColor
#endif

// MARK: - The parameters

/// A number a material is parameterised by: a value, or a texture to read it from.
public enum MaterialScalarParameter: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Hashable {
    case float(Float)
    case texture(TextureResource)

    public init(floatLiteral value: Float) { self = .float(value) }
    public init(integerLiteral value: Int) { self = .float(Float(value)) }

    /// The value, when it is a value rather than a texture.
    public var value: Float? {
        if case .float(let value) = self { return value }
        return nil
    }
}

/// A colour a material is parameterised by, either one value or one per channel.
public enum MaterialColorParameter: ExpressibleByFloatLiteral, Hashable {
    case float(Float)
    case color(CGColor)
    case texture(TextureResource)

    public init(floatLiteral value: Float) { self = .float(value) }
}

// MARK: - Textures

/// A texture a material is painted with: an image, and how to read it.
@MainActor
open class TextureResource {
    /// What the texture's channels mean.
    public enum Semantic: Hashable {
        case raw
        case scalar
        case color
        case hdrColor
        case normal
    }

    /// How the mipmaps are made.
    public enum MipmapsMode: Hashable {
        case none
        case allocatedAndUpdated
        case allocated
    }

    /// The image, in the bytes a texture is uploaded from.
    public private(set) var pixels: [UInt8]
    public private(set) var width: Int
    public private(set) var height: Int
    public private(set) var semantic: Semantic

    public init(pixels: [UInt8], width: Int, height: Int, semantic: Semantic = .color) {
        self.pixels = pixels
        self.width = width
        self.height = height
        self.semantic = semantic
    }

    /// A texture of one colour, which is what `TextureResource.generate` makes.
    public static func generate(from color: CGColor, width: Int = 1, height: Int = 1) -> TextureResource {
        let components = color.components ?? [0, 0, 0, 1]
        let isGrey = (color.colorSpace?.name as String?) == "pattern"
        let scalar = isGrey ? components : [components.count > 0 ? components[0] : 0,
                                                                            components.count > 1 ? components[1] : 0,
                                                                            components.count > 2 ? components[2] : 0,
                                                                            components.count > 3 ? components[3] : 1]
        var pixels: [UInt8] = []
        for _ in 0..<(width * height) { pixels += scalar.map { UInt8(max(0, min(255, $0 * 255))) } }
        return TextureResource(pixels: pixels, width: width, height: height, semantic: .color)
    }

    /// A texture of one number.
    public static func generate(from scalar: Float, width: Int = 1, height: Int = 1) -> TextureResource {
        let byte = UInt8(max(0, min(255, scalar * 255)))
        return TextureResource(pixels: [UInt8](repeating: byte, count: width * height),
                              width: width, height: height, semantic: .scalar)
    }
}

extension TextureResource: Hashable {
    // The identity of a texture is its object, which needs no actor, as the SDK's own
    // `nonisolated` witnesses for `==` and `hash` say.
    nonisolated public static func == (lhs: TextureResource, rhs: TextureResource) -> Bool { lhs === rhs }
    nonisolated public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

// MARK: - The material

/// What an entity's surface is made of.
public protocol Material {
    /// The name the renderer knows this material by, which is the type's own.
    var __name: String { get }
}

extension Material {
    public var __name: String { String(describing: Self.self) }
}

/// A material of one colour, lit.
@frozen public struct SimpleMaterial: Material {
    public struct BaseColor {
        public var tint: UIColor
        public var texture: TextureResource?

        public init(tint: UIColor, texture: TextureResource? = nil) {
            self.tint = tint
            self.texture = texture
        }
    }

    public var color: BaseColor
    public var roughness: MaterialScalarParameter
    public var metallic: MaterialScalarParameter

    public init(color: BaseColor, roughness: MaterialScalarParameter, metallic: MaterialScalarParameter) {
        self.color = color
        self.roughness = roughness
        self.metallic = metallic
    }

    public init(color: UIColor, isMetallic: Bool) {
        self.init(color: BaseColor(tint: color), roughness: .float(isMetallic ? 0.2 : 0.7), metallic: .float(isMetallic ? 0.0 : 0.0))
    }
}

/// A material of one colour, not lit: what a surface shows whatever light falls on it.
@frozen public struct UnlitMaterial: Material {
    public struct BaseColor {
        public var tint: UIColor
        public var texture: TextureResource?

        public init(tint: UIColor, texture: TextureResource? = nil) {
            self.tint = tint
            self.texture = texture
        }
    }

    public var color: BaseColor

    public init(color: BaseColor) { self.color = color }
    public init(color: UIColor) { self.init(color: BaseColor(tint: color)) }
}

/// A material that only writes depth, which is what an occluder is: it hides what is behind
/// it and is itself invisible.
@frozen public struct OcclusionMaterial: Material, Sendable {
    public init() {}
}

/// A material that shows a video, which is what an `AVPlayer` is drawn with.
@frozen public struct VideoMaterial: Material {
    public struct BaseColor {
        public var texture: TextureResource
        public init(texture: TextureResource) { self.texture = texture }
    }

    public var color: BaseColor

    public init(color: BaseColor) { self.color = color }
}

/// A material whose response to light is set parameter by parameter.
@frozen public struct PhysicallyBasedMaterial: Material {
    public struct BaseColor {
        public var tint: UIColor
        public var texture: TextureResource?

        public init(tint: UIColor = UIColor.white, texture: TextureResource? = nil) {
            self.tint = tint
            self.texture = texture
        }
    }

    public struct Metallic {
        public var value: MaterialScalarParameter
        public var texture: TextureResource?
        public init(value: MaterialScalarParameter) { self.value = value; texture = nil }
    }

    public struct Roughness {
        public var value: MaterialScalarParameter
        public var texture: TextureResource?
        public init(value: MaterialScalarParameter) { self.value = value; texture = nil }
    }

    public struct Specular {
        public var value: MaterialScalarParameter
        public var texture: TextureResource?
        public init(value: MaterialScalarParameter) { self.value = value; texture = nil }
    }

    public struct EmissiveColor {
        public var color: UIColor
        public var texture: TextureResource?
        public init(color: UIColor, texture: TextureResource? = nil) {
            self.color = color
            self.texture = texture
        }
    }

    public struct Normal {
        public var texture: TextureResource
        public init(texture: TextureResource) { self.texture = texture }
    }

    public struct Clearcoat {
        public var value: MaterialScalarParameter
        public var texture: TextureResource?
        public init(value: MaterialScalarParameter) { self.value = value; texture = nil }
    }

    public struct ClearcoatRoughness {
        public var value: MaterialScalarParameter
        public var texture: TextureResource?
        public init(value: MaterialScalarParameter) { self.value = value; texture = nil }
    }

    public struct Anisotropy {
        public var value: MaterialScalarParameter
        public var texture: TextureResource?
        public init(value: MaterialScalarParameter) { self.value = value; texture = nil }
    }

    public struct Occlusion {
        public var value: MaterialScalarParameter
        public var texture: TextureResource?
        public init(value: MaterialScalarParameter) { self.value = value; texture = nil }
    }

    public var baseColor: BaseColor
    public var metallic: Metallic
    public var roughness: Roughness
    public var specular: Specular
    public var emissiveColor: EmissiveColor
    public var emissiveIntensity: Float
    public var clearcoat: Clearcoat
    public var clearcoatRoughness: ClearcoatRoughness
    public var anisotropy: Anisotropy
    public var normal: Normal?
    public var occlusion: Occlusion?

    public init() {
        baseColor = BaseColor()
        metallic = Metallic(value: .float(0))
        roughness = Roughness(value: .float(0.5))
        specular = Specular(value: .float(0.5))
        emissiveColor = EmissiveColor(color: UIColor.black)
        emissiveIntensity = 0
        clearcoat = Clearcoat(value: .float(0))
        clearcoatRoughness = ClearcoatRoughness(value: .float(0))
        anisotropy = Anisotropy(value: .float(0))
        normal = nil
        occlusion = nil
    }
}
