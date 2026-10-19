// Differential probe for the AuthenticationServices error structs: built once against the host's
// AuthenticationServices (no -DOURS) and once against packages/s/swift-runtime/files/AuthenticationServices/Errors.swift
// (-DOURS). The two outputs must match line for line (facts/AuthenticationServices/Errors.md).
import Foundation
#if !OURS
import AuthenticationServices
#endif

print("domains", ASAuthorizationError.errorDomain, ASCredentialIdentityStoreError.errorDomain,
      ASExtensionError.errorDomain, ASWebAuthenticationSessionError.errorDomain)

for n in -1...1005 {
    if let c = ASAuthorizationError.Code(rawValue: n) {
        print("authorization", n, "\(c)")
    }
}
for n in -1...4 {
    if let c = ASWebAuthenticationSessionError.Code(rawValue: n) { print("webauth", n, "\(c)") } else { print("webauth", n, "none") }
    if let c = ASCredentialIdentityStoreError.Code(rawValue: n) { print("store", n, "\(c)") } else { print("store", n, "none") }
    if let c = ASExtensionError.Code(rawValue: n) { print("extension", n, "\(c)") } else { print("extension", n, "none") }
}
for n in [100, 101, 102, 1000, 1009, 1010, 1011] {
    if let c = ASExtensionError.Code(rawValue: n) { print("extension", n, "\(c)") } else { print("extension", n, "none") }
    if let c = ASAuthorizationError.Code(rawValue: n) { print("authorization", n, "\(c)") } else { print("authorization", n, "none") }
}

let foreign = NSError(domain: "not.ours", code: 1000, userInfo: nil)
let wrapped = ASAuthorizationError(_nsError: foreign)
print("wrapped", wrapped.errorCode, wrapped.errorUserInfo.count, wrapped._nsError.domain)
let canceled = ASAuthorizationError(_nsError: NSError(domain: ASAuthorizationError.errorDomain,
                                                      code: ASAuthorizationError.Code.canceled.rawValue, userInfo: nil))
print("canceled", canceled.errorCode, canceled.errorUserInfo.count, canceled._nsError.domain)
print("canceled-equal", canceled == ASAuthorizationError(_nsError: canceled._nsError))
let store = ASCredentialIdentityStoreError(_nsError: NSError(domain: ASCredentialIdentityStoreError.errorDomain,
                                                             code: ASCredentialIdentityStoreError.Code.storeBusy.rawValue, userInfo: nil))
print("store-busy", store.errorCode, store._nsError.domain)
let ext = ASExtensionError(_nsError: NSError(domain: ASExtensionError.errorDomain, code: 101, userInfo: nil))
print("extension-101", ext.errorCode, ext._nsError.domain)
let web = ASWebAuthenticationSessionError(_nsError: NSError(domain: ASWebAuthenticationSessionError.errorDomain,
                                                            code: ASWebAuthenticationSessionError.Code.canceledLogin.rawValue, userInfo: nil))
print("web-canceled", web.errorCode, web._nsError.domain)

func customNSError<T: CustomNSError>(_: T.Type) -> Bool { true }
func hashable<T: Hashable>(_: T.Type) -> Bool { true }
func sendable<T: Sendable>(_: T.Type) -> Bool { true }
print("conform", customNSError(ASAuthorizationError.self), hashable(ASAuthorizationError.self), sendable(ASAuthorizationError.self))
print("conform-web", customNSError(ASWebAuthenticationSessionError.self), hashable(ASWebAuthenticationSessionError.self), sendable(ASWebAuthenticationSessionError.self))
func errorCodeProtocol<T: _ErrorCodeProtocol>(_: T.Type) -> Bool { true }
print("error-code-protocol", errorCodeProtocol(ASAuthorizationError.Code.self), errorCodeProtocol(ASCredentialIdentityStoreError.Code.self),
      errorCodeProtocol(ASExtensionError.Code.self), errorCodeProtocol(ASWebAuthenticationSessionError.Code.self))
print("static-constants", ASAuthorizationError.canceled.rawValue, ASAuthorizationError.deviceNotConfiguredForPasskeyCreation.rawValue,
      ASCredentialIdentityStoreError.internalError.rawValue, ASExtensionError.credentialIdentityNotFound.rawValue,
      ASWebAuthenticationSessionError.presentationContextInvalid.rawValue)
