import simd
import Foundation

public enum MeshBuffers {
    public struct Identifier: Hashable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { self.rawValue = value }
        public var description: String { rawValue }

        public static let positions = Identifier("positions")
        public static let normals = Identifier("normals")
        public static let tangents = Identifier("tangents")
        public static let bitangents = Identifier("bitangents")
        public static let textureCoordinates = Identifier("texCoords")
        public static let triangleIndices = Identifier("triangleIndices")
    }

    public struct Rate: Hashable {
        public var vertex: Float
        public var primitive: Float
        public init(vertex: Float, primitive: Float) {
            self.vertex = vertex
            self.primitive = primitive
        }
        public static let vertex = Rate(vertex: 1, primitive: 1)
        public static let vertexNotInterpolated = Rate(vertex: 0, primitive: 0)
    }

    public struct ElementType: Hashable {
        public let byteCount: Int
        public init(byteCount: Int) { self.byteCount = byteCount }
        public static let scalar = ElementType(byteCount: 4)
        public static let vector2 = ElementType(byteCount: 8)
        public static let vector3 = ElementType(byteCount: 12)
        public static let vector4 = ElementType(byteCount: 16)
    }

    public struct Semantic<Element>: MeshBufferSemantic {
        public let id: Identifier
        public init(id: Identifier) { self.id = id }
    }

    public static let positions = Semantic<SIMD3<Float>>(id: .positions)
    public static let normals = Semantic<SIMD3<Float>>(id: .normals)
    public static let tangents = Semantic<SIMD3<Float>>(id: .tangents)
    public static let bitangents = Semantic<SIMD3<Float>>(id: .bitangents)
    public static let textureCoordinates = Semantic<SIMD2<Float>>(id: .textureCoordinates)
    public static let triangleIndices = Semantic<UInt32>(id: .triangleIndices)

    public static func custom<Value>(_ name: String, type: Value.Type) -> Semantic<Value> {
        Semantic<Value>(id: Identifier(name))
    }
}

public protocol MeshBufferSemantic: Identifiable {
    associatedtype Element
    var id: MeshBuffers.Identifier { get }
}

public struct MeshBuffer<Element>: RandomAccessCollection {
    public typealias Element = Element

    public let elements: [Element]
    public let id: MeshBuffers.Identifier
    public let rate: MeshBuffers.Rate

    public init(id: MeshBuffers.Identifier, elements: [Element], rate: MeshBuffers.Rate = .vertex) {
        self.id = id
        self.elements = elements
        self.rate = rate
    }

    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }
    public var startIndex: Int { 0 }
    public var endIndex: Int { elements.count }
    public func index(after i: Int) -> Int { i + 1 }
    public func makeIterator() -> IndexingIterator<[Element]> { elements.makeIterator() }
    public subscript(index: Int) -> Element { elements[index] }
    public var array: [Element] { elements }
}

public struct AnyMeshBuffer {
    public var id: MeshBuffers.Identifier
    public var count: Int
    public var rate: MeshBuffers.Rate
    public var elementType: MeshBuffers.ElementType
    private let storage: [Any]

    init(id: MeshBuffers.Identifier, rate: MeshBuffers.Rate, elementType: MeshBuffers.ElementType, storage: [Any]) {
        self.id = id
        self.rate = rate
        self.elementType = elementType
        self.count = storage.count
        self.storage = storage
    }

    public func get<Value>(_: Value.Type = Value.self) -> MeshBuffer<Value>? {
        let values = storage.compactMap { $0 as? Value }
        return values.count == storage.count ? MeshBuffer(id: id, elements: values, rate: rate) : nil
    }
}

public protocol MeshBufferContainer {
    var buffers: [MeshBuffers.Identifier: AnyMeshBuffer] { get set }
    subscript<S>(semantic: S) -> MeshBuffer<S.Element>? where S: MeshBufferSemantic { get set }
}

extension MeshBufferContainer {
    public subscript<S>(semantic: S) -> MeshBuffer<S.Element>? where S: MeshBufferSemantic {
        get { buffers[semantic.id]?.get(S.Element.self) }
        set {
            guard let newValue else {
                buffers.removeValue(forKey: semantic.id)
                return
            }
            let any = AnyMeshBuffer(id: semantic.id, rate: newValue.rate,
                                     elementType: MeshBuffers.ElementType(byteCount: MemoryLayout<S.Element>.size),
                                     storage: newValue.elements.map { $0 as Any })
            buffers[semantic.id] = any
        }
    }

