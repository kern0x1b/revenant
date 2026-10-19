// The port's SCNSceneRenderer.projectPoint / unprojectPoint, against macOS SceneKit's own.
//
// The backports carry neither (measured 2026-09-28: `grep -rn projectPoint packages/a/apple-backports/`
// is empty, while the SDK's SCNSceneRenderer.h:129-142 declares both), so this states the
// arithmetic the port is given and checks it against the system's answers for the same camera and
// the same points. The port's implementation is the same arithmetic in Objective-C; what is checked
// here is the arithmetic, and the device holds the Objective-C to it.
//
// The header (SCNSceneRenderer.h:129-136) is what the shape comes from: projectPoint takes a world
// point and answers in the point-of-view's viewport, with z 0 at the near plane and 1 at the far one.

import Foundation
import SceneKit
import Metal
import simd

// MARK: The arithmetic the port uses

/// world -> viewport, with z 0 at the near plane and 1 at the far one.
func project(point world: SIMD3<Float>, camera: SCNNode, viewport: CGSize) -> SIMD3<Float> {
    let eye = simd_float4x4(camera.worldTransform).inverse * simd_float4(world.x, world.y, world.z, 1)
    // The camera's *own* numbers: an earlier version of this read fieldOfView and the planes off a
    // freshly made SCNCamera, which has the defaults (zFar 100) and not the camera's, and that is
    // one of the three ways it was wrong.
    guard let cam = camera.camera else { return .zero }
    let tanHalf = tan(Float(cam.fieldOfView) * .pi / 360)   // SceneKit's fieldOfView is a full angle, in degrees
    let aspect = Float(viewport.width / max(viewport.height, 1))
    let near = Float(cam.zNear), far = Float(cam.zFar)
    // SceneKit looks down -z from the camera, so the depth in front of it is the negated z.
    let depth = max(-eye.z, 1e-6)
    let ndcX = (eye.x / depth) / (tanHalf * aspect)
    let ndcY = (eye.y / depth) / tanHalf
    // The depth is the *perspective* one, not a linear share of the range: the header's z is 0 at
    // the near plane and 1 at the far one, and only the perspective mapping gets there (measured:
    // the host answers 0.9342675 for a point 15 in front of a camera whose planes are 1 and 1000,
    // which is ((f+n)/(f-n) - 2fn/((f-n)d) + 1)/2 = 0.9342675; the linear share would be 0.014).
    let ndcZ = (far + near) / (far - near) - (2 * far * near) / ((far - near) * depth)
    return SIMD3<Float>((ndcX + 1) / 2 * Float(viewport.width),
                        (ndcY + 1) / 2 * Float(viewport.height),   // no flip: the host's y has the sign, not the opposite
                        (ndcZ + 1) / 2)
}

/// viewport -> world, the inverse of the above.
func unproject(point screen: SIMD3<Float>, camera: SCNNode, viewport: CGSize) -> SIMD3<Float> {
    guard let cam = camera.camera else { return .zero }
    let tanHalf = tan(Float(cam.fieldOfView) * .pi / 360)
    let aspect = Float(viewport.width / max(viewport.height, 1))
    let near = Float(cam.zNear), far = Float(cam.zFar)
    let ndcX = Float(screen.x) / Float(viewport.width) * 2 - 1
    let ndcY = Float(screen.y) / Float(viewport.height) * 2 - 1
    let ndcZ = Float(screen.z) * 2 - 1
    // The inverse of the perspective mapping above: from ndcZ back to the view-space depth.
    let depth = (2 * far * near) / ((far + near) - ndcZ * (far - near))
    let eye = SIMD3<Float>(ndcX * tanHalf * aspect * depth, ndcY * tanHalf * depth, -depth)
    let world = simd_float4x4(camera.worldTransform) * simd_float4(eye.x, eye.y, eye.z, 1)
    return SIMD3<Float>(world.x, world.y, world.z)
}

// MARK: The case

// The oracle is an SCNRenderer, which is what the method belongs to: SCNRenderer and SCNView both
// conform to SCNSceneRenderer, and the existing SceneKit render case
// (tests/backports/host/scenekit/render.swift:47-53) is the setup - a Metal device, a scene, a
// point of view and one offscreen frame - that makes a renderer project anything at all. A view
// that has never rendered answers projectPoint its input back unchanged, which is what this case
// measured before it rendered, and the control below is what catches that.
let size = CGSize(width: 800, height: 600)
let scene = SCNScene()
let camera = SCNNode()
let cam = SCNCamera()
// fieldOfView is left at its default, 60, which is what the device test gets too: setting it is
// iOS 11 and newer (measured on the store's clang at -target armv7-apple-ios6.1.3), and a test that
// needed a value the release cannot set would be a test of nothing.
cam.zNear = 1
cam.zFar = 1000
camera.camera = cam
camera.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(10))
camera.eulerAngles = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(0))
scene.rootNode.addChildNode(camera)
// Something in the scene for the renderer to draw, so the frame is a real one.
let box = SCNBox(width: 2, height: 2, length: 2, chamferRadius: 0)
let lit = SCNNode(geometry: box)
lit.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(0))
scene.rootNode.addChildNode(lit)

let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
renderer.scene = scene
renderer.pointOfView = camera
// One frame, offscreen: this is what gives the renderer its projection.
_ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)

// The control: a point off the camera's axis has to come back *moved*. If the renderer hands it
// back unchanged it has no projection, and every comparison below would be against an identity -
// which is an error in the oracle, not a pass.
let control = SIMD3<Float>(1, 0.5, 0)
let controlTheirs = renderer.projectPoint(SCNVector3(CGFloat(control.x), CGFloat(control.y), CGFloat(control.z)))
let controlOut = SIMD3<Float>(Float(controlTheirs.x), Float(controlTheirs.y), Float(controlTheirs.z))
let controlMoved = simd_distance(controlOut, control) > 0.01
print("control: a point off the axis comes back at \(controlOut), \(simd_distance(controlOut, control)) from where it went in - \(controlMoved ? "moved" : "UNCHANGED, the oracle has no projection")")
if !controlMoved {
    print("scenekitprojection: ERROR - the host answered an off-axis point unchanged, so there is no projection to compare against")
    exit(2)
}

// Points in front of the camera, spread across the viewport and in depth, including the near and far
// planes where the header says z is exactly 0 and 1.
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

// MARK: Recording, for the device test
//
// The same answers in the form tests/backports/device/accelerate7-expectations.h uses - one
// {"name", "value"} per answer - written to the header the device test includes. The names are the
// contract: the device test asks the *port's* projectPoint and unprojectPoint for the same camera,
// viewport and points, and has to come back with these.
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
