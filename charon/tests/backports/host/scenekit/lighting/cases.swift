// cases <out.json> [ladder] : the lighting grid as data, with macOS SceneKit's pixel for each case. One quad facing an
// orthographic camera at z = 5 (scale 1), 8x8 pixels, the pixel at (4, 4) read as SceneKit stores it (sRGB,
// premultiplied). tests/backports/device/scenekit-lighting.m builds the same scenes from the same data through the
// port and holds its shader to these pixels. Each case whose result depends on the specular exponent or the roughness
// also carries the pixel of a known-wrong renderer (the exponent 132/128 too large, the roughness 0.02 too large), which
// the device's pixel must miss: the negative control of the check.
import SceneKit
import AppKit
import Metal

typealias Case = [String: Any]
let device = MTLCreateSystemDefaultDevice()

func quad() -> SCNGeometry {
    let v: [SCNVector3] = [SCNVector3(-1, -1, 0), SCNVector3(1, -1, 0), SCNVector3(1, 1, 0), SCNVector3(-1, 1, 0)]
    let n = [SCNVector3](repeating: SCNVector3(0, 0, 1), count: 4)
    let idx: [UInt16] = [0, 1, 2, 0, 2, 3]
    let uv = [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0)]
    return SCNGeometry(sources: [SCNGeometrySource(vertices: v), SCNGeometrySource(normals: n), SCNGeometrySource(textureCoordinates: uv)],
                       elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
}
func colour(_ c: [Double]) -> NSColor { NSColor(srgbRed: c[0], green: c[1], blue: c[2], alpha: c.count > 3 ? c[3] : 1) }
func grey(_ g: Double) -> NSColor { colour([g, g, g, 1]) }
func d(_ c: Case, _ k: String) -> Double? { c[k] as? Double }
// an opaque image of one colour, for the cases that put an image in the diffuse slot
func solid(_ c: [Double]) -> NSImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    return NSImage(cgImage: context.makeImage()!, size: NSSize(width: 4, height: 4))
}
func render(_ c: Case) -> [Int] {
    let scene = SCNScene()
    let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera!.usesOrthographicProjection = true
    camera.camera!.orthographicScale = 1; camera.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(camera)
    let node = SCNNode(geometry: quad()); scene.rootNode.addChildNode(node)
    node.eulerAngles = SCNVector3(Float(d(c, "tilt") ?? 0), 0, 0)
    node.opacity = CGFloat(d(c, "opacity") ?? 1)
    let m = SCNMaterial(); node.geometry!.materials = [m]
    m.lightingModel = SCNMaterial.LightingModel(rawValue: "SCNLightingModel" + (c["model"] as! String))
    m.diffuse.contents = c["diffuseImage"] != nil ? (solid(c["diffuse"] as! [Double]) as Any) : (colour(c["diffuse"] as! [Double]) as Any)
    if let v = d(c, "diffuseIntensity") { m.diffuse.intensity = CGFloat(v) }
    if let v = d(c, "specular") { m.specular.contents = grey(v) }
    if let v = d(c, "shininess") { m.shininess = CGFloat(v) }
    if let v = d(c, "metalness") { m.metalness.contents = v }
    if let v = d(c, "roughness") { m.roughness.contents = v }
    if let v = d(c, "emission") { m.emission.contents = grey(v) }
    if let v = d(c, "multiply") { m.multiply.contents = grey(v) }
    if let v = d(c, "selfIllumination") { m.selfIllumination.contents = grey(v) }
    if let v = d(c, "selfIlluminationIntensity") { m.selfIllumination.intensity = CGFloat(v) }
    if c["roughnessDefaultAssigned"] != nil { m.roughness.contents = SCNMaterial().roughness.contents }
    if let v = d(c, "roughnessIntensity") { m.roughness.intensity = CGFloat(v) }
    if let v = d(c, "ambientOcclusion") { m.ambientOcclusion.contents = grey(v) }
    if let v = d(c, "transparency") { m.transparency = CGFloat(v) }
    if let v = c["transparent"] as? [Double] { m.transparent.contents = NSColor(white: v[0], alpha: v[1]) }
    if let v = c["ambient"] as? [Double] { m.ambient.contents = grey(v[0]); m.locksAmbientWithDiffuse = v[1] != 0 }
    for l in c["lights"] as! [Case] {
        let n = SCNNode(); let light = SCNLight(); n.light = light
        light.type = SCNLight.LightType(rawValue: l["type"] as! String)
        light.intensity = CGFloat(l["intensity"] as! Double)
        light.color = colour(l["color"] as? [Double] ?? [1, 1, 1])
        if let v = d(l, "start") { light.attenuationStartDistance = CGFloat(v) }
        if let v = d(l, "end") { light.attenuationEndDistance = CGFloat(v) }
        if let v = d(l, "exponent") { light.attenuationFalloffExponent = CGFloat(v) }
        if let v = d(l, "inner") { light.spotInnerAngle = CGFloat(v) }
        if let v = d(l, "outer") { light.spotOuterAngle = CGFloat(v) }
        if let e = l["euler"] as? [Double] { n.eulerAngles = SCNVector3(Float(e[0]), Float(e[1]), Float(e[2])) }
        if let p = l["position"] as? [Double] { n.position = SCNVector3(Float(p[0]), Float(p[1]), Float(p[2])) }
        scene.rootNode.addChildNode(n)
    }
    let r = SCNRenderer(device: device, options: nil); r.scene = scene; r.pointOfView = camera
    let image = r.snapshot(atTime: 0, with: CGSize(width: 8, height: 8), antialiasingMode: .none)
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    var px = [Int](repeating: 0, count: 4)
    rep.getPixel(&px, atX: 4, y: 4)
    return px
}

