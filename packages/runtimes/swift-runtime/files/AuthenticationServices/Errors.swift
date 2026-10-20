import Foundation

public struct ASAuthorizationError: _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError: NSError) {
        self._nsError = _nsError
    }

    public static var errorDomain: String { "com.apple.AuthenticationServices.AuthorizationError" }

    public enum Code: Int, Sendable, Equatable, Hashable, RawRepresentable {
        case unknown = 1000
        case canceled = 1001
        case invalidResponse = 1002
        case notHandled = 1003
        case failed = 1004
        case notInteractive = 1005
        case matchedExcludedCredential = 1006
        case credentialImport = 1007
        case credentialExport = 1008
        case preferSignInWithApple = 1009
        case deviceNotConfiguredForPasskeyCreation = 1010
    }

    public static var unknown: ASAuthorizationError.Code { .unknown }
    public static var canceled: ASAuthorizationError.Code { .canceled }
    public static var invalidResponse: ASAuthorizationError.Code { .invalidResponse }
    public static var notHandled: ASAuthorizationError.Code { .notHandled }
    public static var failed: ASAuthorizationError.Code { .failed }
    public static var notInteractive: ASAuthorizationError.Code { .notInteractive }
    public static var matchedExcludedCredential: ASAuthorizationError.Code { .matchedExcludedCredential }
    public static var credentialImport: ASAuthorizationError.Code { .credentialImport }
    public static var credentialExport: ASAuthorizationError.Code { .credentialExport }
    public static var preferSignInWithApple: ASAuthorizationError.Code { .preferSignInWithApple }
    public static var deviceNotConfiguredForPasskeyCreation: ASAuthorizationError.Code { .deviceNotConfiguredForPasskeyCreation }
}

extension ASAuthorizationError.Code: _ErrorCodeProtocol {
    public typealias _ErrorType = ASAuthorizationError
}

public struct ASCredentialIdentityStoreError: _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError: NSError) {
        self._nsError = _nsError
    }

    public static var errorDomain: String { "ASCredentialIdentityStoreErrorDomain" }

    public enum Code: Int, Sendable, Equatable, Hashable, RawRepresentable {
        case internalError = 0
        case storeDisabled = 1
        case storeBusy = 2
    }

    public static var internalError: ASCredentialIdentityStoreError.Code { .internalError }
    public static var storeDisabled: ASCredentialIdentityStoreError.Code { .storeDisabled }
    public static var storeBusy: ASCredentialIdentityStoreError.Code { .storeBusy }
}

extension ASCredentialIdentityStoreError.Code: _ErrorCodeProtocol {
    public typealias _ErrorType = ASCredentialIdentityStoreError
}

public struct ASExtensionError: _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError: NSError) {
        self._nsError = _nsError
    }

    public static var errorDomain: String { "ASExtensionErrorDomain" }

    public enum Code: Int, Sendable, Equatable, Hashable, RawRepresentable {
        case failed = 0
        case userCanceled = 1
        case userInteractionRequired = 100
        case credentialIdentityNotFound = 101
        case matchedExcludedCredential = 102
    }

    public static var failed: ASExtensionError.Code { .failed }
    public static var userCanceled: ASExtensionError.Code { .userCanceled }
    public static var userInteractionRequired: ASExtensionError.Code { .userInteractionRequired }
    public static var credentialIdentityNotFound: ASExtensionError.Code { .credentialIdentityNotFound }
    public static var matchedExcludedCredential: ASExtensionError.Code { .matchedExcludedCredential }
}

extension ASExtensionError.Code: _ErrorCodeProtocol {
    public typealias _ErrorType = ASExtensionError
}

public struct ASWebAuthenticationSessionError: _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError: NSError) {
        self._nsError = _nsError
    }

    public static var errorDomain: String { "com.apple.AuthenticationServices.WebAuthenticationSession" }

    public enum Code: Int, Sendable, Equatable, Hashable, RawRepresentable {
        case canceledLogin = 1
        case presentationContextNotProvided = 2
        case presentationContextInvalid = 3
    }

    public static var canceledLogin: ASWebAuthenticationSessionError.Code { .canceledLogin }
    public static var presentationContextNotProvided: ASWebAuthenticationSessionError.Code { .presentationContextNotProvided }
    public static var presentationContextInvalid: ASWebAuthenticationSessionError.Code { .presentationContextInvalid }
}

extension ASWebAuthenticationSessionError.Code: _ErrorCodeProtocol {
    public typealias _ErrorType = ASWebAuthenticationSessionError
}
