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
    NSAttributeDescription *required = [[NSAttributeDescription alloc] init];
    required.name = @"req";
    required.attributeType = NSStringAttributeType;
    required.optional = NO;
    required.defaultValue = @"d";
    NSAttributeDescription *when = [[NSAttributeDescription alloc] init];
    when.name = @"when";
    when.attributeType = NSDateAttributeType;
    when.optional = YES;
    NSAttributeDescription *flag = [[NSAttributeDescription alloc] init];
    flag.name = @"flag";
    flag.attributeType = NSBooleanAttributeType;
    flag.optional = YES;
    NSAttributeDescription *amount = [[NSAttributeDescription alloc] init];
    amount.name = @"amount";
    amount.attributeType = NSDoubleAttributeType;
    amount.optional = YES;
    item.properties = @[name, rank, required, when, flag, amount];
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
    NSRelationshipDescription *toOne = [[NSRelationshipDescription alloc] init];
    toOne.name = @"owner";
    toOne.destinationEntity = item;
    toOne.maxCount = 1;
    toOne.optional = YES;
    toOne.deleteRule = NSNullifyDeleteRule;
    NSRelationshipDescription *toMany = [[NSRelationshipDescription alloc] init];
    toMany.name = @"things";
    toMany.destinationEntity = item;
    toMany.maxCount = 0;
    toMany.optional = YES;
    toMany.deleteRule = NSNullifyDeleteRule;
    other.properties = @[otherName, toOne, toMany];
    m.entities = @[item, sub, other];
    return m;
}

@interface Stack : NSObject
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic) BOOL ours;
@end

@implementation Stack
@end

static int stack_counter;

static Stack *make_stack(BOOL ours)
{
    Stack *stack = [Stack new];
    stack.ours = ours;
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"batchupdate-%d-%d.sqlite", getpid(), stack_counter++]]];
    for (NSString *suffix in @[@"", @"-shm", @"-wal"])
        [[NSFileManager defaultManager] removeItemAtPath:[url.path stringByAppendingString:suffix] error:NULL];
    stack.coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
    [stack.coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:NULL];
    stack.context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    stack.context.persistentStoreCoordinator = stack.coordinator;
    for (int i = 0; i < 6; i++) {
        NSManagedObject *item = [NSEntityDescription insertNewObjectForEntityForName:i == 5 ? @"Sub" : @"Item" inManagedObjectContext:stack.context];
        [item setValue:[NSString stringWithFormat:@"%c%d", i < 3 ? 'a' : 'b', i] forKey:@"name"];
        [item setValue:@(i) forKey:@"rank"];
        [item setValue:@(i * 1.5) forKey:@"amount"];
        [item setValue:@(i % 2 == 0) forKey:@"flag"];
        [item setValue:[NSDate dateWithTimeIntervalSince1970:i * 1000] forKey:@"when"];
    }
    [stack.context save:NULL];
    return stack;
}

static NSArray *rows(Stack *stack)
{
    NSManagedObjectContext *fresh = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    fresh.persistentStoreCoordinator = stack.coordinator;
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
    fetch.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES], [NSSortDescriptor sortDescriptorWithKey:@"when" ascending:YES]];
    NSMutableArray *out = [NSMutableArray array];
    for (NSManagedObject *object in [fresh executeFetchRequest:fetch error:NULL]) {
        NSMutableString *line = [NSMutableString stringWithString:object.entity.name];
        for (NSString *key in @[@"name", @"rank", @"req", @"when", @"flag", @"amount", @"extra"])
            if (object.entity.propertiesByName[key])
                [line appendFormat:@" %@=%@", key, [object valueForKey:key] ?: @"nil"];
        [out addObject:line];
    }
    return out;
}

static NSString *normalise(NSString *text)
{
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    text = [expression stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"0x"];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    return text;
}

static NSString *guarded(void (^block)(NSString **out))
{
    NSString *result = @"";
    @try {
        block(&result);
    } @catch (NSException *exception) {
        NSMutableArray *keys = [NSMutableArray array];
        for (NSString *key in exception.userInfo)
            [keys addObject:key];
        [keys sortUsingSelector:@selector(compare:)];
        return normalise([NSString stringWithFormat:@"EXC %@: %@ %@", exception.name, exception.reason, keys]);
    }
    return normalise(result);
}

static Class request_class(Stack *stack)
{
    return NSClassFromString(stack.ours ? @"CharonHostNSBatchUpdateRequest" : @"NSBatchUpdateRequest");
}

static id named_request(Stack *stack, NSString *entityName)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(request_class(stack), @selector(batchUpdateRequestWithEntityName:), entityName);
}

