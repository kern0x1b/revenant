// MARK: - Particles
//
// The emitter component: how many particles, how fast, which way, how long they live, and what
// the renderer would do with them.
//
// Every declaration and every member below is read from the SDK's own interface,
// `iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/
// RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:11789-11960`: the component and
// its nested enums, the `ParticleEmitter` it holds and that emitter's own members. The names,
// the cases and the types are the system's.
//
// What is not here is the drawing, and the registry says so where a reader will look: a particle
// is drawn by RealityKit's renderer through a low-level instance buffer, and this port's view is
// an SCNView over the SceneKit bridge, and no release this old has a particle renderer in either.
// So the component is carried whole as the value a program sets and reads back - the numbers, the
// cases, the emitter's own curve and noise and attraction settings - and nothing pretends to
// spawn a particle. `Entity.components[ParticleEmitterComponent.self]` is where a program finds it,
// and the simulation step is where a renderer would be called.

import simd
import Foundation

/// What shape the particles are born in.
@frozen public enum ParticleEmitterShape: Codable, Equatable, Hashable {
    case point
    case plane
    case box
    case sphere
    case cone
    case cylinder
    case torus
}

/// Where in the shape a particle is born.
@frozen public enum ParticleBirthLocation: Codable, Equatable, Hashable {
    /// On the surface of the shape.
    case surface
    /// Anywhere inside it.
    case volume
    /// At a point on the surface, chosen per axis - the system's own `SIMD3<UInt>`, which is the
    /// resolution of the shape's own box and is `UInt` because a count of vertices cannot be
    /// negative.
    case vertices(count: SIMD3<UInt>)
}

/// The frame a particle's birth direction is taken in.
@frozen public enum ParticleBirthDirection: Codable, Equatable, Hashable {
    case world
    case local
    case normal
}

/// When a particle is born.
@frozen public enum ParticleSpawnOccasion: Codable, Equatable, Hashable {
    case onBirth
    case onUpdate
    case onDeath
}

/// The frame the particles are simulated in.
@frozen public enum ParticleSimulationSpace: Codable {
    case local
    case global
}

/// Whether the emitter's simulation runs.
@frozen public enum ParticleSimulationState: Codable {
    case play
    case pause
    case stop
}

/// One emitter's own settings: how it is born, how it moves, how it fades.
@frozen public struct ParticleEmitter: Codable, Equatable {
    /// How the particle is turned to face the camera.
    public enum BillboardMode: Codable, Equatable, Hashable {
        case billboard
        case billboardYAligned
        /// Faced freely about an axis, with a variation in degrees.
        case free(axis: SIMD3<Float>, variation: Float)
    }

    /// How a particle's opacity runs over its life: :11907-11914, the linear, the eased, the
    /// gradual and the quick shapes, and constant for one that does not change.
    public enum OpacityCurve: Codable, Equatable, Hashable {
        case linearFadeOut
        case linearFadeIn
        case gradualFadeInOut
        case quickFadeInOut
        case easeFadeIn
        case easeFadeOut
        case constant
    }

    /// How particles are ordered against each other: :11923-11929, by depth, by id or by age,
    /// each in both directions, and unsorted. The directions are the system's names, not
    /// "near to far": increasing is the order the renderer walks.
    public enum SortOrder: Codable, Equatable, Hashable {
        case increasingDepth
        case decreasingDepth
        case increasingID
        case decreasingID
        case increasingAge
        case decreasingAge
        case unsorted
    }

    /// How a particle is blended into what is behind it: :11940-11942, the three cases the
    /// interface lists. A renderer reads it; the value is carried so a program can set it.
    public enum BlendMode: Codable, Equatable, Hashable {
        case alpha
        case opaque
        case additive
    }

    /// A particle that is a frame of a sprite sheet, and how the sheet is walked: :11951-11957.
    /// The interface declares the type and its members with no member of `ParticleEmitter` that
    /// holds one - the one that holds it is `imageSequence` below - so this is the whole of it.
    public struct ImageSequence: Codable, Equatable, Hashable {
        /// How many frames the sheet is cut into, along each axis of the grid.
        public var rowCount: Int
        public var columnCount: Int
        /// Which frame the first particle starts on, and by how much that may differ.
        public var initialFrame: Int
        public var initialFrameVariation: Int
        /// How many frames a second the sheet is played at, and by how much that may differ.
        public var frameRate: Float
        public var frameRateVariation: Float
        public var animationMode: AnimationRepeatMode

        /// How the sheet carries on past its last frame: :11959-11961.
        public enum AnimationRepeatMode: Codable, Equatable, Hashable {
            case playOnce
            case looping
            case autoReverse
        }

