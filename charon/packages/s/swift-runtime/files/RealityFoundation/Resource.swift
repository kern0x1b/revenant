import Foundation

// MARK: - The resource protocol

/// What a resource is: something loaded once and then shared, with no reference to the scene that
/// used it. Apple's own declaration at `RealityFoundation.swiftinterface:5453` is a bare protocol
/// inheriting `Sendable` and nothing else, and that is exactly what is carried here — the
/// conformance is the whole contract, and every resource type in this module carries it.
public protocol Resource: Sendable {}

// MARK: - The environment

/// An environment: the prefiltered lighting an image-based sky is drawn with, and that a scene's
/// ambient light and reflections come from. RealityKit ships it in a compiled form of its own.
@MainActor
public class EnvironmentResource: Resource {
    /// The name the environment was loaded under.
    public let name: String

    /// Where it was read from, when it came from a file.
    public let url: URL?

    /// The compiled bytes, held whole.
    ///
    /// Held and not converted. Turning these bytes into a prefiltered cube map with its
    /// irradiance and radiance mip levels is RealityKit's own image-based-lighting runtime, and it
    /// is not in this backport: the format is closed and the spherical-harmonics and
    /// split-sum-approximation passes it needs have no counterpart on a release this old. Those
    /// members are recorded absent in the registry with that reason rather than answered here with
    /// a texture that is not the environment.
    public let contents: Data

    public init(name: String, url: URL? = nil, contents: Data) {
        self.name = name
        self.url = url
        self.contents = contents
    }

    /// How many bytes the compiled environment holds.
    public var byteCount: Int { contents.count }

    // MARK: Loading

    /// The environment a bundle holds under `name`, read whole.
    ///
    /// The name is the resource name with no extension invented for it, so what this finds is what
    /// the bundle actually holds; a name it does not hold is `.fileNoSuchFile`, which is the error
    /// Foundation itself raises for a file that is not there.
    ///
    /// `loadAsync(_:in:)` is absent and is not this method renamed: it returns a `LoadRequest`,
    /// which is a Combine `Publisher`, and there is no Combine on a release this old. The registry
    /// carries that row with the reason.
    public static func load(named name: String, in bundle: Bundle? = nil) throws -> EnvironmentResource {
        let bundle = bundle ?? Bundle.main
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let contents: Data
        do {
            contents = try Data(contentsOf: url)
        } catch {
            throw CocoaError(.fileReadUnknown)
        }
        return EnvironmentResource(name: name, url: url, contents: contents)
    }
}