    public var positions: MeshBuffer<SIMD3<Float>>? { self[MeshBuffers.positions] }
    public var normals: MeshBuffer<SIMD3<Float>>? { self[MeshBuffers.normals] }
    public var tangents: MeshBuffer<SIMD3<Float>>? { self[MeshBuffers.tangents] }
    public var bitangents: MeshBuffer<SIMD3<Float>>? { self[MeshBuffers.bitangents] }
    public var textureCoordinates: MeshBuffer<SIMD2<Float>>? { self[MeshBuffers.textureCoordinates] }
    public var triangleIndices: MeshBuffer<UInt32>? { self[MeshBuffers.triangleIndices] }
}

public struct MeshDescriptor: MeshBufferContainer {
    public enum Materials {
        case allFaces(UInt32)
        case perFace([UInt32])
    }

    public enum Primitives {
        case triangles([UInt32])
        case polygons([UInt8], [UInt32])
        case trianglesAndQuads(triangles: [UInt32], quads: [UInt32])
    }

    public var name: String
    public var materials: Materials
    public var primitives: Primitives?
    public var buffers: [MeshBuffers.Identifier: AnyMeshBuffer]

    public init(name: String = "") {
        self.name = name
        materials = .allFaces(0)
        buffers = [:]
    }

    public var expectedMaterialCount: Int {
        switch materials {
        case .allFaces: return 1
        case .perFace(let faces): return Int(faces.max() ?? 0) + 1
        }
    }
}

@MainActor
open class MeshResource: Resource {
    public private(set) var descriptor: MeshDescriptor

    public init(_ descriptor: MeshDescriptor) {
        self.descriptor = descriptor
    }

    public var expectedMaterialCount: Int { descriptor.expectedMaterialCount }

    public var bounds: BoundingBox {
        guard let positions = descriptor.positions, positions.count > 0 else { return BoundingBox() }
        var box = BoundingBox()
        for position in positions { box.extend(with: position) }
        return box
    }

    public static func generateBox(size: Float, cornerRadius: Float = 0) -> MeshResource {
        generateBox(size: SIMD3<Float>(repeating: size), cornerRadius: cornerRadius)
    }

    public static func generateBox(size: SIMD3<Float>, cornerRadius: Float = 0) -> MeshResource {
        generateBox(width: size.x, height: size.y, depth: size.z, cornerRadius: cornerRadius)
    }

