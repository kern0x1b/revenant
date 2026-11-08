import Foundation
import AuthenticationServices

func reportUpdates(updater: ASCredentialUpdater, identifier: String, handle: Data, credential: Data) async throws {
    try await updater.reportPublicKeyCredentialUpdate(relyingPartyIdentifier: identifier, userHandle: handle, newName: "name")
    try await updater.reportUnknownPublicKeyCredential(relyingPartyIdentifier: identifier, credentialID: credential)
    try await updater.reportAllAcceptedPublicKeyCredentials(relyingPartyIdentifier: identifier, userHandle: handle, acceptedCredentialIDs: [credential])
    try await updater.reportUnusedPasswordCredential(domain: identifier, userName: "user")
}

func makeUpdater() -> ASCredentialUpdater {
    return ASCredentialUpdater()
}
