// Pixel probes of SceneKit's lighting on macOS: one quad facing an orthographic camera, one light.
import SceneKit
import AppKit
import Metal

func quad() -> SCNGeometry {
    let v: [SCNVector3] = [SCNVector3(-1, -1, 0), SCNVector3(1, -1, 0), SCNVector3(1, 1, 0), SCNVector3(-1, 1, 0)]
    let n = [SCNVector3](repeating: SCNVector3(0, 0, 1), count: 4)
    let t: [CGPoint] = [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0)]
    let idx: [UInt16] = [0, 1, 2, 0, 2, 3]
    return SCNGeometry(sources: [SCNGeometrySource(vertices: v), SCNGeometrySource(normals: n), SCNGeometrySource(textureCoordinates: t)],
                       elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
}
let device = MTLCreateSystemDefaultDevice()
var printedSpace = false
var tilt = 0.0
func probe(_ configure: (SCNScene, SCNMaterial) -> Void) -> [Double] {
    let scene = SCNScene()
    let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.usesOrthographicProjection = true; cam.camera!.orthographicScale = 1
    cam.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(cam)
    let node = SCNNode(geometry: quad()); node.eulerAngles = SCNVector3(Float(tilt), 0, 0); scene.rootNode.addChildNode(node)
    let m = SCNMaterial(); node.geometry!.materials = [m]
    configure(scene, m)
    let r = SCNRenderer(device: device, options: nil); r.scene = scene; r.pointOfView = cam
    let img = r.snapshot(atTime: 0, with: CGSize(width: 8, height: 8), antialiasingMode: .none)
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    if !printedSpace { printedSpace = true; print("# snapshot space=\(rep.colorSpaceName.rawValue) \(rep.colorSpace.localizedName ?? "?") bps=\(rep.bitsPerSample) spp=\(rep.samplesPerPixel) float=\(rep.bitmapFormat.contains(.floatingPointSamples)) cg=\(String(describing: img.cgImage(forProposedRect: nil, context: nil, hints: nil)?.colorSpace))") }
    var px = [Int](repeating: 0, count: 4)
    rep.getPixel(&px, atX: 4, y: 4)
    return px.map { Double($0) }
}
func light(_ scene: SCNScene, _ type: SCNLight.LightType, _ intensity: CGFloat, _ color: NSColor, euler: SCNVector3 = SCNVector3(0, 0, 0), position: SCNVector3 = SCNVector3(0, 0, 0)) {
    let l = SCNNode(); l.light = SCNLight(); l.light!.type = type; l.light!.intensity = intensity; l.light!.color = color
    l.eulerAngles = euler; l.position = position; scene.rootNode.addChildNode(l)
}
func fmt(_ v: [Double]) -> String { v.map { String(format: "%.1f", $0) }.joined(separator: ",") }

func gray(_ g: Double) -> NSColor { NSColor(srgbRed: g, green: g, blue: g, alpha: 1) }
for t in [0.9, 1.1, 1.25, 1.35] {
    tilt = t
    for rough in [0.2, 0.45, 0.8] {
        for (met, alb) in [(0.0, 0.0), (0.0, 0.5), (1.0, 0.5), (0.45, 0.8)] {
            for la in [-0.4, 0.0, 0.4, 0.8] {
                // light rotated about x by (t + la) so it sweeps around the tilted surface normal
                let v = probe { s, m in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(alb); m.metalness.contents = met; m.roughness.contents = rough; light(s, .directional, 250, .white, euler: SCNVector3(Float(t + la), 0, 0)) }
                print("graze tilt=\(t) rough=\(rough) met=\(met) alb=\(alb) la=\(la) \(v[0])")
            }
        }
    }
}
