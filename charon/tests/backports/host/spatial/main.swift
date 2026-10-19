// main.swift - the host differential of the Spatial overlay: the same expressions, run against
// Apple's Spatial.framework and against the module built from packages/s/swift-runtime/files/Spatial,
// each in its own binary, and the two transcripts compared number by number by check.lua.
//
// One file, built twice (run.sh): an expression only one of the two modules can answer is a
// difference the comparison cannot see, so every expression below is spelled in the surface the two
// share. What is in Apple's surface and not in this module's is measured by the two compiles: the
// coordinate-space family, swingTwist/slerp/spline, changeBasis, Point3D.clamp, and the C-level
// __SPEulerAngleOrder.pitchYawRoll. What is in this module's surface and not in Apple's is measured
// by the same two compiles, and each of those is named in the commit message.
//
// What this is not: a test of the module against itself. Every number on the right-hand side is
// Apple's own answer for the same input, and the checker's tolerance is the only slack: 1e-12
// relative for the Double half, 1e-6 for the Float half, nothing at all for a flag or a string.

import Foundation
import Spatial
// Apple's module re-exports simd (`@_exported import simd` in its interface) and this one imports
// it without re-exporting it, so the harness names it itself: the matrix types below are the C
// library's in both builds, and without this line only Apple's side sees them.
import simd

// A fixed width, so that equal numbers print identically on both sides: Swift's own `print` writes
// the shortest representation that round-trips, which differs for two values one ulp apart.
func say(_ name: String, _ value: Double) { print("\(name)\t\(String(format: "%.17g", value))") }
func say(_ name: String, _ value: Float) { print("\(name)\t\(String(format: "%.9g", value))") }
func say(_ name: String, _ value: Bool) { print("\(name)\t\(value ? 1 : 0)") }
func say(_ name: String, _ value: String) { print("\(name)\tstr:\(value)") }

// The value types and the vectors behind them, one expression per component: a difference then
// names the component that differs and not a struct's description.
func say(_ name: String, _ value: SIMD3<Double>) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}
func say(_ name: String, _ value: SIMD3<Float>) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}
func say(_ name: String, _ value: SIMD4<Double>) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
    say(name + ".w", value.w)
}
func say(_ name: String, _ value: SIMD4<Float>) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
    say(name + ".w", value.w)
}
func say(_ name: String, _ value: simd_double4x4) {
    say(name + ".0", value.columns.0)
    say(name + ".1", value.columns.1)
    say(name + ".2", value.columns.2)
    say(name + ".3", value.columns.3)
}
func say(_ name: String, _ value: simd_float4x4) {
    say(name + ".0", value.columns.0)
    say(name + ".1", value.columns.1)
    say(name + ".2", value.columns.2)
    say(name + ".3", value.columns.3)
}
func say(_ name: String, _ value: Rect3D) {
    say(name + ".origin", value.origin)
    say(name + ".size", value.size)
}
func say(_ name: String, _ value: Rect3DFloat) {
    say(name + ".origin", value.origin)
    say(name + ".size", value.size)
}
func say(_ name: String, _ value: Ray3D) {
    say(name + ".origin", value.origin)
    say(name + ".direction", value.direction)
}
func say(_ name: String, _ value: Vector3D) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}
func say(_ name: String, _ value: Vector3DFloat) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}
func say(_ name: String, _ value: Point3D) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}
func say(_ name: String, _ value: Point3DFloat) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}
func say(_ name: String, _ value: Size3D) {
    say(name + ".width", value.width)
    say(name + ".height", value.height)
    say(name + ".depth", value.depth)
}
func say(_ name: String, _ value: Size3DFloat) {
    say(name + ".width", value.width)
    say(name + ".height", value.height)
    say(name + ".depth", value.depth)
}
func say(_ name: String, _ value: RotationAxis3D) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}
func say(_ name: String, _ value: RotationAxis3DFloat) {
    say(name + ".x", value.x)
    say(name + ".y", value.y)
    say(name + ".z", value.z)
}

