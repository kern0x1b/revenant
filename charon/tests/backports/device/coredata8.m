#import <CoreData/CoreData.h>
#import <dlfcn.h>
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

static NSManagedObjectModel *model(void)
{
    NSManagedObjectModel *m = [[NSManagedObjectModel alloc] init];
    NSEntityDescription *item = [[NSEntityDescription alloc] init];
    item.name = @"Item";
    item.managedObjectClassName = @"NSManagedObject";
    NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
    name.name = @"name";
    name.attributeType = NSStringAttributeType;
    name.optional = YES;
    NSAttributeDescription *rank = [[NSAttributeDescription alloc] init];
    rank.name = @"rank";
    rank.attributeType = NSInteger32AttributeType;
    rank.optional = YES;
    NSAttributeDescription *required = [[NSAttributeDescription alloc] init];
    required.name = @"req";
    required.attributeType = NSStringAttributeType;
    required.optional = NO;
    required.defaultValue = @"d";
    NSAttributeDescription *amount = [[NSAttributeDescription alloc] init];
    amount.name = @"amount";
    amount.attributeType = NSDoubleAttributeType;
    amount.optional = YES;
    item.properties = @[name, rank, required, amount];
    NSEntityDescription *sub = [[NSEntityDescription alloc] init];
    sub.name = @"Sub";
    sub.managedObjectClassName = @"NSManagedObject";
    NSAttributeDescription *extra = [[NSAttributeDescription alloc] init];
    extra.name = @"extra";
    extra.attributeType = NSStringAttributeType;
    extra.optional = YES;
    sub.properties = @[extra];
    item.subentities = @[sub];
    NSEntityDescription *other = [[NSEntityDescription alloc] init];
    other.name = @"Other";
    other.managedObjectClassName = @"NSManagedObject";
    NSAttributeDescription *otherName = [[NSAttributeDescription alloc] init];
    otherName.name = @"name";
    otherName.attributeType = NSStringAttributeType;
    otherName.optional = YES;
    NSRelationshipDescription *owner = [[NSRelationshipDescription alloc] init];
    owner.name = @"owner";
    owner.destinationEntity = item;
    owner.maxCount = 1;
    owner.optional = YES;
    owner.deleteRule = NSNullifyDeleteRule;
    other.properties = @[otherName, owner];
    m.entities = @[item, sub, other];
    return m;
}

static int counter;

@interface Stack : NSObject
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectContext *main;
@property (nonatomic, strong) NSManagedObjectContext *priv;
@end
@implementation Stack
@end

static Stack *make_stack(int count)
{
    Stack *stack = [Stack new];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"coredata8-%d-%d.sqlite", getpid(), counter++]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    stack.coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
    NSError *error = nil;
    if (![stack.coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:nil error:&error])
        printf("FAIL store: %s\n", error.description.UTF8String);
    stack.main = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    stack.main.persistentStoreCoordinator = stack.coordinator;
    stack.priv = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    stack.priv.persistentStoreCoordinator = stack.coordinator;
    for (int i = 0; i < count; i++) {
        NSManagedObject *item = [NSEntityDescription insertNewObjectForEntityForName:i == count - 1 ? @"Sub" : @"Item" inManagedObjectContext:stack.main];
        [item setValue:[NSString stringWithFormat:@"n%d", i] forKey:@"name"];
        [item setValue:@(i) forKey:@"rank"];
        [item setValue:@(i * 1.5) forKey:@"amount"];
    }
    [stack.main save:NULL];
    return stack;
}

static NSArray *rows(Stack *stack)
{
    NSManagedObjectContext *fresh = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    fresh.persistentStoreCoordinator = stack.coordinator;
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    fetch.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES], [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES], [NSSortDescriptor sortDescriptorWithKey:@"amount" ascending:YES]];
    NSMutableArray *out = [NSMutableArray array];
    for (NSManagedObject *object in [fresh executeFetchRequest:fetch error:NULL])
        [out addObject:[NSString stringWithFormat:@"%@:%@:%@:%@", object.entity.name, [object valueForKey:@"name"] ?: @"nil", [object valueForKey:@"rank"], [object valueForKey:@"amount"]]];
    return out;
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"ok";
}

