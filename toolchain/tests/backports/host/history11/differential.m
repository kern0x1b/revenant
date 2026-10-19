#import <CoreData/CoreData.h>
#import <objc/message.h>
#import <objc/runtime.h>
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

extern NSString *const CharonHostNSPersistentHistoryTrackingKey, *const CharonHostNSBinaryStoreSecureDecodingClasses,
    *const CharonHostNSBinaryStoreInsecureDecodingCompatibilityOption, *const CharonHostNSCoreDataCoreSpotlightExporter, *const CharonHostNSPersistentHistoryTokenKey,
    *const CharonHostNSPersistentStoreRemoteChangeNotification, *const CharonHostNSPersistentStoreURLKey;

static Class cls(BOOL ours, NSString *name)
{
    return NSClassFromString(ours ? [@"CharonHost" stringByAppendingString:name] : name);
}

static id request(BOOL ours, NSString *factory, id argument)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(cls(ours, @"NSPersistentHistoryChangeRequest"), NSSelectorFromString(factory), argument);
}

static NSString *describe(NSPersistentHistoryChangeRequest *request)
{
    return [NSString stringWithFormat:@"type=%lu result=%ld token=%p", (unsigned long)[request requestType], (long)request.resultType, request.token];
}

static NSString *description_without_result(NSString *text)
{
    NSRange range = [text rangeOfString:@"> "];
    return range.location == NSNotFound ? text : [text substringToIndex:range.location + 1];
}

static void constants(void)
{
    CHECK_EQUAL(CharonHostNSPersistentHistoryTrackingKey, NSPersistentHistoryTrackingKey, "constant tracking key");
    CHECK_EQUAL(CharonHostNSBinaryStoreSecureDecodingClasses, NSBinaryStoreSecureDecodingClasses, "constant secure decoding classes");
    CHECK_EQUAL(CharonHostNSBinaryStoreInsecureDecodingCompatibilityOption, NSBinaryStoreInsecureDecodingCompatibilityOption, "constant insecure decoding option");
    CHECK_EQUAL(CharonHostNSCoreDataCoreSpotlightExporter, NSCoreDataCoreSpotlightExporter, "constant spotlight exporter");
    CHECK_EQUAL(CharonHostNSPersistentHistoryTokenKey, NSPersistentHistoryTokenKey, "constant history token key");
    CHECK_EQUAL(CharonHostNSPersistentStoreRemoteChangeNotification, NSPersistentStoreRemoteChangeNotification, "constant remote change notification");
    CHECK_EQUAL(CharonHostNSPersistentStoreURLKey, NSPersistentStoreURLKey, "constant store URL key");
}

static void requests(void)
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:100];
    NSArray *factories = @[@"fetchHistoryAfterDate:", @"deleteHistoryBeforeDate:", @"fetchHistoryAfterToken:", @"deleteHistoryBeforeToken:", @"fetchHistoryAfterTransaction:", @"deleteHistoryBeforeTransaction:"];
    for (NSString *factory in factories) {
        id argument = [factory containsString:@"Date"] ? (id)date : nil;
        NSPersistentHistoryChangeRequest *ours = request(YES, factory, argument), *system = request(NO, factory, argument);
        CHECK_EQUAL(describe(ours), describe(system), label(@"%@ fresh", factory));
        CHECK_EQUAL(description_without_result(ours.description), description_without_result(system.description), label(@"%@ description", factory));
        CHECK([ours isKindOfClass:[NSPersistentStoreRequest class]] && [ours class] == cls(YES, @"NSPersistentHistoryChangeRequest"), label(@"%@ class", factory));
        for (int type = 0; type <= 6; type++) {
            if (([factory hasPrefix:@"delete"]) && (type == 2 || type == 6))
                continue;
            ours.resultType = (NSPersistentHistoryResultType)type;
            system.resultType = (NSPersistentHistoryResultType)type;
            CHECK_EQUAL(@(ours.resultType), @(system.resultType), label(@"%@ set %d", factory, type));
        }
        NSPersistentHistoryChangeRequest *ourCopy = [ours copy], *systemCopy = [system copy];
        CHECK_EQUAL(describe(ourCopy), describe(systemCopy), label(@"%@ copy", factory));
        CHECK(ourCopy != ours && [ourCopy class] == [ours class], label(@"%@ copy is new", factory));
    }
    NSPersistentHistoryChangeRequest *ourDefault = [[cls(YES, @"NSPersistentHistoryChangeRequest") alloc] init], *systemDefault = [[cls(NO, @"NSPersistentHistoryChangeRequest") alloc] init];
    CHECK_EQUAL(describe(ourDefault), describe(systemDefault), "init");
    CHECK_EQUAL(description_without_result(ourDefault.description), description_without_result(systemDefault.description), "init description");
    NSPersistentHistoryChangeRequest *ourDelete = request(YES, @"deleteHistoryBeforeDate:", date);
    ourDelete.resultType = NSPersistentHistoryResultTypeTransactionsAndChanges;
    CHECK_EQUAL(@(ourDelete.resultType), @(NSPersistentHistoryResultTypeStatusOnly), "a delete request keeps the status only result");
    CHECK_EQUAL(ourDelete.description, ([NSString stringWithFormat:@"NSPersistentHistoryChangeRequest : Delete < %@ - (null)-(null)> 0", date]), "delete description in the format of iOS 12");
    CHECK_EQUAL(((NSPersistentHistoryChangeRequest *)request(YES, @"fetchHistoryAfterDate:", date)).description, ([NSString stringWithFormat:@"NSPersistentHistoryChangeRequest : Fetch < %@ - (null)-(null)> 5", date]), "fetch description in the format of iOS 12");
}

