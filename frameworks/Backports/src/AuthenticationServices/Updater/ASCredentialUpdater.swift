import Foundation

public final class ASCredentialUpdater {
    public init() {}

    public func reportPublicKeyCredentialUpdate(relyingPartyIdentifier: String, userHandle: Data, newName: String) async throws {
        throw ASCredentialUpdater.failed()
    }

    public func reportUnknownPublicKeyCredential(relyingPartyIdentifier: String, credentialID: Data) async throws {
        throw ASCredentialUpdater.failed()
    }

    public func reportAllAcceptedPublicKeyCredentials(relyingPartyIdentifier: String, userHandle: Data, acceptedCredentialIDs: [Data]) async throws {
        throw ASCredentialUpdater.failed()
    }

    public func reportUnusedPasswordCredential(domain: String, userName: String) async throws {
        throw ASCredentialUpdater.failed()
    }

    private static func failed() -> NSError {
        NSError(domain: "com.apple.AuthenticationServices.AuthorizationError", code: 1004, userInfo: nil)
    }
}
