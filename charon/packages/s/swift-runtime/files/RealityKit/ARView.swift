// RealityKit: the view an AR application is shown in.
//
// `ARView` is a `UIView` that hosts an `SCNView` and shows the scene graph the RealityFoundation
// module above holds, through the bridge that module's SceneKitBridge.swift provides. The
// render loop is a display link that steps the simulation and hands the translated graph to
// SceneKit; a program with no display - a test, a command-line tool - calls the same step
// itself, which is what the host checks do.

#if canImport(UIKit)
import UIKit
/// The view a RealityKit view is: UIKit's on the platform this port is, AppKit's on a host
/// build, which is what lets the same sources be differential-tested on a Mac.
public typealias RealityViewBase = UIView
#else
import AppKit
public typealias RealityViewBase = NSView
#endif
import SceneKit
import simd
import Foundation
import RealityFoundation

// MARK: - The session

/// What a view reads its camera frames from.
///
/// The SDK's `ARView` conforms to `ARKit.ARSessionProviding`, whose one requirement is the
/// session itself, and its `session` is an `ARSession`. This module cannot name that type: the
/// runtime does not depend on the ARKit band (e1986da0's), and ARKit's headers carry their
/// iOS 11 marks, which only that band's port headers lower. So the session is this protocol, whose
/// shape is `ARSessionProviding`'s, and a program that has the ARKit session bridges it in a
/// line - which is the same arrangement `Cancellable` has with Combine:
///
///     extension ARSession: RealityKit.SessionProviding {}
@MainActor
public protocol SessionProviding: AnyObject {
    /// A name for the session the view reads from, which is what the bridge hands back.
    var sessionName: String { get }
    /// Whether the session is running, and asks it to run or stop.
    var isSessionRunning: Bool { get set }
    /// The frame the session last delivered, in the world's coordinates.
    var sessionCameraTransform: Transform? { get }
    /// The targets the session has found, by identifier. A session that reports none - one
    /// that has not been bridged, or one with no ARKit camera behind it - reports an empty
    /// table rather than failing.
    func sessionAnchors() -> [UUID: any SessionAnchor]
}

// MARK: - ARView

/// A view that shows a scene.
@MainActor
open class ARView: RealityViewBase {

    /// Whether the view shows what a camera sees or what the scene itself contains.
    public enum CameraMode: UInt, Hashable {
        case nonAR
        case ar
    }

    /// What the renderer draws.
    /// What the renderer draws. The seven options are the ones the SDK names, each the effect
    /// its declaration documents; they are iOS only, so the host could not be asked what a new
    /// view's are the way the environment's were (measured 2026-09-27, MacOSX26.5: ARView has no
    /// `renderOptions` there), and the defaults below are the header's.
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

