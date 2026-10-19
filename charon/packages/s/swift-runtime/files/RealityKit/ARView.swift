#if canImport(UIKit)
import UIKit
public typealias RealityViewBase = UIView
#else
import AppKit
public typealias RealityViewBase = NSView
#endif
import SceneKit
import simd
import Foundation
import RealityFoundation

@MainActor
public protocol SessionProviding: AnyObject {
    var sessionName: String { get }
    var isSessionRunning: Bool { get set }
    var sessionCameraTransform: Transform? { get }
    func sessionAnchors() -> [UUID: any SessionAnchor]
}

@MainActor
open class ARView: RealityViewBase {

    public enum CameraMode: UInt, Hashable {
        case nonAR
        case ar
    }

    public struct RenderOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let disableMotionBlur = RenderOptions(rawValue: 1 << 0)
        public static let disableDepthOfField = RenderOptions(rawValue: 1 << 1)
        public static let disableCameraGrain = RenderOptions(rawValue: 1 << 2)
        public static let disableHDR = RenderOptions(rawValue: 1 << 3)
        public static let disableAREnvironmentLighting = RenderOptions(rawValue: 1 << 4)
        public static let disableGroundingShadows = RenderOptions(rawValue: 1 << 5)
        public static let disableFrameDebugMarkers = RenderOptions(rawValue: 1 << 6)

