import Foundation

// A task the system runs in the background for an app, and the work it hands back. Apple's shape from
// the SDK of 26.2 (`SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:18160`): a `Sendable` struct of
// two generic parameters - the request it is given and the response it answers with - and an empty body
// of its own, with the URL-session flavour and the others in an extension.
//
// iOS 6.1.3 has no `URLSession`, and no other way an app hands work to the system from the background
// except `beginBackgroundTask`, which finishes before it is done. So the type is carried and its
// flavours are not: there is nothing here to run them on.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct BackgroundTask<Request, Response>: Sendable {
    /// What the task is asked to do.
    public let request: Request
    /// What it answers with, once the system has run it.
    public let response: Response

    public init(request: Request, response: Response) {
        self.request = request
        self.response = response
    }
}