        public init(rowCount: Int = 1, columnCount: Int = 1, initialFrame: Int = 0,
                    initialFrameVariation: Int = 0, frameRate: Float = 0,
                    frameRateVariation: Float = 0, animationMode: AnimationRepeatMode = .playOnce) {
            self.rowCount = rowCount
            self.columnCount = columnCount
            self.initialFrame = initialFrame
            self.initialFrameVariation = initialFrameVariation
            self.frameRate = frameRate
            self.frameRateVariation = frameRateVariation
            self.animationMode = animationMode
        }
    }

    /// How many particles are born in a second, and by how much that may differ.
    public var birthRate: Float
    public var birthRateVariation: Float
    /// How fast a particle loses speed, per second.
    public var dampingFactor: Float
    /// What the particles are pushed by, in the emitter's own frame.
    public var acceleration: SIMD3<Float>
    /// How far from the emission direction a particle may start, in degrees.
    public var spreadingAngle: Float
    public var size: Float
    public var sizeVariation: Float
    public var billboardMode: BillboardMode
    public var mass: Float
    public var massVariation: Float
    /// How long a particle lives, in seconds, and by how much that may differ.
    public var lifeSpan: Double
    public var lifeSpanVariation: Double
    /// How fast the particle turns, in degrees per second, and by how much that may differ.
    public var angle: Float
    public var angleVariation: Float
    public var angularSpeed: Float
    public var angularSpeedVariation: Float
    public var opacityCurve: OpacityCurve
    /// What the particle's size has become by the end of its life, and the power of the curve
    /// that gets it there.
    public var sizeMultiplierAtEndOfLifespan: Float
    public var sizeMultiplierAtEndOfLifespanPower: Float
    /// The power of the curve its colour runs.
    public var colorEvolutionPower: Float
    /// How far the noise field moves a particle, how large its features are, and how fast they
    /// change.
    public var noiseStrength: Float
    public var noiseScale: Float
    public var noiseAnimationSpeed: Float
    /// How hard the emitter pulls its particles towards a point, and where that point is.
    public var attractionStrength: Float
    public var attractionCenter: SIMD3<Float>
    /// How hard the emitter swirls them, and about which axis.
    public var vortexStrength: Float
    public var vortexDirection: SIMD3<Float>
    public var isLightingEnabled: Bool
    /// How far a fast particle is stretched along its own direction.
    public var stretchFactor: Float
    public var sortOrder: SortOrder
    /// How a particle is blended into what is behind it.
    public var blendMode: BlendMode
    /// The texture a particle is drawn with, and the sheet it walks when the texture is several
    /// frames in one.
    public var image: TextureResource?
    public var imageSequence: ImageSequence?

    public init(birthRate: Float = 1, birthRateVariation: Float = 0, dampingFactor: Float = 0,
                acceleration: SIMD3<Float> = .zero, spreadingAngle: Float = 0, size: Float = 0.05,
                sizeVariation: Float = 0, billboardMode: BillboardMode = .billboard,
                mass: Float = 1, massVariation: Float = 0, lifeSpan: Double = 1,
                lifeSpanVariation: Double = 0, angle: Float = 0, angleVariation: Float = 0,
                angularSpeed: Float = 0, angularSpeedVariation: Float = 0,
                opacityCurve: OpacityCurve = .linearFadeOut,
                sizeMultiplierAtEndOfLifespan: Float = 1, sizeMultiplierAtEndOfLifespanPower: Float = 1,
                colorEvolutionPower: Float = 1, noiseStrength: Float = 0, noiseScale: Float = 1,
                noiseAnimationSpeed: Float = 0, attractionStrength: Float = 0,
                attractionCenter: SIMD3<Float> = .zero, vortexStrength: Float = 0,
                vortexDirection: SIMD3<Float> = .zero, isLightingEnabled: Bool = false,
                stretchFactor: Float = 0, sortOrder: SortOrder = .unsorted,
                blendMode: BlendMode = .alpha, image: TextureResource? = nil,
                imageSequence: ImageSequence? = nil) {
        self.birthRate = birthRate
        self.birthRateVariation = birthRateVariation
        self.dampingFactor = dampingFactor
        self.acceleration = acceleration
        self.spreadingAngle = spreadingAngle
        self.size = size
        self.sizeVariation = sizeVariation
        self.billboardMode = billboardMode
        self.mass = mass
        self.massVariation = massVariation
        self.lifeSpan = lifeSpan
        self.lifeSpanVariation = lifeSpanVariation
        self.angle = angle
        self.angleVariation = angleVariation
        self.angularSpeed = angularSpeed
        self.angularSpeedVariation = angularSpeedVariation
        self.opacityCurve = opacityCurve
        self.sizeMultiplierAtEndOfLifespan = sizeMultiplierAtEndOfLifespan
        self.sizeMultiplierAtEndOfLifespanPower = sizeMultiplierAtEndOfLifespanPower
        self.colorEvolutionPower = colorEvolutionPower
        self.noiseStrength = noiseStrength
        self.noiseScale = noiseScale
        self.noiseAnimationSpeed = noiseAnimationSpeed
        self.attractionStrength = attractionStrength
        self.attractionCenter = attractionCenter
        self.vortexStrength = vortexStrength
        self.vortexDirection = vortexDirection
        self.isLightingEnabled = isLightingEnabled
        self.stretchFactor = stretchFactor
        self.sortOrder = sortOrder
        self.blendMode = blendMode
        self.image = image
        self.imageSequence = imageSequence
    }
}

