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

static int counter;

@interface Stack : NSObject
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectContext *context;
@end
@implementation Stack
@end

static Stack *make_stack(void)
{
    Stack *stack = [Stack new];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"batchdelete9-%d-%d.sqlite", getpid(), counter++]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    stack.coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
    NSError *error = nil;
    if (![stack.coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:nil error:&error])
        printf("FAIL store: %s\n", error.description.UTF8String);
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

static NSDictionary *id_names(Stack *stack)
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSManagedObjectContext *fresh = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    fresh.persistentStoreCoordinator = stack.coordinator;
    for (NSString *entity in @[@"Item", @"Other"])
        for (NSManagedObject *object in [fresh executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:entity] error:NULL])
            map[object.objectID.URIRepresentation.absoluteString] = [NSString stringWithFormat:@"%@/%@", entity, [object valueForKey:@"name"] ?: @"nil"];
    return map;
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

static NSFetchRequest *fetch(NSString *entity, NSString *predicate, NSUInteger limit)
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    if (predicate)
        request.predicate = [NSPredicate predicateWithFormat:predicate];
    if (limit) {
        request.fetchLimit = limit;
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:NO]];
    }
    return request;
}

static id run(Stack *stack, NSFetchRequest *fetchRequest, NSBatchDeleteRequestResultType type, NSError **error)
{
    NSBatchDeleteRequest *request = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fetchRequest];
    request.resultType = type;
    return [stack.context executeRequest:request error:error];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK_EQUAL(image_of((__bridge void *)[NSBatchDeleteRequest class]), @"libCoreDataBackports.dylib", "the request comes from the backports");
        CHECK_EQUAL(image_of((__bridge void *)[NSBatchDeleteResult class]), @"libCoreDataBackports.dylib", "the result comes from the backports");
        CHECK_EQUAL(image_of((__bridge void *)[NSPersistentStoreResult class]), @"libCoreDataBackports.dylib", "the store result base class comes from the backports");
        CHECK([NSBatchDeleteRequest superclass] == [NSPersistentStoreRequest class] && [NSBatchDeleteResult superclass] == [NSPersistentStoreResult class], "the superclasses");

        NSFetchRequest *original = fetch(@"Item", @"rank > 1", 3);
        original.fetchBatchSize = 20;
        original.includesSubentities = NO;
        original.fetchOffset = 1;
        NSBatchDeleteRequest *request = [[NSBatchDeleteRequest alloc] initWithFetchRequest:original];
        NSFetchRequest *target = request.fetchRequest;
        CHECK(request.requestType == 7 && request.resultType == NSBatchDeleteResultTypeStatusOnly, "request type 7, status only to begin with");
        CHECK(target != original && request.fetchRequest == target, "the request keeps a copy");
        CHECK(target.resultType == NSManagedObjectIDResultType && !target.includesPropertyValues && !target.includesPendingChanges && target.fetchBatchSize == 0, "made to ask for object IDs alone");
        CHECK(target.fetchLimit == 3 && target.fetchOffset == 1 && !target.includesSubentities && [target.entityName isEqual:@"Item"] && [target.predicate.predicateFormat isEqual:@"rank > 1"] && target.sortDescriptors.count == 1, "and to keep the rest");
        CHECK(exception_text(^{ target.fetchLimit = 1; }).length > 0 && ![exception_text(^{ target.fetchLimit = 1; }) isEqual:@"no exception"], "the copy the request hands out cannot be changed");
        request.resultType = (NSBatchDeleteRequestResultType)5;
        CHECK(request.resultType == 5, "any result type is kept");
        request.resultType = NSBatchDeleteResultTypeCount;
        CHECK([request.description hasPrefix:@"<NSBatchDeleteRequest : resultType : 2, fetch :<NSFetchRequest: "] && [request.description hasSuffix:@" >"], "the description");
        NSBatchDeleteResult *bare = [[NSBatchDeleteResult alloc] init];
        CHECK(bare.result == nil && bare.resultType == 0, "a result made with init is empty");

        CHECK_EQUAL(exception_text(^{ (void)[[NSBatchDeleteRequest alloc] initWithFetchRequest:nil]; }), @"NSInvalidArgumentException: Must supply a fetch request during initialization (null)", "a nil fetch request is refused");
        CHECK_EQUAL(exception_text(^{ (void)[[NSBatchDeleteRequest alloc] initWithFetchRequest:[[NSFetchRequest alloc] init]]; }), @"NSInvalidArgumentException: Fetch must have an entity (null)", "and so is one with no entity");
        CHECK_EQUAL(exception_text(^{ (void)[[NSBatchDeleteRequest alloc] initWithObjectIDs:@[]]; }), @"NSInvalidArgumentException: Must supply a non-zero number of objectIDs to request during initialization (null)", "and no object IDs");

        for (NSBatchDeleteRequestResultType type = NSBatchDeleteResultTypeStatusOnly; type <= NSBatchDeleteResultTypeCount; type++) {
            Stack *stack = make_stack();
            NSDictionary *idNames = id_names(stack);
            NSError *error = nil;
            NSBatchDeleteResult *result = run(stack, fetch(@"Item", @"name BEGINSWITH 'a'", 0), type, &error);
            CHECK(result != nil && error == nil && [result isKindOfClass:[NSBatchDeleteResult class]] && result.resultType == type, label(@"type %lu makes a result of its type", (unsigned long)type));
            id value = result.result;
            if (type == NSBatchDeleteResultTypeStatusOnly)
                CHECK([value isEqual:@YES], "status only answers YES");
            else if (type == NSBatchDeleteResultTypeCount)
                CHECK([value isEqual:@3], "count answers the number removed");
            else {
                NSMutableArray *removed = [NSMutableArray array];
                for (NSManagedObjectID *objectID in value)
                    [removed addObject:idNames[objectID.URIRepresentation.absoluteString] ?: @"unknown"];
                [removed sortUsingSelector:@selector(compare:)];
                CHECK_EQUAL(removed, (@[@"Item/a0", @"Item/a1", @"Item/a2"]), "object IDs answers the ones removed");
            }
            CHECK_EQUAL(names(stack, @"Item"), (@[@"b3", @"b4", @"b5"]), label(@"type %lu leaves the b items", (unsigned long)type));
            CHECK_EQUAL(names(stack, @"Other").count == 1 ? @"one" : @"other", @"one", label(@"type %lu leaves the other entity", (unsigned long)type));
        }

        Stack *stack = make_stack();
        NSError *error = nil;
        NSBatchDeleteResult *none = run(stack, fetch(@"Item", @"name == 'zzz'", 0), NSBatchDeleteResultTypeCount, &error);
        CHECK([none.result isEqual:@0], "nothing to remove counts zero");
        NSBatchDeleteResult *limited = run(stack, fetch(@"Item", nil, 2), NSBatchDeleteResultTypeCount, &error);
        CHECK([limited.result isEqual:@2] && [names(stack, @"Item") isEqual:(@[@"a0", @"a1", @"a2", @"b3"])], "a limit and an order remove the top two");
        NSManagedObject *pending = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:stack.context];
        NSFetchRequest *listing = fetch(@"Item", nil, 0);
        NSArray *before = [stack.context executeFetchRequest:listing error:NULL];
        NSBatchDeleteResult *third = run(stack, fetch(@"Item", @"name BEGINSWITH 'a'", 0), NSBatchDeleteResultTypeCount, &error);
        CHECK([third.result isEqual:@3] && stack.context.hasChanges && !pending.isDeleted, "the pending insert of the context is left alone");
        BOOL untouched = YES;
        for (NSManagedObject *object in before)
            untouched = untouched && !object.isDeleted;
        CHECK(untouched, "and the objects of the context are not marked deleted");

        Stack *ids = make_stack();
        NSMutableArray *identifiers = [NSMutableArray array];
        NSFetchRequest *ordered = fetch(@"Item", nil, 0);
        ordered.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES]];
        for (NSManagedObject *object in [ids.context executeFetchRequest:ordered error:NULL])
            [identifiers addObject:object.objectID];
        NSBatchDeleteRequest *byIDs = [[NSBatchDeleteRequest alloc] initWithObjectIDs:@[identifiers[1], identifiers[4]]];
        CHECK([byIDs.fetchRequest.entityName isEqual:@"Item"] && [byIDs.fetchRequest.predicate.predicateFormat hasPrefix:@"SELF IN "], "a request made of object IDs fetches them");
        byIDs.resultType = NSBatchDeleteResultTypeCount;
        NSBatchDeleteResult *byIDsResult = [ids.context executeRequest:byIDs error:&error];
        CHECK([byIDsResult.result isEqual:@2] && [names(ids, @"Item") isEqual:(@[@"a0", @"a2", @"b3", @"b5"])], "it removes exactly those");
        Stack *mixed = make_stack();
        NSManagedObject *anItem = [[mixed.context executeFetchRequest:fetch(@"Item", nil, 0) error:NULL] firstObject];
        NSManagedObject *anOther = [[mixed.context executeFetchRequest:fetch(@"Other", nil, 0) error:NULL] firstObject];
        CHECK_EQUAL(exception_text(^{ (void)[[NSBatchDeleteRequest alloc] initWithObjectIDs:@[anItem.objectID, anOther.objectID]]; }), @"NSInvalidArgumentException: mismatched objectIDs in batch delete initializer (\n    objectIDs\n)", "object IDs of two entities are refused");

        id fetched = [stack.context executeRequest:fetch(@"Item", nil, 0) error:&error];
        CHECK([fetched isKindOfClass:[NSArray class]], "a fetch request given to executeRequest is executed and answers the array");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
