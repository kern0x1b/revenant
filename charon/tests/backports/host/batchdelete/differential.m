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
    NSEntityDescription *other = [[NSEntityDescription alloc] init];
    other.name = @"Other";
    other.managedObjectClassName = @"NSManagedObject";
    NSAttributeDescription *otherName = [[NSAttributeDescription alloc] init];
    otherName.name = @"name";
    otherName.attributeType = NSStringAttributeType;
    otherName.optional = YES;
    other.properties = @[otherName];
    m.entities = @[item, other];
    return m;
}

@interface Stack : NSObject
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic) BOOL ours;
@end

@implementation Stack
@end

static int stack_counter;

static Stack *make_stack(BOOL ours)
{
    Stack *stack = [Stack new];
    stack.ours = ours;
    stack.url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"batchdelete-%d-%d.sqlite", getpid(), stack_counter++]]];
    for (NSString *suffix in @[@"", @"-shm", @"-wal"])
        [[NSFileManager defaultManager] removeItemAtPath:[stack.url.path stringByAppendingString:suffix] error:NULL];
    stack.coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
    [stack.coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:stack.url options:nil error:NULL];
    stack.context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    stack.context.persistentStoreCoordinator = stack.coordinator;
    for (int i = 0; i < 6; i++) {
        NSManagedObject *item = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:stack.context];
        [item setValue:[NSString stringWithFormat:@"%c%d", i < 3 ? 'a' : 'b', i] forKey:@"name"];
        [item setValue:@(i) forKey:@"rank"];
    }
    [NSEntityDescription insertNewObjectForEntityForName:@"Other" inManagedObjectContext:stack.context];
    [stack.context save:NULL];
    return stack;
}

static NSArray *names(Stack *stack, NSString *entity)
{
    NSManagedObjectContext *fresh = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    fresh.persistentStoreCoordinator = stack.coordinator;
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entity];
    fetch.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    NSMutableArray *out = [NSMutableArray array];
    for (NSManagedObject *object in [fresh executeFetchRequest:fetch error:NULL])
        [out addObject:[object valueForKey:@"name"] ?: @"nil"];
    return out;
}

static NSFetchRequest *fetch(NSString *entity, NSString *predicate, NSUInteger limit, BOOL descending)
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    if (predicate)
        request.predicate = [NSPredicate predicateWithFormat:predicate];
    if (limit) {
        request.fetchLimit = limit;
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:!descending]];
    }
    return request;
}

static id make_request(Stack *stack, NSFetchRequest *fetchRequest, NSUInteger resultType)
{
    Class cls = NSClassFromString(stack.ours ? @"CharonHostNSBatchDeleteRequest" : @"NSBatchDeleteRequest");
    id request = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], @selector(initWithFetchRequest:), fetchRequest);
    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(request, @selector(setResultType:), resultType);
    return request;
}

static id execute(Stack *stack, id request, NSError **error)
{
    return stack.ours ? [stack.context charonHostexecuteRequest:request error:error] : [stack.context executeRequest:request error:error];
}

static NSMutableDictionary *id_names(Stack *stack)
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSManagedObjectContext *fresh = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    fresh.persistentStoreCoordinator = stack.coordinator;
    for (NSString *entity in @[@"Item", @"Other"])
        for (NSManagedObject *object in [fresh executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:entity] error:NULL])
            map[object.objectID.URIRepresentation.absoluteString] = [NSString stringWithFormat:@"%@/%@", entity, [object valueForKey:@"name"] ?: @"nil"];
    return map;
}

static NSString *describe_result(id result, NSError *error, NSDictionary *idNames)
{
    if (!result)
        return [NSString stringWithFormat:@"nil %@", error ? @(error.code).description : @"noerror"];
    NSString *cls = [NSStringFromClass([result class]) stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    id value = [result result];
    NSString *text;
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *paths = [NSMutableArray array];
        for (NSManagedObjectID *objectID in value)
            [paths addObject:idNames[objectID.URIRepresentation.absoluteString] ?: @"unknown"];
        [paths sortUsingSelector:@selector(compare:)];
        text = [paths componentsJoinedByString:@","];
    } else {
        text = [value description];
    }
    return [NSString stringWithFormat:@"%@ type=%lu result=%@ (%@)", cls, (unsigned long)[result resultType], text, [value isKindOfClass:[NSArray class]] ? @"array" : [value isKindOfClass:[NSNumber class]] ? @"number" : NSStringFromClass([value class])];
}

static void scenario(const char *name, NSFetchRequest *(^build)(void), NSUInteger resultType)
{
    Stack *system = make_stack(NO), *ours = make_stack(YES);
    NSError *systemError = nil, *ourError = nil;
    NSDictionary *systemNames = id_names(system), *ourNames = id_names(ours);
    id systemResult = execute(system, make_request(system, build(), resultType), &systemError);
    id ourResult = execute(ours, make_request(ours, build(), resultType), &ourError);
    CHECK_EQUAL(describe_result(ourResult, ourError, ourNames), describe_result(systemResult, systemError, systemNames), label(@"%s result", name));
    CHECK_EQUAL(names(ours, @"Item"), names(system, @"Item"), label(@"%s items left", name));
    CHECK_EQUAL(names(ours, @"Other"), names(system, @"Other"), label(@"%s others left", name));
}

