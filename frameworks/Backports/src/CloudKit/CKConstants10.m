#include "../revenant_impl.h"
#import <CloudKit/CloudKit.h>

NSString *const BACKPORT_IMPL(CKCurrentUserDefaultName) = @"__defaultOwner__";
CKRecordType const BACKPORT_IMPL(CKRecordTypeShare) = @"cloudkit.share";
CKRecordFieldKey const BACKPORT_IMPL(CKRecordParentKey) = @"___parent";
CKRecordFieldKey const BACKPORT_IMPL(CKRecordShareKey) = @"___share";
NSString *const BACKPORT_IMPL(CKShareTitleKey) = @"cloudkit.title";
NSString *const BACKPORT_IMPL(CKShareTypeKey) = @"cloudkit.type";
NSString *const BACKPORT_IMPL(CKShareThumbnailImageDataKey) = @"cloudkit.thumbnailImageData";