// MARK: - Angle2D and the free functions over it

let angle = Angle2D.degrees(30)
say("d.angle.radians", angle.radians)
say("d.angle.degrees", angle.degrees)
say("d.angle.normalized", Angle2D.degrees(-450).normalized.radians)
say("d.angle.plus", (angle + Angle2D.radians(1)).radians)
say("d.angle.minus", (angle - Angle2D.radians(1)).radians)
say("d.angle.negated", (-angle).radians)
say("d.angle.lt", angle < Angle2D.degrees(31))
say("d.acos", Angle2D.acos(0.5).radians)
say("d.asin", Angle2D.asin(0.5).radians)
say("d.atan", Angle2D.atan(0.5).radians)
say("d.acosh", Angle2D.acosh(1.5).radians)
say("d.asinh", Angle2D.asinh(0.5).radians)
say("d.atanh", Angle2D.atanh(0.5).radians)
say("d.atan2", Angle2D.atan2(y: 0.5, x: -1.5).radians)
say("d.cos", cos(angle))
say("d.sin", sin(angle))
say("d.tan", tan(angle))
say("d.cosh", cosh(angle))
say("d.sinh", sinh(angle))
say("d.tanh", tanh(angle))
say("d.description", angle.description)

// MARK: - Vector3D

let vector = Vector3D(x: 3, y: -4, z: 12)
let other = Vector3D(x: -2, y: 5, z: 1)
say("d.vector.length", vector.length)
say("d.vector.lengthSquared", vector.lengthSquared)
say("d.vector.normalized.length", vector.normalized.length)
say("d.vector.normalized", vector.normalized)
say("d.vector.dot", vector.dot(other))
say("d.vector.cross", vector.cross(other))
say("d.vector.projected", vector.projected(other))
say("d.vector.reflected", vector.reflected(Vector3D(x: 0, y: 1, z: 0)))
say("d.vector.scaledBy", vector.scaledBy(x: 2, y: 0.5, z: -1))
say("d.vector.scaledBySize", vector.scaled(by: Size3D(width: 2, height: 3, depth: 4)))
say("d.vector.uniformlyScaled", vector.uniformlyScaled(by: 0.25))
say("d.vector.sheared", vector.sheared(.xAxis(yShearFactor: 0.5, zShearFactor: 0.25)))
say("d.vector.lerp", Vector3D.lerp(from: vector, to: other, t: Vector3D(x: 0.5, y: 0.25, z: 0.75)))
say("d.vector.smoothstep", Vector3D.smoothstep(edge0: Vector3D(x: -1, y: -1, z: -1),
                                               edge1: Vector3D(x: 2, y: 2, z: 2), x: vector))
say("d.vector.isZero", Vector3D.zero.isZero)
say("d.vector.isFinite", vector.isFinite)
say("d.vector.isNaN", vector.isNaN)
say("d.vector.add", vector + other)
say("d.vector.sub", vector - other)
say("d.vector.forward", Vector3D.forward)
say("d.vector.right", Vector3D.right)
say("d.vector.up", Vector3D.up)
say("d.vector.rotation.to", vector.rotation(to: other).angle.radians)
say("d.vector.rotation.to.axis", vector.rotation(to: other).axis)

// MARK: - Point3D and Size3D