func light(_ type: String, _ intensity: Double, euler: [Double]? = nil, position: [Double]? = nil, colour: [Double]? = nil, extra: Case = [:]) -> Case {
    var l: Case = ["type": type, "intensity": intensity]
    if let euler = euler { l["euler"] = euler }
    if let position = position { l["position"] = position }
    if let colour = colour { l["color"] = colour }
    for (k, v) in extra { l[k] = v }
    return l
}
func add(_ name: String, _ model: String, _ diffuse: [Double], _ lights: [Case], _ extra: Case = [:]) {
    var c: Case = ["name": name, "model": model, "diffuse": diffuse, "lights": lights]
    for (k, v) in extra { c[k] = v }
    cases.append(c)
}
var cases: [Case] = []
let models = ["Constant", "Lambert", "Blinn", "Phong", "PhysicallyBased"]
let half: [Double] = [0.5, 0.5, 0.5, 1]

// the rules of facts/SceneKit/SCNView.md, "Lighting", one case each
for model in models {
    add("\(model) no light", model, half, [])
    for g in [0.25, 1.0] { add("\(model) ambient diffuse \(g)", model, [g, g, g, 1], [light("ambient", 1000)]) }
    for i in [250.0, 2000.0] { add("\(model) ambient \(i)", model, half, [light("ambient", i)]) }
    for a in [0.0, 0.5, 1.0, 1.3] { add("\(model) directional at \(a)", model, half, [light("directional", 1000, euler: [a, 0, 0])]) }
    add("\(model) ambient and directional", model, half, [light("ambient", 1000), light("directional", 1000)])
    add("\(model) ambient and directional away", model, half, [light("ambient", 1000), light("directional", 1000, euler: [Double.pi, 0, 0])])
    add("\(model) coloured light", model, [1, 1, 1, 1], [light("directional", 1000, euler: [0.5, 0, 0], colour: [0.5, 0, 0])])
    add("\(model) emission and multiply", model, half, [light("ambient", 1000)], ["emission": 0.25, "multiply": 0.5])
    add("\(model) diffuse intensity", model, [1, 1, 1, 1], [light("directional", 1000, euler: [0.5, 0, 0])], ["diffuseIntensity": 0.5])
    // an image in the diffuse slot: its intensity scales the colour and leaves the alpha, as a colour's does
    add("\(model) diffuse image", model, half, [light("directional", 1000, euler: [0.5, 0, 0])], ["diffuseImage": true])
    add("\(model) diffuse image intensity 0.5", model, half, [light("directional", 1000, euler: [0.5, 0, 0])], ["diffuseImage": true, "diffuseIntensity": 0.5])
    add("\(model) transparency", model, [1, 1, 1, 1], [light("directional", 1000, euler: [0.5, 0, 0])], ["transparency": 0.5])
    add("\(model) transparent alpha", model, [1, 1, 1, 1], [light("directional", 1000, euler: [0.5, 0, 0])], ["transparent": [1.0, 0.5]])
    add("\(model) diffuse alpha", model, [1, 1, 1, 0.5], [light("directional", 1000, euler: [0.5, 0, 0])])
    add("\(model) node opacity", model, [1, 1, 1, 1], [light("directional", 1000, euler: [0.5, 0, 0])], ["opacity": 0.5])
    add("\(model) ambient slot locked", model, half, [light("ambient", 1000), light("directional", 1000, euler: [0.5, 0, 0])], ["ambient": [0.25, 1]])
    add("\(model) ambient slot unlocked", model, half, [light("ambient", 1000), light("directional", 1000, euler: [0.5, 0, 0])], ["ambient": [0.25, 0]])
    add("\(model) occlusion colour", model, half, [light("ambient", 1000), light("directional", 1000, euler: [0.5, 0, 0])], ["ambientOcclusion": 0.5])
    for si in [0.25, 0.75] {
        add("\(model) self illumination \(si)", model, half, [light("directional", 1000, euler: [1, 0, 0])], ["selfIllumination": si])
        add("\(model) self illumination \(si) metal", model, half, [light("ambient", 1000), light("directional", 1000, euler: [1, 0, 0])], ["selfIllumination": si, "metalness": 0.45])
    }
    // selfIllumination adds to the lights the diffuse colour takes: facing away from the only light, with an ambient
    // light alone or no light at all (where it adds nothing), and at half intensity
    add("\(model) self illumination 0.5 light away", model, half, [light("directional", 1000, euler: [Double.pi, 0, 0])], ["selfIllumination": 0.5])
    add("\(model) self illumination 0.5 ambient only", model, half, [light("ambient", 1000)], ["selfIllumination": 0.5])
    add("\(model) self illumination 0.5 no light", model, half, [], ["selfIllumination": 0.5])
    add("\(model) self illumination 0.5 intensity 0.5", model, half, [light("directional", 1000, euler: [1, 0, 0])], ["selfIllumination": 0.5, "selfIlluminationIntensity": 0.5])
    let pointScale = model == "PhysicallyBased" ? 0.004 : 1.0
    for z in [1.0, 2.0, 4.0] {
        add("\(model) omni at \(z)", model, half, [light("omni", 1000 * pointScale, position: [0, 0, z])], ["roughness": 1.0])
        add("\(model) omni at \(z) end 20", model, half, [light("omni", 1000 * pointScale, position: [0, 0, z], extra: ["end": 20.0])], ["roughness": 1.0])
        add("\(model) omni at \(z) 1 to 5 linear", model, half, [light("omni", 1000 * pointScale, position: [0, 0, z], extra: ["start": 1.0, "end": 5.0, "exponent": 1.0])], ["roughness": 1.0])
    }
    add("\(model) omni off axis", model, half, [light("omni", 1000 * pointScale, position: [1, 0, 1])], ["roughness": 1.0])
    for (inner, outer, off) in [(0.0, 45.0, 0.0), (0.0, 45.0, 0.2), (0.0, 45.0, 0.35), (20.0, 60.0, 0.1), (20.0, 60.0, 0.3), (20.0, 60.0, 0.45)] {
        add("\(model) spot \(inner)-\(outer) off \(off)", model, [1, 1, 1, 1], [light("spot", model == "PhysicallyBased" ? 4 : 1000, euler: [off, 0, 0], position: [0, 0, 2], extra: ["inner": inner, "outer": outer])], ["roughness": 1.0])
    }
}
// the physically based point light's window, 2 to 18 units from the quad
for (start, end, exponent) in [(0.0, 20.0, 2.0), (5.0, 20.0, 1.0), (0.0, 12.0, 4.0)] {
    for dist in stride(from: 2.0, through: 18.0, by: 4.0) {
        add("PBR omni window \(start)-\(end)^\(exponent) at \(dist)", "PhysicallyBased", [1, 1, 1, 1],
            [light("omni", 0.5 * dist * dist, position: [0, 0, dist], extra: ["start": start, "end": end, "exponent": exponent])], ["roughness": 1.0])
    }
}
// the default roughness is drawn from its linear value, 0.2; the colour `contents` answers for it, assigned back, is read
// as it is, 0.484529; an intensity scales the default
for a in [0.0, 0.3, 0.5, 1.0] {
    add("PBR default roughness assigned back at \(a)", "PhysicallyBased", half, [light("directional", 1000, euler: [a, 0, 0])], ["roughnessDefaultAssigned": true])
    add("PBR default roughness intensity 0.5 at \(a)", "PhysicallyBased", half, [light("directional", 1000, euler: [a, 0, 0])], ["roughnessIntensity": 0.5])
}
// the specular fits: 24 angles of a directional light (stride's 0 to 1.15 in 0.05)
let angles = stride(from: 0.0, through: 1.2, by: 0.05).map { $0 }
for model in ["Blinn", "Phong"] {
    for sh in [0.25, 0.5, 1.0, 2.0] {
        for a in angles {
            add("\(model) specular \(sh) at \(a)", model, [0, 0, 0, 1], [light("directional", 1000, euler: [a, 0, 0])], ["specular": 0.5, "shininess": sh])
        }
    }
}
for rough in [0.1, 0.2, 0.3, 0.45, 0.6, 0.8, 1.0] {
    for a in angles {
        for (met, alb) in [(1.0, 1.0), (1.0, 0.5), (0.0, 0.0), (0.0, 1.0)] {
            add("PBR \(rough) metal \(met) albedo \(alb) at \(a)", "PhysicallyBased", [alb, alb, alb, 1], [light("directional", 250, euler: [a, 0, 0])], ["metalness": met, "roughness": rough])
        }
    }
}
// the smallest roughnesses: 0 and 0.05, where the shader's alpha = roughness^2 is exact to the last bit and the port's GGX holds, and
// 0.01 and 0.02 between them, where macOS's own answer leaves the formula (`cases ladder`, below, prints it, and
// facts/SceneKit/SCNView.md, "Open", says how). The seven cases of 0.01 and 0.02 the port does not draw as macOS does are named in
// device/scenekit-lighting.m as known open, not left out of the grid
for rough in [0.0, 0.01, 0.02, 0.05] {
    for a in [0.0, 0.02, 0.05, 0.1, 0.2, 0.4] {
        for (met, alb) in [(1.0, 1.0), (0.0, 1.0)] {
            add("PBR low roughness \(rough) metal \(met) albedo \(alb) at \(a)", "PhysicallyBased", [alb, alb, alb, 1], [light("directional", 250, euler: [a, 0, 0])], ["metalness": met, "roughness": rough])
        }
    }
}
// dark colours in the diffuse slot as an image, beside the same colour as a colour: the image is read by a sampler, whose precision
// (lowp unless the shader says otherwise) holds a dark linear value in coarser steps than the colour's uniform does
for dark in [0.01, 0.03, 0.06, 0.1] {
    for a in [0.0, 0.1, 0.2] {
        for image in [false, true] {
            var extra: [String: Any] = ["metalness": 1.0, "roughness": 0.2]
            if image { extra["diffuseImage"] = true }
            add("PBR dark diffuse \(image ? "image" : "colour") \(dark) metal 1.0 rough 0.2 at \(a)", "PhysicallyBased", [dark, dark, dark, 1], [light("directional", 250, euler: [a, 0, 0])], extra)
        }
    }
}
// grazing views: the quad tilted away from the camera, the light swept around its normal
for t in [0.9, 1.1, 1.25, 1.35] {
    for rough in [0.2, 0.45, 0.8] {
        for (met, alb) in [(0.0, 0.0), (0.0, 0.5), (1.0, 0.5), (0.45, 0.8)] {
            for la in [-0.4, 0.0, 0.4, 0.8] {
                add("PBR grazing \(t) \(rough) metal \(met) albedo \(alb) light \(la)", "PhysicallyBased", [alb, alb, alb, 1], [light("directional", 250, euler: [t + la, 0, 0])], ["metalness": met, "roughness": rough, "tilt": t])
            }
        }
    }
}
// selfIllumination with no light, beside the roughness, the metalness, the albedo and the view angle it depends on: the
// share of it the coat takes, and the diffuse a rough surface gives it (fitselfcoat.py)
for t in [0.0, 1.0, 1.3] {
    for rough in [0.0, 0.45, 1.0] {
        for (met, alb) in [(0.0, 0.2), (0.0, 0.5), (0.45, 0.5), (0.0, 0.8)] {
            add("PBR self illumination tilt \(t) rough \(rough) metal \(met) albedo \(alb)", "PhysicallyBased", [alb, alb, alb, 1], [],
                ["selfIllumination": 1.0, "selfIlluminationIntensity": 0.75, "metalness": met, "roughness": rough, "tilt": t])
        }
    }
}

