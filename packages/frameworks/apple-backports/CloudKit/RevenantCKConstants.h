#ifndef REVENANT_CK_CONSTANTS_H
#define REVENANT_CK_CONSTANTS_H

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
