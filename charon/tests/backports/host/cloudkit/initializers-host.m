#import <Foundation/Foundation.h>
#import <objc/message.h>

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
