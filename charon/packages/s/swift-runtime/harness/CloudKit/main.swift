// Differential probe for CKError: built once against the host's CloudKit (no -DOURS) and once
// against packages/s/swift-runtime/files/CloudKit/CKError.swift (-DOURS). The two outputs must match.
import Foundation
#if !OURS
import CloudKit
#endif

#if OURS
let partialKey = "CKPartialErrors"
let retryKey = "CKRetryAfter"
let domainConstant = "CKErrorDomain"
#else
let partialKey = CKPartialErrorsByItemIDKey
let retryKey = CKErrorRetryAfterKey
let domainConstant = CKErrorDomain
#endif

print("domain", CKError.errorDomain, domainConstant == CKError.errorDomain)
print("keys", partialKey, retryKey)

for n in -1...39 {
    if let c = CKError.Code(rawValue: n) {
        print("code", n, "\(c)", c.rawValue)
    } else {
        print("code", n, "none")
    }
}

print("internalError", CKError.internalError.rawValue)
print("partialFailure", CKError.partialFailure.rawValue)
print("networkUnavailable", CKError.networkUnavailable.rawValue)
print("networkFailure", CKError.networkFailure.rawValue)
print("badContainer", CKError.badContainer.rawValue)
print("serviceUnavailable", CKError.serviceUnavailable.rawValue)
print("requestRateLimited", CKError.requestRateLimited.rawValue)
print("missingEntitlement", CKError.missingEntitlement.rawValue)
print("notAuthenticated", CKError.notAuthenticated.rawValue)
print("permissionFailure", CKError.permissionFailure.rawValue)
print("unknownItem", CKError.unknownItem.rawValue)
print("invalidArguments", CKError.invalidArguments.rawValue)
print("resultsTruncated", CKError.resultsTruncated.rawValue)
print("serverRecordChanged", CKError.serverRecordChanged.rawValue)
print("serverRejectedRequest", CKError.serverRejectedRequest.rawValue)
print("assetFileNotFound", CKError.assetFileNotFound.rawValue)
print("assetFileModified", CKError.assetFileModified.rawValue)
print("incompatibleVersion", CKError.incompatibleVersion.rawValue)
print("constraintViolation", CKError.constraintViolation.rawValue)
print("operationCancelled", CKError.operationCancelled.rawValue)
print("changeTokenExpired", CKError.changeTokenExpired.rawValue)
print("batchRequestFailed", CKError.batchRequestFailed.rawValue)
print("zoneBusy", CKError.zoneBusy.rawValue)
print("badDatabase", CKError.badDatabase.rawValue)
print("quotaExceeded", CKError.quotaExceeded.rawValue)
print("zoneNotFound", CKError.zoneNotFound.rawValue)
print("limitExceeded", CKError.limitExceeded.rawValue)
print("userDeletedZone", CKError.userDeletedZone.rawValue)
print("tooManyParticipants", CKError.tooManyParticipants.rawValue)
print("alreadyShared", CKError.alreadyShared.rawValue)
print("referenceViolation", CKError.referenceViolation.rawValue)
print("managedAccountRestricted", CKError.managedAccountRestricted.rawValue)
print("participantMayNeedVerification", CKError.participantMayNeedVerification.rawValue)
print("serverResponseLost", CKError.serverResponseLost.rawValue)
print("assetNotAvailable", CKError.assetNotAvailable.rawValue)
print("accountTemporarilyUnavailable", CKError.accountTemporarilyUnavailable.rawValue)
print("participantAlreadyInvited", CKError.participantAlreadyInvited.rawValue)

// The wrapped NSError, read back through the value.
let plain = NSError(domain: CKError.errorDomain, code: 11, userInfo: nil)
let wrapped = CKError(_nsError: plain)
print("wrapped", wrapped._nsError.domain, wrapped._nsError.code, wrapped._nsError === plain)
print("wrapped.code", CKError.Code(rawValue: wrapped._nsError.code).map { "\($0)" } ?? "none")

// Nothing in the user info: both optionals are nil.
print("empty.partial", wrapped.partialErrorsByItemID == nil)
print("empty.retry", wrapped.retryAfterSeconds == nil)

// Per-item errors and a retry interval, as the backports' operations put them.
let items: [AnyHashable: Error] = ["item-a": NSError(domain: "probe", code: 5, userInfo: nil),
                                   "item-b": NSError(domain: "probe", code: 6, userInfo: nil)]
let partial = CKError(_nsError: NSError(domain: CKError.errorDomain, code: 2,
                                        userInfo: [partialKey: items, retryKey: NSNumber(value: 7.5)]))
print("partial.count", partial.partialErrorsByItemID?.count ?? -1)
print("partial.keys", (partial.partialErrorsByItemID?.keys.map { "\($0)" } ?? []).sorted())
print("partial.retry", partial.retryAfterSeconds ?? -1)
print("partial.code", CKError.Code(rawValue: partial._nsError.code).map { "\($0)" } ?? "none")

// The value is an Error and bridges back to the NSError it wraps.
let asError: Error = wrapped
print("bridged", (asError as NSError).domain, (asError as NSError).code, (asError as NSError) === plain)