let point = Point3D(x: 3, y: -4, z: 12)
let size = Size3D(width: 2, height: 3, depth: 4)
say("d.point.x", point.x)
say("d.point.y", point.y)
say("d.point.z", point.z)
say("d.point.distance", point.distance(to: .zero))
say("d.point.translated", point.translated(by: Vector3D(x: 1, y: 1, z: 1)))
say("d.point.translatedSize", point.translated(by: size))
say("d.point.plusVector", point + Vector3D(x: 1, y: 2, z: 3))
say("d.size.one", Size3D.one)
say("d.size.isZero", Size3D.zero.isZero)
say("d.size.containsSize", size.contains(Size3D(width: 1, height: 1, depth: 1)))
say("d.size.containsPoint", size.contains(point: Point3D(x: 1, y: 1, z: 1)))
say("d.size.containsAny", size.contains(anyOf: [Point3D(x: 1, y: 1, z: 1), Point3D(x: 9, y: 9, z: 9)]))
say("d.size.union", size.union(Size3D(width: 5, height: 1, depth: 1)))
say("d.size.intersection.isNil", size.intersection(Size3D(width: 5, height: 1, depth: 1)) == nil)
say("d.size.intersection", size.intersection(Size3D(width: 1, height: 5, depth: 1)) ?? .zero)
say("d.size.scaledBy", size.scaledBy(x: 2, y: 2, z: 2))
say("d.size.uniformlyScaled", size.uniformlyScaled(by: 3))
say("d.size.sheared", size.sheared(.yAxis(xShearFactor: 0.5, zShearFactor: 0.25)))

// MARK: - Rect3D

let rect = Rect3D(origin: Point3D(x: -1, y: -2, z: -3), size: size)
say("d.rect.minX", rect.minX)
say("d.rect.midY", rect.midY)
say("d.rect.maxZ", rect.maxZ)
say("d.rect.origin", rect.origin)
say("d.rect.size", rect.size)
say("d.rect.isEmpty", Rect3D.zero.isEmpty)
say("d.rect.containsAny", rect.contains(anyOf: [Point3D.zero, Point3D(x: 9, y: 9, z: 9)]))
say("d.rect.intersection.isNil", rect.intersection(Rect3D(origin: Point3D(x: 9, y: 9, z: 9), size: size)) == nil)
say("d.rect.union", rect.union(Rect3D(origin: Point3D(x: 5, y: 5, z: 5), size: .one)))
say("d.rect.scaledBy", rect.scaledBy(x: 2, y: 2, z: 2))
say("d.rect.sheared", rect.sheared(.zAxis(xShearFactor: 0.5, yShearFactor: 0.25)))
say("d.rect.inset", rect.inset(by: Size3D(width: 0.5, height: 0.5, depth: 0.5)))
say("d.rect.standardized", Rect3D(origin: Point3D(x: 3, y: 3, z: 3), size: size).standardized)
say("d.rect.integral.min", rect.integral.min)
for (index, corner) in rect.cornerPoints.enumerated() {
    say("d.rect.corner\(index)", corner)
}

// MARK: - Ray3D

let ray = Ray3D(origin: point, direction: Vector3D(x: 1, y: 2, z: 3))
say("d.ray.origin", ray.origin)
say("d.ray.direction", ray.direction)
say("d.ray.isZero", Ray3D.zero.isZero)
say("d.ray.translated", ray.translated(by: Vector3D(x: 1, y: 0, z: 0)))
say("d.ray.intersectsSphere", ray.intersects(sphereOrigin: .zero, sphereRadius: 10))
say("d.ray.intersectsRect", ray.intersects(rect))
say("d.ray.rotated", ray.rotated(by: Rotation3D(angle: .radians(0.4), axis: RotationAxis3D(x: 0, y: 1, z: 0))))

// MARK: - Rotation3D

let axis = RotationAxis3D(x: 1, y: 2, z: 3)
let rotation = Rotation3D(angle: .radians(0.7), axis: axis)
say("d.rotation.angle", rotation.angle.radians)
say("d.rotation.axis", rotation.axis)
say("d.rotation.quaternion", rotation.quaternion.vector)
say("d.rotation.vector", rotation.vector)
say("d.rotation.identity", Rotation3D.identity.isIdentity)
say("d.rotation.isIdentity", rotation.isIdentity)
say("d.rotation.inverse.angle", rotation.inverse.angle.radians)
say("d.rotation.inverse.quaternion", rotation.inverse.quaternion.vector)
say("d.rotation.product.angle", (rotation * rotation).angle.radians)
say("d.rotation.product.quaternion", (rotation * rotation).quaternion.vector)
say("d.rotation.rotatedBy", rotation.rotated(by: rotation).angle.radians)
say("d.rotation.eulerAngles.xyz", rotation.eulerAngles(order: .xyz).angles)
say("d.rotation.eulerAngles.zxy", rotation.eulerAngles(order: .zxy).angles)
say("d.rotation.vectorRotated", Vector3D(x: 1, y: 0, z: 0).rotated(by: rotation))
say("d.rotation.vectorRotatedQuaternion", Vector3D(x: 1, y: 0, z: 0).rotated(by: rotation.quaternion))
say("d.rotation.pointRotatedAroundPivot",
    Point3D(x: 1, y: 0, z: 0).rotated(by: rotation, around: Point3D(x: 1, y: 1, z: 1)))

