// The constants CloudKit exported in its first release. Every value is the one the host's own
// CloudKit hands out, read out of the running framework and recorded in
// facts/CloudKit/Values.md; none of them is invented.

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

// On the errors CloudKit documents as retryable the userInfo carries the number of seconds to
// wait, under this key.
NSString *const CKErrorRetryAfterKey = @"CKRetryAfter";

// The maximum a query operation returns, an NSUInteger and not a string: the header declares it
// `const NSUInteger` and the host answers 0, which a %@ prints as (null) and which is the number the
// port answers too. A limit is a property of a container's configuration, and CloudKit's own client
// is handed the service's limit when it asks for none, so 0 is the honest "none": see
// facts/CloudKit/Values.md.
const NSUInteger CKQueryOperationMaximumResults = 0;