static void requests(void)
{
    for (NSUInteger type = 0; type <= 2; type++) {
        scenario(label(@"predicate type %lu", (unsigned long)type), ^{ return fetch(@"Item", @"name BEGINSWITH 'a'", 0, NO); }, type);
        scenario(label(@"whole entity type %lu", (unsigned long)type), ^{ return fetch(@"Item", nil, 0, NO); }, type);
        scenario(label(@"no match type %lu", (unsigned long)type), ^{ return fetch(@"Item", @"name == 'zzz'", 0, NO); }, type);
        scenario(label(@"limit type %lu", (unsigned long)type), ^{ return fetch(@"Item", nil, 2, YES); }, type);
        scenario(label(@"other entity type %lu", (unsigned long)type), ^{ return fetch(@"Other", nil, 0, NO); }, type);
        scenario(label(@"rank predicate type %lu", (unsigned long)type), ^{ return fetch(@"Item", @"rank >= 3 AND rank < 5", 0, NO); }, type);
    }
}

static void object_ids(void)
{
    Stack *system = make_stack(NO), *ours = make_stack(YES);
    NSMutableArray *systemIDs = [NSMutableArray array], *ourIDs = [NSMutableArray array];
    for (Stack *stack in @[system, ours]) {
        NSFetchRequest *all = fetch(@"Item", nil, 0, NO);
        all.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES]];
        for (NSManagedObject *object in [stack.context executeFetchRequest:all error:NULL])
            [stack.ours ? ourIDs : systemIDs addObject:object.objectID];
    }
    NSDictionary *systemNames = id_names(system), *ourNames = id_names(ours);
    NSArray *systemPick = @[systemIDs[1], systemIDs[4]], *ourPick = @[ourIDs[1], ourIDs[4]];
    id systemRequest = ((id (*)(id, SEL, id))objc_msgSend)([NSBatchDeleteRequest alloc], @selector(initWithObjectIDs:), systemPick);
    id ourRequest = ((id (*)(id, SEL, id))objc_msgSend)([NSClassFromString(@"CharonHostNSBatchDeleteRequest") alloc], @selector(charonHostinitWithObjectIDs:), ourPick);
    CHECK_EQUAL([[[ourRequest fetchRequest] entityName] description], [[[systemRequest fetchRequest] entityName] description], "object IDs request entity");
    CHECK_EQUAL([[[ourRequest fetchRequest] predicate].predicateFormat stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""].length > 0 ? @"predicate" : @"none", @"predicate", "object IDs request predicate");
    [systemRequest setResultType:NSBatchDeleteResultTypeObjectIDs];
    [ourRequest setResultType:NSBatchDeleteResultTypeObjectIDs];
    NSError *systemError = nil, *ourError = nil;
    id systemResult = [system.context executeRequest:systemRequest error:&systemError];
    id ourResult = [ours.context charonHostexecuteRequest:ourRequest error:&ourError];
    CHECK_EQUAL(describe_result(ourResult, ourError, ourNames), describe_result(systemResult, systemError, systemNames), "object IDs result");
    CHECK_EQUAL(names(ours, @"Item"), names(system, @"Item"), "object IDs items left");
    CHECK_EQUAL(names(ours, @"Item"), (@[@"a0", @"a2", @"b3", @"b5"]), "the right two were removed");
}

static NSString *exception_text(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@ %@", exception.name, exception.reason, exception.userInfo.allKeys];
    }
    return @"no exception";
}

static void errors(void)
{
    Class ours = NSClassFromString(@"CharonHostNSBatchDeleteRequest");
    CHECK_EQUAL(exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([ours alloc], @selector(initWithFetchRequest:), nil); }),
                exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([NSBatchDeleteRequest alloc], @selector(initWithFetchRequest:), nil); }), "nil fetch request");
    CHECK_EQUAL(exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([ours alloc], @selector(initWithFetchRequest:), [[NSFetchRequest alloc] init]); }),
                exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([NSBatchDeleteRequest alloc], @selector(initWithFetchRequest:), [[NSFetchRequest alloc] init]); }), "a fetch with no entity");
    CHECK_EQUAL(exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([ours alloc], @selector(charonHostinitWithObjectIDs:), @[]); }),
                exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([NSBatchDeleteRequest alloc], @selector(initWithObjectIDs:), @[]); }), "no object IDs");
    CHECK_EQUAL(exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([ours alloc], @selector(charonHostinitWithObjectIDs:), nil); }),
                exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([NSBatchDeleteRequest alloc], @selector(initWithObjectIDs:), nil); }), "nil object IDs");
    Stack *system = make_stack(NO), *port = make_stack(YES);
    NSManagedObject *item = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:system.context], *other = [NSEntityDescription insertNewObjectForEntityForName:@"Other" inManagedObjectContext:system.context];
    [system.context save:NULL];
    NSManagedObject *portItem = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:port.context], *portOther = [NSEntityDescription insertNewObjectForEntityForName:@"Other" inManagedObjectContext:port.context];
    [port.context save:NULL];
    CHECK_EQUAL(exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([ours alloc], @selector(charonHostinitWithObjectIDs:), @[portItem.objectID, portOther.objectID]); }),
                exception_text(^{ ((id (*)(id, SEL, id))objc_msgSend)([NSBatchDeleteRequest alloc], @selector(initWithObjectIDs:), @[item.objectID, other.objectID]); }), "mixed entities");
}