    public static func generateBox(width: Float, height: Float, depth: Float, cornerRadius: Float = 0,
                                  splitFaces: Bool = false) -> MeshResource {
        var descriptor = MeshDescriptor(name: "Box")
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3<Float>(0, 0, 1), SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0)),
            (SIMD3<Float>(0, 0, -1), SIMD3<Float>(-1, 0, 0), SIMD3<Float>(0, 1, 0)),
            (SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 1)),
            (SIMD3<Float>(-1, 0, 0), SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, -1)),
            (SIMD3<Float>(0, 1, 0), SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 0, -1)),
            (SIMD3<Float>(0, -1, 0), SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 0, 1))
        ]
        let extent = SIMD3<Float>(width, height, depth) / 2
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for (normal, right, up) in faces {
            let base = UInt32(positions.count)
            let centre = normal * extent
            for (u, v) in [(Float(0), Float(0)), (Float(1), Float(0)), (Float(0), Float(1)), (Float(1), Float(1))] {
                positions.append(centre + right * (u - 0.5) * 2 * extent + up * (v - 0.5) * 2 * extent)
                normals.append(normal)
                texCoords.append(SIMD2<Float>(u, v))
            }
            indices += [base, base + 1, base + 2, base + 2, base + 1, base + 3]
        }
        descriptor[MeshBuffers.positions] = MeshBuffer(id: .positions, elements: positions)
        descriptor[MeshBuffers.normals] = MeshBuffer(id: .normals, elements: normals)
        descriptor[MeshBuffers.textureCoordinates] = MeshBuffer(id: .textureCoordinates, elements: texCoords)
        descriptor[MeshBuffers.triangleIndices] = MeshBuffer(id: .triangleIndices, elements: indices,
                                                             rate: .vertexNotInterpolated)
        descriptor.primitives = .triangles(indices)
        return MeshResource(descriptor)
    }

    public static func generatePlane(width: Float, height: Float, cornerRadius: Float = 0) -> MeshResource {
        plane(width: width, across: 1, height: height, down: 1, inTheXZPlane: false)
    }

    public static func generatePlane(width: Float, depth: Float, cornerRadius: Float = 0) -> MeshResource {
        __generatePlane(width: width, widthSegmentCount: 1, depth: depth, depthSegmentCount: 1, cornerRadius: cornerRadius)
    }

    private static func plane(width: Float, across: Int, height: Float, down: Int,
                              inTheXZPlane: Bool) -> MeshResource {
        var descriptor = MeshDescriptor(name: "Plane")
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for row in 0...down {
            for column in 0...across {
                let u = Float(column) / Float(across)
                let v = Float(row) / Float(down)
                let along = (u - 0.5) * width
                let other = (v - 0.5) * height
                positions.append(inTheXZPlane ? SIMD3<Float>(along, 0, other) : SIMD3<Float>(along, other, 0))
                normals.append(inTheXZPlane ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1))
                texCoords.append(SIMD2<Float>(u, v))
            }
        }
        for row in 0..<down {
            for column in 0..<across {
                let topLeft = UInt32(row * (across + 1) + column)
                let topRight = topLeft + 1
                let bottomLeft = topLeft + UInt32(across + 1)
                let bottomRight = bottomLeft + 1
                indices += [topLeft, bottomLeft, topRight, topRight, bottomLeft, bottomRight]
            }
        }
        descriptor[MeshBuffers.positions] = MeshBuffer(id: .positions, elements: positions)
        descriptor[MeshBuffers.normals] = MeshBuffer(id: .normals, elements: normals)
        descriptor[MeshBuffers.textureCoordinates] = MeshBuffer(id: .textureCoordinates, elements: texCoords)
        descriptor[MeshBuffers.triangleIndices] = MeshBuffer(id: .triangleIndices, elements: indices,
                                                             rate: .vertexNotInterpolated)
        descriptor.primitives = .triangles(indices)
        return MeshResource(descriptor)
    }

    public static func __generatePlane(width: Float = 1, widthSegmentCount: UInt = 1, depth: Float = 1,
                                       depthSegmentCount: UInt = 1, cornerRadius: Float = 0,
                                       cornerSegmentCount: UInt = 0, addUVs: Bool = true,
                                       addNormals: Bool = true) -> MeshResource {
        var descriptor = MeshDescriptor(name: "Plane")
        let across = Swift.max(1, Int(widthSegmentCount))
        let down = Swift.max(1, Int(depthSegmentCount))
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for row in 0...down {
            for column in 0...across {
                let u = Float(column) / Float(across)
                let v = Float(row) / Float(down)
                positions.append(SIMD3<Float>((u - 0.5) * width, 0, (v - 0.5) * depth))
                if addNormals { normals.append(SIMD3<Float>(0, 1, 0)) }
                if addUVs { texCoords.append(SIMD2<Float>(u, v)) }
            }
        }
        for row in 0..<down {
            for column in 0..<across {
                let topLeft = UInt32(row * (across + 1) + column)
                let topRight = topLeft + 1
                let bottomLeft = topLeft + UInt32(across + 1)
                let bottomRight = bottomLeft + 1
                indices += [topLeft, bottomLeft, topRight, topRight, bottomLeft, bottomRight]
            }
        }
        descriptor[MeshBuffers.positions] = MeshBuffer(id: .positions, elements: positions)
        if addNormals { descriptor[MeshBuffers.normals] = MeshBuffer(id: .normals, elements: normals) }
        if addUVs { descriptor[MeshBuffers.textureCoordinates] = MeshBuffer(id: .textureCoordinates, elements: texCoords) }
        descriptor[MeshBuffers.triangleIndices] = MeshBuffer(id: .triangleIndices, elements: indices,
                                                             rate: .vertexNotInterpolated)
        descriptor.primitives = .triangles(indices)
        return MeshResource(descriptor)
    }

    public static func __generateOccluderPlane(width: Float, depth: Float, cornerRadius: Float = 0) -> MeshResource {
        __generatePlane(width: width, depth: depth, cornerRadius: cornerRadius, addUVs: false)
    }

    public static func generateSphere(radius: Float) -> MeshResource {
        var descriptor = MeshDescriptor(name: "Sphere")
        let around = 16, high = 8
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for ring in 0...high {
            let phi = Float(ring) / Float(high) * .pi
            for step in 0...around {
                let theta = Float(step) / Float(around) * 2 * .pi
                let direction = SIMD3<Float>(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
                positions.append(direction * radius)
                normals.append(direction)
                texCoords.append(SIMD2<Float>(Float(step) / Float(around), 1 - Float(ring) / Float(high)))
            }
        }
        for ring in 0..<high {
            for step in 0..<around {
                let here = UInt32(ring * (around + 1) + step)
                let next = here + UInt32(around + 1)
                indices += [here, next, here + 1, here + 1, next, next + 1]
            }
        }
        descriptor[MeshBuffers.positions] = MeshBuffer(id: .positions, elements: positions)
        descriptor[MeshBuffers.normals] = MeshBuffer(id: .normals, elements: normals)
        descriptor[MeshBuffers.textureCoordinates] = MeshBuffer(id: .textureCoordinates, elements: texCoords)
        descriptor[MeshBuffers.triangleIndices] = MeshBuffer(id: .triangleIndices, elements: indices,
                                                             rate: .vertexNotInterpolated)
        descriptor.primitives = .triangles(indices)
        return MeshResource(descriptor)
    }

    public static func generateCone(height: Float, radius: Float) -> MeshResource {
        revolve(height: height, radius: radius, topRadius: 0, name: "Cone")
    }

    public static func generateCylinder(height: Float, radius: Float) -> MeshResource {
        revolve(height: height, radius: radius, topRadius: radius, name: "Cylinder")
    }

    private static func revolve(height: Float, radius: Float, topRadius: Float, name: String) -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        let around = 16, high = 8
        let half = height / 2
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for ring in 0...high {
            let v = Float(ring) / Float(high)
            let y = -half + v * height
            let here = radius + (topRadius - radius) * v
            for step in 0...around {
                let u = Float(step) / Float(around)
                let theta = u * 2 * .pi
                let outward = SIMD3<Float>(cos(theta), 0, sin(theta))
                positions.append(SIMD3<Float>(outward.x * here, y, outward.z * here))
                let slope = (topRadius - radius) / height
                let normal = simd_normalize(SIMD3<Float>(outward.x, -slope, outward.z))
                normals.append(normal)
                texCoords.append(SIMD2<Float>(u, v))
            }
        }
        for ring in 0..<high {
            for step in 0..<around {
                let here = UInt32(ring * (around + 1) + step)
                let next = here + UInt32(around + 1)
                indices += [here, next, here + 1, here + 1, next, next + 1]
            }
        }
        descriptor[MeshBuffers.positions] = MeshBuffer(id: .positions, elements: positions)
        descriptor[MeshBuffers.normals] = MeshBuffer(id: .normals, elements: normals)
        descriptor[MeshBuffers.textureCoordinates] = MeshBuffer(id: .textureCoordinates, elements: texCoords)
        descriptor[MeshBuffers.triangleIndices] = MeshBuffer(id: .triangleIndices, elements: indices,
                                                             rate: .vertexNotInterpolated)
        descriptor.primitives = .triangles(indices)
        return MeshResource(descriptor)
    }

    public convenience init(shape resource: ShapeResource) {
        switch resource.shape {
        case .box(let halfExtents):
            self.init(MeshResource.generateBox(size: halfExtents * 2).descriptor)
        case .sphere(let radius):
            self.init(MeshResource.generateSphere(radius: radius).descriptor)
        case .capsule(let radius, let halfHeight):
            var descriptor = MeshResource.__generatePlane(width: 2 * radius, depth: 2 * radius).descriptor
            descriptor.name = "Capsule"
            self.init(descriptor)
        case .convex(let points):
            var box = BoundingBox()
            for point in points { box.extend(with: point) }
            self.init(MeshResource.generateBox(size: box.max - box.min).descriptor)
        }
    }
}

