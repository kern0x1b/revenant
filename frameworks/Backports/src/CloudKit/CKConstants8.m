#include "../revenant_impl.h"
#import <CloudKit/CloudKit.h>

CKRecordType const BACKPORT_IMPL(CKRecordTypeUserRecord) = @"Users";
NSString *const BACKPORT_IMPL(CKRecordZoneDefaultName) = @"_defaultZone";
NSString *const BACKPORT_IMPL(CKOwnerDefaultName) = @"__defaultOwner__";

NSString *const BACKPORT_IMPL(CKErrorDomain) = @"CKErrorDomain";
NSString *const BACKPORT_IMPL(CKPartialErrorsByItemIDKey) = @"CKPartialErrors";

NSString *const BACKPORT_IMPL(CKRecordChangedErrorAncestorRecordKey) = @"AncestorRecord";
NSString *const BACKPORT_IMPL(CKRecordChangedErrorServerRecordKey) = @"ServerRecord";
NSString *const BACKPORT_IMPL(CKRecordChangedErrorClientRecordKey) = @"ClientRecord";

NSString *const BACKPORT_IMPL(CKRecordRecordIDKey) = @"___recordID";
NSString *const BACKPORT_IMPL(CKRecordCreationDateKey) = @"___createTime";
NSString *const BACKPORT_IMPL(CKRecordModificationDateKey) = @"___modTime";
NSString *const BACKPORT_IMPL(CKRecordCreatorUserRecordIDKey) = @"___createdBy";
NSString *const BACKPORT_IMPL(CKRecordLastModifiedUserRecordIDKey) = @"___modifiedBy";

NSString *const BACKPORT_IMPL(CKErrorRetryAfterKey) = @"CKRetryAfter";

const NSUInteger BACKPORT_IMPL(CKQueryOperationMaximumResults) = 0;