    /// What the view reports while it draws.
    public struct DebugOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let showSceneUnderstanding = DebugOptions(rawValue: 1 << 0)
        public static let showPhysics = DebugOptions(rawValue: 1 << 1)
        public static let showCollisionShapes = DebugOptions(rawValue: 1 << 2)
    }

    /// Called as each frame is drawn.
    /// A frame the renderer is about to draw, and what it is drawing into: the device, the
    /// command buffer the frame is recorded into, the colour and depth it reads, the texture
    /// it writes, the camera's projection, and the time.
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

    // MARK: The scene

    /// The scene the view shows. A view has one of its own, and an `ARView` a caller is given
    /// keeps the one it was handed.
    public private(set) var scene: Scene

    /// The SceneKit view the scene is drawn in. It is the view's own subview, and it is what a
    /// program that wants a snapshot, a pick or a custom delegate talks to.
    public private(set) var scnView: SCNView

    /// Whether the view shows the camera's world or the scene's.
    public var cameraMode: CameraMode

    /// The session the camera frames come from, when the view has one.
    public weak var session: (any SessionProviding)?

    public var renderOptions: RenderOptions
    public var debugOptions: DebugOptions
    public var renderCallbacks = RenderCallbacks()

    /// The world the camera is in: the session's, when there is a session, and the origin when
    /// there is not.
    public var cameraTransform: Transform {
        get { session?.sessionCameraTransform ?? Transform.identity }
        set {
            guard let session else { return }
            // A session that does not place itself cannot be told to; the view keeps the value
            // and the next frame reads it back, which is what a device without ARKit's camera
            // has.
            cameraTransformOverride = newValue
        }
    }

    /// The value `cameraTransform` was set to, for a view whose session does not place it.
    var cameraTransformOverride: Transform?

    /// The entity the camera's position is heard from, for spatial audio.
    public var audioListener: Entity?

    /// Whether the view is asked to run its loop, which it is by default.
    public var isPaused = false {
        didSet { __updateDisplayLink() }
    }

    /// How many frames the view has drawn, which is what a test reads to know the loop ran.
    public private(set) var frameCount: Int = 0

    /// The environment the view shows the scene in, which a caller sets.
    public var environment = Environment()

    // MARK: The loop

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: __DisplayLinkTarget?
    #endif

    // MARK: Making one

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
        // A deinit is not on the main actor, and the display link's target is what holds the
        // view, so the link is invalidated through the target's own teardown instead.
        displayLink?.invalidate()
    }
    #endif

    private func __install() {
        scnView.frame = bounds
        addSubview(scnView)
        scnView.scene = scene.scnScene
        // The scene knows which view shows it, which is what a pixel cast projects through: a scene
        // with no view is one that is not shown.
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

    // MARK: Drawing

    /// One frame: the simulation is stepped, the graph is handed to SceneKit, and the callbacks
    /// are run around it.
    ///
    /// This is the loop's body and it takes no display: a view runs it from a display link, and
    /// a program with none calls it itself, which is how the host checks draw frames.
    public func __renderFrame(_ deltaTime: TimeInterval) {
        renderCallbacks.willRenderFrame()
        __syncAnchors()
        scene.coreScene.__advancePhysics(deltaTime: deltaTime)
        scnView.scene = scene.scnScene
        // The scene knows which view shows it, which is what a pixel cast projects through: a scene
        // with no view is one that is not shown.
        scene.view = scnView
        frameCount += 1
        renderCallbacks.didRenderFrame()
    }

    /// Starts the loop, or stops it.
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
        // A program with no display calls __renderFrame(_:) itself; there is nothing to start.
        #endif
    }

    private func __stopDisplayLink() {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #endif
    }


    // MARK: Gestures

    /// Which of a set of gestures to install on an entity.
    public struct EntityGestures: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let translation = EntityGestures(rawValue: 1 << 0)
        public static let rotation = EntityGestures(rawValue: 1 << 1)
        public static let scale = EntityGestures(rawValue: 1 << 2)
        public static let all: EntityGestures = [.translation, .rotation, .scale]
    }

    /// Installs the gestures an entity answers, and returns the recognizers so that a caller
    /// can take one away again.
    #if canImport(UIKit)
    /// Installs the gestures an entity answers, and returns the recognizers so that a caller
    /// can take one away again.
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
    /// Whether a gesture may begin: a gesture on an entity begins only when the touch is on
    /// that entity's own geometry, which is what SceneKit's hit test answers.
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

    /// Every node of the tree below `node`, flattened.
    private func childNodes(of node: SCNNode) -> [SCNNode] {
        node.childNodes.flatMap { [$0] + childNodes(of: $0) }
    }
    #endif
}

#if canImport(UIKit)
/// The display link's target: a view cannot be the target, because the link retains it.
private final class __DisplayLinkTarget: NSObject {
    weak var owner: ARView?
    private var lastFrameTime: TimeInterval?
    init(owner: ARView) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let delta = lastFrameTime.map { now - $0 } ?? 1.0 / 60.0
        lastFrameTime = now
        guard let owner else { link.invalidate(); return }
        // The display link's callback is not on the main actor by declaration, and the view is
        // main-actor confined; that it is on the main thread is what a display link guarantees.
        MainActor.assumeIsolated { owner.__renderFrame(delta) }
    }
}
#endif

