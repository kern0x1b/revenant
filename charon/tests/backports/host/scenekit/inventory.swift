// inventory <scenes-dir> : what macOS SceneKit finds in each of Telegram's ten scenes (facts/SceneKit/SCNView.md, "Which
// scenes Telegram draws"): the decompressed files star2.scn, coin.scn, gift2.scn, badge.scn, emoji.scn, tag.scn, business.scn,
// boost.scn, lightspeed.scn and swirl.scn (`git show release-12.9.2:submodules/PremiumUI/Resources/<name> | gunzip`).
import SceneKit
import AppKit

let directory = CommandLine.arguments[1]
for name in ["star2", "coin", "gift2", "badge", "emoji", "tag", "business", "boost", "lightspeed", "swirl"] {
    guard let scene = try? SCNScene(url: URL(fileURLWithPath: "\(directory)/\(name).scn"), options: nil) else { print(name, "does not load"); continue }
    var nodes = 0, geometries = 0, lights: [String] = [], models = Set<String>(), particles = 0, subdivided = 0, cameras = 0, imageSlots = 0
    func walk(_ node: SCNNode) {
        nodes += 1
        if let light = node.light { lights.append(light.type.rawValue) }
        if node.camera != nil { cameras += 1 }
        particles += node.particleSystems?.count ?? 0
        if let geometry = node.geometry {
            geometries += 1
            if geometry.subdivisionLevel > 0 { subdivided += 1 }
            for material in geometry.materials {
                models.insert(material.lightingModel.rawValue.replacingOccurrences(of: "SCNLightingModel", with: ""))
                for property in [material.diffuse, material.emission, material.metalness, material.roughness, material.selfIllumination, material.transparent, material.multiply, material.reflective]
                where property.contents is NSImage || property.contents is URL || property.contents is String { imageSlots += 1 }
            }
        }
        node.childNodes.forEach(walk)
    }
    walk(scene.rootNode)
    print(name, "nodes", nodes, "geometries", geometries, "cameras", cameras, "lights", lights.sorted(), "models", models.sorted(), "particleSystems", particles, "subdivided", subdivided, "imageSlots", imageSlots)
}
