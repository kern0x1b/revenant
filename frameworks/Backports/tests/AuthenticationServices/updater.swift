import Foundation
import UIKit
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

final class PasskeyView: UIView, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if #available(iOS 17.0, *) {
            if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                _ = credential.rawClientDataJSON
                _ = credential.rawAttestationObject
                _ = credential.credentialID
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = self.window?.windowScene else {
            preconditionFailure()
        }
        return ASPresentationAnchor(windowScene: windowScene)
    }

    func createPasskey(relyingPartyIdentifier: String, challenge: Data, name: String, userID: Data) {
        if #available(iOS 15.0, *) {
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyIdentifier)
            let platformKeyRequest = platformProvider.createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userID)
            let authController = ASAuthorizationController(authorizationRequests: [platformKeyRequest])
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
        }
    }
}
