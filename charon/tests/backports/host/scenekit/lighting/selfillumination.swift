// selfIllumination in Lambert, Blinn and Phong on macOS SceneKit: one quad facing an orthographic camera, pixel (4, 4)
// of an 8x8 snapshot. Prints "model diffuse selfIllumination lights pixel"; fitselfillumination.py holds every line to
// diffuse * (ambient + sum of N.L + selfIllumination), with the sum taken as 1 when no light but ambient ones is there.
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
typealias Light = (type: SCNLight.LightType, intensity: Double, angle: Double)
func render(_ model: String, _ diffuse: Double, _ lights: [Light], _ setup: (SCNMaterial) -> Void) -> Int {
    let scene = SCNScene()
    let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera!.usesOrthographicProjection = true
    camera.camera!.orthographicScale = 1; camera.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(camera)
    let node = SCNNode(geometry: quad()); scene.rootNode.addChildNode(node)
    let m = SCNMaterial(); node.geometry!.materials = [m]
    m.lightingModel = SCNMaterial.LightingModel(rawValue: "SCNLightingModel" + model)
    m.diffuse.contents = grey(diffuse)
    setup(m)
    for l in lights {
        let n = SCNNode(); let light = SCNLight(); n.light = light; light.type = l.type; light.intensity = CGFloat(l.intensity)
        n.eulerAngles = SCNVector3(Float(l.angle), 0, 0); scene.rootNode.addChildNode(n)
    }
    let r = SCNRenderer(device: device, options: nil); r.scene = scene; r.pointOfView = camera
    let rep = NSBitmapImageRep(data: r.snapshot(atTime: 0, with: CGSize(width: 8, height: 8), antialiasingMode: .none).tiffRepresentation!)!
    var px = [Int](repeating: 0, count: 4); rep.getPixel(&px, atX: 4, y: 4)
    return px[0]
}
// name -> lights; a directional light at angle a has N.L = cos(a)
let lightSets: [(String, [Light])] = [
    ("none", []), ("dir0", [(.directional, 1000, 0)]), ("dir1", [(.directional, 1000, 1)]), ("away", [(.directional, 1000, Double.pi)]),
    ("amb", [(.ambient, 1000, 0)]), ("amb+dir1", [(.ambient, 1000, 0), (.directional, 1000, 1)]), ("dir1x0.5", [(.directional, 500, 1)]),
]
for model in ["Constant", "Lambert", "Blinn", "Phong"] {
    for diffuse in [0.25, 0.5, 1.0] {
        for si in [0.0, 0.1, 0.25, 0.5, 0.75, 1.0] {
            for (name, lights) in lightSets {
                print(model, diffuse, si, name, render(model, diffuse, lights) { $0.selfIllumination.contents = grey(si) })
            }
        }
    }
    // beside the other terms: "model term selfIllumination pixel"
    for si in [0.0, 0.5] {
        print(model, "specular", si, render(model, 0.5, [(.directional, 1000, 0.2)]) { m in m.selfIllumination.contents = grey(si); m.specular.contents = grey(0.5) })
        print(model, "emission", si, render(model, 0.5, [(.directional, 1000, 1)]) { m in m.selfIllumination.contents = grey(si); m.emission.contents = grey(0.25) })
        print(model, "intensity0.5", si, render(model, 0.5, [(.directional, 1000, 1)]) { m in m.selfIllumination.contents = grey(si); m.selfIllumination.intensity = 0.5 })
        print(model, "unlockedambient", si, render(model, 0.5, [(.ambient, 1000, 0), (.directional, 1000, 1)]) { m in
            m.selfIllumination.contents = grey(si); m.ambient.contents = grey(0.25); m.locksAmbientWithDiffuse = false })
    }
}
