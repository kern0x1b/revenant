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
- (id)charonHostqueryGenerationToken;
- (BOOL)charonHostsetQueryGenerationFromToken:(id)token error:(NSError **)error;
@end

static NSString *plain(NSString *text)
{
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost_" withString:@"_"];
    return [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        NSString *reason = [exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
        reason = [reason stringByReplacingOccurrencesOfString:@"0x" withString:@"0x"];
        return [NSString stringWithFormat:@"%@: %@", exception.name, reason];
    }
    return @"ok";
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
    m.entities = @[item];
    return m;
}

static NSManagedObjectContext *make_context(NSPersistentStoreCoordinator *coordinator)
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.persistentStoreCoordinator = coordinator;
    return context;
}

static NSPersistentStoreCoordinator *make_coordinator(void)
{
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
    [coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL];
    return coordinator;
}

static Class token_class(BOOL ours) { return NSClassFromString(ours ? @"CharonHostNSQueryGenerationToken" : @"NSQueryGenerationToken"); }

static void tokens(void)
{
    id ours = [token_class(YES) currentQueryGenerationToken], system = [token_class(NO) currentQueryGenerationToken];
    CHECK([token_class(YES) currentQueryGenerationToken] == ours && [token_class(NO) currentQueryGenerationToken] == system, "the current token is one object");
    CHECK_EQUAL(NSStringFromClass([ours class]), @"CharonHostNSQueryGenerationToken", "the current token is of the class itself");
    CHECK_EQUAL(NSStringFromClass([system class]), @"_NSQueryGenerationToken", "where iOS 12 makes it of a private subclass");
    CHECK_EQUAL([ours description], [system description], "the description");
    CHECK([ours copy] == ours && [system copy] == system && [ours isEqual:[token_class(YES) currentQueryGenerationToken]] && [ours hash] == [[token_class(YES) currentQueryGenerationToken] hash], "copy, equality and hash");
    CHECK([[token_class(YES) class] supportsSecureCoding] == [[token_class(NO) class] supportsSecureCoding], "secure coding");
    NSMutableArray *rows = [NSMutableArray array];
    for (int i = 0; i < 2; i++) {
        BOOL isOurs = i == 1;
        id token = [token_class(isOurs) currentQueryGenerationToken];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
        [archiver encodeObject:token forKey:@"root"];
        [archiver finishEncoding];
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archiver.encodedData options:0 format:NULL error:NULL];
        NSMutableArray *keys = [NSMutableArray array];
        for (id object in plist[@"$objects"])
            if ([object isKindOfClass:[NSDictionary class]] && [object objectForKey:@"NSQueryTokenIsSingleton"])
                [keys addObject:[NSString stringWithFormat:@"%@ %@", [[[object allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF BEGINSWITH '$'"]] sortedArrayUsingSelector:@selector(compare:)], [object objectForKey:@"NSQueryTokenWhichSingleton"]]];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
        unarchiver.requiresSecureCoding = YES;
        id back = [unarchiver decodeObjectOfClass:token_class(isOurs) forKey:@"root"];
        [keys addObject:[NSString stringWithFormat:@"round trip %d", back == token]];
        [rows addObject:keys];
    }
    CHECK_EQUAL(rows[1], rows[0], "the archive of the current token");
}

static NSString *unpin_row(BOOL ours, NSPersistentStoreCoordinator *coordinator, NSPersistentStoreCoordinator *other)
{
    NSMutableArray *out = [NSMutableArray array];
    NSManagedObjectContext *a = make_context(coordinator), *b = make_context(other), *none = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    id current = [token_class(ours) currentQueryGenerationToken];
    id (^get)(NSManagedObjectContext *) = ^id(NSManagedObjectContext *c) { return ours ? [c charonHostqueryGenerationToken] : [c queryGenerationToken]; };
    BOOL (^set)(NSManagedObjectContext *, id, NSError **) = ^BOOL(NSManagedObjectContext *c, id t, NSError **e) { return ours ? [c charonHostsetQueryGenerationFromToken:t error:e] : [c setQueryGenerationFromToken:t error:e]; };
    [out addObject:[NSString stringWithFormat:@"initial %d", get(a) == nil]];
    NSError *error = nil;
    [out addObject:[NSString stringWithFormat:@"nil %d %@", set(a, nil, &error), error]];
    error = nil;
    [out addObject:[NSString stringWithFormat:@"current %d %@", set(a, current, &error), error]];
    [out addObject:[NSString stringWithFormat:@"after %d %@", get(a) == current, plain([get(a) description])]];
    error = nil;
    [out addObject:[NSString stringWithFormat:@"other coordinator %d %@", set(b, get(a), &error), error]];
    error = nil;
    [out addObject:[NSString stringWithFormat:@"unpin %d %d", set(a, nil, &error), get(a) == nil]];
    error = nil;
    BOOL ok = set(none, current, &error);
    [out addObject:[NSString stringWithFormat:@"no coordinator current %d %@ %@ %ld %@", ok, error.domain, error.userInfo, (long)error.code, error.localizedDescription]];
    error = nil;
    ok = set(none, nil, &error);
    [out addObject:[NSString stringWithFormat:@"no coordinator nil %d %ld", ok, (long)error.code]];
    id abstract = [[token_class(ours) alloc] init];
    [out addObject:plain(raised(^{ NSError *e = nil; set(a, abstract, &e); }))];
    [out addObject:[NSString stringWithFormat:@"abstract copy %d", [abstract copy] == abstract]];
    return [out componentsJoinedByString:@"\n"];
}

static void contexts(void)
{
    NSString *system = unpin_row(NO, make_coordinator(), make_coordinator());
    NSString *ours = unpin_row(YES, make_coordinator(), make_coordinator());
    NSString *systemNormal = [system stringByReplacingOccurrencesOfString:@"0x" withString:@"0x"];
    NSMutableArray *a = [[ours componentsSeparatedByString:@"\n"] mutableCopy], *b = [[systemNormal componentsSeparatedByString:@"\n"] mutableCopy];
    for (NSUInteger i = 0; i < MAX(a.count, b.count); i++) {
        NSString *x = i < a.count ? a[i] : @"", *y = i < b.count ? b[i] : @"";
        x = [x stringByReplacingOccurrencesOfString:@"[0-9a-fx]+" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, x.length)];
        y = [y stringByReplacingOccurrencesOfString:@"[0-9a-fx]+" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, y.length)];
        CHECK_EQUAL(x, y, label(@"query generation row %lu", (unsigned long)i));
    }
}

static void isolation(void)
{
    NSPersistentStoreCoordinator *coordinator = make_coordinator();
    NSManagedObjectContext *a = make_context(coordinator), *b = make_context(coordinator);
    NSManagedObject *first = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:b];
    [first setValue:@"x" forKey:@"name"];
    [b save:NULL];
    [a setQueryGenerationFromToken:[NSQueryGenerationToken currentQueryGenerationToken] error:NULL];
    NSManagedObject *second = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:b];
    [second setValue:@"y" forKey:@"name"];
    [b save:NULL];
    CHECK([a countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL] == 2, "an in-memory store gives a pinned context the latest rows");
}