static void requests_shape(void)
{
    Stack *system = make_stack(NO), *ours = make_stack(YES);
    NSFetchRequest *original = fetch(@"Item", @"rank > 1", 3, NO);
    original.fetchBatchSize = 20;
    original.includesSubentities = NO;
    original.fetchOffset = 1;
    id systemRequest = make_request(system, original, 0), ourRequest = make_request(ours, original, 0);
    NSFetchRequest *s = [systemRequest fetchRequest], *o = [ourRequest fetchRequest];
    CHECK([systemRequest requestType] == 7 && [ourRequest requestType] == 7, "request type 7");
    CHECK(s != original && o != original && [systemRequest fetchRequest] == s && [ourRequest fetchRequest] == o, "the request keeps a copy");
    CHECK(o.resultType == s.resultType && o.includesPropertyValues == s.includesPropertyValues && o.includesPendingChanges == s.includesPendingChanges && o.fetchBatchSize == s.fetchBatchSize
          && o.fetchLimit == s.fetchLimit && o.fetchOffset == s.fetchOffset && o.includesSubentities == s.includesSubentities && [o.entityName isEqual:s.entityName] && [o.predicate isEqual:s.predicate], "the copy's settings");
    CHECK([ourRequest resultType] == [systemRequest resultType], "result type starts alike");
    [ourRequest setResultType:5];
    [systemRequest setResultType:5];
    CHECK([ourRequest resultType] == [systemRequest resultType], "any result type is kept");
    CHECK_EQUAL([[ourRequest description] substringToIndex:60], [[systemRequest description] substringToIndex:60], "description");
    NSString *ourText = [ourRequest description], *systemText = [systemRequest description];
    CHECK([ourText hasPrefix:@"<NSBatchDeleteRequest : resultType : 5, fetch :<NSFetchRequest: "] && [systemText hasPrefix:@"<NSBatchDeleteRequest : resultType : 5, fetch :<NSFetchRequest: "], "description starts alike");
    NSString *ourTail = [ourText substringFromIndex:[ourText rangeOfString:@"(entity:"].location], *systemTail = [systemText substringFromIndex:[systemText rangeOfString:@"(entity:"].location];
    CHECK_EQUAL(ourTail, systemTail, "description tail");
    id ourResult = [[NSClassFromString(@"CharonHostNSBatchDeleteResult") alloc] init], systemResult = [[NSBatchDeleteResult alloc] init];
    CHECK([ourResult resultType] == [systemResult resultType] && [ourResult result] == [systemResult result], "a result made with init");
    CHECK([NSClassFromString(@"CharonHostNSBatchDeleteResult") superclass] == NSClassFromString(@"CharonHostNSPersistentStoreResult"), "the result is a persistent store result");
    CHECK([NSClassFromString(@"CharonHostNSBatchDeleteRequest") superclass] == [NSPersistentStoreRequest class], "the request is a persistent store request");
}

static void caller_context(void)
{
    Stack *system = make_stack(NO), *ours = make_stack(YES);
    for (Stack *stack in @[system, ours]) {
        NSFetchRequest *all = fetch(@"Item", nil, 0, NO);
        NSArray *objects = [stack.context executeFetchRequest:all error:NULL];
        NSManagedObject *pending = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:stack.context];
        [pending setValue:@"pending" forKey:@"name"];
        id request = make_request(stack, fetch(@"Item", @"name BEGINSWITH 'a'", 0, NO), 2);
        NSError *error = nil;
        id result = execute(stack, request, &error);
        CHECK_EQUAL([[result result] description], @"3", label(@"%@ counts what it removed", stack.ours ? @"ours" : @"system"));
        CHECK(stack.context.hasChanges && !pending.isDeleted && !pending.isFault, label(@"%@ leaves the pending insert alone", stack.ours ? @"ours" : @"system"));
        BOOL untouched = YES;
        for (NSManagedObject *object in objects)
            untouched = untouched && !object.isDeleted;
        CHECK(untouched, label(@"%@ does not mark objects of the context deleted", stack.ours ? @"ours" : @"system"));
    }
}

int main(void)
{
    @autoreleasepool {
        requests();
        object_ids();
        errors();
        requests_shape();
        caller_context();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
