#import <CloudKit/CloudKit.h>

CKRecordType const CKRecordTypeUserRecord = @"Users";
NSString *const CKRecordZoneDefaultName = @"_defaultZone";
NSString *const CKOwnerDefaultName = @"__defaultOwner__";

NSString *const CKErrorDomain = @"CKErrorDomain";
NSString *const CKPartialErrorsByItemIDKey = @"CKPartialErrors";

NSString *const CKRecordChangedErrorAncestorRecordKey = @"AncestorRecord";
NSString *const CKRecordChangedErrorServerRecordKey = @"ServerRecord";
NSString *const CKRecordChangedErrorClientRecordKey = @"ClientRecord";

NSString *const CKRecordRecordIDKey = @"___recordID";
NSString *const CKRecordCreationDateKey = @"___createTime";
NSString *const CKRecordModificationDateKey = @"___modTime";
NSString *const CKRecordCreatorUserRecordIDKey = @"___createdBy";
NSString *const CKRecordLastModifiedUserRecordIDKey = @"___modifiedBy";

NSString *const CKErrorRetryAfterKey = @"CKRetryAfter";

const NSUInteger CKQueryOperationMaximumResults = 0;
