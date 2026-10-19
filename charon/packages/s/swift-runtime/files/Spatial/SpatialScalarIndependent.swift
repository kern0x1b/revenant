// What of Spatial does not depend on the scalar: the axis enumeration, the two shear
// enumerations, the set of dimensions, and the tolerances the C headers compare with
// (`SPBase.h`, which defines them as the square root of the machine epsilon of each half).

import Foundation

// MARK: - Axis3D

/// One or more of the three axes of a coordinate system, as the bits of the `SPAxis` enumeration.
@frozen
public struct Axis3D: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let x = Axis3D(0x0001)
    public static let y = Axis3D(0x0002)
    public static let z = Axis3D(0x0004)
}

// MARK: - AxisWithFactors

/// The axis a shear is about, with how far the two axes across from it are carried with it.
@frozen
public enum AxisWithFactors {
    case xAxis(yShearFactor: Double, zShearFactor: Double)
    case yAxis(xShearFactor: Double, zShearFactor: Double)
    case zAxis(xShearFactor: Double, yShearFactor: Double)
}

/// The axis a shear is about, with how far the two axes across from it are carried with it.
@frozen
public enum AxisWithFactorsFloat {
    case xAxis(yShearFactor: Float, zShearFactor: Float)
    case yAxis(xShearFactor: Float, zShearFactor: Float)
    case zAxis(xShearFactor: Float, yShearFactor: Float)
}

// MARK: - Dimension3DSet

/// Which of the three dimensions of a box a question is about.
@frozen
public struct Dimension3DSet: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let x = Dimension3DSet(rawValue: 1 << 0)
    public static let y = Dimension3DSet(rawValue: 1 << 1)
    public static let z = Dimension3DSet(rawValue: 1 << 2)
    public static let all: Dimension3DSet = [.x, .y, .z]
}

// MARK: - The tolerances

/// `SPDefaultTolerance` from `SPBase.h`, which is `sqrt(__DBL_EPSILON__)`: under it, two lengths
/// are the same length.
public let defaultTolerance = Double.ulpOfOne.squareRoot()

/// `SPDefaultToleranceFloat` from `SPBase.h`, which is `sqrt(__FLT_EPSILON__)`.
public let defaultToleranceFloat = Float.ulpOfOne.squareRoot()
