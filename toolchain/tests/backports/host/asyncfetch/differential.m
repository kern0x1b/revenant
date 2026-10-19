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

@interface NSManagedObjectContext (CharonHost)
- (id)charonHostexecuteRequest:(NSPersistentStoreRequest *)request error:(NSError **)error;
@end

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
    item.properties = @[name, rank];
    NSEntityDescription *sub = [[NSEntityDescription alloc] init];
    sub.name = @"Sub";
    sub.managedObjectClassName = @"NSManagedObject";
    NSAttributeDescription *extra = [[NSAttributeDescription alloc] init];
    extra.name = @"extra";
    extra.attributeType = NSStringAttributeType;
    extra.optional = YES;
    sub.properties = @[extra];
    item.subentities = @[sub];
    m.entities = @[item, sub];
    return m;
}

@interface Stack : NSObject
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectContext *main;
@property (nonatomic, strong) NSManagedObjectContext *priv;
@property (nonatomic) BOOL ours;
@end

@implementation Stack
@end

static int stack_counter;

static Stack *make_stack(BOOL ours, int count)
{
    Stack *stack = [Stack new];
    stack.ours = ours;
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"asyncfetch-%d-%d.sqlite", getpid(), stack_counter++]]];
    for (NSString *suffix in @[@"", @"-shm", @"-wal"])
        [[NSFileManager defaultManager] removeItemAtPath:[url.path stringByAppendingString:suffix] error:NULL];
    stack.coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
    [stack.coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:NULL];
    stack.main = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    stack.main.persistentStoreCoordinator = stack.coordinator;
    stack.priv = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    stack.priv.persistentStoreCoordinator = stack.coordinator;
    for (int i = 0; i < count; i++) {
        NSManagedObject *item = [NSEntityDescription insertNewObjectForEntityForName:i == count - 1 ? @"Sub" : @"Item" inManagedObjectContext:stack.main];
        [item setValue:[NSString stringWithFormat:@"n%04d", i] forKey:@"name"];
        [item setValue:@(i) forKey:@"rank"];
    }
    [stack.main save:NULL];
    return stack;
}

static NSDictionary *id_names(Stack *stack)
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSManagedObjectContext *fresh = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    fresh.persistentStoreCoordinator = stack.coordinator;
    for (NSManagedObject *object in [fresh executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL])
        map[object.objectID.URIRepresentation.absoluteString] = [NSString stringWithFormat:@"%@/%@", object.entity.name, [object valueForKey:@"name"]];
    return map;
}

static id async_request(Stack *stack, NSFetchRequest *fetch, void (^block)(id result))
{
    Class cls = NSClassFromString(stack.ours ? @"CharonHostNSAsynchronousFetchRequest" : @"NSAsynchronousFetchRequest");
    return ((id (*)(id, SEL, id, id))objc_msgSend)([cls alloc], @selector(initWithFetchRequest:completionBlock:), fetch, block);
}

static id execute(Stack *stack, NSManagedObjectContext *context, id request, NSError **error)
{
    return stack.ours ? [context charonHostexecuteRequest:request error:error] : [context executeRequest:request error:error];
}

static NSString *normalise(NSString *text)
{
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    text = [expression stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"0x"];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *url = [NSRegularExpression regularExpressionWithPattern:@"x-coredata://[0-9A-F-]+/" options:0 error:NULL];
    return [url stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"x-coredata://S/"];
}

static NSDictionary *current_names;

