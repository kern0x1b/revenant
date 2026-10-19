// The answers of macOS SceneKit that tests/backports/device/scenekit.m holds the port to: its matrix functions,
// a node's rotation conventions and SCNView's defaults and delegate messages. Writes them as JSON.
import SceneKit
import GLKit

var out: [String: Any] = [:]
func m(_ x: SCNMatrix4) -> [Float] { [x.m11, x.m12, x.m13, x.m14, x.m21, x.m22, x.m23, x.m24, x.m31, x.m32, x.m33, x.m34, x.m41, x.m42, x.m43, x.m44].map { Float($0) } }
func v3(_ v: SCNVector3) -> [Float] { [Float(v.x), Float(v.y), Float(v.z)] }
func v4(_ v: SCNVector4) -> [Float] { [Float(v.x), Float(v.y), Float(v.z), Float(v.w)] }

let a = SCNMatrix4(m11: 1, m12: 2, m13: 0, m14: 0, m21: 0, m22: 1, m23: 3, m24: 0, m31: 4, m32: 0, m33: 1, m34: 0, m41: 5, m42: 6, m43: 7, m44: 1)
out["matrix/rotation 0.6 (1,2,3)"] = m(SCNMatrix4MakeRotation(0.6, 1, 2, 3))
out["matrix/rotation 0.6 zero axis"] = m(SCNMatrix4MakeRotation(0.6, 0, 0, 0))
out["matrix/mult a rotation"] = m(SCNMatrix4Mult(a, SCNMatrix4MakeRotation(0.6, 1, 2, 3)))
out["matrix/invert a"] = m(SCNMatrix4Invert(a))
out["matrix/invert singular"] = m(SCNMatrix4Invert(SCNMatrix4MakeScale(1, 0, 1)))
out["matrix/scale a (2,3,4)"] = m(SCNMatrix4Scale(a, 2, 3, 4))
out["matrix/rotate a 0.6 (1,2,3)"] = m(SCNMatrix4Rotate(a, 0.6, 1, 2, 3))
out["matrix/to GLK a"] = { let g = SCNMatrix4ToGLKMatrix4(a); return [g.m00, g.m01, g.m02, g.m03, g.m10, g.m11, g.m12, g.m13, g.m20, g.m21, g.m22, g.m23, g.m30, g.m31, g.m32, g.m33] }()
out["matrix/from GLK rotation"] = m(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeRotation(0.6, 1, 2, 3)))
out["equal/identity is identity"] = SCNMatrix4IsIdentity(SCNMatrix4Identity)
out["equal/a is identity"] = SCNMatrix4IsIdentity(a)
out["equal/a a"] = SCNMatrix4EqualToMatrix4(a, a)
out["equal/v3 nan"] = SCNVector3EqualToVector3(SCNVector3(Float.nan, 0, 0), SCNVector3(Float.nan, 0, 0))
out["equal/v3 negative zero"] = SCNVector3EqualToVector3(SCNVector3(-0.0, 0, 0), SCNVector3(0, 0, 0))
out["equal/v4 differs"] = SCNVector4EqualToVector4(SCNVector4(1, 2, 3, 4), SCNVector4(0, 2, 3, 4))

