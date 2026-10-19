import SceneKit
import AppKit
import Metal

let a = CommandLine.arguments
let scene = try! SCNScene(url: URL(fileURLWithPath: a[1]), options: nil)
for name in a.dropFirst(5) {
    switch name {
    case "noparticles":
        scene.rootNode.enumerateHierarchy { n, _ in n.removeAllParticleSystems() }
    case "nosubdiv":
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.subdivisionLevel = 0 }
    case "noclearcoat":
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.clearCoat.intensity = 0 } }
    case "nonormal":
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.normal.contents = nil } }
    case "nometalness":
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.metalness.intensity = 0 } }
    case "noselfillumination":
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.selfIllumination.intensity = 0 } }
    case "noemission":
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.emission.intensity = 0 } }
    case "flatdiffuse":
        let grey = NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.diffuse.contents = grey } }
    case let name where name.hasPrefix("nolight+"):
        let type = ["ambient": SCNLight.LightType.ambient, "omni": .omni, "directional": .directional, "spot": .spot][String(name.dropFirst(8))]!
        scene.rootNode.enumerateHierarchy { n, _ in if n.light?.type == type { n.light = nil } }
    case let name where name.hasPrefix("metalness="):
        let value = Double(name.dropFirst(10))!
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.metalness.contents = value; $0.metalness.intensity = 1 } }
    case let name where name.hasPrefix("roughness="):
        let value = Double(name.dropFirst(10))!
        scene.rootNode.enumerateHierarchy { n, _ in n.geometry?.materials.forEach { $0.roughness.contents = value; $0.roughness.intensity = 1 } }
    default:
        FileHandle.standardError.write("render: unknown switch \(name)\n".data(using: .utf8)!)
        exit(2)
    }
}
let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
renderer.scene = scene
var camera: SCNNode?
scene.rootNode.enumerateHierarchy { n, stop in if n.camera != nil { camera = n; stop.pointee = true } }
renderer.pointOfView = camera
let size = Double(a[2])!
let image = renderer.snapshot(atTime: Double(a[3])!, with: CGSize(width: size, height: size), antialiasingMode: .none)
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[4]))
