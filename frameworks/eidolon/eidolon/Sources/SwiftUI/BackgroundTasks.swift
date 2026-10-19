import Foundation

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct BackgroundTask<Request, Response>: Sendable {
    public let request: Request
    public let response: Response

    public init(request: Request, response: Response) {
        self.request = request
        self.response = response
    }
}