static NSString *render_results(NSArray *results)
{
    if (!results)
        return @"nil";
    NSMutableArray *out = [NSMutableArray array];
    for (id item in results) {
        if ([item isKindOfClass:[NSManagedObject class]])
        {
            BOOL fault = [item isFault];
            [out addObject:[NSString stringWithFormat:@"%@:%@:%@:fault=%d", [[item entity] name], [item valueForKey:@"name"], [item valueForKey:@"rank"], fault]];
        }
        else if ([item isKindOfClass:[NSManagedObjectID class]])
            [out addObject:current_names[[[item URIRepresentation] absoluteString]] ?: @"unknown"];
        else
            [out addObject:normalise([[item description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "])];
    }
    return [out componentsJoinedByString:@","];
}

static NSFetchRequest *fetch(NSString *entity, NSString *predicate)
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    if (predicate)
        request.predicate = [NSPredicate predicateWithFormat:predicate];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES]];
    return request;
}

@interface Outcome : NSObject
@property (nonatomic, copy) NSString *returned;
@property (nonatomic, copy) NSString *callback;
@property (nonatomic) int calls;
@end

@implementation Outcome
@end

static void wait_for(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

typedef void (^Tweak)(NSAsynchronousFetchRequest *request);

static Outcome *run(Stack *stack, BOOL onMain, NSFetchRequest *fetchRequest, id (^inBlock)(id request, id result, NSManagedObjectContext *context), NSInteger estimate, BOOL withParent, double wait)
{
    Outcome *outcome = [Outcome new];
    current_names = id_names(stack);
    NSManagedObjectContext *context = onMain ? stack.main : stack.priv;
    NSProgress *parent = withParent ? [NSProgress progressWithTotalUnitCount:10] : nil;
    __block NSString *callback = nil;
    __block int calls = 0;
    __block id returnedResult = nil;
    __weak id weakContext = context;
    id request = async_request(stack, fetchRequest, ^(id result) {
        calls++;
        NSManagedObjectContext *c = weakContext;
        callback = [NSString stringWithFormat:@"main=%d same=%d ctxQueue=%d final=%@ err=%@ resultContext=%d", [NSThread isMainThread], result == returnedResult, c != nil, render_results([result finalResult]), [result operationError], [result managedObjectContext] == c];
    });
    [request setEstimatedResultCount:estimate];
    __block NSString *returned = nil;
    void (^body)(void) = ^{
        if (parent)
            [parent becomeCurrentWithPendingUnitCount:10];
        NSError *error = nil;
        id result = nil;
        @try {
            result = execute(stack, context, request, &error);
        } @catch (NSException *exception) {
            returned = normalise([NSString stringWithFormat:@"EXC %@ %@", exception.name, exception.reason]);
        }
        if (parent)
            [parent resignCurrent];
        if ([result isKindOfClass:[NSArray class]]) {
            returned = [NSString stringWithFormat:@"%@ %@", normalise(NSStringFromClass([result class])), render_results(result)];
        } else if (result) {
            returnedResult = result;
            NSProgress *progress = [result progress];
            NSString *extra = inBlock ? inBlock(request, result, context) : @"";
            returned = normalise([NSString stringWithFormat:@"%@ final=%@ err=%@ ctx=%d req=%d progress=%@ %@", [result class], render_results([result finalResult]), [result operationError], [result managedObjectContext] == context, [result fetchRequest] == request,
                progress ? [NSString stringWithFormat:@"total=%lld completed=%lld kind=%@ cancellable=%d indet=%d", progress.totalUnitCount, progress.completedUnitCount, progress.kind, progress.cancellable, progress.indeterminate] : @"nil", extra]);
        } else if (!returned) {
            returned = [NSString stringWithFormat:@"nil %@", error];
        }
    };
    if (onMain)
        body();
    else
        [context performBlockAndWait:body];
    outcome.returned = returned;
    wait_for(^BOOL { return calls > 0; }, wait);
    wait_for(^BOOL { return NO; }, 0.15);
    outcome.calls = calls;
    NSProgress *progress = [returnedResult progress];
    outcome.callback = [NSString stringWithFormat:@"%@ | %@ | after: %@ parent=%@", callback, @"", progress ? [NSString stringWithFormat:@"total=%lld completed=%lld cancelled=%d", progress.totalUnitCount, progress.completedUnitCount, progress.cancelled] : @"nil",
        parent ? [NSString stringWithFormat:@"%lld/%lld", parent.completedUnitCount, parent.totalUnitCount] : @"nil"];
    return outcome;
}

static void compare(const char *name, int count, BOOL onMain, NSFetchRequest *(^build)(void), id (^inBlock)(id request, id result, NSManagedObjectContext *context), NSInteger estimate, BOOL withParent, double wait, void (^prepare)(Stack *stack))
{
    if (getenv("TRACE"))
        fprintf(stderr, "scenario %s\n", name);
    Stack *system = make_stack(NO, count), *ours = make_stack(YES, count);
    if (prepare) {
        prepare(system);
        prepare(ours);
    }
    if (getenv("TRACE"))
        fprintf(stderr, "system\n");
    Outcome *a = run(system, onMain, build(), inBlock, estimate, withParent, wait);
    if (getenv("TRACE"))
        fprintf(stderr, "ours\n");
    Outcome *b = run(ours, onMain, build(), inBlock, estimate, withParent, wait);
    CHECK_EQUAL(b.returned, a.returned, label(@"%s returned", name));
    CHECK_EQUAL(normalise(b.callback), normalise(a.callback), label(@"%s callback", name));
    CHECK(b.calls == a.calls, label(@"%s calls %d against %d", name, b.calls, a.calls));
}

static void scenarios(void)
{
    for (int main = 0; main <= 1; main++) {
        const char *where = main ? "main" : "private";
        compare(label(@"%s objects", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, 0, NO, 5, nil);
        compare(label(@"%s object ids", where), 8, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.resultType = NSManagedObjectIDResultType; return f; }, nil, 0, NO, 5, nil);
        compare(label(@"%s dictionaries", where), 8, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.resultType = NSDictionaryResultType; f.propertiesToFetch = @[@"name"]; return f; }, nil, 0, NO, 5, nil);
        compare(label(@"%s dictionaries all", where), 8, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.resultType = NSDictionaryResultType; return f; }, nil, 0, NO, 5, nil);
        compare(label(@"%s predicate", where), 8, main, ^{ return fetch(@"Item", @"rank >= 3 AND rank < 6"); }, nil, 0, NO, 5, nil);
        compare(label(@"%s limit offset", where), 8, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.fetchLimit = 3; f.fetchOffset = 2; return f; }, nil, 0, NO, 5, nil);
        compare(label(@"%s batch size", where), 20, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.fetchBatchSize = 4; return f; }, nil, 0, NO, 5, nil);
        compare(label(@"%s no match", where), 8, main, ^{ return fetch(@"Item", @"rank == 99"); }, nil, 0, NO, 5, nil);
        compare(label(@"%s sub only", where), 8, main, ^{ return fetch(@"Sub", nil); }, nil, 0, NO, 5, nil);
        compare(label(@"%s no subentities", where), 8, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.includesSubentities = NO; return f; }, nil, 0, NO, 5, nil);
        compare(label(@"%s many objects", where), 1500, main, ^{ return fetch(@"Item", nil); }, nil, 0, NO, 20, nil);
        compare(label(@"%s many ids", where), 1500, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.resultType = NSManagedObjectIDResultType; return f; }, nil, 0, NO, 20, nil);
        compare(label(@"%s count", where), 8, main, ^{ NSFetchRequest *f = fetch(@"Item", @"rank > 2"); f.resultType = NSCountResultType; return f; }, nil, 0, NO, 0.5, nil);
        compare(label(@"%s with progress", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, 3, YES, 5, nil);
        compare(label(@"%s with progress no estimate", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, 0, YES, 5, nil);
        compare(label(@"%s with progress negative estimate", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, -4, YES, 5, nil);
        compare(label(@"%s with progress large estimate", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, 500, YES, 5, nil);
        compare(label(@"%s cancel result", where), 8, main, ^{ return fetch(@"Item", nil); }, ^NSString *(id request, id result, NSManagedObjectContext *context) { [result cancel]; return @"cancelled"; }, 0, NO, 5, nil);
        compare(label(@"%s cancel result with progress", where), 8, main, ^{ return fetch(@"Item", nil); }, ^NSString *(id request, id result, NSManagedObjectContext *context) { [result cancel]; return [NSString stringWithFormat:@"cancelled=%d", [[result progress] isCancelled]]; }, 3, YES, 5, nil);
        compare(label(@"%s cancel progress", where), 8, main, ^{ return fetch(@"Item", nil); }, ^NSString *(id request, id result, NSManagedObjectContext *context) { [[result progress] cancel]; return @"progress cancelled"; }, 3, YES, 5, nil);
        compare(label(@"%s bad predicate", where), 8, main, ^{ return fetch(@"Item", @"nokey == 1"); }, nil, 0, NO, 1, nil);
        compare(label(@"%s no entity", where), 8, main, ^{ return [[NSFetchRequest alloc] init]; }, nil, 0, NO, 0.3, nil);
        compare(label(@"%s pending insert", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, 0, NO, 5, ^(Stack *stack) {
            NSManagedObjectContext *c = main ? stack.main : stack.priv;
            [c performBlockAndWait:^{ NSManagedObject *o = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:c]; [o setValue:@"pending" forKey:@"name"]; [o setValue:@100 forKey:@"rank"]; }];
        });
        compare(label(@"%s pending delete", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, 0, NO, 5, ^(Stack *stack) {
            NSManagedObjectContext *c = main ? stack.main : stack.priv;
            [c performBlockAndWait:^{ NSArray *all = [c executeFetchRequest:fetch(@"Item", nil) error:NULL]; [c deleteObject:all[1]]; }];
        });
        compare(label(@"%s pending edit", where), 8, main, ^{ return fetch(@"Item", @"name == 'edited'"); }, nil, 0, NO, 5, ^(Stack *stack) {
            NSManagedObjectContext *c = main ? stack.main : stack.priv;
            [c performBlockAndWait:^{ NSArray *all = [c executeFetchRequest:fetch(@"Item", nil) error:NULL]; [all[2] setValue:@"edited" forKey:@"name"]; }];
        });
        compare(label(@"%s pending ignored", where), 8, main, ^{ NSFetchRequest *f = fetch(@"Item", nil); f.includesPendingChanges = NO; return f; }, nil, 0, NO, 5, ^(Stack *stack) {
            NSManagedObjectContext *c = main ? stack.main : stack.priv;
            [c performBlockAndWait:^{ NSManagedObject *o = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:c]; [o setValue:@"pending" forKey:@"name"]; }];
        });
        compare(label(@"%s registered objects", where), 8, main, ^{ return fetch(@"Item", nil); }, nil, 0, NO, 5, ^(Stack *stack) {
            NSManagedObjectContext *c = main ? stack.main : stack.priv;
            [c performBlockAndWait:^{ (void)[c executeFetchRequest:fetch(@"Item", nil) error:NULL]; }];
        });
    }
}

static void confinement_and_shape(void)
{
    Stack *system = make_stack(NO, 4), *ours = make_stack(YES, 4);
    NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
    int index = 0;
    for (Stack *stack in @[system, ours]) {
        NSMutableArray *out = answers[index++];
        NSManagedObjectContext *confined = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
        confined.persistentStoreCoordinator = stack.coordinator;
        NSFetchRequest *f = fetch(@"Item", nil);
        id request = async_request(stack, f, nil);
        @try {
            (void)execute(stack, confined, request, NULL);
            [out addObject:@"no exception"];
        } @catch (NSException *exception) {
            NSString *reason = normalise(exception.reason);
            NSRange range = [reason rangeOfString:@"asynchronous fetch request"];
            [out addObject:[NSString stringWithFormat:@"%@ %@", exception.name, [reason substringToIndex:range.location + range.length]]];
        }
        [out addObject:[NSString stringWithFormat:@"type=%lu est=%ld cb=%d fetch=%d", (unsigned long)[request requestType], (long)[request estimatedResultCount], [request completionBlock] != nil, [request fetchRequest] == f]];
        NSString *description = normalise([request description]);
        NSRange entityRange = [description rangeOfString:@"(entity"];
        [out addObject:entityRange.location == NSNotFound ? description : [description substringToIndex:entityRange.location]];
        void (^block)(id) = ^(id result) {};
        id withBlock = async_request(stack, f, block);
        [out addObject:[NSString stringWithFormat:@"block kept=%d", [withBlock completionBlock] != nil]];
        NSFetchRequest *stored = [f copy];
        stored.affectedStores = stack.coordinator.persistentStores;
        id withStores = async_request(stack, stored, nil);
        [out addObject:[NSString stringWithFormat:@"stores=%lu", (unsigned long)[[withStores affectedStores] count]]];
        id nothing = async_request(stack, nil, nil);
        [out addObject:[NSString stringWithFormat:@"nil fetch: %@ %@", [nothing fetchRequest], normalise([nothing description])]];
        id copied = [withBlock copy];
        [out addObject:[NSString stringWithFormat:@"copy: %d %@ %d %lu", copied == withBlock, normalise(NSStringFromClass([copied class])), [copied fetchRequest] == f, (unsigned long)[copied requestType]]];
    }
    for (NSUInteger i = 0; i < answers[0].count; i++)
        CHECK_EQUAL(answers[1][i], answers[0][i], label(@"shape %lu", (unsigned long)i));
    CHECK([NSClassFromString(@"CharonHostNSAsynchronousFetchRequest") superclass] == [NSPersistentStoreRequest class], "the request is a persistent store request");
    CHECK([NSClassFromString(@"CharonHostNSAsynchronousFetchResult") superclass] == NSClassFromString(@"CharonHostNSPersistentStoreAsynchronousResult"), "the fetch result is an asynchronous result");
    CHECK([NSClassFromString(@"CharonHostNSPersistentStoreAsynchronousResult") superclass] == NSClassFromString(@"CharonHostNSPersistentStoreResult"), "which is a persistent store result");
}

int main(void)
{
    @autoreleasepool {
        scenarios();
        confinement_and_shape();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