        public static let standard: RenderOptions = []
        public static let `default`: RenderOptions = [.disableAREnvironmentLighting, .disableGroundingShadows]
    }

    public struct DebugOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let showSceneUnderstanding = DebugOptions(rawValue: 1 << 0)
        public static let showPhysics = DebugOptions(rawValue: 1 << 1)
        public static let showCollisionShapes = DebugOptions(rawValue: 1 << 2)
    }

    public struct PostProcessContext {
        public let device: Any?
        public let commandBuffer: Any?
        public let sourceColorTexture: Any?
        public let sourceDepthTexture: Any?
        public let targetColorTexture: Any?
        public let projection: float4x4
        public let time: TimeInterval

        public init(_ device: Any?, _ commandBuffer: Any?, _ sourceColorTexture: Any?,
                    _ sourceDepthTexture: Any?, _ targetColorTexture: Any?, _ projection: float4x4,
                    _ time: TimeInterval) {
            self.device = device
            self.commandBuffer = commandBuffer
            self.sourceColorTexture = sourceColorTexture
            self.sourceDepthTexture = sourceDepthTexture
            self.targetColorTexture = targetColorTexture
            self.projection = projection
            self.time = time
        }
    }

    public struct RenderCallbacks {
        public var willRenderFrame: () -> Void
        public var didRenderFrame: () -> Void

        public init(willRenderFrame: @escaping () -> Void = {}, didRenderFrame: @escaping () -> Void = {}) {
            self.willRenderFrame = willRenderFrame
            self.didRenderFrame = didRenderFrame
        }
    }

    public private(set) var scene: Scene

    public private(set) var scnView: SCNView

    public var cameraMode: CameraMode

    public weak var session: (any SessionProviding)?

    public var renderOptions: RenderOptions
    public var debugOptions: DebugOptions
    public var renderCallbacks = RenderCallbacks()

    public var cameraTransform: Transform {
        get { session?.sessionCameraTransform ?? Transform.identity }
        set {
            guard let session else { return }
            cameraTransformOverride = newValue
        }
    }

    var cameraTransformOverride: Transform?

    public var audioListener: Entity?

    public var isPaused = false {
        didSet { __updateDisplayLink() }
    }

    public private(set) var frameCount: Int = 0

    public var environment = Environment()

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: __DisplayLinkTarget?
    #endif

    #if canImport(UIKit)
    public override init(frame: CGRect) {
        scene = Scene()
        scnView = SCNView(frame: frame)
        cameraMode = .nonAR
        renderOptions = .default
        debugOptions = []
        super.init(frame: frame)
        __install()
    }

    public convenience init(frame: CGRect, cameraMode: CameraMode) {
        self.init(frame: frame, cameraMode: cameraMode, automaticallyConfigureSession: true)
    }

    public init(frame: CGRect, cameraMode: CameraMode, automaticallyConfigureSession: Bool) {
        scene = Scene()
        scnView = SCNView(frame: frame)
        self.cameraMode = cameraMode
        renderOptions = .default
        debugOptions = []
        super.init(frame: frame)
        __install()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("RealityKit.ARView is made with init(frame:), not from an archive")
    }
    #else
    public override init(frame frameRect: NSRect) {
        scene = Scene()
        scnView = SCNView(frame: frameRect, options: nil)
        cameraMode = .nonAR
        renderOptions = .default
        debugOptions = []
        super.init(frame: frameRect)
        __install()
    }

    public convenience init(frame frameRect: NSRect, cameraMode: CameraMode) {
        self.init(frame: frameRect, cameraMode: cameraMode, automaticallyConfigureSession: true)
    }

    public init(frame frameRect: NSRect, cameraMode: CameraMode, automaticallyConfigureSession: Bool) {
        scene = Scene()
        scnView = SCNView(frame: frameRect, options: nil)
        self.cameraMode = cameraMode
        renderOptions = .default
        debugOptions = []
        super.init(frame: frameRect)
        __install()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("RealityKit.ARView is made with init(frame:), not from an archive")
    }
    #endif

    #if canImport(UIKit)
    deinit {
        displayLink?.invalidate()
    }
    #endif

    private func __install() {
        scnView.frame = bounds
        addSubview(scnView)
        scnView.scene = scene.scnScene
        scene.view = scnView
        __updateDisplayLink()
    }

    #if canImport(UIKit)
    public override func layoutSubviews() {
        super.layoutSubviews()
        scnView.frame = bounds
    }
    #else
    public override func layout() {
        super.layout()
        scnView.frame = bounds
    }
    #endif

    public func __renderFrame(_ deltaTime: TimeInterval) {
        renderCallbacks.willRenderFrame()
        __syncAnchors()
        scene.coreScene.__advancePhysics(deltaTime: deltaTime)
        scnView.scene = scene.scnScene
        scene.view = scnView
        frameCount += 1
        renderCallbacks.didRenderFrame()
    }

    public func __updateDisplayLink() {
        #if canImport(UIKit)
        if isPaused {
            __stopDisplayLink()
        } else if displayLink == nil {
            let target = __DisplayLinkTarget(owner: self)
            displayLinkTarget = target
            let link = CADisplayLink(target: target, selector: #selector(__DisplayLinkTarget.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        #else
        #endif
    }

    private func __stopDisplayLink() {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #endif
    }


    public struct EntityGestures: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let translation = EntityGestures(rawValue: 1 << 0)
        public static let rotation = EntityGestures(rawValue: 1 << 1)
        public static let scale = EntityGestures(rawValue: 1 << 2)
        public static let all: EntityGestures = [.translation, .rotation, .scale]
    }

    #if canImport(UIKit)
    public func installGestures(_ gestures: EntityGestures = .all,
                                for entity: any HasCollision) -> [any EntityGestureRecognizer] {
        var installed: [any EntityGestureRecognizer] = []
        if gestures.contains(.translation) {
            let recognizer = EntityTranslationGestureRecognizer(entity: entity)
            addGestureRecognizer(recognizer)
            installed.append(recognizer)
        }
        if gestures.contains(.rotation) {
            let recognizer = EntityRotationGestureRecognizer(entity: entity)
            addGestureRecognizer(recognizer)
            installed.append(recognizer)
        }
        if gestures.contains(.scale) {
            let recognizer = EntityScaleGestureRecognizer(entity: entity)
            addGestureRecognizer(recognizer)
            installed.append(recognizer)
        }
        return installed
    }
    #endif

    #if canImport(UIKit)
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let recognizer = gestureRecognizer as? EntityGestureRecognizer,
              recognizer.recognizer === gestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let point = gestureRecognizer.location(in: self)
        guard let hit = scnView.hitTest(point, options: nil).first,
              let root = scnView.scene?.rootNode else { return false }
        return (root.childNodes + childNodes(of: root)).contains { $0.name == hit.node.name }
    }

    private func childNodes(of node: SCNNode) -> [SCNNode] {
        node.childNodes.flatMap { [$0] + childNodes(of: $0) }
    }
    #endif
}