static void abstract_classes(void)
{
    NSArray *names = @[@"NSPersistentHistoryToken", @"NSPersistentHistoryTransaction", @"NSPersistentHistoryChange"];
    for (NSString *name in names) {
        id ours = [[cls(YES, name) alloc] init], system = [[cls(NO, name) alloc] init];
        CHECK([ours copy] == ours && [system copy] == system, label(@"%@ copy is itself", name));
    }
    id ourToken = [[cls(YES, @"NSPersistentHistoryToken") alloc] init], systemToken = [[cls(NO, @"NSPersistentHistoryToken") alloc] init];
    CHECK([cls(YES, @"NSPersistentHistoryToken") supportsSecureCoding] == [cls(NO, @"NSPersistentHistoryToken") supportsSecureCoding], "token secure coding");
    NSKeyedArchiver *ourArchiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES], *systemArchiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    NSString *ourReason = nil, *systemReason = nil;
    @try { [ourToken encodeWithCoder:ourArchiver]; } @catch (NSException *exception) { ourReason = [[exception.name stringByAppendingString:exception.reason] stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""]; }
    @try { [systemToken encodeWithCoder:systemArchiver]; } @catch (NSException *exception) { systemReason = [exception.name stringByAppendingString:exception.reason]; }
    CHECK_EQUAL(ourReason, systemReason, "token encoding exception text");
    NSArray *selectors = @[@"timestamp", @"changes", @"transactionNumber", @"storeID", @"bundleID", @"processID", @"contextName", @"author", @"token", @"objectIDNotification"];
    for (NSString *selector in selectors) {
        id ours = [[cls(YES, @"NSPersistentHistoryTransaction") alloc] init], system = [[cls(NO, @"NSPersistentHistoryTransaction") alloc] init];
        NSString *ourText = nil, *systemText = nil;
        @try { ((id (*)(id, SEL))objc_msgSend)(ours, NSSelectorFromString(selector)); } @catch (NSException *exception) { ourText = [exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""]; }
        @try { ((id (*)(id, SEL))objc_msgSend)(system, NSSelectorFromString(selector)); } @catch (NSException *exception) { systemText = exception.reason; }
        CHECK(ourText != nil && systemText != nil, label(@"transaction %@ raises", selector));
        CHECK_EQUAL(ourText, systemText, label(@"transaction %@ text", selector));
    }
    NSArray *changeSelectors = @[@"changeID", @"changedObjectID", @"changeType", @"tombstone", @"transaction", @"updatedProperties"];
    for (NSString *selector in changeSelectors) {
        id ours = [[cls(YES, @"NSPersistentHistoryChange") alloc] init], system = [[cls(NO, @"NSPersistentHistoryChange") alloc] init];
        NSString *ourText = nil, *systemText = nil;
        @try { ((id (*)(id, SEL))objc_msgSend)(ours, NSSelectorFromString(selector)); } @catch (NSException *exception) { ourText = [exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""]; }
        @try { ((id (*)(id, SEL))objc_msgSend)(system, NSSelectorFromString(selector)); } @catch (NSException *exception) { systemText = exception.reason; }
        CHECK(ourText != nil, label(@"change %@ raises", selector));
        CHECK_EQUAL(ourText, systemText, label(@"change %@ text", selector));
    }
    NSPersistentHistoryResult *ourResult = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)([cls(YES, @"NSPersistentHistoryResult") alloc], NSSelectorFromString(@"initWithResultType:andResult:"), 3, @"x");
    CHECK(ourResult.resultType == 3 && [ourResult.result isEqual:@"x"], "a result holds its type and result");
    NSPersistentHistoryResult *emptyOurs = [[cls(YES, @"NSPersistentHistoryResult") alloc] init], *emptySystem = [[cls(NO, @"NSPersistentHistoryResult") alloc] init];
    CHECK(emptyOurs.result == emptySystem.result && emptyOurs.resultType == emptySystem.resultType, "an empty result");
}

@interface NSManagedObjectContext (CharonHost)
- (NSString *)charonHosttransactionAuthor;
- (void)charonHostsetTransactionAuthor:(NSString *)author;
@end

@interface NSPersistentStoreCoordinator (CharonHost)
- (id)charonHostcurrentPersistentHistoryTokenFromStores:(NSArray *)stores;
@end

static void contexts(void)
{
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSError *error = nil;
    [coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error];
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = coordinator;
    CHECK([context transactionAuthor] == nil && [context charonHosttransactionAuthor] == nil, "author starts nil");
    NSMutableString *author = [NSMutableString stringWithString:@"one"];
    [context setTransactionAuthor:author];
    [context charonHostsetTransactionAuthor:author];
    [author appendString:@"two"];
    CHECK_EQUAL([context transactionAuthor], @"one", "the system copies the author");
    CHECK_EQUAL([context charonHosttransactionAuthor], @"one", "the port copies the author");
    [context setTransactionAuthor:nil];
    [context charonHostsetTransactionAuthor:nil];
    CHECK([context transactionAuthor] == nil && [context charonHosttransactionAuthor] == nil, "author cleared");
    CHECK([coordinator currentPersistentHistoryTokenFromStores:nil] == [coordinator charonHostcurrentPersistentHistoryTokenFromStores:nil], "no token for a store without history");
    CHECK([coordinator currentPersistentHistoryTokenFromStores:coordinator.persistentStores] == [coordinator charonHostcurrentPersistentHistoryTokenFromStores:coordinator.persistentStores], "no token for given stores");
}

int main(void)
{
    @autoreleasepool {
        constants();
        requests();
        abstract_classes();
        contexts();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