// MARK: - What a session sees

/// One target a session has found in the world: an identifier, the pose it was seen at, and
/// whether it is still there.
///
/// The SDK's own `ARAnchor` cannot be named here - ARKit is another band's module and its
/// headers keep their iOS 11 marks until that band's port headers lower them - so the view reports what
/// a session found through this, and the ARKit band bridges it in a line:
///
///     extension ARAnchor: RealityKit.SessionAnchor {}
@MainActor
public protocol SessionAnchor: AnyObject {
    /// The identifier the session knows this target by, which is the one an anchoring component
    /// names.
    var anchorIdentifier: UUID { get }
    /// Where the target was seen, in the world's coordinates.
    var anchorTransform: Transform { get }
    /// Whether the session still sees it.
    var isAnchorTracked: Bool { get }
}

/// The anchors a session reports, or none: a session that has not been bridged to a camera has
/// nothing to report, and says so with an empty table rather than failing.
@MainActor
public func __reSessionAnchors(of session: (any SessionProviding)?) -> [UUID: any SessionAnchor] {
    session?.sessionAnchors() ?? [:]
}

@MainActor
extension Scene {
    /// Puts every anchor the session has found into the scene, and takes out the ones it no
    /// longer sees. A view calls this once a frame; a program calls it when it wants the world
    /// brought up to date.
    ///
    /// The anchors that are already in the scene and are still seen keep their identity, so a
    /// program holding one does not lose it to a frame.
    /// Written against the scene's own public API - `anchors`, `addAnchor`, `removeAnchor`, and
    /// the anchoring component through `components` - because `coreScene`, `Entity.coreEntity`
    /// and `anchoring` are internal to RealityFoundation or its core node, and a module that
    /// cannot see them does not build. That was the shape it had: it reached for all three.
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
    /// Brings the scene's anchors up to date with the session, once a frame. A view with no
    /// session leaves the scene as it is.
    public func __syncAnchors() {
        scene.syncAnchors(with: session)
    }
}

// MARK: - The environment the scene is shown in

/// What a view shows around and lights the scene with.
///
/// A new view's environment, measured on the host 2026-09-27 (macOS 26.5, arm64): a white
/// background, an image-based light with no resource and an intensity exponent of zero, and no
/// reverb at all.
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
    /// What is behind the scene.
    public struct Background {
        /// The value a background carries: a colour, the camera's own feed, or a skybox.
        public enum Value {
            case color(UIColor)
            case cameraFeed
            case skybox(EnvironmentResource?)
        }

        public var value: Value

        public init(value: Value) { self.value = value }

        /// A plain colour behind the scene.
        public static func color(_ color: UIColor) -> Background { Background(value: .color(color)) }
        /// What the camera sees, which is what an AR view shows.
        public static func cameraFeed(exposureCompensation: Float = 0) -> Background {
            Background(value: .cameraFeed)
        }
        /// A captured environment, or nothing for the one the view has of its own.
        public static func skybox(_ resource: EnvironmentResource?) -> Background {
            Background(value: .skybox(resource))
        }
    }

    /// The light the scene is lit by: how bright, how warm, and from what.
    public struct Lighting {
        /// The resource an environment's light is measured from, and the exponent its intensity
        /// is raised to. Measured on the host, 2026-09-27: a new view's light has no resource
        /// and an intensity exponent of 0.
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

    /// How a scene sounds where it is: not at all, or as one of the rooms.
    public enum Reverb: Equatable {
        /// No room: what a new view's environment has, measured on the host 2026-09-27.
        case noReverb
        /// One of the rooms, by name.
        case preset(Preset)

        /// The rooms a scene can sound like.
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

// MARK: - What the renderer is asked to do
