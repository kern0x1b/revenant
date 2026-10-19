import Foundation

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

@frozen
public enum AxisWithFactors {
    case xAxis(yShearFactor: Double, zShearFactor: Double)
    case yAxis(xShearFactor: Double, zShearFactor: Double)
    case zAxis(xShearFactor: Double, yShearFactor: Double)
}

@frozen
public enum AxisWithFactorsFloat {
    case xAxis(yShearFactor: Float, zShearFactor: Float)
    case yAxis(xShearFactor: Float, zShearFactor: Float)
    case zAxis(xShearFactor: Float, yShearFactor: Float)
}

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

public let defaultTolerance = Double.ulpOfOne.squareRoot()

public let defaultToleranceFloat = Float.ulpOfOne.squareRoot()
