// What a physically based material's selfIllumination draws on macOS SceneKit, with no light: one quad facing an orthographic camera,
// turned about y by theta, pixel (4, 4) of an 8x8 snapshot. Prints "albedo roughness theta metalness selfIllumination pixel";
// fitselfcoat.py holds every line to the port's model of it.
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
func gray(_ g: Double) -> NSColor { NSColor(srgbRed: g, green: g, blue: g, alpha: 1) }
for m in [0.0, 0.45] {
    for alb in [0.2, 0.5, 0.8] {
        for theta in [0.0, 45.0, 60.0, 70.0, 75.0, 80.0] {
            for rough in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0] {
                for si in [1.0, 0.75] {
                    let v = probe { s, mat in
                        mat.lightingModel = .physicallyBased; mat.diffuse.contents = gray(alb); mat.metalness.contents = m
                        mat.roughness.contents = rough; mat.selfIllumination.contents = gray(1); mat.selfIllumination.intensity = CGFloat(si)
                        s.rootNode.childNodes[1].eulerAngles = SCNVector3(0, Float(theta * Double.pi / 180), 0)
                    }
                    print(alb, rough, theta, m, si, Int(v[0]))
                }
            }
        }
    }
}