// MARK: - AffineTransform3D

let affine = AffineTransform3D(scale: Size3D(width: 2, height: 3, depth: 4))
    .rotated(by: rotation)
    .translated(by: Vector3D(x: 5, y: 6, z: 7))
say("d.affine.scale", affine.scale)
say("d.affine.translation", affine.translation)
say("d.affine.matrix", affine.matrix4x4)
say("d.affine.identity", AffineTransform3D.identity.isIdentity)
say("d.affine.isTranslation", AffineTransform3D.identity.translated(by: Vector3D(x: 1, y: 0, z: 0)).isTranslation)
say("d.affine.isRectilinear", affine.isRectilinear)
say("d.affine.isUniform", affine.isUniform)
say("d.affine.isUniformOver", affine.isUniform(overDimensions: [.x, .z]))
say("d.affine.rotation.angle", affine.rotation?.angle.radians ?? -1)
say("d.affine.inverse.isNil", affine.inverse == nil)
say("d.affine.inverted.isNil", affine.inverted() == nil)
say("d.affine.inverseThenApply", vector.applying(affine).applying(affine.inverse!))
say("d.affine.product", (affine * affine).matrix4x4)
say("d.affine.concatenating", affine.concatenating(.identity).matrix4x4)
say("d.affine.scaledBy", affine.scaledBy(x: 2, y: 2, z: 2).matrix4x4)
say("d.affine.sheared", affine.sheared(.zAxis(xShearFactor: 0.5, yShearFactor: 0.25)).matrix4x4)
say("d.affine.flipped.x", affine.flipped(along: .x).matrix4x4)
say("d.affine.flipped.z", affine.flipped(along: .z).matrix4x4)
say("d.affine.point", point.applying(affine))
say("d.affine.point.unapplying", point.applying(affine).unapplying(affine))
say("d.affine.vector", vector.applying(affine))
say("d.affine.ray", ray.applying(affine))
say("d.affine.rect", rect.applying(affine))
say("d.affine.size", size.applying(affine))
say("d.affine.rotationTo", point.applying(affine).rotation(to: point).angle.radians)
say("d.affine.isApproximatelyEqual", affine.isApproximatelyEqual(to: affine, tolerance: 1e-9))

// MARK: - ProjectiveTransform3D

let projective = ProjectiveTransform3D(scale: Size3D(width: 2, height: 2, depth: 2))
    .rotated(by: rotation)
    .translated(by: Vector3D(x: 1, y: 2, z: 3))
say("d.projective.matrix", projective.matrix)
say("d.projective.translation", projective.translation)
say("d.projective.scaleComponent", projective.scaleComponent)
say("d.projective.point", point.applying(projective))
say("d.projective.point.unapplying", point.applying(projective).unapplying(projective))
say("d.projective.inverse.isNil", projective.inverse == nil)
say("d.projective.product", (projective * projective).matrix)

// MARK: - Pose3D and ScaledPose3D

