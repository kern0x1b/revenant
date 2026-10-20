import simd
import Foundation

@frozen public enum ParticleEmitterShape: Codable, Equatable, Hashable {
    case point
    case plane
    case box
    case sphere
    case cone
    case cylinder
    case torus
}

@frozen public enum ParticleBirthLocation: Codable, Equatable, Hashable {
    case surface
    case volume
    case vertices(count: SIMD3<UInt>)
}

@frozen public enum ParticleBirthDirection: Codable, Equatable, Hashable {
    case world
    case local
    case normal
}

@frozen public enum ParticleSpawnOccasion: Codable, Equatable, Hashable {
    case onBirth
    case onUpdate
    case onDeath
}

@frozen public enum ParticleSimulationSpace: Codable {
    case local
    case global
}

@frozen public enum ParticleSimulationState: Codable {
    case play
    case pause
    case stop
}

@frozen public struct ParticleEmitter: Codable, Equatable {
    public enum BillboardMode: Codable, Equatable, Hashable {
        case billboard
        case billboardYAligned
        case free(axis: SIMD3<Float>, variation: Float)
    }

    public enum OpacityCurve: Codable, Equatable, Hashable {
        case linearFadeOut
        case linearFadeIn
        case gradualFadeInOut
        case quickFadeInOut
        case easeFadeIn
        case easeFadeOut
        case constant
    }

    public enum SortOrder: Codable, Equatable, Hashable {
        case increasingDepth
        case decreasingDepth
        case increasingID
        case decreasingID
        case increasingAge
        case decreasingAge
        case unsorted
    }

    public enum BlendMode: Codable, Equatable, Hashable {
        case alpha
        case opaque
        case additive
    }

    public struct ImageSequence: Codable, Equatable, Hashable {
        public var rowCount: Int
        public var columnCount: Int
        public var initialFrame: Int
        public var initialFrameVariation: Int
        public var frameRate: Float
        public var frameRateVariation: Float
        public var animationMode: AnimationRepeatMode

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

    public var birthRate: Float
    public var birthRateVariation: Float
    public var dampingFactor: Float
    public var acceleration: SIMD3<Float>
    public var spreadingAngle: Float
    public var size: Float
    public var sizeVariation: Float
    public var billboardMode: BillboardMode
    public var mass: Float
    public var massVariation: Float
    public var lifeSpan: Double
    public var lifeSpanVariation: Double
    public var angle: Float
    public var angleVariation: Float
    public var angularSpeed: Float
    public var angularSpeedVariation: Float
    public var opacityCurve: OpacityCurve
    public var sizeMultiplierAtEndOfLifespan: Float
    public var sizeMultiplierAtEndOfLifespanPower: Float
    public var colorEvolutionPower: Float
    public var noiseStrength: Float
    public var noiseScale: Float
    public var noiseAnimationSpeed: Float
    public var attractionStrength: Float
    public var attractionCenter: SIMD3<Float>
    public var vortexStrength: Float
    public var vortexDirection: SIMD3<Float>
    public var isLightingEnabled: Bool
    public var stretchFactor: Float
    public var sortOrder: SortOrder
    public var blendMode: BlendMode
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
    public var emitterShapeSize: SIMD3<Float>
    public var speed: Float
    public var speedVariation: Float
    public var emissionDirection: SIMD3<Float>
    public var radialAmount: Float
    public var torusInnerRadius: Float
    public var spawnOccasion: SpawnOccasion
    public var spawnVelocityFactor: Float
    public var spawnSpreadFactor: Float
    public var spawnSpreadFactorVariation: Float
    public var spawnInheritsParentColor: Bool
    public var simulationState: SimulationState
    public var particlesInheritTransform: Bool
    public var fieldSimulationSpace: SimulationSpace
    public var isEmitting: Bool
    public var burstCount: Int
    public var burstCountVariation: Int
    public var mainEmitter: ParticleEmitter
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