#if canImport(UIKit)
private final class __DisplayLinkTarget: NSObject {
    weak var owner: ARView?
    private var lastFrameTime: TimeInterval?
    init(owner: ARView) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let delta = lastFrameTime.map { now - $0 } ?? 1.0 / 60.0
        lastFrameTime = now
        guard let owner else { link.invalidate(); return }
        MainActor.assumeIsolated { owner.__renderFrame(delta) }
    }
}
#endif

@MainActor
public protocol SessionAnchor: AnyObject {
    var anchorIdentifier: UUID { get }
    var anchorTransform: Transform { get }
    var isAnchorTracked: Bool { get }
}

@MainActor
public func __reSessionAnchors(of session: (any SessionProviding)?) -> [UUID: any SessionAnchor] {
    session?.sessionAnchors() ?? [:]
}

@MainActor
extension Scene {
    public func syncAnchors(with session: (any SessionProviding)?) {
        guard let session else { return }
        let seen = __reSessionAnchors(of: session)
        for (identifier, anchor) in seen {
            if let existing = anchors.first(where: { node in
                return node.components[AnchoringComponent.self]?.target == .anchor(identifier: identifier)
            }) {
                existing.transform = anchor.anchorTransform
                existing.isAnchorTracked = anchor.isAnchorTracked
                continue
            }
            let entity = AnchorEntity(world: .zero)
            entity.name = "anchor-" + identifier.uuidString
            entity.components.set(AnchoringComponent(.anchor(identifier: identifier)))
            entity.transform = anchor.anchorTransform
            entity.isAnchorTracked = anchor.isAnchorTracked
            addAnchor(entity)
        }
        for node in anchors {
            guard let target = node.components[AnchoringComponent.self]?.target,
                  case .anchor(let identifier) = target, seen[identifier] == nil else { continue }
            removeAnchor(node)
        }
    }
}

@MainActor
extension ARView {
    public func __syncAnchors() {
        scene.syncAnchors(with: session)
    }
}

extension ARView {
    public final class Environment {
        public var background: Background
        public var lighting: Lighting
        public var reverb: Reverb

        public init(background: Background = .color(.white), lighting: Lighting = Lighting(),
                    reverb: Reverb = .noReverb) {
            self.background = background
            self.lighting = lighting
            self.reverb = reverb
        }
    }
}

extension ARView.Environment {
    public struct Background {
        public enum Value {
            case color(UIColor)
            case cameraFeed
            case skybox(EnvironmentResource?)
        }

        public var value: Value

        public init(value: Value) { self.value = value }

        public static func color(_ color: UIColor) -> Background { Background(value: .color(color)) }
        public static func cameraFeed(exposureCompensation: Float = 0) -> Background {
            Background(value: .cameraFeed)
        }
        public static func skybox(_ resource: EnvironmentResource?) -> Background {
            Background(value: .skybox(resource))
        }
    }

    public struct Lighting {
        public struct ImageBasedLight {
            public var resource: EnvironmentResource?
            public var intensityExponent: Float
            public init(resource: EnvironmentResource? = nil, intensityExponent: Float = 0) {
                self.resource = resource
                self.intensityExponent = intensityExponent
            }
        }

        public var intensity: Float
        public var temperature: Float
        public var resource: ImageBasedLight

        public init(intensity: Float = 1000, temperature: Float = 6500,
                    resource: EnvironmentResource? = nil) {
            self.intensity = intensity
            self.temperature = temperature
            self.resource = ImageBasedLight(resource: resource)
        }
    }

    public enum Reverb: Equatable {
        case noReverb
        case preset(Preset)

        public enum Preset: Equatable {
            case smallRoom
            case mediumRoom
            case largeRoom
            case mediumHall
            case largeHall
            case cathedral
        }
    }
}
