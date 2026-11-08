import UIKit
import SceneKit

func radians(_ degrees: Float) -> Float {
    return degrees * Float.pi / 180
}

func vectors(node: SCNNode, other: SCNNode, particleSystem: SCNParticleSystem, color: UIColor) {
    var yaw: CGFloat = 0.6
    var pitch: CGFloat = -0.3
    yaw += 0.1
    pitch -= 0.1
    let target = SCNVector3(pitch, yaw, 0.0)
    node.eulerAngles = SCNVector3(radians(3.0), radians(4.0), 0.0)
    node.eulerAngles = SCNVector3(0.0, 0.0, 0.0)
    node.position = SCNVector3(0, 1, 2)
    node.pivot = SCNMatrix4(float4x4(1))
    other.scale = SCNVector3(1.03, 1.03, 1.03)
    let narrow = SIMD3<Float>(target)
    other.position = SCNVector3(narrow)
    let wide = SIMD3<Double>(target)
    other.position = SCNVector3(wide)
    particleSystem.particleIntensity = 1.0
    particleSystem.particleIntensityVariation = 0.05
    particleSystem.particleColor = color
    particleSystem.particleColorVariation = SCNVector4Make(0.07, 0.0, 0.1, 0.0)
    particleSystem.particleIntensity = min(1.0, 2.0 * particleSystem.particleIntensity)
    let from: CGFloat = 1.0
    let animation = CABasicAnimation(keyPath: "scale")
    animation.fromValue = NSValue(scnVector3: SCNVector3(x: Float(from), y: Float(from), z: Float(from)))
    animation.toValue = SCNVector3(from, from, from)
    let tint = SCNVector4(0.1, 0.2, 0.3, 1.0)
    _ = SIMD4<Float>(tint)
}

func geometry(vertices: [SCNVector3], normals: [SCNVector3], coordinates: [CGPoint], indices: [Int32]) -> SCNGeometry {
    let sources = [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals), SCNGeometrySource(textureCoordinates: coordinates)]
    let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    return SCNGeometry(sources: sources, elements: [element])
}

func bounds(node: SCNNode) -> Float {
    let box = node.boundingBox
    let sphere = node.boundingSphere
    return box.max.x - box.min.x + sphere.radius
}

func bridged(value: NSValue) -> SCNVector3? {
    return value as? SCNVector3
}