let pose = Pose3D(position: point, rotation: rotation)
let scaledPose = ScaledPose3D(position: point, rotation: rotation, scale: 1.5)
say("d.pose.matrix", pose.matrix)
say("d.pose.inverse.matrix", pose.inverse.matrix)
say("d.pose.identity", Pose3D.identity.isIdentity)
say("d.pose.translated", pose.translated(by: Vector3D(x: 1, y: 1, z: 1)).matrix)
say("d.pose.rotated", pose.rotated(by: rotation).matrix)
say("d.pose.concatenating", pose.concatenating(pose).matrix)
say("d.pose.point", point.applying(pose))
say("d.pose.point.unapplying", point.applying(pose).unapplying(pose))
say("d.pose.vector", vector.applying(pose))
say("d.pose.size", size.applying(pose))
say("d.pose.rect", rect.applying(pose))
say("d.pose.ray", ray.applying(pose))
say("d.pose.vector.rotation", vector.applying(pose).rotation(to: vector).angle.radians)
say("d.scaledPose.matrix", scaledPose.matrix)
say("d.scaledPose.inverse.matrix", scaledPose.inverse.matrix)
say("d.scaledPose.identity", ScaledPose3D.identity.isIdentity)
say("d.scaledPose.point", point.applying(scaledPose))
say("d.scaledPose.point.unapplying", point.applying(scaledPose).unapplying(scaledPose))
say("d.scaledPose.vector", vector.applying(scaledPose))
say("d.scaledPose.size", size.applying(scaledPose))

// MARK: - SphericalCoordinates3D

let spherical = SphericalCoordinates3D(vector)
say("d.spherical.radius", spherical.radius)
say("d.spherical.inclination", spherical.inclination.radians)
say("d.spherical.azimuth", spherical.azimuth.radians)
say("d.spherical.vector.x", spherical.vector.x)
say("d.spherical.vector.y", spherical.vector.y)
say("d.spherical.vector.z", spherical.vector.z)
say("d.spherical.fromXYZ", SphericalCoordinates3D(x: 1, y: 2, z: 3).vector)

// MARK: - The Codable shapes

// A transformation is four named columns and a rotation is four numbers, so a round trip through
// JSON measures the shape as well as the value. Sorted keys, so the two encodings are comparable
// as strings.
/// The keys of a Codable shape, and what the first of them holds, as one string: the shape is
/// compared exactly and the values are compared as numbers by the lines above it, which is what a
/// tolerance is for. Two modules that agree to 1e-12 need not print the same last bit of a Double.
func shape(of data: Data) -> String {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return "not an object"
    }
    let keys = object.keys.sorted().joined(separator: ",")
    guard let first = object[object.keys.sorted().first ?? ""] else { return keys }
    if let numbers = first as? [Any] {
        return "\(keys) first: \(numbers.count) numbers"
    }
    return "\(keys) first: \(type(of: first))"
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
let decoder = JSONDecoder()
if let data = try? encoder.encode(rotation), let back = try? decoder.decode(Rotation3D.self, from: data) {
    say("d.codable.rotation.vector", back.vector)
    say("d.codable.rotation.shape", shape(of: data))
} else {
    say("d.codable.rotation.failed", true)
}
if let data = try? encoder.encode(affine), let back = try? decoder.decode(AffineTransform3D.self, from: data) {
    say("d.codable.affine.matrix", back.matrix4x4)
    say("d.codable.affine.shape", shape(of: data))
} else {
    say("d.codable.affine.failed", true)
}
if let data = try? encoder.encode(rect), let back = try? decoder.decode(Rect3D.self, from: data) {
    say("d.codable.rect.min", back.minX)
    say("d.codable.rect.shape", shape(of: data))
} else {
    say("d.codable.rect.failed", true)
}
if let data = try? encoder.encode(pose), let back = try? decoder.decode(Pose3D.self, from: data) {
    say("d.codable.pose.matrix", back.matrix)
    say("d.codable.pose.shape", shape(of: data))
} else {
    say("d.codable.pose.failed", true)
}

// MARK: - The Float half: the same expressions, the same inputs, the type's own precision

