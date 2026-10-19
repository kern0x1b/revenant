#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKRecordPrivate.h"
#import <objc/runtime.h>

static const char CharonCKRecordParentKey[] = "CharonCKRecordParent";
static const char CharonCKRecordShareKey[] = "CharonCKRecordShare";

void CharonCKRecordSetParent(CKRecord *record, CKReference *parent)
{
    objc_setAssociatedObject(record, CharonCKRecordParentKey, parent, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

void CharonCKRecordSetParentReferenceFromRecordID(CKRecord *record, CKRecordID *parentRecordID)
{
    if (!parentRecordID) {
        CharonCKRecordSetParent(record, nil);
        return;
    }
    if (![record.recordID.zoneID isEqual:parentRecordID.zoneID]) {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                reason:@"Parent record must be in the same zone as the current record"
                              userInfo:nil] raise];
    }
    CharonCKRecordSetParent(record, [[CKReference alloc] initWithRecordID:parentRecordID
                                                                 action:CKReferenceActionDeleteSelf]);
}

void CharonCKRecordSetParentReferenceFromRecord(CKRecord *record, CKRecord *parentRecord)
{
    CharonCKRecordSetParentReferenceFromRecordID(record, parentRecord ? parentRecord.recordID : nil);
}

@implementation CKRecord (CharonCKParent)

- (CKReference *)parent
{
    return objc_getAssociatedObject(self, CharonCKRecordParentKey);
}

- (void)setParent:(CKReference *)parent
{
    CharonCKRecordSetParent(self, parent);
}

- (CKReference *)share
{
    return objc_getAssociatedObject(self, CharonCKRecordShareKey);
}

@end

@interface CharonCKRecordParentInstaller : NSObject
@end

@implementation CharonCKRecordParentInstaller

+ (void)load
{
    Class record = [CKRecord class];
    if (!class_getInstanceMethod(record, @selector(setParentReferenceFromRecordID:))) {
        class_addMethod(record, @selector(setParentReferenceFromRecordID:),
                        (IMP)CharonCKRecordSetParentReferenceFromRecordID, "v@:@");
    }
    if (!class_getInstanceMethod(record, @selector(setParentReferenceFromRecord:))) {
        class_addMethod(record, @selector(setParentReferenceFromRecord:),
                        (IMP)CharonCKRecordSetParentReferenceFromRecord, "v@:@");
    }
}

@end