extension ParticleEmitter {
    /// The coding of an emitter is written by hand, and the reason is a member that cannot be
    /// coded: `image` is a `TextureResource`, a class that is not `Codable` in the SDK either
    /// (26.2:1784), so the SDK's own `ParticleEmitter: Codable` is written by hand as well
    /// (:11893). A texture is an asset - it is generated from a colour or a scalar, or handed over
    /// by a renderer - and this port's `TextureResource` has no loader that could rebuild one from
    /// a name, so the name is what is coded and a decode that names a texture this process does
    /// not have says so instead of quietly dropping it.
    private enum CodingKey: String, Swift.CodingKey {
        case birthRate, birthRateVariation, dampingFactor, acceleration, spreadingAngle
        case size, sizeVariation, billboardMode, mass, massVariation
        case lifeSpan, lifeSpanVariation, angle, angleVariation
        case angularSpeed, angularSpeedVariation, opacityCurve
        case sizeMultiplierAtEndOfLifespan, sizeMultiplierAtEndOfLifespanPower
        case colorEvolutionPower, noiseStrength, noiseScale, noiseAnimationSpeed
        case attractionStrength, attractionCenter, vortexStrength, vortexDirection
        case isLightingEnabled, stretchFactor, sortOrder, blendMode, image, imageSequence
    }