@MainActor
@frozen public struct ModelComponent: Component {
    public struct Part: Identifiable {
        public let id: Entity.ID
        public var name: String
        public var mesh: MeshResource
        public var materials: [any Material]
        public var boundingBox: BoundingBox

        @MainActor
        public init(name: String, mesh: MeshResource, materials: [any Material] = [], boundingBox: BoundingBox? = nil) {
            self.id = ModelComponent.nextPartIdentifier()
            self.name = name
            self.mesh = mesh
            self.materials = materials
            self.boundingBox = boundingBox ?? mesh.bounds
        }
    }

    public struct Model {
        public var name: String
        public var parts: [Part]
        public var availableBounds: BoundingBox?

        public init(name: String, parts: [Part], availableBounds: BoundingBox? = nil) {
            self.name = name
            self.parts = parts
            self.availableBounds = availableBounds
        }
    }

    public var model: Model

    public init(mesh: MeshResource, materials: [any Material] = []) {
        model = Model(name: mesh.descriptor.name, parts: [Part(name: mesh.descriptor.name, mesh: mesh, materials: materials)])
    }

    public init(model: Model) {
        self.model = model
    }

    private static let partCounter = __REAtomicCounter()
    static func nextPartIdentifier() -> Entity.ID { Entity.ID(partCounter.next()) }
}

