import Foundation

public protocol Resource: Sendable {}

@MainActor
public class EnvironmentResource: Resource {
    public let name: String

    public let url: URL?

    public let contents: Data

    public init(name: String, url: URL? = nil, contents: Data) {
        self.name = name
        self.url = url
        self.contents = contents
    }

    public var byteCount: Int { contents.count }

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