    /// What a texture is coded as. A texture is a runtime object here - generated from a colour
    /// or a scalar, or handed over by a renderer - and the port gives it no name to code, so what
    /// is written is its type name, which says which texture it was and not which one. A decode
    /// refuses any data that carries one, so the loss is never silent.
    private static func codedName(of texture: TextureResource) -> String { String(describing: type(of: texture)) }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKey.self)
        self.birthRate = try container.decode(Float.self, forKey: .birthRate)
        self.birthRateVariation = try container.decode(Float.self, forKey: .birthRateVariation)
        self.dampingFactor = try container.decode(Float.self, forKey: .dampingFactor)
        self.acceleration = try container.decode(SIMD3<Float>.self, forKey: .acceleration)
        self.spreadingAngle = try container.decode(Float.self, forKey: .spreadingAngle)
        self.size = try container.decode(Float.self, forKey: .size)
        self.sizeVariation = try container.decode(Float.self, forKey: .sizeVariation)
        self.billboardMode = try container.decode(BillboardMode.self, forKey: .billboardMode)
        self.mass = try container.decode(Float.self, forKey: .mass)
        self.massVariation = try container.decode(Float.self, forKey: .massVariation)
        self.lifeSpan = try container.decode(Double.self, forKey: .lifeSpan)
        self.lifeSpanVariation = try container.decode(Double.self, forKey: .lifeSpanVariation)
        self.angle = try container.decode(Float.self, forKey: .angle)
        self.angleVariation = try container.decode(Float.self, forKey: .angleVariation)
        self.angularSpeed = try container.decode(Float.self, forKey: .angularSpeed)
        self.angularSpeedVariation = try container.decode(Float.self, forKey: .angularSpeedVariation)
        self.opacityCurve = try container.decode(OpacityCurve.self, forKey: .opacityCurve)
        self.sizeMultiplierAtEndOfLifespan = try container.decode(Float.self, forKey: .sizeMultiplierAtEndOfLifespan)
        self.sizeMultiplierAtEndOfLifespanPower = try container.decode(Float.self, forKey: .sizeMultiplierAtEndOfLifespanPower)
        self.colorEvolutionPower = try container.decode(Float.self, forKey: .colorEvolutionPower)
        self.noiseStrength = try container.decode(Float.self, forKey: .noiseStrength)
        self.noiseScale = try container.decode(Float.self, forKey: .noiseScale)
        self.noiseAnimationSpeed = try container.decode(Float.self, forKey: .noiseAnimationSpeed)
        self.attractionStrength = try container.decode(Float.self, forKey: .attractionStrength)
        self.attractionCenter = try container.decode(SIMD3<Float>.self, forKey: .attractionCenter)
        self.vortexStrength = try container.decode(Float.self, forKey: .vortexStrength)
        self.vortexDirection = try container.decode(SIMD3<Float>.self, forKey: .vortexDirection)
        self.isLightingEnabled = try container.decode(Bool.self, forKey: .isLightingEnabled)
        self.stretchFactor = try container.decode(Float.self, forKey: .stretchFactor)
        self.sortOrder = try container.decode(SortOrder.self, forKey: .sortOrder)
        self.blendMode = try container.decode(BlendMode.self, forKey: .blendMode)
        self.imageSequence = try container.decodeIfPresent(ImageSequence.self, forKey: .imageSequence)
        if try container.decodeIfPresent(String.self, forKey: .image) != nil {
            throw DecodingError.dataCorruptedError(forKey: .image, in: container,
                debugDescription: "an emitter's image is a texture, and this port's TextureResource is not Codable and "
                                   + "has no loader that could rebuild one from a name, so a texture named in the data "
                                   + "cannot be decoded; remove the image, or carry the emitter without coding it")
        }
        self.image = nil
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKey.self)
        try container.encode(birthRate, forKey: .birthRate)
        try container.encode(birthRateVariation, forKey: .birthRateVariation)
        try container.encode(dampingFactor, forKey: .dampingFactor)
        try container.encode(acceleration, forKey: .acceleration)
        try container.encode(spreadingAngle, forKey: .spreadingAngle)
        try container.encode(size, forKey: .size)
        try container.encode(sizeVariation, forKey: .sizeVariation)
        try container.encode(billboardMode, forKey: .billboardMode)
        try container.encode(mass, forKey: .mass)
        try container.encode(massVariation, forKey: .massVariation)
        try container.encode(lifeSpan, forKey: .lifeSpan)
        try container.encode(lifeSpanVariation, forKey: .lifeSpanVariation)
        try container.encode(angle, forKey: .angle)
        try container.encode(angleVariation, forKey: .angleVariation)
        try container.encode(angularSpeed, forKey: .angularSpeed)
        try container.encode(angularSpeedVariation, forKey: .angularSpeedVariation)
        try container.encode(opacityCurve, forKey: .opacityCurve)
        try container.encode(sizeMultiplierAtEndOfLifespan, forKey: .sizeMultiplierAtEndOfLifespan)
        try container.encode(sizeMultiplierAtEndOfLifespanPower, forKey: .sizeMultiplierAtEndOfLifespanPower)
        try container.encode(colorEvolutionPower, forKey: .colorEvolutionPower)
        try container.encode(noiseStrength, forKey: .noiseStrength)
        try container.encode(noiseScale, forKey: .noiseScale)
        try container.encode(noiseAnimationSpeed, forKey: .noiseAnimationSpeed)
        try container.encode(attractionStrength, forKey: .attractionStrength)
        try container.encode(attractionCenter, forKey: .attractionCenter)
        try container.encode(vortexStrength, forKey: .vortexStrength)
        try container.encode(vortexDirection, forKey: .vortexDirection)
        try container.encode(isLightingEnabled, forKey: .isLightingEnabled)
        try container.encode(stretchFactor, forKey: .stretchFactor)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(blendMode, forKey: .blendMode)
        try container.encodeIfPresent(imageSequence, forKey: .imageSequence)
        try container.encodeIfPresent(image.map { ParticleEmitter.codedName(of: $0) }, forKey: .image)
    }
}

/// An emitter on an entity: the particle system's settings, as a component the entity carries.
///
/// The names are the system's own and the nesting is the system's own, with one departure the
/// registry records: the SDK nests `EmitterShape`, `BirthLocation`, `BirthDirection`,
/// `SpawnOccasion`, `SimulationSpace`, `SimulationState` and `ParticleEmitter` *inside* this
/// struct (`ParticleEmitterComponent.EmitterShape` and so on), and they are declared here at file
/// scope under their own names. The reason is mechanical and it is the same one the module's
/// other components meet: a nested type inside a `@frozen` struct that conforms to `Component`
/// cannot be named by a program that spells the component through the protocol, and this
/// component's own members are typed with all of them. `ParticleEmitterComponent.EmitterShape` is
/// what a caller writes, and it is a typealias to the same type.
@frozen public struct ParticleEmitterComponent: Component, Codable {
    public typealias EmitterShape = ParticleEmitterShape
    public typealias BirthLocation = ParticleBirthLocation
    public typealias BirthDirection = ParticleBirthDirection
    public typealias SpawnOccasion = ParticleSpawnOccasion
    public typealias SimulationSpace = ParticleSimulationSpace
    public typealias SimulationState = ParticleSimulationState
    public typealias ParticleEmitter = RealityFoundation.ParticleEmitter