let fangle = Angle2DFloat.degrees(30)
say("f.angle.radians", fangle.radians)
say("f.angle.degrees", fangle.degrees)
say("f.angle.normalized", Angle2DFloat.degrees(-450).normalized.radians)
say("f.angle.plus", (fangle + Angle2DFloat.radians(1)).radians)
say("f.angle.negated", (-fangle).radians)
say("f.acos", Angle2DFloat.acos(0.5).radians)
say("f.asin", Angle2DFloat.asin(0.5).radians)
say("f.atan", Angle2DFloat.atan(0.5).radians)
say("f.atan2", Angle2DFloat.atan2(y: 0.5, x: -1.5).radians)
say("f.acosh", Angle2DFloat.acosh(1.5).radians)
say("f.asinh", Angle2DFloat.asinh(0.5).radians)
say("f.atanh", Angle2DFloat.atanh(0.5).radians)
say("f.cos", cos(fangle))
say("f.sin", sin(fangle))
say("f.tan", tan(fangle))
say("f.cosh", cosh(fangle))
say("f.sinh", sinh(fangle))
say("f.tanh", tanh(fangle))
say("f.description", fangle.description)

let fvector = Vector3DFloat(x: 3, y: -4, z: 12)
let fother = Vector3DFloat(x: -2, y: 5, z: 1)
say("f.vector.length", fvector.length)
say("f.vector.lengthSquared", fvector.lengthSquared)
say("f.vector.normalized", fvector.normalized)
say("f.vector.dot", fvector.dot(fother))
say("f.vector.cross", fvector.cross(fother))
say("f.vector.projected", fvector.projected(fother))
say("f.vector.reflected", fvector.reflected(Vector3DFloat(x: 0, y: 1, z: 0)))
say("f.vector.scaledBy", fvector.scaledBy(x: 2, y: 0.5, z: -1))
say("f.vector.scaledBySize", fvector.scaled(by: Size3DFloat(width: 2, height: 3, depth: 4)))
say("f.vector.uniformlyScaled", fvector.uniformlyScaled(by: 0.25))
say("f.vector.sheared", fvector.sheared(.xAxis(yShearFactor: 0.5, zShearFactor: 0.25)))
say("f.vector.lerp", Vector3DFloat.lerp(from: fvector, to: fother, t: Vector3DFloat(x: 0.5, y: 0.25, z: 0.75)))
say("f.vector.smoothstep", Vector3DFloat.smoothstep(edge0: Vector3DFloat(x: -1, y: -1, z: -1),
                                                     edge1: Vector3DFloat(x: 2, y: 2, z: 2), x: fvector))
say("f.vector.isZero", Vector3DFloat.zero.isZero)
say("f.vector.isFinite", fvector.isFinite)
say("f.vector.add", fvector + fother)
say("f.vector.rotation.to", fvector.rotation(to: fother).angle.radians)

let fpoint = Point3DFloat(x: 3, y: -4, z: 12)
let fsize = Size3DFloat(width: 2, height: 3, depth: 4)
say("f.point.distance", fpoint.distance(to: .zero))
say("f.point.translated", fpoint.translated(by: Vector3DFloat(x: 1, y: 1, z: 1)))
say("f.size.containsPoint", fsize.contains(point: Point3DFloat(x: 1, y: 1, z: 1)))
say("f.size.union", fsize.union(Size3DFloat(width: 5, height: 1, depth: 1)))
say("f.size.sheared", fsize.sheared(.yAxis(xShearFactor: 0.5, zShearFactor: 0.25)))

let frect = Rect3DFloat(origin: Point3DFloat(x: -1, y: -2, z: -3), size: fsize)
say("f.rect.min", frect.min)
say("f.rect.max", frect.max)
say("f.rect.center", frect.center)
say("f.rect.union", frect.union(Rect3DFloat(origin: Point3DFloat(x: 5, y: 5, z: 5), size: .one)))
say("f.rect.inset", frect.inset(by: Size3DFloat(width: 0.5, height: 0.5, depth: 0.5)))
for (index, corner) in frect.cornerPoints.enumerated() {
    say("f.rect.corner\(index)", corner)
}

