// The constants sharing added in iOS 10: the owner name a record zone of the signed-in user's
// carries, the field keys a record's parent and share references live under, the type of the
// record a share is, and the three fields of a share's own record. Every value is the one the
// host's own CloudKit hands out; see facts/CloudKit/Values.md.

#import <CloudKit/CloudKit.h>

NSString *const CKCurrentUserDefaultName = @"__defaultOwner__";
CKRecordType const CKRecordTypeShare = @"cloudkit.share";
CKRecordFieldKey const CKRecordParentKey = @"___parent";
CKRecordFieldKey const CKRecordShareKey = @"___share";
NSString *const CKShareTitleKey = @"cloudkit.title";
NSString *const CKShareTypeKey = @"cloudkit.type";
NSString *const CKShareThumbnailImageDataKey = @"cloudkit.thumbnailImageData";