let n = SCNNode()
n.eulerAngles = SCNVector3(0.3, 0.5, 0.7)
out["node/euler (0.3,0.5,0.7) orientation"] = v4(n.orientation)
out["node/euler (0.3,0.5,0.7) rotation"] = v4(n.rotation)
out["node/euler (0.3,0.5,0.7) transform"] = m(n.transform)
n.position = SCNVector3(1, 2, 3); n.scale = SCNVector3(2, 3, 4)
out["node/TRS transform"] = m(n.transform)
let q = SCNNode(); q.orientation = SCNVector4(0.1, 0.2, 0.3, 0.927361849549570)
out["node/orientation to euler"] = v3(q.eulerAngles)
out["node/orientation to rotation"] = v4(q.rotation)
let big = SCNNode(); big.eulerAngles = SCNVector3(2.0, 0.2, -2.5)
out["node/euler set is kept"] = v3(big.eulerAngles)
let parent = SCNNode(); parent.position = SCNVector3(0, 1, 0); parent.eulerAngles = SCNVector3(0, 0.5, 0)
let child = SCNNode(); child.position = SCNVector3(1, 0, 0); parent.addChildNode(child)
out["node/child world transform"] = m(child.worldTransform)
out["node/new rotation"] = v4(SCNNode().rotation)
out["node/new eulerAngles"] = v3(SCNNode().eulerAngles)
let r = SCNNode(); r.rotation = SCNVector4(0, 1, 0, 1.2)
out["node/rotation to orientation"] = v4(r.orientation)
// a matrix set as the transform is kept as it was given; the parts are its split, and setting one recomposes it
var shear = SCNMatrix4Identity; shear.m21 = 0.5; shear.m41 = 1
let sheared = SCNNode(); sheared.transform = shear
out["node/shear transform"] = m(sheared.transform)
out["node/shear position"] = v3(sheared.position)
out["node/shear scale"] = v3(sheared.scale)
let shearedChild = SCNNode(); shearedChild.position = SCNVector3(0, 1, 0); sheared.addChildNode(shearedChild)
out["node/shear child world transform"] = m(shearedChild.worldTransform)
var reflection = SCNMatrix4MakeScale(-1, 1, 1); reflection.m42 = 2
let mirrored = SCNNode(); mirrored.transform = reflection
out["node/mirror transform"] = m(mirrored.transform)
out["node/mirror scale"] = v3(mirrored.scale)
out["node/mirror orientation"] = v4(mirrored.orientation)
mirrored.position = SCNVector3(9, 8, 7)
out["node/mirror then position transform"] = m(mirrored.transform)
// the presentation node: one for each node, with the hierarchy, after a frame
let presented = SCNNode(); presented.position = SCNVector3(0, 1, 0)
let presentedChild = SCNNode(); presentedChild.position = SCNVector3(1, 0, 0); presented.addChildNode(presentedChild)
let presentedCamera = SCNNode(); presentedCamera.camera = SCNCamera(); presentedCamera.position = SCNVector3(0, 0, 5)
let presentedScene = SCNScene(); presentedScene.rootNode.addChildNode(presented); presentedScene.rootNode.addChildNode(presentedCamera)
let presentedView = SCNView(frame: NSRect(x: 0, y: 0, width: 32, height: 32), options: nil); presentedView.scene = presentedScene
_ = presentedView.snapshot()
out["node/presentation is one node"] = presented.presentation === presented.presentation
out["node/presentation of a presentation"] = presented.presentation.presentation === presented.presentation
out["node/presentation child world transform"] = m(presentedChild.presentation.worldTransform)
out["node/presentation child count"] = presented.presentation.childNodes.count
let held = SCNNode(); held.addAnimation(CABasicAnimation(keyPath: "opacity"), forKey: "held")
for (name, node) in [("none", SCNNode()), ("other key", held)] {
    out["node/\(name): animationForKey of a missing key"] = node.animation(forKey: "missing") == nil ? "nil" : "set"
    out["node/\(name): isAnimationForKeyPaused of a missing key"] = node.isAnimationPaused(forKey: "missing")
}
out["node/other key: animationForKey of the held key"] = held.animation(forKey: "held") == nil ? "nil" : "set"
out["node/other key: isAnimationForKeyPaused of the held key"] = held.isAnimationPaused(forKey: "held")
let property = SCNMaterialProperty(); property.addAnimation(CABasicAnimation(keyPath: "intensity"), forKey: "held")
out["copy/property keeps its animation keys"] = (property.copy() as! SCNMaterialProperty).animationKeys
let movable = SCNNode(); movable.movabilityHint = .movable
out["copy/node keeps movabilityHint"] = (movable.copy() as! SCNNode).movabilityHint.rawValue
let archived = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(NSKeyedArchiver.archivedData(withRootObject: movable, requiringSecureCoding: false)) as! SCNNode
out["copy/archived node keeps movabilityHint"] = archived.movabilityHint.rawValue

final class Recorder: NSObject, SCNSceneRendererDelegate {
    var log: [String] = []
    func renderer(_ r: SCNSceneRenderer, updateAtTime t: TimeInterval) { log.append("update") }
    func renderer(_ r: SCNSceneRenderer, didApplyAnimationsAtTime t: TimeInterval) { log.append("didApplyAnimations") }
    func renderer(_ r: SCNSceneRenderer, didSimulatePhysicsAtTime t: TimeInterval) { log.append("didSimulatePhysics") }
    func renderer(_ r: SCNSceneRenderer, didApplyConstraintsAtTime t: TimeInterval) { log.append("didApplyConstraints") }
    func renderer(_ r: SCNSceneRenderer, willRenderScene s: SCNScene, atTime t: TimeInterval) { log.append("willRenderScene \(t)") }
    func renderer(_ r: SCNSceneRenderer, didRenderScene s: SCNScene, atTime t: TimeInterval) { log.append("didRenderScene \(t)") }
}
let view = SCNView(frame: NSRect(x: 0, y: 0, width: 32, height: 32), options: nil)
out["view/preferredFramesPerSecond"] = view.preferredFramesPerSecond
out["view/jitteringEnabled"] = view.isJitteringEnabled
out["view/pointOfView without scene"] = view.pointOfView == nil ? "nil" : "set"
let scene = SCNScene()
let camera = SCNNode(); camera.name = "camera"; camera.camera = SCNCamera()
let holder = SCNNode(); holder.name = "holder"; holder.addChildNode(camera); scene.rootNode.addChildNode(holder)
view.scene = scene
out["view/pointOfView after scene"] = view.pointOfView?.name ?? "nil"
let recorder = Recorder()
view.delegate = recorder
_ = view.snapshot()
out["view/snapshot delegate messages"] = recorder.log

let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