let frotation = Rotation3DFloat(angle: .radians(0.7), axis: RotationAxis3DFloat(x: 1, y: 2, z: 3))
say("f.rotation.angle", frotation.angle.radians)
say("f.rotation.axis", frotation.axis)
say("f.rotation.quaternion", frotation.quaternion.vector)
say("f.rotation.vector", frotation.vector)
say("f.rotation.identity", Rotation3DFloat.identity.isIdentity)
say("f.rotation.inverse.angle", frotation.inverse.angle.radians)
say("f.rotation.product.angle", (frotation * frotation).angle.radians)
say("f.rotation.rotatedBy", frotation.rotated(by: frotation).angle.radians)
say("f.rotation.eulerAngles.xyz", frotation.eulerAngles(order: .xyz).angles)
say("f.rotation.eulerAngles.zxy", frotation.eulerAngles(order: .zxy).angles)
say("f.rotation.vectorRotated", Vector3DFloat(x: 1, y: 0, z: 0).rotated(by: frotation))
say("f.rotation.pointRotatedAroundPivot",
    Point3DFloat(x: 1, y: 0, z: 0).rotated(by: frotation, around: Point3DFloat(x: 1, y: 1, z: 1)))

let faffine = AffineTransform3DFloat(scale: Size3DFloat(width: 2, height: 3, depth: 4))
    .rotated(by: frotation)
    .translated(by: Vector3DFloat(x: 5, y: 6, z: 7))
say("f.affine.scale", faffine.scale)
say("f.affine.translation", faffine.translation)
say("f.affine.matrix", faffine.matrix4x4)
say("f.affine.isRectilinear", faffine.isRectilinear)
say("f.affine.isUniform", faffine.isUniform)
say("f.affine.inverse.isNil", faffine.inverse == nil)
say("f.affine.inverseThenApply", fvector.applying(faffine).applying(faffine.inverse!))
say("f.affine.flipped.x", faffine.flipped(along: .x).matrix4x4)
say("f.affine.point", fpoint.applying(faffine))
say("f.affine.point.unapplying", fpoint.applying(faffine).unapplying(faffine))
say("f.affine.size", fsize.applying(faffine))

let fprojective = ProjectiveTransform3DFloat(scale: Size3DFloat(width: 2, height: 2, depth: 2))
    .rotated(by: frotation)
    .translated(by: Vector3DFloat(x: 1, y: 2, z: 3))
say("f.projective.matrix", fprojective.matrix)
say("f.projective.translation", fprojective.translation)
say("f.projective.point", fpoint.applying(fprojective))

let fpose = Pose3DFloat(position: fpoint, rotation: frotation)
let fscaledPose = ScaledPose3DFloat(position: fpoint, rotation: frotation, scale: 1.5)
say("f.pose.matrix", fpose.matrix)
say("f.pose.inverse.matrix", fpose.inverse.matrix)
say("f.pose.point", fpoint.applying(fpose))
say("f.pose.point.unapplying", fpoint.applying(fpose).unapplying(fpose))
say("f.scaledPose.matrix", fscaledPose.matrix)
say("f.scaledPose.point", fpoint.applying(fscaledPose))
say("f.spherical.radius", SphericalCoordinates3DFloat(fvector).radius)
say("f.spherical.inclination", SphericalCoordinates3DFloat(fvector).inclination.radians)
say("f.spherical.azimuth", SphericalCoordinates3DFloat(fvector).azimuth.radians)

let fencoder = JSONEncoder()
fencoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
if let data = try? fencoder.encode(frotation), let back = try? JSONDecoder().decode(Rotation3DFloat.self, from: data) {
    say("f.codable.rotation.vector", back.vector)
    say("f.codable.rotation.shape", shape(of: data))
} else {
    say("f.codable.rotation.failed", true)
}
if let data = try? fencoder.encode(faffine), let back = try? JSONDecoder().decode(AffineTransform3DFloat.self, from: data) {
    say("f.codable.affine.matrix", back.matrix4x4)
    say("f.codable.affine.shape", shape(of: data))
} else {
    say("f.codable.affine.failed", true)
}