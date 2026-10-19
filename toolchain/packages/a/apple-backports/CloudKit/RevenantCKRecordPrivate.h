#import "RevenantCloudKit.h"

@interface CKRecord () {
    NSString *_recordType;
    CKRecordID *_recordID;
    NSString *_recordChangeTag;
    CKRecordID *_creatorUserRecordID;
    NSDate *_creationDate;
    CKRecordID *_lastModifiedUserRecordID;
    NSDate *_modificationDate;
    NSMutableDictionary *_fields;
    NSMutableArray *_changedKeys;
}
@property (nonatomic, copy) NSString *recordType;
@property (nonatomic, copy) CKRecordID *recordID;
@property (nonatomic, copy, nullable) NSString *recordChangeTag;
@property (nonatomic, copy, nullable) CKRecordID *creatorUserRecordID;
@property (nonatomic, copy, nullable) NSDate *creationDate;
@property (nonatomic, copy, nullable) CKRecordID *lastModifiedUserRecordID;
@property (nonatomic, copy, nullable) NSDate *modificationDate;
@end
extern void RevenantCKRecordSetParent(CKRecord *_Nonnull record, CKReference *_Nullable parent);
extern void RevenantCKRecordSetParentReferenceFromRecordID(CKRecord *_Nonnull record, CKRecordID *_Nullable parentRecordID);
extern void RevenantCKRecordSetParentReferenceFromRecord(CKRecord *_Nonnull record, CKRecord *_Nullable parentRecord);