// `cases <out.json> ladder`: macOS's pixel for a metal quad under a directional light at the smallest roughnesses, face-on
// and at two angles, printed (nothing is written)
if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "ladder" {
    for rough in [0.0, 0.005, 0.01, 0.0125, 0.015, 0.0175, 0.02, 0.03, 0.04, 0.05, 0.07, 0.1] {
        let row = [0.0, 0.05, 0.2].map { a -> String in
            let c: Case = ["model": "PhysicallyBased", "diffuse": [1.0, 1.0, 1.0, 1.0], "lights": [light("directional", 250, euler: [a, 0, 0])], "metalness": 1.0, "roughness": rough]
            return String(render(c)[0])
        }
        print("roughness \(rough): angle 0, 0.05, 0.2 draw", row.joined(separator: " "))
    }
    exit(0)
}

var out: [Case] = []
for c in cases {
    var r = c
    r["expected"] = render(c)
    var mutant = c
    if let sh = d(c, "shininess") { mutant["shininess"] = sh * 132 / 128 }
    else if let rough = d(c, "roughness"), c["model"] as! String == "PhysicallyBased" { mutant["roughness"] = rough + 0.02 }
    else { mutant = [:] }
    if !mutant.isEmpty { r["mutant"] = render(mutant) }
    out.append(r)
}
let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("\(out.count) cases")
