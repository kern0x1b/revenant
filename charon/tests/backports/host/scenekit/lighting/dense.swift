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
func probe(_ configure: (SCNScene, SCNMaterial) -> Void) -> [Double] {
    let scene = SCNScene()
    let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.usesOrthographicProjection = true; cam.camera!.orthographicScale = 1
    cam.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(cam)
    let node = SCNNode(geometry: quad()); scene.rootNode.addChildNode(node)
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
// dense data for fitting: angle a of a directional light from the view axis
let angles = stride(from: 0.0, through: 1.2, by: 0.05).map { $0 }
for model in [SCNMaterial.LightingModel.blinn, .phong] {
    for sh in [0.25, 0.5, 1.0, 2.0] {
        for a in angles {
            let v = probe { s, m in m.lightingModel = model; m.diffuse.contents = gray(0); m.specular.contents = gray(0.5); m.shininess = CGFloat(sh); light(s, .directional, 1000, .white, euler: SCNVector3(Float(a), 0, 0)) }
            print("spec \(model.rawValue) shin=\(sh) a=\(a) \(v[0])")
        }
    }
}
for rough in [0.1, 0.2, 0.3, 0.45, 0.6, 0.8, 1.0] {
    for a in angles {
        for (met, alb) in [(1.0, 1.0), (1.0, 0.5), (0.0, 0.0), (0.0, 1.0)] {
            let v = probe { s, m in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(alb); m.metalness.contents = met; m.roughness.contents = rough; light(s, .directional, 250, .white, euler: SCNVector3(Float(a), 0, 0)) }
            print("pbr rough=\(rough) met=\(met) alb=\(alb) a=\(a) \(v[0])")
        }
    }
}
for si in [0.0, 0.25, 0.5, 0.75, 1.0] {
    for (amb, dir) in [(0.0, 0.0), (1000.0, 0.0), (500.0, 0.0), (0.0, 1000.0)] {
        for alb in [0.5, 1.0] {
            let v = probe { s, m in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(alb); m.selfIllumination.contents = gray(si)
                if amb > 0 { light(s, .ambient, CGFloat(amb), .white) }
                if dir > 0 { light(s, .directional, CGFloat(dir), .white, euler: SCNVector3(1.0, 0, 0)) } }
            print("selfillum si=\(si) amb=\(amb) dir=\(dir) alb=\(alb) \(v[0])")
        }
    }
}
for (name, body) in [
    ("roughness number .45", { (s: SCNScene, m: SCNMaterial) in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(1); m.metalness.contents = 1.0; m.roughness.contents = 0.45; light(s, .directional, 250, .white, euler: SCNVector3(0.3, 0, 0)) }),
    ("roughness color .45", { (s: SCNScene, m: SCNMaterial) in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(1); m.metalness.contents = 1.0; m.roughness.contents = gray(0.45); light(s, .directional, 250, .white, euler: SCNVector3(0.3, 0, 0)) }),
    ("roughness white intensity .45", { (s: SCNScene, m: SCNMaterial) in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(1); m.metalness.contents = 1.0; m.roughness.contents = gray(1); m.roughness.intensity = 0.45; light(s, .directional, 250, .white, euler: SCNVector3(0.3, 0, 0)) }),
    ("metalness number .45", { (s: SCNScene, m: SCNMaterial) in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(0.5); m.metalness.contents = 0.45; m.roughness.contents = 0.45; light(s, .directional, 250, .white, euler: SCNVector3(0.3, 0, 0)) }),
    ("metalness color .45", { (s: SCNScene, m: SCNMaterial) in m.lightingModel = .physicallyBased; m.diffuse.contents = gray(0.5); m.metalness.contents = gray(0.45); m.roughness.contents = 0.45; light(s, .directional, 250, .white, euler: SCNVector3(0.3, 0, 0)) }),
] { print("scalar \(name) \(probe(body)[0])") }
