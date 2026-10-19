import Foundation

public struct CKError: _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError: NSError) {
        self._nsError = _nsError
    }

    public static var errorDomain: String { "CKErrorDomain" }

    private static let partialErrorsByItemIDKey = "CKPartialErrors"
    private static let retryAfterKey = "CKRetryAfter"

    public var partialErrorsByItemID: [AnyHashable: Error]? {
        _nsError.userInfo[CKError.partialErrorsByItemIDKey] as? [AnyHashable: Error]
    }

    public var retryAfterSeconds: Double? {
        (_nsError.userInfo[CKError.retryAfterKey] as? NSNumber)?.doubleValue
    }

    public enum Code: Int {
        case internalError = 1
        case partialFailure = 2
        case networkUnavailable = 3
        case networkFailure = 4
        case badContainer = 5
        case serviceUnavailable = 6
        case requestRateLimited = 7
        case missingEntitlement = 8
        case notAuthenticated = 9
        case permissionFailure = 10
        case unknownItem = 11
        case invalidArguments = 12
        case resultsTruncated = 13
        case serverRecordChanged = 14
        case serverRejectedRequest = 15
        case assetFileNotFound = 16
        case assetFileModified = 17
        case incompatibleVersion = 18
        case constraintViolation = 19
        case operationCancelled = 20
        case changeTokenExpired = 21
        case batchRequestFailed = 22
        case zoneBusy = 23
        case badDatabase = 24
        case quotaExceeded = 25
        case zoneNotFound = 26
        case limitExceeded = 27
        case userDeletedZone = 28
        case tooManyParticipants = 29
        case alreadyShared = 30
        case referenceViolation = 31
        case managedAccountRestricted = 32
        case participantMayNeedVerification = 33
        case serverResponseLost = 34
        case assetNotAvailable = 35
        case accountTemporarilyUnavailable = 36
        case participantAlreadyInvited = 37
    }

    public static var internalError: CKError.Code { .internalError }
    public static var partialFailure: CKError.Code { .partialFailure }
    public static var networkUnavailable: CKError.Code { .networkUnavailable }
    public static var networkFailure: CKError.Code { .networkFailure }
    public static var badContainer: CKError.Code { .badContainer }
    public static var serviceUnavailable: CKError.Code { .serviceUnavailable }
    public static var requestRateLimited: CKError.Code { .requestRateLimited }
    public static var missingEntitlement: CKError.Code { .missingEntitlement }
    public static var notAuthenticated: CKError.Code { .notAuthenticated }
    public static var permissionFailure: CKError.Code { .permissionFailure }
    public static var unknownItem: CKError.Code { .unknownItem }
    public static var invalidArguments: CKError.Code { .invalidArguments }
    public static var resultsTruncated: CKError.Code { .resultsTruncated }
    public static var serverRecordChanged: CKError.Code { .serverRecordChanged }
    public static var serverRejectedRequest: CKError.Code { .serverRejectedRequest }
    public static var assetFileNotFound: CKError.Code { .assetFileNotFound }
    public static var assetFileModified: CKError.Code { .assetFileModified }
    public static var incompatibleVersion: CKError.Code { .incompatibleVersion }
    public static var constraintViolation: CKError.Code { .constraintViolation }
    public static var operationCancelled: CKError.Code { .operationCancelled }
    public static var changeTokenExpired: CKError.Code { .changeTokenExpired }
    public static var batchRequestFailed: CKError.Code { .batchRequestFailed }
    public static var zoneBusy: CKError.Code { .zoneBusy }
    public static var badDatabase: CKError.Code { .badDatabase }
    public static var quotaExceeded: CKError.Code { .quotaExceeded }
    public static var zoneNotFound: CKError.Code { .zoneNotFound }
    public static var limitExceeded: CKError.Code { .limitExceeded }
    public static var userDeletedZone: CKError.Code { .userDeletedZone }
    public static var tooManyParticipants: CKError.Code { .tooManyParticipants }
    public static var alreadyShared: CKError.Code { .alreadyShared }
    public static var referenceViolation: CKError.Code { .referenceViolation }
    public static var managedAccountRestricted: CKError.Code { .managedAccountRestricted }
    public static var participantMayNeedVerification: CKError.Code { .participantMayNeedVerification }
    public static var serverResponseLost: CKError.Code { .serverResponseLost }
    public static var assetNotAvailable: CKError.Code { .assetNotAvailable }
    public static var accountTemporarilyUnavailable: CKError.Code { .accountTemporarilyUnavailable }
    public static var participantAlreadyInvited: CKError.Code { .participantAlreadyInvited }
}

extension CKError.Code: _ErrorCodeProtocol {
    public typealias _ErrorType = CKError
}
