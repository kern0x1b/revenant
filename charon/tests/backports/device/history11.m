#import <CoreData/CoreData.h>
#import <dlfcn.h>
#import <objc/message.h>
#import "check.h"

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(id object, SEL selector)
{
    @try {
        ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (NSException *exception) {
        return [exception.name stringByAppendingFormat:@": %@", exception.reason];
    }
    return @"no exception";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK_EQUAL(NSPersistentHistoryTrackingKey, @"NSPersistentHistoryTrackingKey", "constant tracking key");
        CHECK_EQUAL(NSBinaryStoreSecureDecodingClasses, @"NSBinaryStoreSecureDecodingClasses", "constant secure decoding classes");
        CHECK_EQUAL(NSBinaryStoreInsecureDecodingCompatibilityOption, @"_NSBinaryStoreInsecureDecodingCompatibilityOption", "constant insecure decoding option");
        CHECK_EQUAL(NSCoreDataCoreSpotlightExporter, @"NSCoreDataCoreSpotlightExporter", "constant spotlight exporter");
        CHECK_EQUAL(NSPersistentHistoryTokenKey, @"historyToken", "constant history token key");
        CHECK_EQUAL(NSPersistentStoreRemoteChangeNotification, @"NSPersistentStoreRemoteChangeNotification", "constant remote change notification");
        CHECK_EQUAL(NSPersistentStoreURLKey, @"storeURL", "constant store URL key");
        CHECK_EQUAL(image_of((void *)&NSPersistentHistoryTrackingKey), @"libCoreDataBackports.dylib", "the tracking key comes from the backports");
        CHECK_EQUAL(image_of((void *)&NSPersistentStoreURLKey), @"libCoreDataBackports.dylib", "the store URL key comes from the backports");

        NSDate *date = [NSDate dateWithTimeIntervalSince1970:100];
        NSPersistentHistoryChangeRequest *fetch = [NSPersistentHistoryChangeRequest fetchHistoryAfterDate:date], *remove = [NSPersistentHistoryChangeRequest deleteHistoryBeforeDate:date];
        NSPersistentHistoryChangeRequest *fetchToken = [NSPersistentHistoryChangeRequest fetchHistoryAfterToken:nil], *removeToken = [NSPersistentHistoryChangeRequest deleteHistoryBeforeToken:nil];
        NSPersistentHistoryChangeRequest *fetchTransaction = [NSPersistentHistoryChangeRequest fetchHistoryAfterTransaction:nil];
        CHECK_EQUAL(image_of((__bridge void *)[NSPersistentHistoryChangeRequest class]), @"libCoreDataBackports.dylib", "the request class comes from the backports");
        CHECK([fetch isKindOfClass:[NSPersistentStoreRequest class]], "a request is a persistent store request");
        CHECK(fetch.requestType == 8 && remove.requestType == 8, "its request type is 8");
        CHECK(fetch.resultType == NSPersistentHistoryResultTypeTransactionsAndChanges, "a fetch asks for transactions and changes");
        CHECK(remove.resultType == NSPersistentHistoryResultTypeStatusOnly, "a delete asks for the status only");
        CHECK(fetchToken.token == nil && removeToken.token == nil && fetchTransaction.token == nil, "a request made of no token has none");
        CHECK(fetchToken.resultType == 5 && removeToken.resultType == 0 && fetchTransaction.resultType == 5, "and the same result types");
        for (int type = 0; type <= 6; type++) {
            fetch.resultType = (NSPersistentHistoryResultType)type;
            remove.resultType = (NSPersistentHistoryResultType)type;
            CHECK(fetch.resultType == type, label(@"a fetch takes result type %d", type));
            CHECK(remove.resultType == NSPersistentHistoryResultTypeStatusOnly, label(@"a delete keeps the status only against %d", type));
        }
        fetch.resultType = NSPersistentHistoryResultTypeChangesOnly;
        NSPersistentHistoryChangeRequest *copy = [fetch copy];
        CHECK(copy != fetch && [copy class] == [fetch class] && copy.resultType == NSPersistentHistoryResultTypeChangesOnly && copy.requestType == 8, "a copy is a new request of the same kind and keeps the result type");
        NSPersistentHistoryChangeRequest *empty = [[NSPersistentHistoryChangeRequest alloc] init];
        CHECK(empty.resultType == NSPersistentHistoryResultTypeTransactionsAndChanges && empty.token == nil, "a new request fetches transactions and changes");
        CHECK_EQUAL([NSPersistentHistoryChangeRequest fetchHistoryAfterDate:date].description, ([NSString stringWithFormat:@"NSPersistentHistoryChangeRequest : Fetch < %@ - (null)-(null)> 5", date]), "the description of a fetch");
        CHECK_EQUAL([NSPersistentHistoryChangeRequest deleteHistoryBeforeDate:date].description, ([NSString stringWithFormat:@"NSPersistentHistoryChangeRequest : Delete < %@ - (null)-(null)> 0", date]), "the description of a delete");

        NSPersistentHistoryToken *token = [[NSPersistentHistoryToken alloc] init];
        CHECK([token copy] == token && [NSPersistentHistoryToken supportsSecureCoding], "a token copies to itself and codes securely");
        NSString *encoding = nil;
        @try { [token encodeWithCoder:[[NSKeyedArchiver alloc] initForWritingWithMutableData:[NSMutableData data]]]; } @catch (NSException *exception) { encoding = [exception.name stringByAppendingFormat:@": %@", exception.reason]; }
        CHECK_EQUAL(encoding, @"NSInvalidArgumentException: *** -encodeWithCoder: cannot be sent to an abstract object of class NSPersistentHistoryToken: Create a concrete instance!", "a token cannot be encoded");
        NSPersistentHistoryTransaction *transaction = [[NSPersistentHistoryTransaction alloc] init];
        CHECK([transaction copy] == transaction, "a transaction copies to itself");
        for (NSString *name in @[@"timestamp", @"changes", @"transactionNumber", @"storeID", @"bundleID", @"processID", @"contextName", @"author", @"token", @"objectIDNotification"])
            CHECK_EQUAL(raised(transaction, NSSelectorFromString(name)), ([NSString stringWithFormat:@"NSInvalidArgumentException: *** -%@ cannot be sent to an abstract object of class NSPersistentHistoryTransaction: Create a concrete instance!", name]), label(@"a transaction raises for %@", name));
        NSPersistentHistoryChange *change = [[NSPersistentHistoryChange alloc] init];
        CHECK([change copy] == change, "a change copies to itself");
        for (NSString *name in @[@"changeID", @"changedObjectID", @"changeType", @"tombstone", @"transaction", @"updatedProperties"])
            CHECK_EQUAL(raised(change, NSSelectorFromString(name)), ([NSString stringWithFormat:@"NSInvalidArgumentException: *** -%@ cannot be sent to an abstract object of class NSPersistentHistoryChange: Create a concrete instance!", name]), label(@"a change raises for %@", name));
        NSPersistentHistoryResult *result = [[NSPersistentHistoryResult alloc] init];
        CHECK(result.result == nil && result.resultType == 0, "an empty result");

        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        NSError *error = nil;
        CHECK([coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:@{NSPersistentHistoryTrackingKey: @YES} error:&error] != nil, "a store accepts the tracking option");
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
        context.persistentStoreCoordinator = coordinator;
        CHECK(context.transactionAuthor == nil, "the author starts nil");
        NSMutableString *author = [NSMutableString stringWithString:@"one"];
        context.transactionAuthor = author;
        [author appendString:@"two"];
        CHECK_EQUAL(context.transactionAuthor, @"one", "the author is copied");
        context.transactionAuthor = nil;
        CHECK(context.transactionAuthor == nil, "and cleared");
        CHECK([coordinator currentPersistentHistoryTokenFromStores:nil] == nil, "no store keeps a history, so there is no token");
        CHECK([coordinator currentPersistentHistoryTokenFromStores:coordinator.persistentStores] == nil, "not for the stores that are given either");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
