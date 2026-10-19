// series <case> : macOS SceneKit's values for one of Telegram's animations on a node or a material property (from
// PremiumStarComponent and PremiumCoinComponent), sampled every ~4 ms (so that a straight line between samples cuts no corner of the curve by more
// than the tolerance of compare.py) by rendering: the presentation node's value,
// or for a material property the pixel (4, 4) of a constant-lit quad whose image's red is u and green is v; with the
// delegate's calls and animationKeys. Times are from the first frame after the add; abs= is media time. The -mutant
// cases are the same animations a little wrong (a duration 5% long, a spring 22 stiff instead of 21): the negative
// control of tests/backports/host/scenekit/animation/compare.py. tests/backports/device/scenekit-animation.m runs the
// same cases through the port.
import SceneKit
import Metal
import AppKit

final class Delegate: NSObject, CAAnimationDelegate {
    var events: [String] = []
    var origin: CFTimeInterval = 0
    func animationDidStart(_ anim: CAAnimation) { events.append(String(format: "start %.3f", CACurrentMediaTime() - origin)) }
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) { events.append(String(format: "stop %.3f finished=%d", CACurrentMediaTime() - origin, flag ? 1 : 0)) }
}

let which = CommandLine.arguments[1]
let scene = SCNScene()
let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.usesOrthographicProjection = true; cam.camera!.orthographicScale = 1; cam.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(cam)
let node = SCNNode(); node.name = "star"
let plane = SCNGeometry(sources: [SCNGeometrySource(vertices: [SCNVector3(-1, -1, 0), SCNVector3(1, -1, 0), SCNVector3(1, 1, 0), SCNVector3(-1, 1, 0)]),
                                  SCNGeometrySource(textureCoordinates: [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0)])],
                        elements: [SCNGeometryElement(indices: [UInt16(0), 1, 2, 0, 2, 3], primitiveType: .triangles)])
func gradient() -> CGImage {
    var bytes = [UInt8](repeating: 255, count: 256 * 256 * 4)
    for y in 0..<256 { for x in 0..<256 { bytes[(y * 256 + x) * 4] = UInt8(x); bytes[(y * 256 + x) * 4 + 1] = UInt8(y); bytes[(y * 256 + x) * 4 + 2] = 0 } }
    let ctx = CGContext(data: &bytes, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 1024, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx.makeImage()!
}
node.geometry = plane
let material = SCNMaterial(); plane.materials = [material]
material.lightingModel = .constant
// gradient and shimmer: the image as an MTLTexture holding the levels of srgblevels.swift's rule, which SceneKit
// samples as they are under mipFilter linear (at the cases' constant scale, lambda 5, the same level alone as nearest);
// the -metal cases: the image itself, whose levels SceneKit has Metal make (the release's own bytes, reported beside)
let image: Any = which.hasSuffix("-metal") ? gradient() : { () -> MTLTexture in
    var bytes = [UInt8](repeating: 0, count: 256 * 256 * 4)
    gradient().dataProvider.map { CFDataGetBytes($0.data!, CFRange(location: 0, length: bytes.count), &bytes) }
    return srgbTexture(MTLCreateSystemDefaultDevice()!, srgbLevels(bytes, side: 256), side: 256)
}()
let filter: SCNFilterMode = which.hasSuffix("-metal") ? .nearest : .linear
if which.hasPrefix("gradient") { material.diffuse.contents = image; material.diffuse.mipFilter = filter; material.diffuse.wrapS = .repeat; material.diffuse.wrapT = .repeat }
if which.hasPrefix("shimmer") { material.diffuse.contents = NSColor.black; material.emission.contents = image; material.emission.mipFilter = filter; material.emission.wrapS = .clamp; material.emission.wrapT = .clampToBorder }
let initialTransform = SCNMatrix4MakeScale(0.5, 0.5, 1)
material.emission.contentsTransform = SCNMatrix4Translate(initialTransform, 1, 0.15, 0)
material.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.24, -0.24, 0)
scene.rootNode.addChildNode(node)
let r = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil); r.scene = scene; r.pointOfView = cam
let delegate = Delegate()
var lastPixel = [Int](repeating: 0, count: 4)
// SceneKit evaluates the animations at the time a frame is rendered for; each sample records exactly that time
var renderedAt: CFTimeInterval = 0
func render() {
    renderedAt = CACurrentMediaTime()
    let image = r.snapshot(atTime: renderedAt, with: CGSize(width: 8, height: 8), antialiasingMode: .none)
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    rep.getPixel(&lastPixel, atX: 4, y: 4)
}
func m4(_ m: SCNMatrix4?) -> String {
    guard let m = m else { return "nil" }
    return String(format: "%.4f %.4f %.4f %.4f", m.m11, m.m22, m.m41, m.m42)
}

