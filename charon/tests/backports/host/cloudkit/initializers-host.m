// The operation initializers, read out of the host's own CloudKit, and checked against the answers
// this file records.
//
// facts/CloudKit/Values.md holds what the port does with them; this file holds where the answer came
// from. Every case is one line, the expectation beside it is the host's own answer as measured by
// running this program against the framework, and the run exits non-zero naming any case whose answer
// is not the recorded one -- so the measurement in the facts is reproducible and a host that changes
// its mind goes red instead of leaving the facts describing another host.
//
// Both spellings of both are asked, and both are asked through objc_msgSend: -init and +new are the
// two a caller gets wrong, and this file compiles against the SDK headers where -init is marked
// NS_DESIGNATED_INITIALIZER, so a direct send would measure the header rather than the framework.
//
// One process, because none of these cases can end it: the two CKOperation spellings raise and are
// caught here, and every other case answers with an object that is never sent anywhere. The one
// initializer in this family that DOES end the process -- +[CKSyncEngine new], which traps in the host
// because the class behind the public one is private -- is in the facts and not here, and that is the
// reason it is not here.
#import <Foundation/Foundation.h>
#import <objc/message.h>

// What the host answers for one spelling of one class: the class it makes, or the exception and the
// reason it raises. "absent" is a class this framework does not carry, which is a difference from the
// expectation and not a pass.
static NSString *answer(Class c, BOOL instance)
{
    NSString *selName = instance ? @"init" : @"new";
    SEL sel = NSSelectorFromString(selName);
    id receiver = instance ? ((id (*)(id, SEL))objc_msgSend)((id)c, NSSelectorFromString(@"alloc"))
                           : (id)c;
    @try {
        id made = ((id (*)(id, SEL))objc_msgSend)(receiver, sel);
        if (!made) {
            return @"nil";
        }
        return [@"answers " stringByAppendingString:NSStringFromClass([made class])];
    } @catch (NSException *e) {
        return [@"raises " stringByAppendingFormat:@"%@: %@", e.name, e.reason ?: @"(no reason)"];
    }
}

// The base class refuses, in the host's own exception class and the host's own words. Every concrete
// subclass this port carries answers for both spellings, which is what makes its -init the designated
// initializer the header declares: a modify built with -init is a modify with nothing in it. One
// constant for the refusal, because it is one answer to two cases and the host gives it twice.
#define REFUSES @"raises NSInternalInconsistencyException: You must use a concrete subclass of CKOperation"
#define MAKES(C)  @"answers " C

static const struct { const char *name; BOOL instance; NSString *expected; } CASES[] = {
    { "CKOperation", NO, REFUSES },
    { "CKOperation", YES, REFUSES },

    { "CKDatabaseOperation", NO, MAKES("CKDatabaseOperation") },
    { "CKDatabaseOperation", YES, MAKES("CKDatabaseOperation") },
    { "CKModifyRecordsOperation", NO, MAKES("CKModifyRecordsOperation") },
    { "CKModifyRecordsOperation", YES, MAKES("CKModifyRecordsOperation") },
    { "CKModifyRecordZonesOperation", NO, MAKES("CKModifyRecordZonesOperation") },
    { "CKModifyRecordZonesOperation", YES, MAKES("CKModifyRecordZonesOperation") },
    { "CKModifySubscriptionsOperation", NO, MAKES("CKModifySubscriptionsOperation") },
    { "CKModifySubscriptionsOperation", YES, MAKES("CKModifySubscriptionsOperation") },
    { "CKFetchRecordsOperation", NO, MAKES("CKFetchRecordsOperation") },
    { "CKFetchRecordsOperation", YES, MAKES("CKFetchRecordsOperation") },
    { "CKFetchRecordZonesOperation", NO, MAKES("CKFetchRecordZonesOperation") },
    { "CKFetchRecordZonesOperation", YES, MAKES("CKFetchRecordZonesOperation") },
    { "CKFetchSubscriptionsOperation", NO, MAKES("CKFetchSubscriptionsOperation") },
    { "CKFetchSubscriptionsOperation", YES, MAKES("CKFetchSubscriptionsOperation") },
    { "CKQueryOperation", NO, MAKES("CKQueryOperation") },
    { "CKQueryOperation", YES, MAKES("CKQueryOperation") },
    { "CKFetchRecordChangesOperation", NO, MAKES("CKFetchRecordChangesOperation") },
    { "CKFetchRecordChangesOperation", YES, MAKES("CKFetchRecordChangesOperation") },
    { "CKFetchDatabaseChangesOperation", NO, MAKES("CKFetchDatabaseChangesOperation") },
    { "CKFetchDatabaseChangesOperation", YES, MAKES("CKFetchDatabaseChangesOperation") },
    { "CKFetchRecordZoneChangesOperation", NO, MAKES("CKFetchRecordZoneChangesOperation") },
    { "CKFetchRecordZoneChangesOperation", YES, MAKES("CKFetchRecordZoneChangesOperation") },
    { "CKAcceptSharesOperation", NO, MAKES("CKAcceptSharesOperation") },
    { "CKAcceptSharesOperation", YES, MAKES("CKAcceptSharesOperation") },
    { "CKDiscoverUserIdentitiesOperation", NO, MAKES("CKDiscoverUserIdentitiesOperation") },
    { "CKDiscoverUserIdentitiesOperation", YES, MAKES("CKDiscoverUserIdentitiesOperation") },
    { "CKDiscoverAllUserIdentitiesOperation", NO, MAKES("CKDiscoverAllUserIdentitiesOperation") },
    { "CKDiscoverAllUserIdentitiesOperation", YES, MAKES("CKDiscoverAllUserIdentitiesOperation") },
    { "CKFetchShareMetadataOperation", NO, MAKES("CKFetchShareMetadataOperation") },
    { "CKFetchShareMetadataOperation", YES, MAKES("CKFetchShareMetadataOperation") },
    { "CKFetchShareParticipantsOperation", NO, MAKES("CKFetchShareParticipantsOperation") },
    { "CKFetchShareParticipantsOperation", YES, MAKES("CKFetchShareParticipantsOperation") },

    // Measured in the same probe and recorded here because they are the other two refusals in this
    // family. CKShare is a case the port cannot mirror -- it carries no CKShare -- so the line names
    // what the host does rather than pretending the port answers it.
    { "CKShare", NO, @"raises CKException: You must call -[CKShare initWithRootRecord:shareID:]" },
    { "CKShare", YES, @"raises CKException: You must call -[CKShare initWithRootRecord:shareID:]" },
};

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        size_t count = sizeof(CASES) / sizeof(CASES[0]);
        size_t failed = 0;
        printf("# transcript: the operation initializers, read out of the host's own CloudKit\n");
        for (size_t i = 0; i < count; i++) {
            NSString *name = [NSString stringWithUTF8String:CASES[i].name];
            NSString *what = [NSString stringWithFormat:@"%@[%@ %@]", name, CASES[i].instance ? @"-" : @"+",
                                                      CASES[i].instance ? @"init" : @"new"];
            Class c = NSClassFromString(name);
            NSString *got = c ? answer(c, CASES[i].instance) : @"absent";
            BOOL ok = [got isEqualToString:CASES[i].expected];
            if (!ok) {
                failed++;
            }
            printf("  %-44s %s\n", what.UTF8String, ok ? got.UTF8String :
                   ([NSString stringWithFormat:@"%@ -- expected %@", got, CASES[i].expected]).UTF8String);
        }
        printf("# %zu case(s), %zu differing from the host's own answer\n", count, failed);
        return failed == 0 ? 0 : 1;
    }
}