static id make_conflict(BOOL ours, NSArray *constraint, NSManagedObject *database, NSDictionary *snapshot, NSArray *conflicting, NSArray *snapshots)
{
    Class cls = NSClassFromString(ours ? @"CharonHostNSConstraintConflict" : @"NSConstraintConflict");
    return ((id (*)(id, SEL, id, id, id, id, id))objc_msgSend)([cls alloc], @selector(initWithConstraint:databaseObject:databaseSnapshot:conflictingObjects:conflictingSnapshots:), constraint, database, snapshot, conflicting, snapshots);
}

static NSString *conflict_row(id conflict)
{
    NSMutableString *description = [[conflict description] mutableCopy];
    [description replaceOccurrencesOfString:@"0x[0-9a-f]+" withString:@"0xADDR" options:NSRegularExpressionSearch range:NSMakeRange(0, description.length)];
    [description replaceOccurrencesOfString:@"/t[0-9A-F-]+[0-9]" withString:@"/tID" options:NSRegularExpressionSearch range:NSMakeRange(0, description.length)];
    [description replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, description.length)];
    return [NSString stringWithFormat:@"%@ | %@ | %@ | %d | %@ | %lu %lu | %@", [conflict constraint], [conflict constraintValues], [conflict databaseSnapshot], [conflict databaseObject] != nil, [conflict conflictingSnapshots], (unsigned long)[[conflict conflictingObjects] count], (unsigned long)[[conflict conflictingSnapshots] count], description];
}

static void conflicts(void)
{
    NSPersistentStoreCoordinator *coordinator = make_coordinator();
    NSManagedObjectContext *context = make_context(coordinator);
    NSManagedObject *database = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
    [database setValue:@"a" forKey:@"name"];
    [database setValue:@1 forKey:@"rank"];
    NSManagedObject *conflicting = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
    [conflicting setValue:@"a" forKey:@"name"];
    NSManagedObject *third = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
    [third setValue:@"a" forKey:@"name"];
    [third setValue:@7 forKey:@"rank"];
    NSArray *cases = @[
        @[@[@"name", @"rank"], database, @{@"name": @"a"}, @[conflicting], @[@{@"name": @"a"}]],
        @[@[@"name"], [NSNull null], [NSNull null], @[database, conflicting], [NSNull null]],
        @[@[@"name", @"rank"], [NSNull null], [NSNull null], @[conflicting, third], @[@{@"n": @1}, @{@"n": @2}]],
        @[[NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null]],
        @[@[], database, [NSNull null], @[conflicting], [NSNull null]],
    ];
    for (NSUInteger i = 0; i < cases.count; i++) {
        NSArray *c = cases[i];
        id (^value)(NSUInteger) = ^id(NSUInteger k) { return c[k] == [NSNull null] ? nil : c[k]; };
        id ours = make_conflict(YES, value(0), value(1), value(2), value(3), value(4)), system = make_conflict(NO, value(0), value(1), value(2), value(3), value(4));
        CHECK_EQUAL(conflict_row(ours), conflict_row(system), label(@"conflict case %lu", (unsigned long)i));
    }
    CHECK_EQUAL(raised(^{ make_conflict(YES, @[@"zzz"], database, nil, @[conflicting], nil); }), raised(^{ make_conflict(NO, @[@"zzz"], database, nil, @[conflicting], nil); }), "a key the object does not have");
    NSMutableArray *held = [NSMutableArray arrayWithObject:conflicting];
    id ours = make_conflict(YES, @[@"name"], database, nil, held, nil);
    [held addObject:third];
    CHECK([[ours conflictingObjects] count] == 1, "the conflicting objects are copied");
    CHECK([(id)[NSClassFromString(@"CharonHostNSConstraintConflict") class] supportsSecureCoding] == [(id)[NSConstraintConflict class] supportsSecureCoding], "secure coding");
    CHECK([raised(^{ [ours encodeWithCoder:[[NSKeyedArchiver alloc] initRequiringSecureCoding:YES]]; }) hasPrefix:@"NSInvalidArgumentException: CoreData does not support encoding of conflict objects."], "a conflict cannot be encoded");
}

int main(void)
{
    @autoreleasepool {
        tokens();
        contexts();
        isolation();
        conflicts();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