static id entity_request(Stack *stack, NSString *entityName)
{
    NSEntityDescription *entity = stack.coordinator.managedObjectModel.entitiesByName[entityName];
    return ((id (*)(id, SEL, id))objc_msgSend)([request_class(stack) alloc], @selector(initWithEntity:), entity);
}

static id execute(Stack *stack, id request, NSError **error)
{
    return stack.ours ? [stack.context charonHostexecuteRequest:request error:error] : [stack.context executeRequest:request error:error];
}

static NSString *describe(id result, NSError *error, NSDictionary *idNames)
{
    if (!result)
        return [NSString stringWithFormat:@"nil %@ %ld %@", error.domain, (long)error.code, error.userInfo];
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
    return normalise([NSString stringWithFormat:@"%@ type=%lu result=%@ (%@)", NSStringFromClass([result class]), (unsigned long)[result resultType], text, [value isKindOfClass:[NSArray class]] ? @"array" : NSStringFromClass([value class])]);
}

static NSDictionary *id_names(Stack *stack)
{
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSManagedObjectContext *fresh = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    fresh.persistentStoreCoordinator = stack.coordinator;
    for (NSString *entity in @[@"Item", @"Other"])
        for (NSManagedObject *object in [fresh executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:entity] error:NULL])
            map[object.objectID.URIRepresentation.absoluteString] = [NSString stringWithFormat:@"%@/%@", object.entity.name, [object valueForKey:@"name"] ?: @"nil"];
    return map;
}

typedef void (^Setup)(Stack *stack, id request);

static void scenario(const char *name, BOOL byEntity, NSString *entityName, NSUInteger resultType, Setup setup)
{
    Stack *system = make_stack(NO), *ours = make_stack(YES);
    NSString *outputs[2];
    NSArray *tables[2];
    int index = 0;
    for (Stack *stack in @[system, ours]) {
        NSDictionary *names = id_names(stack);
        __block NSError *error = nil;
        __block NSString *answer = nil;
        outputs[index] = guarded(^(NSString **out) {
            id request = byEntity ? entity_request(stack, entityName) : named_request(stack, entityName);
            setup(stack, request);
            [request setResultType:resultType];
            id result = execute(stack, request, &error);
            answer = describe(result, error, names);
            *out = answer;
        });
        tables[index++] = rows(stack);
    }
    CHECK_EQUAL(outputs[1], outputs[0], label(@"%s answer", name));
    CHECK_EQUAL(tables[1], tables[0], label(@"%s rows", name));
}

static NSExpression *constant(id value)
{
    return [NSExpression expressionForConstantValue:value];
}

static NSExpression *keypath(NSString *path)
{
    return [NSExpression expressionForKeyPath:path];
}

static NSExpression *function(NSString *name, NSArray *arguments)
{
    return [NSExpression expressionForFunction:name arguments:arguments];
}

