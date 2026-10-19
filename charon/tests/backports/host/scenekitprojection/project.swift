import Foundation
import SceneKit
import Metal
import simd

func project(point world: SIMD3<Float>, camera: SCNNode, viewport: CGSize) -> SIMD3<Float> {
    let eye = simd_float4x4(camera.worldTransform).inverse * simd_float4(world.x, world.y, world.z, 1)
    guard let cam = camera.camera else { return .zero }
    let tanHalf = tan(Float(cam.fieldOfView) * .pi / 360)
    let aspect = Float(viewport.width / max(viewport.height, 1))
    let near = Float(cam.zNear), far = Float(cam.zFar)
    let depth = max(-eye.z, 1e-6)
    let ndcX = (eye.x / depth) / (tanHalf * aspect)
    let ndcY = (eye.y / depth) / tanHalf
    let ndcZ = (far + near) / (far - near) - (2 * far * near) / ((far - near) * depth)
    return SIMD3<Float>((ndcX + 1) / 2 * Float(viewport.width),
                        (ndcY + 1) / 2 * Float(viewport.height),
                        (ndcZ + 1) / 2)
}

func unproject(point screen: SIMD3<Float>, camera: SCNNode, viewport: CGSize) -> SIMD3<Float> {
    guard let cam = camera.camera else { return .zero }
    let tanHalf = tan(Float(cam.fieldOfView) * .pi / 360)
    let aspect = Float(viewport.width / max(viewport.height, 1))
    let near = Float(cam.zNear), far = Float(cam.zFar)
    let ndcX = Float(screen.x) / Float(viewport.width) * 2 - 1
    let ndcY = Float(screen.y) / Float(viewport.height) * 2 - 1
    let ndcZ = Float(screen.z) * 2 - 1
    let depth = (2 * far * near) / ((far + near) - ndcZ * (far - near))
    let eye = SIMD3<Float>(ndcX * tanHalf * aspect * depth, ndcY * tanHalf * depth, -depth)
    let world = simd_float4x4(camera.worldTransform) * simd_float4(eye.x, eye.y, eye.z, 1)
    return SIMD3<Float>(world.x, world.y, world.z)
}

let size = CGSize(width: 800, height: 600)
let scene = SCNScene()
let camera = SCNNode()
let cam = SCNCamera()
cam.zNear = 1
cam.zFar = 1000
camera.camera = cam
camera.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(10))
camera.eulerAngles = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(0))
scene.rootNode.addChildNode(camera)
let box = SCNBox(width: 2, height: 2, length: 2, chamferRadius: 0)
let lit = SCNNode(geometry: box)
lit.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(0))
scene.rootNode.addChildNode(lit)

let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
renderer.scene = scene
renderer.pointOfView = camera
_ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)

let control = SIMD3<Float>(1, 0.5, 0)
let controlTheirs = renderer.projectPoint(SCNVector3(CGFloat(control.x), CGFloat(control.y), CGFloat(control.z)))
let controlOut = SIMD3<Float>(Float(controlTheirs.x), Float(controlTheirs.y), Float(controlTheirs.z))
let controlMoved = simd_distance(controlOut, control) > 0.01
print("control: a point off the axis comes back at \(controlOut), \(simd_distance(controlOut, control)) from where it went in - \(controlMoved ? "moved" : "UNCHANGED, the oracle has no projection")")
if !controlMoved {
    print("scenekitprojection: ERROR - the host answered an off-axis point unchanged, so there is no projection to compare against")
    exit(2)
}

let points: [SIMD3<Float>] = [
    SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(-1, -1, 0),
    SIMD3<Float>(0, 0, -9), SIMD3<Float>(0, 0, -9.999), SIMD3<Float>(0, 0, -990), SIMD3<Float>(3, -2, -5),
]
var worst = 0.0
for point in points {
    let ours = project(point: point, camera: camera, viewport: size)
    let theirs = renderer.projectPoint(SCNVector3(CGFloat(point.x), CGFloat(point.y), CGFloat(point.z)))
    let theirsPoint = SIMD3<Float>(Float(theirs.x), Float(theirs.y), Float(theirs.z))
    let delta = simd_distance(ours, theirsPoint)
    worst = max(worst, Double(delta))
    let mark = delta < 0.01 ? "ok  " : "DIFF"
    print("\(mark) point (\(point.x), \(point.y), \(point.z)) ours (\(ours.x), \(ours.y), \(ours.z)) theirs (\(theirs.x), \(theirs.y), \(theirs.z)) delta \(delta)")
    let back = unproject(point: theirsPoint, camera: camera, viewport: size)
    let round = simd_distance(back, point)
    worst = max(worst, Double(round))
    print("\(round < 0.01 ? "ok  " : "DIFF") unproject -> (\(back.x), \(back.y), \(back.z)) round trip \(round)")
}
print("worst delta \(worst)")

if CommandLine.arguments.count > 1 {
    var lines: [String] = []
    lines.append("// The answers of macOS SceneKit's SCNSceneRenderer.projectPoint / unprojectPoint, written by")
    lines.append("// host/scenekitprojection/project.swift from an SCNRenderer that rendered one offscreen frame.")
    lines.append("// The camera is at (0, 0, 10) looking down -z, fieldOfView 60, zNear 1, zFar 1000, viewport 800x600.")
    let cases: [(String, SIMD3<Float>)] = [
        ("0,0,0", SIMD3<Float>(0, 0, 0)), ("1,0,0", SIMD3<Float>(1, 0, 0)),
        ("0,1,0", SIMD3<Float>(0, 1, 0)), ("-1,-1,0", SIMD3<Float>(-1, -1, 0)),
        ("0,0,-9", SIMD3<Float>(0, 0, -9)), ("0,0,-9.999", SIMD3<Float>(0, 0, -9.999)),
        ("0,0,-990", SIMD3<Float>(0, 0, -990)), ("3,-2,-5", SIMD3<Float>(3, -2, -5)),
    ]
    for (label, point) in cases {
        let projected = renderer.projectPoint(SCNVector3(CGFloat(point.x), CGFloat(point.y), CGFloat(point.z)))
        let value = "\(projected.x),\(projected.y),\(projected.z)"
        lines.append("    {\"projectPoint \(label)\", \"\(value)\"},")
        let back = renderer.unprojectPoint(projected)
        lines.append("    {\"unprojectPoint \(label)\", \"\(back.x),\(back.y),\(back.z)\"},")
    }
    let header = lines.joined(separator: "\n") + "\n"
    try! header.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
    print("wrote \(CommandLine.arguments[1])")
}
print(worst < 0.01 ? "scenekitprojection: OK - the port's projection is the system's" : "scenekitprojection: FAILED - the port's projection is not the system's")
