// How macOS SceneKit draws a new material's roughness: the pixel (4, 4) of a physically based quad lit by a directional
// light at 0, 0.3 and 0.5 rad, for the untouched default and for values set in its place, after a copy, an archive round
// trip, contents = nil and an intensity; and which properties a material's archive carries.
import SceneKit
import AppKit
import Metal

let device = MTLCreateSystemDefaultDevice()
func quad() -> SCNGeometry {
    let v: [SCNVector3] = [SCNVector3(-1, -1, 0), SCNVector3(1, -1, 0), SCNVector3(1, 1, 0), SCNVector3(-1, 1, 0)]
    let n = [SCNVector3](repeating: SCNVector3(0, 0, 1), count: 4)
    let idx: [UInt16] = [0, 1, 2, 0, 2, 3]
    return SCNGeometry(sources: [SCNGeometrySource(vertices: v), SCNGeometrySource(normals: n)],
                       elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
}
func grey(_ g: Double) -> NSColor { NSColor(srgbRed: g, green: g, blue: g, alpha: 1) }
func pixel(_ m: SCNMaterial, _ angle: Float) -> Int {
    let scene = SCNScene()
    let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera!.usesOrthographicProjection = true
    camera.camera!.orthographicScale = 1; camera.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(camera)
    let node = SCNNode(geometry: quad()); scene.rootNode.addChildNode(node); node.geometry!.materials = [m]
    let n = SCNNode(); let l = SCNLight(); n.light = l; l.type = .directional; l.intensity = 1000
    n.eulerAngles = SCNVector3(angle, 0, 0); scene.rootNode.addChildNode(n)
    let r = SCNRenderer(device: device, options: nil); r.scene = scene; r.pointOfView = camera
    let rep = NSBitmapImageRep(data: r.snapshot(atTime: 0, with: CGSize(width: 8, height: 8), antialiasingMode: .none).tiffRepresentation!)!
    var px = [Int](repeating: 0, count: 4); rep.getPixel(&px, atX: 4, y: 4); return px[0]
}
func archived(_ m: SCNMaterial) -> Data { try! NSKeyedArchiver.archivedData(withRootObject: m, requiringSecureCoding: false) }
func roundTrip(_ m: SCNMaterial) -> SCNMaterial { try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archived(m)) as! SCNMaterial }
func archivedProperties(_ m: SCNMaterial) -> String {
    let plist = try! PropertyListSerialization.propertyList(from: archived(m), format: nil) as! [String: Any]
    let slots = ["diffuse", "ambient", "specular", "normal", "reflective", "emission", "transparent", "multiply", "displacement",
                 "ambientOcclusion", "selfIllumination", "metalness", "roughness"]
    let material = (plist["$objects"] as! [Any]).compactMap { $0 as? [String: Any] }.first { $0["shininess"] != nil }!
    return slots.filter { material[$0] != nil }.joined(separator: ",")
}
func pbr(_ set: (SCNMaterial) -> Void) -> SCNMaterial {
    let m = SCNMaterial(); m.lightingModel = .physicallyBased; m.diffuse.contents = grey(0.5); set(m); return m
}
let lin = NSColorSpace(cgColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!)!
let linGrey = NSColorSpace(cgColorSpace: CGColorSpace(name: CGColorSpace.linearGray)!)!
print("# the default contents:", SCNMaterial().roughness.contents!)
let cases: [(String, SCNMaterial)] = [
    ("default", pbr { _ in }),
    ("number 0.2", pbr { $0.roughness.contents = 0.2 }),
    ("number 0.484529", pbr { $0.roughness.contents = 0.484529 }),
    ("sRGB grey 0.2", pbr { $0.roughness.contents = grey(0.2) }),
    ("sRGB grey 0.484529", pbr { $0.roughness.contents = grey(0.484529) }),
    ("linear sRGB grey 0.2", pbr { $0.roughness.contents = NSColor(colorSpace: lin, components: [0.2, 0.2, 0.2, 1], count: 4) }),
    ("linear grey 0.2", pbr { $0.roughness.contents = NSColor(colorSpace: linGrey, components: [0.2, 1], count: 2) }),
    ("generic gamma 2.2 white 0.2", pbr { $0.roughness.contents = NSColor(genericGamma22White: 0.2, alpha: 1) }),
    ("calibrated white 0.2", pbr { $0.roughness.contents = NSColor(calibratedWhite: 0.2, alpha: 1) }),
    ("device white 0.2", pbr { $0.roughness.contents = NSColor(deviceWhite: 0.2, alpha: 1) }),
    ("Display P3 grey 0.2", pbr { $0.roughness.contents = NSColor(displayP3Red: 0.2, green: 0.2, blue: 0.2, alpha: 1) }),
    ("the default's contents assigned back", pbr { $0.roughness.contents = SCNMaterial().roughness.contents }),
    ("default after reading contents", pbr { _ = $0.roughness.contents }),
    ("default, copied", pbr { _ in }.copy() as! SCNMaterial),
    ("default, archived and decoded", roundTrip(pbr { _ in })),
    ("the default's contents assigned back, archived and decoded", roundTrip(pbr { $0.roughness.contents = SCNMaterial().roughness.contents })),
    ("contents nil", pbr { $0.roughness.contents = nil }),
    ("default at intensity 0.5", pbr { $0.roughness.intensity = 0.5 }),
    ("number 0.1", pbr { $0.roughness.contents = 0.1 }),
]
for (name, m) in cases {
    print("\(name): \(pixel(m, 0)) \(pixel(m, 0.3)) \(pixel(m, 0.5))")
}
print("# archived properties: new material [\(archivedProperties(SCNMaterial()))], diffuse set [\(archivedProperties(pbr { _ in }))], roughness intensity set [\(archivedProperties(pbr { $0.roughness.intensity = 0.5 }))]")