static void update_scenarios(void)
{
    for (int byEntity = 0; byEntity <= 1; byEntity++) {
        const char *how = byEntity ? "entity" : "name";
        for (NSUInteger type = 0; type <= 2; type++) {
            scenario(label(@"%s constant t%lu", how, (unsigned long)type), byEntity, @"Item", type, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": @"x"}]; });
            scenario(label(@"%s predicate t%lu", how, (unsigned long)type), byEntity, @"Item", type, ^(Stack *s, id r) { [r setPredicate:[NSPredicate predicateWithFormat:@"rank >= 3"]]; [r setPropertiesToUpdate:@{@"name": @"hi", @"flag": @NO}]; });
            scenario(label(@"%s no subentities t%lu", how, (unsigned long)type), byEntity, @"Item", type, ^(Stack *s, id r) { [r setIncludesSubentities:NO]; [r setPropertiesToUpdate:@{@"name": @"nosub"}]; });
            scenario(label(@"%s sub only t%lu", how, (unsigned long)type), byEntity, @"Sub", type, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"extra": @"e"}]; });
            scenario(label(@"%s no match t%lu", how, (unsigned long)type), byEntity, @"Item", type, ^(Stack *s, id r) { [r setPredicate:[NSPredicate predicateWithFormat:@"name == 'zzz'"]]; [r setPropertiesToUpdate:@{@"name": @"x"}]; });
            scenario(label(@"%s other entity t%lu", how, (unsigned long)type), byEntity, @"Other", type, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": @"x"}]; });
        }
        scenario(label(@"%s arithmetic", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"rank": function(@"add:to:", @[keypath(@"rank"), constant(@10)])}]; });
        scenario(label(@"%s multiply two", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"rank": function(@"multiply:by:", @[keypath(@"rank"), constant(@3)]), @"amount": function(@"add:to:", @[keypath(@"amount"), keypath(@"rank")])}]; });
        scenario(label(@"%s swap uses old values", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"rank": keypath(@"amount"), @"amount": keypath(@"rank")}]; });
        scenario(label(@"%s uppercase", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": function(@"uppercase:", @[keypath(@"name")])}]; });
        scenario(label(@"%s null", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": [NSNull null], @"when": [NSNull null]}]; });
        scenario(label(@"%s date and bool", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"when": [NSDate dateWithTimeIntervalSince1970:12345], @"flag": @YES}]; });
        scenario(label(@"%s several", how), byEntity, @"Item", 1, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": @"n", @"rank": @7, @"amount": @2.5, @"req": @"r"}]; });
        scenario(label(@"%s description keys", how), byEntity, @"Item", 2, ^(Stack *s, id r) {
            NSEntityDescription *entity = s.coordinator.managedObjectModel.entitiesByName[@"Item"];
            [r setPropertiesToUpdate:@{entity.propertiesByName[@"name"]: @"described"}];
        });
        scenario(label(@"%s description of another entity", how), byEntity, @"Item", 2, ^(Stack *s, id r) {
            NSEntityDescription *other = s.coordinator.managedObjectModel.entitiesByName[@"Other"];
            [r setPropertiesToUpdate:@{other.propertiesByName[@"name"]: @"borrowed"}];
        });
        scenario(label(@"%s empty", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{}]; });
        scenario(label(@"%s never set", how), byEntity, @"Item", 2, ^(Stack *s, id r) {});
        scenario(label(@"%s nil dictionary", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:nil]; });
        scenario(label(@"%s bad key", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"nope": @"x"}]; });
        scenario(label(@"%s subentity key on parent", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"extra": @"x"}]; });
        scenario(label(@"%s keypath key", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name.x": @"x"}]; });
        scenario(label(@"%s to-one key", how), byEntity, @"Other", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"owner": [NSNull null]}]; });
        scenario(label(@"%s to-many key", how), byEntity, @"Other", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"things": [NSNull null]}]; });
        scenario(label(@"%s expression description key", how), byEntity, @"Item", 2, ^(Stack *s, id r) {
            NSExpressionDescription *description = [[NSExpressionDescription alloc] init];
            description.name = @"ed";
            description.expression = constant(@1);
            description.expressionResultType = NSInteger32AttributeType;
            [r setPropertiesToUpdate:@{description: @"x"}];
        });
        scenario(label(@"%s variable value", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"rank": [NSExpression expressionForVariable:@"x"]}]; });
        scenario(label(@"%s self value", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": [NSExpression expressionForEvaluatedObject]}]; });
        scenario(label(@"%s aggregate value", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": [NSExpression expressionForAggregate:@[constant(@1)]]}]; });
        scenario(label(@"%s join keypath value", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"rank": keypath(@"owner.rank")}]; });
        scenario(label(@"%s nil for required", how), byEntity, @"Item", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"req": [NSNull null]}]; });
        scenario(label(@"%s unknown entity", how), 0, @"Nope", 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": @"x"}]; });
    }
    scenario("unknown entity with no properties", 0, @"Nope", 2, ^(Stack *s, id r) {});
    scenario("no entity name", 0, nil, 2, ^(Stack *s, id r) { [r setPropertiesToUpdate:@{@"name": @"x"}]; });
}

static void objects_are_left_alone(void)
{
    Stack *system = make_stack(NO), *ours = make_stack(YES);
    for (Stack *stack in @[system, ours]) {
        NSFetchRequest *all = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
        all.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES]];
        NSArray *objects = [stack.context executeFetchRequest:all error:NULL];
        NSManagedObject *first = objects[0];
        id request = named_request(stack, @"Item");
        [request setPropertiesToUpdate:@{@"name": @"changed"}];
        [request setResultType:1];
        NSError *error = nil;
        id result = execute(stack, request, &error);
        NSString *who = stack.ours ? @"ours" : @"system";
        CHECK_EQUAL(@([[result result] count]), @6, label(@"%@ answers the IDs of what it changed", who));
        CHECK(!stack.context.hasChanges, label(@"%@ leaves the context without changes", who));
        CHECK(!first.isUpdated && !first.isDeleted, label(@"%@ does not mark a registered object", who));
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSUpdatedObjectsKey: [result result]} intoContexts:@[stack.context]];
        CHECK_EQUAL([first valueForKey:@"name"], @"changed", label(@"%@ shows the change once the IDs are merged", who));
    }
    [system.context reset];
    [ours.context reset];
    NSManagedObject *stale = [system.context executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL][0], *fresh = [ours.context executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL][0];
    (void)stale;
    (void)fresh;
}

