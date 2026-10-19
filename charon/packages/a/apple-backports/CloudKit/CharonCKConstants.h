// The exported constants of CKConstants*.m, declared for the other files of this folder.
//
// They are declared here rather than taken from the SDK because the SDK this package builds against
// is 16.4 and does not declare several of them: CKRecordCreationDateKey and the three keys beside it
// arrived in a release after 16.4's CloudKit.h stopped carrying them, and the ledger's own list of
// what needs code is the record of which. A name no header of the SDK declares is covered by rule R4
// of .agents/skills/patch-merge.

#ifndef CHARON_CK_CONSTANTS_H
#define CHARON_CK_CONSTANTS_H

#import <Foundation/Foundation.h>

extern NSString *const CKErrorDomain;
extern NSString *const CKPartialErrorsByItemIDKey;
extern NSString *const CKRecordChangedErrorAncestorRecordKey;
extern NSString *const CKRecordChangedErrorServerRecordKey;
extern NSString *const CKRecordChangedErrorClientRecordKey;
extern NSString *const CKErrorRetryAfterKey;
extern NSString *const CKErrorUserDidResetEncryptedDataKey;
extern NSString *const CKAccountChangedNotification;
extern NSString *const CKRecordRecordIDKey;
extern NSString *const CKRecordCreationDateKey;
extern NSString *const CKRecordModificationDateKey;
extern NSString *const CKRecordCreatorUserRecordIDKey;
extern NSString *const CKRecordLastModifiedUserRecordIDKey;
extern NSString *const CKRecordParentKey;
extern NSString *const CKRecordShareKey;
extern NSString *const CKRecordNameZoneWideShare;
extern NSString *const CKRecordZoneDefaultName;
extern NSString *const CKOwnerDefaultName;
extern NSString *const CKCurrentUserDefaultName;
extern NSString *const CKRecordTypeShare;
extern NSString *const CKShareTitleKey;
extern NSString *const CKShareTypeKey;
extern NSString *const CKShareThumbnailImageDataKey;
extern const NSUInteger CKQueryOperationMaximumResults;

#endif