var sample: () -> String = { "" }
var duration = 1.5
var midway: ((Double) -> Void)? = nil
render()
let addedAt = CACurrentMediaTime()
switch which {
case "euler-basic", "euler-basic-mutant":
    // PremiumStarComponent tap: 0.25 s ease-out, fill forwards, the model set to the target right after
    let a = CABasicAnimation(keyPath: "eulerAngles")
    a.fromValue = NSValue(scnVector3: SCNVector3(0, 0, 0)); a.toValue = NSValue(scnVector3: SCNVector3(0.3, -0.5, 0))
    a.duration = which.hasSuffix("mutant") ? 0.2625 : 0.25; a.timingFunction = CAMediaTimingFunction(name: .easeOut); a.fillMode = .forwards; a.delegate = delegate
    node.addAnimation(a, forKey: "tapRotate"); node.eulerAngles = SCNVector3(0.3, -0.5, 0)
    sample = { let e = node.presentation.eulerAngles; return String(format: "%.4f %.4f %.4f model %.4f", e.x, e.y, e.z, node.eulerAngles.x) }
    duration = 0.5
case "euler-spring", "euler-spring-mutant":
    // PremiumStarComponent: the spring back from the tap target, the model set to the initial value first
    node.eulerAngles = SCNVector3(0, 0, 0)
    let a = CASpringAnimation(keyPath: "eulerAngles")
    a.fromValue = NSValue(scnVector3: SCNVector3(0.3, -0.5, 0)); a.toValue = NSValue(scnVector3: SCNVector3(0, 0, 0))
    a.mass = 1; a.stiffness = which.hasSuffix("mutant") ? 22 : 21; a.damping = 5.8; a.duration = a.settlingDuration * 0.8; a.delegate = delegate
    node.addAnimation(a, forKey: "tapRotate")
    sample = { let e = node.presentation.eulerAngles; return String(format: "%.4f %.4f %.4f", e.x, e.y, e.z) }
    duration = a.duration + 0.3
case "euler-spring-velocity":
    // PremiumStarComponent pan end: velocity-driven spring to a full turn
    let a = CASpringAnimation(keyPath: "eulerAngles")
    a.fromValue = NSValue(scnVector3: SCNVector3(0, 0.4, 0)); a.toValue = NSValue(scnVector3: SCNVector3(0, 2 * Float.pi, 0))
    a.mass = 1; a.stiffness = 21; a.damping = 5.8; a.duration = a.settlingDuration * 0.75; a.initialVelocity = 1.7; a.delegate = delegate
    node.addAnimation(a, forKey: "rotate")
    sample = { let e = node.presentation.eulerAngles; return String(format: "%.4f %.4f %.4f", e.x, e.y, e.z) }
    duration = a.duration + 0.3
case "scale-reverse":
    let a = CABasicAnimation(keyPath: "scale")
    a.duration = 0.6
    a.fromValue = NSValue(scnVector3: SCNVector3(0.1, 0.1, 0.1)); a.toValue = NSValue(scnVector3: SCNVector3(0.115, 0.115, 0.115))
    a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut); a.autoreverses = true; a.repeatCount = .infinity
    node.addAnimation(a, forKey: "scale")
    sample = { let s = node.presentation.scale; return String(format: "%.5f %.5f %.5f", s.x, s.y, s.z) }
    duration = 2.6
case "gradient", "gradient-metal":
    let initial = material.diffuse.contentsTransform
    let a = CABasicAnimation(keyPath: "contentsTransform")
    a.duration = 0.9
    a.fromValue = NSValue(scnMatrix4: initial); a.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -0.35, 0.35, 0))
    a.timingFunction = CAMediaTimingFunction(name: .linear); a.autoreverses = true; a.repeatCount = .infinity
    material.diffuse.addAnimation(a, forKey: "gradient")
    sample = { "pixel \(lastPixel[0]) \(lastPixel[1]) model " + m4(material.diffuse.contentsTransform) }
    duration = 2.0
case "shimmer", "shimmer-metal":
    let initial = material.emission.contentsTransform
    let a = CABasicAnimation(keyPath: "contentsTransform")
    a.fillMode = .forwards
    a.fromValue = NSValue(scnMatrix4: initial); a.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -1.6, 0, 0))
    a.timingFunction = CAMediaTimingFunction(name: .easeOut); a.beginTime = 1.1; a.duration = 0.9
    let g = CAAnimationGroup(); g.animations = [a]; g.beginTime = 1.0; g.duration = 4.0; g.repeatCount = .infinity
    material.emission.addAnimation(g, forKey: "shimmer")
    sample = { "pixel \(lastPixel[0]) \(lastPixel[1])" }
    duration = 9.0
case "opacity-later":
    // the appearance flash: begins 0.1 s after now in media time, fades over 0.7 s, stays, then its delegate fires
    let a = CABasicAnimation(keyPath: "opacity")
    a.beginTime = addedAt + 0.1; a.duration = 0.7; a.fromValue = 1.0; a.toValue = 0.0
    a.fillMode = .forwards; a.isRemovedOnCompletion = false; a.delegate = delegate
    node.addAnimation(a, forKey: "opacity")
    sample = { String(format: "%.4f model %.4f", node.presentation.opacity, node.opacity) }
    duration = 1.2
case "remove-midway":
    let a = CABasicAnimation(keyPath: "eulerAngles")
    a.fromValue = NSValue(scnVector3: SCNVector3(0, 0, 0)); a.toValue = NSValue(scnVector3: SCNVector3(0, 1, 0)); a.duration = 1.0; a.delegate = delegate
    node.addAnimation(a, forKey: "tapRotate")
    sample = { let e = node.presentation.eulerAngles; return String(format: "%.4f %.4f %.4f", e.x, e.y, e.z) }
    midway = { t in if t > 0.4 && node.animationKeys.contains("tapRotate") { node.removeAnimation(forKey: "tapRotate") } }
    duration = 0.8
default:
    fatalError("no case \(which)")
}
setvbuf(stdout, nil, _IOLBF, 0)
print("added keys=\(node.animationKeys) \(material.diffuse.animationKeys) \(material.emission.animationKeys)")
render()
delegate.origin = renderedAt
let origin = delegate.origin
print(String(format: "added=%.5f", addedAt))
print(String(format: "t=0.00000 abs=%.5f ", origin) + sample())
while renderedAt - origin < duration {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.004))
    midway?(CACurrentMediaTime() - origin)
    render()
    print(String(format: "t=%.5f abs=%.5f ", renderedAt - origin, renderedAt) + sample() + " keys=\(node.animationKeys.count + material.diffuse.animationKeys.count + material.emission.animationKeys.count)")
}
print("events: \(delegate.events)")