static void request_shape(void)
{
    Stack *system = make_stack(NO), *ours = make_stack(YES);
    NSMutableArray *answers[2] = {[NSMutableArray array], [NSMutableArray array]};
    int index = 0;
    for (Stack *stack in @[system, ours]) {
        NSMutableArray *out = answers[index++];
        id byName = named_request(stack, @"Item");
        id byEntity = entity_request(stack, @"Item");
        [out addObject:[NSString stringWithFormat:@"defaults %d %lu %lu %@ %@ %@", [byName includesSubentities], (unsigned long)[byName resultType], (unsigned long)[byName requestType], [byName predicate], [byName propertiesToUpdate], [byName entityName]]];
        [out addObject:guarded(^(NSString **s) { *s = [[byName entity] description]; })];
        [out addObject:guarded(^(NSString **s) { *s = [[byEntity entity] name]; })];
        [out addObject:[byEntity entityName]];
        [out addObject:guarded(^(NSString **s) { *s = [[[request_class(stack) alloc] init] entityName] ?: @"nil"; })];
        [out addObject:guarded(^(NSString **s) { *s = [[[request_class(stack) alloc] initWithEntityName:nil] entityName] ?: @"nil"; })];
        [byName setResultType:7];
        [out addObject:[NSString stringWithFormat:@"result type kept as %lu", (unsigned long)[byName resultType]]];
        [byName setResultType:2];
        [byName setIncludesSubentities:NO];
        [byName setPredicate:[NSPredicate predicateWithFormat:@"rank > 1"]];
        [byName setPropertiesToUpdate:@{@"name": @"x"}];
        [out addObject:[NSString stringWithFormat:@"set %d %lu %@ %@", [byName includesSubentities], (unsigned long)[byName resultType], [byName predicate], [[byName propertiesToUpdate] allKeys]]];
        [out addObject:guarded(^(NSString **s) { *s = [[[byName propertiesToUpdate] description] copy]; })];
        [byEntity setPropertiesToUpdate:@{@"name": @"x", @"rank": function(@"add:to:", @[keypath(@"rank"), constant(@1)])}];
        NSMutableArray *lines = [NSMutableArray array];
        NSDictionary *validated = [byEntity propertiesToUpdate];
        for (id key in validated)
            [lines addObject:[NSString stringWithFormat:@"%@ %@ => %@", NSStringFromClass([key class]), [key name], [validated[key] description]]];
        [lines sortUsingSelector:@selector(compare:)];
        [out addObject:[lines componentsJoinedByString:@"; "]];
        [byEntity setPropertiesToUpdate:@{@"name": @"y"}];
        [out addObject:[NSString stringWithFormat:@"replaced keeps %lu", (unsigned long)[[byEntity propertiesToUpdate] count]]];
        NSString *text = [byName description];
        [out addObject:normalise([text substringToIndex:[text rangeOfString:@"subentities = "].location + 15])];
        id copied = [byName copy];
        [out addObject:[NSString stringWithFormat:@"copy %d %d %d %lu %@ %@ %@ %@", copied == byName, [copied includesSubentities], [copied resultType] == [byName resultType], (unsigned long)[copied requestType], [[copied predicate] predicateFormat], [copied entityName], [[copied propertiesToUpdate] allKeys], normalise(NSStringFromClass([copied class]))]];
    }
    for (NSUInteger i = 0; i < answers[0].count; i++)
        CHECK_EQUAL(answers[1][i], answers[0][i], label(@"request shape %lu", (unsigned long)i));
    CHECK([NSClassFromString(@"CharonHostNSBatchUpdateRequest") superclass] == [NSPersistentStoreRequest class], "the request is a persistent store request");
    CHECK([NSClassFromString(@"CharonHostNSBatchUpdateResult") superclass] == NSClassFromString(@"CharonHostNSPersistentStoreResult"), "the result is a persistent store result");
    id ourResult = [[NSClassFromString(@"CharonHostNSBatchUpdateResult") alloc] init], systemResult = [[NSBatchUpdateResult alloc] init];
    CHECK([ourResult resultType] == [systemResult resultType] && [ourResult result] == [systemResult result], "a result made with init");
}

int main(void)
{
    @autoreleasepool {
        update_scenarios();
        objects_are_left_alone();
        request_shape();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
