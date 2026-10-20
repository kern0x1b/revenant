import simd
import Foundation

@frozen public struct BindPath: Equatable {
    public enum Part: Equatable {
        case scene(String)
        case anchorEntity(String)
        case entity(String)
        case parameter(String)
        case transform
    }

    public var parts: [Part]

    public init(parts: [Part] = []) { self.parts = parts }
    public init(_ parts: Part...) { self.parts = parts }

    public var target: BindTarget { .path(self) }
}

@frozen public enum BindTarget: Equatable {
    case transform
    case parameter(String)
    case path(BindPath)

    public struct ScenePath {
        let parts: [BindPath.Part]

        public func anchorEntity(_ name: String) -> EntityPath {
            EntityPath(parts: parts + [.anchorEntity(name)])
        }

        public var `self`: BindTarget { .path(BindPath(parts: parts)) }
    }

    public struct EntityPath {
        let parts: [BindPath.Part]

        public func entity(_ name: String) -> EntityPath {
            EntityPath(parts: parts + [.entity(name)])
        }

        public var transform: BindTarget { .path(BindPath(parts: parts + [.transform])) }

        public func parameter(_ name: String) -> BindTarget {
            .path(BindPath(parts: parts + [.parameter(name)]))
        }

        public func ikSolver(_ id: IKComponent.Solver.ID? = nil) -> IkSolverPath {
            IkSolverPath(parts: parts, solver: id)
        }

        public var `self`: BindTarget { .path(BindPath(parts: parts)) }
    }

    public struct IkSolverPath {
        let parts: [BindPath.Part]
        let solver: IKComponent.Solver.ID?

        public func constraintTarget(_ constraintName: String) -> BindTarget {
            .path(BindPath(parts: parts + [.parameter("ikSolver.constraintTarget.\(constraintName)")]))
        }

        public func constraintLookAtTarget(_ constraintName: String) -> BindTarget {
            .path(BindPath(parts: parts + [.parameter("ikSolver.constraintLookAtTarget.\(constraintName)")]))
        }
    }

    public static func scene(_ name: String) -> ScenePath {
        ScenePath(parts: [.scene(name)])
    }
}

public protocol BindableData {}

extension Float: BindableData {}
extension Double: BindableData {}
extension SIMD2: BindableData where Scalar == Float {}
extension SIMD3: BindableData where Scalar == Float {}
extension SIMD4: BindableData where Scalar == Float {}
extension simd_quatf: BindableData {}
extension Transform: BindableData {}

extension Entity {
    public var bindTarget: BindTarget { .transform }
}
