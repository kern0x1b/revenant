// CKRecord's parent and its share, which arrived in iOS 10.0, beside the rest of the class's surface
// in CKRecords8.m.
//
// The build refuses one object that holds the API of more than one release, and this is the half of
// CKRecord that is 10.0: the record type, the name, the fields and the copy are 8.0 and are in
// CKRecords8.m. This file defines no class of its own, so no band drops it: it is in every one of
// them, which is why it may not reach anything of the port's CKRecord. A band from iOS 8.0 on links
// the release's CKRecord, whose ivars are the release's and in another order, so an offset this port
// compiled is an offset into somebody else's object - and a category whose accessor reads one does
// not fail to link, it answers from the wrong bytes. Measured on the 8.0 gate, before this file
// stopped: _OBJC_IVAR_$_CKRecord._parent, ._recordID and ._share are undefined symbols in
// CharonCKRecords.o and CKRecords10.o against CKRecords8.o, which the 8.0 band does not link because
// the release exports that file's API.
//
// So the parent and the share are kept beside the record instead of inside it, as an associated
// object, and the zone the record is in is read through the SDK's own recordID. Both are the
// runtime's public interface, and both are what a port of this class has always used for state that
// outlives one release's layout: CharonCKDocuments.m sets its finished flag the same way.
//
// A parent names the record this one hangs under, and the service refuses a parent in another zone
// with NSInternalInconsistencyException - "Parent record must be in the same zone as the current
// record" - which is the host's own wording and is measured. A nil parent clears it. The share is the
// reference the record is published through; it is nil until the service says otherwise.
//
// The two SDK wrappers that build a parent out of a record or out of a record ID are the same method
// on both sides of iOS 8.0, so they are here once and installed where the class needs them: the port's
// own class implements them (CKRecords8.m forwards to the functions below, which is what keeps the
// compiler's two objects from each holding a body), and the installer adds them to the release's class
// for the bands of 8.0 to 9.3, which does not carry them until 10.0. That is the NSBundle+ReceiptURL
// shape, and only in the direction that adds: where the class answers the selector the release's own
// body stays.

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

// Where the class does not answer the two wrappers, add them: the release's CKRecord has them from
// iOS 10.0 and the port's own class implements them, so this is the 8.0 to 9.3 bands and nowhere
// else. class_getInstanceMethod() decides per release, which is the rule for a +load in this tree
// (Foundation/NSBundle+ReceiptURL.m): decide on the release, and never replace what it answers.
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