final class __REAtomicCounter {
    private var value: UInt64 = 0
    private let lock = NSLock()

    func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

@MainActor
open class ModelEntity: Entity, HasModel {
    public var model: ModelComponent? {
        get { coreEntity.component(of: ModelComponent.self) }
        set {
            if let newValue {
                coreEntity.setComponent(newValue)
                generateCollisionShapes(recursive: false)
            } else {
                coreEntity.removeComponent(of: ModelComponent.self)
            }
        }
    }

    public convenience init(mesh: MeshResource, materials: [any Material] = []) {
        self.init(model: ModelComponent(mesh: mesh, materials: materials))
    }

    public convenience init(model: ModelComponent) {
        self.init()
        self.model = model
    }

    public init(mesh: MeshResource) {
        super.init()
        name = mesh.descriptor.name
        model = ModelComponent(mesh: mesh, materials: [])
    }

    public init(mesh: MeshResource, name: String) {
        super.init()
        self.name = name
        model = ModelComponent(mesh: mesh, materials: [])
    }

    public required init(_coreEntity: __EntityRef) {
        super.init(_coreEntity: _coreEntity)
    }

    public required init() {
        super.init()
    }
}

@MainActor
extension HasModel {
    public func generateCollisionShapes(recursive: Bool) {
        coreEntity.generateCollisionShapes(recursive: recursive)
    }
}

@MainActor
extension __REEntity {
    func generateCollisionShapes(recursive: Bool) {
        if let model = component(of: ModelComponent.self) {
            for part in model.model.parts {
                setComponent(CollisionComponent(shapes: [ShapeResource(mesh: part.mesh)]))
            }
        }
        if recursive {
            for child in children { child.generateCollisionShapes(recursive: true) }
        }
    }
}

@MainActor
extension ShapeResource {
    public convenience init(mesh: MeshResource) {
        let box = mesh.bounds
        self.init(shape: .box(halfExtents: box.extents / 2),
                  offset: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                  offsetTranslation: box.center)
    }
}

@MainActor
extension HasModel {
    public var visualBounds: BoundingBox {
        let parts = coreEntity.component(of: ModelComponent.self)?.model.parts ?? []
        guard !parts.isEmpty else { return coreEntity.boundingBox(recursive: true, excludeInactive: false) }
        var box = BoundingBox()
        for part in parts {
            box.extend(with: part.boundingBox.min)
            box.extend(with: part.boundingBox.max)
        }
        return box
    }

    public var mesh: MeshResource? {
        guard let model = coreEntity.component(of: ModelComponent.self) else { return nil }
        return model.model.parts.count == 1 ? model.model.parts[0].mesh : nil
    }

    public var partNames: [String] {
        coreEntity.component(of: ModelComponent.self)?.model.parts.map { $0.name } ?? []
    }
}

@MainActor
extension HasAnchoring {
    public var isAnchorTracked: Bool {
        get { coreEntity.isTracked }
        set { coreEntity.isTracked = newValue }
    }

    public var anchorPosition: Transform? {
        switch coreEntity.anchoring.target {
        case .world(let pose): return Transform(matrix: pose)
        case .anchor: return coreEntity.transform
        default: return nil
        }
    }
}