    public var emitterShape: EmitterShape
    public var birthLocation: BirthLocation
    public var birthDirection: BirthDirection
    /// The size of the shape the particles are born in.
    public var emitterShapeSize: SIMD3<Float>
    public var speed: Float
    public var speedVariation: Float
    /// The direction the particles start in, in the emitter's own frame.
    public var emissionDirection: SIMD3<Float>
    /// How far from the emission direction a particle may start.
    public var radialAmount: Float
    /// The hole in the middle of a torus emitter.
    public var torusInnerRadius: Float
    public var spawnOccasion: SpawnOccasion
    /// How much of its own velocity a particle starts with.
    public var spawnVelocityFactor: Float
    /// How far from the emission direction a particle starts, and by how much that may differ.
    public var spawnSpreadFactor: Float
    public var spawnSpreadFactorVariation: Float
    public var spawnInheritsParentColor: Bool
    public var simulationState: SimulationState
    public var particlesInheritTransform: Bool
    /// The frame the force fields the particles read are in.
    public var fieldSimulationSpace: SimulationSpace
    public var isEmitting: Bool
    /// How many particles a burst makes, and by how much that may differ.
    public var burstCount: Int
    public var burstCountVariation: Int
    /// The emitter the entity always has.
    public var mainEmitter: ParticleEmitter
    /// The emitter that only exists while particles are alive, which a renderer writes. It is
    /// absent here: it holds a low-level instance buffer, and there is no particle renderer in
    /// this port to write one - the registry carries the row with that reason.
    public var spawnedEmitter: ParticleEmitter?

    public init(emitterShape: EmitterShape = .sphere, birthLocation: BirthLocation = .volume,
                birthDirection: BirthDirection = .normal,
                emitterShapeSize: SIMD3<Float> = .one, speed: Float = 1, speedVariation: Float = 0,
                emissionDirection: SIMD3<Float> = .zero, radialAmount: Float = 0,
                torusInnerRadius: Float = 0, spawnOccasion: SpawnOccasion = .onUpdate,
                spawnVelocityFactor: Float = 0, spawnSpreadFactor: Float = 0,
                spawnSpreadFactorVariation: Float = 0, spawnInheritsParentColor: Bool = false,
                simulationState: SimulationState = .play, particlesInheritTransform: Bool = false,
                fieldSimulationSpace: SimulationSpace = .local, isEmitting: Bool = true,
                burstCount: Int = 0, burstCountVariation: Int = 0,
                mainEmitter: ParticleEmitter = ParticleEmitter(), spawnedEmitter: ParticleEmitter? = nil) {
        self.emitterShape = emitterShape
        self.birthLocation = birthLocation
        self.birthDirection = birthDirection
        self.emitterShapeSize = emitterShapeSize
        self.speed = speed
        self.speedVariation = speedVariation
        self.emissionDirection = emissionDirection
        self.radialAmount = radialAmount
        self.torusInnerRadius = torusInnerRadius
        self.spawnOccasion = spawnOccasion
        self.spawnVelocityFactor = spawnVelocityFactor
        self.spawnSpreadFactor = spawnSpreadFactor
        self.spawnSpreadFactorVariation = spawnSpreadFactorVariation
        self.spawnInheritsParentColor = spawnInheritsParentColor
        self.simulationState = simulationState
        self.particlesInheritTransform = particlesInheritTransform
        self.fieldSimulationSpace = fieldSimulationSpace
        self.isEmitting = isEmitting
        self.burstCount = burstCount
        self.burstCountVariation = burstCountVariation
        self.mainEmitter = mainEmitter
        self.spawnedEmitter = spawnedEmitter
    }
}

extension Entity {
    /// The emitter on this entity, or nil when it has none.
    public var particleEmitter: ParticleEmitterComponent? {
        get { components[ParticleEmitterComponent.self] }
        set {
            if let newValue {
                components.set(newValue)
            } else {
                components.remove(ParticleEmitterComponent.self)
            }
        }
    }
}