static NSString *update(Stack *stack, NSString *entity, void (^setup)(NSBatchUpdateRequest *), NSBatchUpdateRequestResultType type, __strong id *result, NSError * __autoreleasing *error)
{
    NSBatchUpdateRequest *request = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:entity];
    setup(request);
    request.resultType = type;
    __block id answer = nil;
    NSString *exception = raised(^{ answer = [stack.main executeRequest:request error:error]; });
    if (result)
        *result = answer;
    return exception;
}

static void updates(void)
{
    Stack *s = make_stack(6);
    id result = nil;
    NSError *error = nil;
    CHECK_EQUAL(image_of((__bridge void *)[NSBatchUpdateRequest class]), @"libCoreDataBackports.dylib", "the request comes from the backports");
    CHECK_EQUAL(update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.predicate = [NSPredicate predicateWithFormat:@"rank >= 4"]; r.propertiesToUpdate = @{@"name": @"hi", @"amount": @0}; }, NSUpdatedObjectsCountResultType, &result, &error), @"ok", "an update runs");
    CHECK_EQUAL([[result result] description], @"2", "and counts what it changed");
    CHECK_EQUAL(rows(s), (@[@"Item:n0:0:0", @"Item:n1:1:1.5", @"Item:n2:2:3", @"Item:n3:3:4.5", @"Item:hi:4:0", @"Sub:hi:5:0"]), "for the rows the predicate finds and the subentity");
    update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.includesSubentities = NO; r.propertiesToUpdate = @{@"name": @"only"}; }, NSUpdatedObjectsCountResultType, &result, &error);
    CHECK_EQUAL([[result result] description], @"5", "without subentities the sub row stays");
    update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"rank": [NSExpression expressionForFunction:@"add:to:" arguments:@[[NSExpression expressionForKeyPath:@"rank"], [NSExpression expressionForConstantValue:@10]]]}; }, NSUpdatedObjectsCountResultType, &result, &error);
    CHECK_EQUAL(rows(s), (@[@"Item:only:10:0", @"Item:only:11:1.5", @"Item:only:12:3", @"Item:only:13:4.5", @"Item:only:14:0", @"Sub:hi:15:0"]), "an expression reads the old row");
    update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"rank": [NSExpression expressionForKeyPath:@"amount"], @"amount": [NSExpression expressionForKeyPath:@"rank"]}; }, NSStatusOnlyResultType, &result, &error);
    CHECK_EQUAL(rows(s), (@[@"Sub:hi:0:15", @"Item:only:0:10", @"Item:only:0:14", @"Item:only:1:11", @"Item:only:3:12", @"Item:only:4:13"]), "two properties swap from the old values");
    CHECK_EQUAL([[result result] description], @"1", "status only answers YES");
    update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.predicate = [NSPredicate predicateWithFormat:@"rank == 3"]; r.propertiesToUpdate = @{@"name": [NSNull null]}; }, NSUpdatedObjectIDsResultType, &result, &error);
    CHECK([[result result] count] == 1 && [[result result][0] isKindOfClass:[NSManagedObjectID class]], "object IDs are answered");
    CHECK([rows(s) containsObject:@"Item:nil:3:12"], "an optional property takes null");
    CHECK_EQUAL(update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"req": [NSNull null]}; }, 2, &result, &error), @"NSInvalidArgumentException: Invalid NULL value for key (req) passed to propertiesToUpdate:", "a required property refuses null");
    CHECK_EQUAL(update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"nope": @1}; }, 2, &result, &error), @"NSInvalidArgumentException: Invalid string key (null) passed to propertiesToUpdate:", "an unknown key raises");
    CHECK_EQUAL(update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"name.x": @1}; }, 2, &result, &error), @"NSInvalidArgumentException: Invalid string keypath name.x passed to propertiesToUpdate:", "a key path raises");
    CHECK([update(s, @"Other", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"owner": [NSNull null]}; }, 2, &result, &error) hasPrefix:@"NSInvalidArgumentException: Invalid relationship ("], "a relationship raises");
    CHECK_EQUAL(update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"rank": [NSExpression expressionForVariable:@"x"]}; }, 2, &result, &error), @"NSInvalidArgumentException: Invalid expression ($x) in propertiesToUpdate", "a variable raises");
    CHECK_EQUAL(update(s, @"Nope", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{@"name": @1}; }, 2, &result, &error), @"NSInternalInconsistencyException: Can't find entity for batch update (Nope)", "an unknown entity raises");
    error = nil;
    result = nil;
    CHECK_EQUAL(update(s, @"Item", ^(NSBatchUpdateRequest *r) { r.propertiesToUpdate = @{}; }, 2, &result, &error), @"ok", "an empty dictionary does not raise");
    CHECK(result == nil && error.code == 134030 && [error.domain isEqual:NSCocoaErrorDomain] && [error.userInfo[@"Reason"] isEqual:@"Empty or Null Dictionary passed to propertiesToUpdate:"], "it answers nil and an error");
    NSBatchUpdateRequest *byEntity = [[NSBatchUpdateRequest alloc] initWithEntity:s.coordinator.managedObjectModel.entitiesByName[@"Item"]];
    CHECK_EQUAL(raised(^{ byEntity.propertiesToUpdate = @{@"nope": @1}; }), @"NSInvalidArgumentException: Invalid string key (null) passed to propertiesToUpdate:", "a request with an entity checks the keys when they are set");
    CHECK_EQUAL(raised(^{ (void)[NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Item"].entity; }).length > 0 ? @"raised" : @"no", @"raised", "a request with a name has no entity");
    NSBatchUpdateRequest *plain = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Item"];
    CHECK(plain.includesSubentities && plain.resultType == 0 && plain.requestType == 6, "defaults");
    CHECK([[plain description] hasPrefix:@"<NSBatchUpdateRequest : entity = Item, properties = (null), subentities = 1"], "description");
    NSManagedObject *registered = [s.main executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL][0];
    NSBatchUpdateRequest *touch = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Item"];
    touch.propertiesToUpdate = @{@"req": @"fresh"};
    touch.resultType = NSUpdatedObjectIDsResultType;
    id touched = [s.main executeRequest:touch error:NULL];
    CHECK(!s.main.hasChanges, "the calling context has no changes");
    (void)touched;
    [s.main refreshObject:registered mergeChanges:NO];
    CHECK_EQUAL([registered valueForKey:@"req"], @"fresh", "a registered object shows it once it is refreshed");
}

static void wait_for(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

static NSFetchRequest *sorted(NSString *entity)
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES]];
    return request;
}

static NSString *names(NSArray *objects)
{
    NSMutableArray *out = [NSMutableArray array];
    for (id object in objects)
        [out addObject:[object isKindOfClass:[NSManagedObject class]] ? [object valueForKey:@"name"] : [object isKindOfClass:[NSDictionary class]] ? [object valueForKey:@"name"] : @"?"];
    return [out componentsJoinedByString:@","];
}

static void asynchronous(void)
{
    Stack *s = make_stack(6);
    CHECK_EQUAL(image_of((__bridge void *)[NSAsynchronousFetchRequest class]), @"libCoreDataBackports.dylib", "the request comes from the backports");
    __block NSAsynchronousFetchResult *delivered = nil;
    __block BOOL onMain = YES;
    __block int calls = 0;
    __block NSAsynchronousFetchResult *returned = nil;
    __block NSString *seenInBlock = nil;
    NSAsynchronousFetchRequest *request = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:sorted(@"Item") completionBlock:^(NSAsynchronousFetchResult *result) {
        calls++;
        delivered = result;
        onMain = [NSThread isMainThread];
    }];
    CHECK(request.requestType == NSFetchRequestType && request.estimatedResultCount == 0 && request.completionBlock != nil, "the request's own state");
    [s.priv performBlockAndWait:^{
        returned = (NSAsynchronousFetchResult *)[s.priv executeRequest:request error:NULL];
        seenInBlock = returned.finalResult ? @"early" : @"none yet";
    }];
    CHECK_EQUAL(seenInBlock, @"none yet", "the result comes back before the fetch is delivered");
    wait_for(^BOOL { return calls > 0; }, 10);
    CHECK(calls == 1 && delivered == returned && !onMain, "the block runs once, with the same result, on the context's queue");
    CHECK_EQUAL(names(delivered.finalResult), @"n0,n1,n2,n3,n4,n5", "the final result in order");
    CHECK(returned.operationError == nil && returned.managedObjectContext == s.priv && returned.fetchRequest == request && returned.progress == nil, "the result's own state");
    CHECK([delivered.finalResult.lastObject isKindOfClass:[NSManagedObject class]] && [[delivered.finalResult.lastObject entity].name isEqual:@"Sub"], "a subentity comes back as its own");

    __block int mainCalls = 0;
    __block BOOL mainThread = NO;
    NSAsynchronousFetchRequest *onMainRequest = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:sorted(@"Item") completionBlock:^(NSAsynchronousFetchResult *result) { mainCalls++; mainThread = [NSThread isMainThread]; }];
    [s.main executeRequest:onMainRequest error:NULL];
    CHECK(mainCalls == 0, "a main context defers the block");
    wait_for(^BOOL { return mainCalls > 0; }, 10);
    CHECK(mainCalls == 1 && mainThread, "and runs it on the main thread");

    NSArray *(^fetched)(NSFetchRequest *) = ^NSArray *(NSFetchRequest *fetch) {
        __block NSArray *final = nil;
        __block BOOL done = NO;
        NSAsynchronousFetchRequest *r = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:fetch completionBlock:^(NSAsynchronousFetchResult *result) { final = result.finalResult; done = YES; }];
        [s.priv performBlockAndWait:^{ [s.priv executeRequest:r error:NULL]; }];
        wait_for(^BOOL { return done; }, 10);
        return final;
    };
    NSFetchRequest *ids = sorted(@"Item");
    ids.resultType = NSManagedObjectIDResultType;
    NSArray *idResult = fetched(ids);
    CHECK(idResult.count == 6 && [idResult[0] isKindOfClass:[NSManagedObjectID class]], "object IDs");
    NSFetchRequest *dictionaries = sorted(@"Item");
    dictionaries.resultType = NSDictionaryResultType;
    dictionaries.propertiesToFetch = @[@"name"];
    CHECK_EQUAL(names(fetched(dictionaries)), @"n0,n1,n2,n3,n4,n5", "dictionaries");
    NSFetchRequest *filtered = sorted(@"Item");
    filtered.predicate = [NSPredicate predicateWithFormat:@"rank >= 2 AND rank < 4"];
    CHECK_EQUAL(names(fetched(filtered)), @"n2,n3", "a predicate");
    NSFetchRequest *limited = sorted(@"Item");
    limited.fetchLimit = 2;
    limited.fetchOffset = 3;
    CHECK_EQUAL(names(fetched(limited)), @"n3,n4", "a limit and an offset");
    Stack *fresh = make_stack(3);
    __block NSArray *freshResult = nil;
    __block BOOL freshDone = NO;
    NSAsynchronousFetchRequest *freshRequest = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:sorted(@"Item") completionBlock:^(NSAsynchronousFetchResult *result) { freshResult = result.finalResult; freshDone = YES; }];
    [fresh.priv performBlockAndWait:^{ [fresh.priv executeRequest:freshRequest error:NULL]; }];
    wait_for(^BOOL { return freshDone; }, 10);
    CHECK([freshResult.firstObject isFault], "the objects come as faults, as the release's do");

    NSFetchRequest *count = sorted(@"Item");
    count.resultType = NSCountResultType;
    __block int countCalls = 0;
    NSAsynchronousFetchRequest *countRequest = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:count completionBlock:^(NSAsynchronousFetchResult *result) { countCalls++; }];
    __block id countAnswer = nil;
    [s.priv performBlockAndWait:^{ countAnswer = [s.priv executeRequest:countRequest error:NULL]; }];
    wait_for(^BOOL { return NO; }, 0.3);
    CHECK([countAnswer isKindOfClass:[NSArray class]] && [countAnswer count] == 1 && [countAnswer[0] intValue] == 6 && countCalls == 0, "a count is answered at once as an array, with no block");

    __block int pendingCalls = 0;
    __block NSArray *pendingResult = nil;
    [s.priv performBlockAndWait:^{
        NSManagedObject *pending = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:s.priv];
        [pending setValue:@"pending" forKey:@"name"];
        [pending setValue:@100 forKey:@"rank"];
        NSAsynchronousFetchRequest *r = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:sorted(@"Item") completionBlock:^(NSAsynchronousFetchResult *result) { pendingCalls++; pendingResult = result.finalResult; }];
        [s.priv executeRequest:r error:NULL];
    }];
    wait_for(^BOOL { return pendingCalls > 0; }, 10);
    CHECK_EQUAL(names(pendingResult), @"n0,n1,n2,n3,n4,n5,pending", "an unsaved insert is in the result");
    [s.priv performBlockAndWait:^{ [s.priv reset]; }];

    NSProgress *parent = [NSProgress progressWithTotalUnitCount:10];
    [parent becomeCurrentWithPendingUnitCount:10];
    __block int progressCalls = 0;
    NSAsynchronousFetchRequest *progressed = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:sorted(@"Item") completionBlock:^(NSAsynchronousFetchResult *result) { progressCalls++; }];
    progressed.estimatedResultCount = 3;
    __block NSAsynchronousFetchResult *progressResult = nil;
    __block NSString *inside = nil;
    [s.priv performBlockAndWait:^{
        progressResult = (NSAsynchronousFetchResult *)[s.priv executeRequest:progressed error:NULL];
        inside = [NSString stringWithFormat:@"%lld %lld %@ %d", progressResult.progress.totalUnitCount, progressResult.progress.completedUnitCount, progressResult.progress.kind, progressResult.progress.cancellable];
    }];
    [parent resignCurrent];
    CHECK_EQUAL(inside, @"3 0 managed objects 1", "a progress is made under the current one, sized by the estimate");
    wait_for(^BOOL { return progressCalls > 0; }, 10);
    CHECK_EQUAL(([NSString stringWithFormat:@"%lld %lld", progressResult.progress.totalUnitCount, progressResult.progress.completedUnitCount]), @"6 6", "and finishes at the size of the result");
    CHECK(parent.fractionCompleted == 1.0, "which completes the share the parent gave it");

    NSProgress *cancelParent = [NSProgress progressWithTotalUnitCount:10];
    [cancelParent becomeCurrentWithPendingUnitCount:10];
    __block int cancelCalls = 0;
    __block NSArray *cancelResult = nil;
    NSAsynchronousFetchRequest *cancelled = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:sorted(@"Item") completionBlock:^(NSAsynchronousFetchResult *result) { cancelCalls++; cancelResult = result.finalResult; }];
    __block NSAsynchronousFetchResult *cancelledResult = nil;
    [s.priv performBlockAndWait:^{
        cancelledResult = (NSAsynchronousFetchResult *)[s.priv executeRequest:cancelled error:NULL];
        [cancelledResult cancel];
    }];
    [cancelParent resignCurrent];
    wait_for(^BOOL { return cancelCalls > 0; }, 10);
    CHECK(cancelCalls == 1 && cancelResult.count == 0 && cancelledResult.progress.cancelled, "a cancelled fetch delivers an empty result and a cancelled progress");

    NSManagedObjectContext *confined = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    confined.persistentStoreCoordinator = s.coordinator;
    NSString *confinedText = raised(^{ [confined executeRequest:request error:NULL]; });
    CHECK([confinedText hasPrefix:@"NSInvalidArgumentException: NSConfinementConcurrencyType context "] && [confinedText rangeOfString:@"cannot support asynchronous fetch request"].location != NSNotFound, "a confinement context refuses it");
    NSAsynchronousFetchRequest *noEntity = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:[[NSFetchRequest alloc] init] completionBlock:nil];
    __block NSString *noEntityText = nil;
    [s.priv performBlockAndWait:^{ noEntityText = raised(^{ [s.priv executeRequest:noEntity error:NULL]; }); }];
    CHECK_EQUAL(noEntityText, @"NSInvalidArgumentException: _executeAsynchronousFetchRequest: A fetch request must have an entity.", "a fetch request without an entity is refused");

    NSFetchRequest *bad = sorted(@"Item");
    bad.predicate = [NSPredicate predicateWithFormat:@"nokey == 1"];
    __block int badCalls = 0;
    NSAsynchronousFetchRequest *badRequest = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:bad completionBlock:^(NSAsynchronousFetchResult *result) { badCalls++; }];
    [s.priv performBlockAndWait:^{ [s.priv executeRequest:badRequest error:NULL]; }];
    wait_for(^BOOL { return badCalls > 0; }, 1);
    CHECK(badCalls == 0, "a fetch the store raises on is not delivered, as the release does");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        updates();
        asynchronous();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
