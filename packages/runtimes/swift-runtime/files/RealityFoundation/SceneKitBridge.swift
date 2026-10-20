import SceneKit
import simd
import Foundation
import CoreGraphics

@MainActor
extension MeshResource {
    public func scnGeometry(materials partMaterials: [any Material] = []) -> SCNGeometry {
        var sources: [SCNGeometrySource] = []
        if let positions = descriptor.positions {
            sources.append(__reSource(positions.array, semantic: .vertex, components: 3))
        }
        if let normals = descriptor.normals {
            sources.append(__reSource(normals.array, semantic: .normal, components: 3))
        }
        if let texCoords = descriptor.textureCoordinates {
            sources.append(__reSource(texCoords.array, semantic: .texcoord, components: 2))
        }
        var elements: [SCNGeometryElement] = []
        if let indices = descriptor.triangleIndices, !indices.array.isEmpty {
            elements.append(SCNGeometryElement(data: Data(bytes: indices.array, count: indices.array.count * MemoryLayout<UInt32>.size),
                                                primitiveType: .triangles, primitiveCount: indices.array.count / 3,
                                                bytesPerIndex: MemoryLayout<UInt32>.size))
        }
        let geometry = SCNGeometry(sources: sources, elements: elements)
        var materials = partMaterials.map { $0.scnMaterial }
        while materials.count < descriptor.expectedMaterialCount { materials.append(SCNMaterial()) }
        geometry.materials = materials
        return geometry
    }
}

@MainActor
internal func __reSource<Value>(_ vectors: [Value], semantic: SCNGeometrySource.Semantic,
                               components: Int) -> SCNGeometrySource {
    SCNGeometrySource(data: Data(bytes: vectors, count: vectors.count * MemoryLayout<Value>.size),
                      semantic: semantic, vectorCount: vectors.count, usesFloatComponents: true,
                      componentsPerVector: components, bytesPerComponent: MemoryLayout<Float>.size,
                      dataOffset: 0, dataStride: MemoryLayout<Value>.size)
}

@MainActor
extension Material {
    public var scnMaterial: SCNMaterial {
        let material = SCNMaterial()
        switch self {
        case let simple as SimpleMaterial:
            material.lightingModel = .physicallyBased
            material.diffuse.contents = __reCGColor(simple.color.tint)
            material.metalness.contents = NSNumber(value: simple.metallic.value ?? 0)
            material.roughness.contents = NSNumber(value: simple.roughness.value ?? 0.5)
        case let unlit as UnlitMaterial:
            material.lightingModel = .constant
            material.diffuse.contents = __reCGColor(unlit.color.tint)
        case let pbr as PhysicallyBasedMaterial:
            material.lightingModel = .physicallyBased
            material.diffuse.contents = __reCGColor(pbr.baseColor.tint)
            material.metalness.contents = NSNumber(value: pbr.metallic.value.value ?? 0)
            material.roughness.contents = NSNumber(value: pbr.roughness.value.value ?? 0.5)
            material.emission.contents = __reCGColor(pbr.emissiveColor.color)
        case is OcclusionMaterial:
            material.lightingModel = .shadowOnly
            material.writesToDepthBuffer = true
        case is VideoMaterial:
            material.lightingModel = .constant
        default:
            material.lightingModel = .physicallyBased
        }
        return material
    }
}

@MainActor
internal func __reCGColor(_ color: UIColor) -> Any {
    color.cgColor
}

@MainActor
extension __REEntity {
    public var scnNode: SCNNode {
        let node = SCNNode()
        node.name = name
        node.transform = nodeTransform
        if let model = component(of: ModelComponent.self) {
            for part in model.model.parts {
                let child = SCNNode(geometry: part.mesh.scnGeometry(materials: part.materials))
                child.name = part.name
                node.addChildNode(child)
            }
        }
        for child in children {
            node.addChildNode(child.scnNode)
        }
        return node
    }

    private var nodeTransform: SCNMatrix4 {
        let m = transform.matrix
        let rows: [Float] = [m.columns.0.x, m.columns.0.y, m.columns.0.z, m.columns.0.w,
                             m.columns.1.x, m.columns.1.y, m.columns.1.z, m.columns.1.w,
                             m.columns.2.x, m.columns.2.y, m.columns.2.z, m.columns.2.w,
                             m.columns.3.x, m.columns.3.y, m.columns.3.z, m.columns.3.w]
        var matrix = SCNMatrix4Identity
        let values = rows.map { CGFloat($0) }
        values.withUnsafeBytes { source in
            withUnsafeMutableBytes(of: &matrix) { destination in
                destination.copyBytes(from: source)
            }
        }
        return matrix
    }
}

@MainActor
extension Scene {
    public var scnScene: SCNScene {
        let scene = SCNScene()
        for anchor in coreScene.anchors {
            scene.rootNode.addChildNode(anchor.scnNode)
        }
        return scene
    }
}

@MainActor
extension SCNNode {
    public func entity(in scene: Scene) -> Entity? {
        var current: SCNNode? = self
        while let node = current {
            if let name = node.name, !name.isEmpty, let found = scene.findEntity(named: name) { return found }
            current = node.parent
        }
        return nil
    }
}
