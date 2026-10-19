// The bridge to SceneKit: this port's scene graph as an `SCNScene`, which is what a view
// presents.
//
// RealityKit's own `ARView` has an `scnScene`, and the translation from its entity graph to
// SceneKit's is private. This is the same translation, written here so that the meshes and
// materials above are drawn by the SceneKit the backports carry rather than sitting in a
// module with no way out. It is a translation and nothing else: it reads the graph, it does not
// step the simulation and it does not draw.
//
// The SDK's SceneKit apinote has two top-level `Protocols:` keys and Swift's importer refuses
// the module because of it (measured 2026-09-27, iPhoneOS16.4.sdk cccc080d0cbe42c2a85b1369aba6e290:
// `SceneKit.apinotes:141:1: error: duplicated mapping key 'Protocols'` for every target). The
// package merges the two lists into one with merge_apinotes in xmake.lua and hands this
// compile a clang VFS overlay that points the SDK's file at the merged one, so the fix is local
// to this module and the SDK package's hash does not move for any other band.

import SceneKit
import simd
import Foundation
import CoreGraphics

@MainActor
extension MeshResource {
    /// The SceneKit geometry of the mesh: one source per buffer the mesh has, and one element
    /// holding the indices as triangles.
    public func scnGeometry(materials partMaterials: [any Material] = []) -> SCNGeometry {
        var sources: [SCNGeometrySource] = []
        // Every source is built through SceneKit's one public constructor, the one its own
        // header documents for custom geometry: the three convenience constructors that take
        // an `SCNVector3` buffer are marked `SwiftPrivate` in the SDK's apinote, so Swift does
        // not have them, and the bytes are handed over as the raw data the constructor takes.
        if let positions = descriptor.positions {
            sources.append(__reSource(positions.array, semantic: .vertex, components: 3))
        }
        if let normals = descriptor.normals {
            sources.append(__reSource(normals.array, semantic: .normal, components: 3))
        }
        if let texCoords = descriptor.textureCoordinates {
            sources.append(__reSource(texCoords.array, semantic: .texcoord, components: 2))
        }
        // The geometry is built by SceneKit's own factory from the sources and the elements:
        // both properties are readonly at this SDK's availability, so there is nothing to
        // assign to afterwards. Swift spells the factory's arguments `sources:` and `elements:`,
        // which the SDK's own apinote renames them to.
        var elements: [SCNGeometryElement] = []
        if let indices = descriptor.triangleIndices, !indices.array.isEmpty {
            elements.append(SCNGeometryElement(data: Data(bytes: indices.array, count: indices.array.count * MemoryLayout<UInt32>.size),
                                                primitiveType: .triangles, primitiveCount: indices.array.count / 3,
                                                bytesPerIndex: MemoryLayout<UInt32>.size))
        }
        let geometry = SCNGeometry(sources: sources, elements: elements)
        // The faces' own material count decides how many materials the geometry carries: a mesh
        // whose faces are all one material carries one, and one that names a material per face
        // carries as many as the highest index it names.
        var materials = partMaterials.map { $0.scnMaterial }
        while materials.count < descriptor.expectedMaterialCount { materials.append(SCNMaterial()) }
        geometry.materials = materials
        return geometry
    }
}

/// One geometry source from an array of vectors, through SceneKit's public constructor.
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
    /// The SceneKit material this one is, with its parameters carried across.
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
            // An occluder writes depth and shows nothing: a material with no diffuse and no
            // emission is exactly that, and SceneKit's depth-only pass draws it.
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

/// The SceneKit contents of a colour: a `CGColor` boxed, which is what `SCNMaterialProperty`
/// takes on both this port and macOS.
@MainActor
internal func __reCGColor(_ color: UIColor) -> Any {
    color.cgColor
}

@MainActor
extension __REEntity {
    /// The SceneKit node of this entity: its transform, and a geometry for the model it
    /// carries. A child of it is a child of the node, so the whole subtree follows.
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

    /// The transform as SceneKit spells it: the same sixteen floats, laid out row-major, which
    /// is what `SCNMatrix4` is - its `m11`…`m14` are the *first* row, and a translation on z is
    /// therefore `m34` and not `m14`. A row-vector matrix, so a composition applies the left
    /// factor first, which is what the backports' own `SCNMatrix4Mult` documents.
    ///
    /// The sixteen values are converted to the matrix's own element type and written through its
    /// storage rather than through a memberwise call, because there is no spelling of the
    /// constructor that takes both: `SCNMatrix4` is an array of `Float` on this port and of
    /// `CGFloat`, which is `Double`, on a 64-bit host, and copying `Float` bytes into the latter
    /// would put every other element in the wrong place.
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
    /// The SceneKit scene this scene is: one node per anchor, and each anchor's subtree below
    /// it, with every mesh's geometry and every material's parameters carried across.
    ///
    /// This is what a view presents on this port. It is a translation of the graph as it is
    /// now: a caller that wants the drawing to follow the simulation takes it again after a
    /// step, which is what `__advancePhysics(deltaTime:)`'s caller does.
    public var scnScene: SCNScene {
        let scene = SCNScene()
        for anchor in coreScene.anchors {
            scene.rootNode.addChildNode(anchor.scnNode)
        }
        return scene
    }
}

// MARK: - What a hit test answers

@MainActor
extension SCNNode {
    /// The entity of this node in the given scene: the nearest node up the chain whose name is an
    /// entity's name there.
    ///
    /// A hit test answers with a node, and a *geometry* node carries a mesh part's name, not its
    /// entity's - so the walk goes up to the nearest ancestor that names an entity, and a node the
    /// bridge did not build (a camera, a light, anything the view added) has no answer and returns
    /// nil rather than an entity it cannot know.
    ///
    /// This is the resolution `ARView.gestureRecognizerShouldBegin` (ARView.swift:364) did inline
    /// for a touch, so a touch and a pixel cast cannot disagree about what was hit.
    public func entity(in scene: Scene) -> Entity? {
        var current: SCNNode? = self
        while let node = current {
            if let name = node.name, !name.isEmpty, let found = scene.findEntity(named: name) { return found }
            current = node.parent
        }
        return nil
    }
}
