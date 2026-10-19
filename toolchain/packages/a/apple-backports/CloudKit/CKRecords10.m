#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKRecordPrivate.h"
#import <objc/runtime.h>

static const char RevenantCKRecordParentKey[] = "RevenantCKRecordParent";
static const char RevenantCKRecordShareKey[] = "RevenantCKRecordShare";

void RevenantCKRecordSetParent(CKRecord *record, CKReference *parent)
{
    objc_setAssociatedObject(record, RevenantCKRecordParentKey, parent, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

void RevenantCKRecordSetParentReferenceFromRecordID(CKRecord *record, CKRecordID *parentRecordID)
{
    if (!parentRecordID) {
        RevenantCKRecordSetParent(record, nil);
        return;
    }
    if (![record.recordID.zoneID isEqual:parentRecordID.zoneID]) {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                reason:@"Parent record must be in the same zone as the current record"
                              userInfo:nil] raise];
    }
    RevenantCKRecordSetParent(record, [[CKReference alloc] initWithRecordID:parentRecordID
                                                                 action:CKReferenceActionDeleteSelf]);
}

void RevenantCKRecordSetParentReferenceFromRecord(CKRecord *record, CKRecord *parentRecord)
{
    RevenantCKRecordSetParentReferenceFromRecordID(record, parentRecord ? parentRecord.recordID : nil);
}

@implementation CKRecord (RevenantCKParent)

- (CKReference *)parent
{
    return objc_getAssociatedObject(self, RevenantCKRecordParentKey);
}

- (void)setParent:(CKReference *)parent
{
    RevenantCKRecordSetParent(self, parent);
}

- (CKReference *)share
{
    return objc_getAssociatedObject(self, RevenantCKRecordShareKey);
}

@end

@interface RevenantCKRecordParentInstaller : NSObject
@end

@implementation RevenantCKRecordParentInstaller

+ (void)load
{
    Class record = [CKRecord class];
    if (!class_getInstanceMethod(record, @selector(setParentReferenceFromRecordID:))) {
        class_addMethod(record, @selector(setParentReferenceFromRecordID:),
                        (IMP)RevenantCKRecordSetParentReferenceFromRecordID, "v@:@");
    }
    if (!class_getInstanceMethod(record, @selector(setParentReferenceFromRecord:))) {
        class_addMethod(record, @selector(setParentReferenceFromRecord:),
                        (IMP)RevenantCKRecordSetParentReferenceFromRecord, "v@:@");
    }
}

@end
