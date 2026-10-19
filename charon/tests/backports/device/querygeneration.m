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

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
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

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        NSQueryGenerationToken *current = [NSQueryGenerationToken currentQueryGenerationToken];
        CHECK_EQUAL(image_of((__bridge void *)[NSQueryGenerationToken class]), @"libCoreDataBackports.dylib", "the token comes from the backports");
        CHECK_EQUAL(image_of((__bridge void *)[NSConstraintConflict class]), @"libCoreDataBackports.dylib", "the conflict comes from the backports");
        CHECK(current == [NSQueryGenerationToken currentQueryGenerationToken] && [current copy] == current && [current isEqual:current], "the current token is one object");
        CHECK_EQUAL(current.description, @"<NSQueryGenerationToken : (null)/current>", "and this description");
        CHECK([NSQueryGenerationToken supportsSecureCoding], "it codes securely");
        NSMutableData *data = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeObject:current forKey:@"root"];
        [archiver finishEncoding];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        CHECK([unarchiver decodeObjectForKey:@"root"] == current, "and comes back as itself");

        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"querygeneration-%d.sqlite", getpid()]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        NSError *error = nil;
        CHECK([coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:nil error:&error] != nil, "a store");
        NSManagedObjectContext *a = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType], *b = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        a.persistentStoreCoordinator = coordinator;
        b.persistentStoreCoordinator = coordinator;
        CHECK(a.queryGenerationToken == nil, "a context is not pinned to begin with");
        error = nil;
        CHECK([a setQueryGenerationFromToken:nil error:&error] && error == nil && a.queryGenerationToken == nil, "unpinning an unpinned context is taken");
        CHECK([a setQueryGenerationFromToken:current error:&error] && error == nil, "the current token is taken");
        CHECK(a.queryGenerationToken == current, "and is what the context answers");
        NSManagedObject *first = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:b];
        [first setValue:@"x" forKey:@"name"];
        [b save:NULL];
        NSUInteger seen = [a countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL];
        NSManagedObject *second = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:b];
        [second setValue:@"y" forKey:@"name"];
        [b save:NULL];
        CHECK(seen == 1 && [a countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Item"] error:NULL] == 2, "the pinned context reads the latest rows: nothing isolates it");
        CHECK([a setQueryGenerationFromToken:nil error:&error] && a.queryGenerationToken == nil, "nil unpins");
        NSManagedObjectContext *none = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        error = nil;
        CHECK(![none setQueryGenerationFromToken:current error:&error] && [error.domain isEqual:NSCocoaErrorDomain] && error.code == 134060 && [error.userInfo[@"reason"] isEqual:@"Cannot set a query generation on an NSManagedObjectContext that does not have a coordinator"], "a context with no coordinator answers NO and the error");
        error = nil;
        CHECK(![none setQueryGenerationFromToken:nil error:&error] && error.code == 134060, "nil is refused as well");
        NSPersistentStoreCoordinator *other = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
        [other addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:NULL];
        NSManagedObjectContext *c = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        c.persistentStoreCoordinator = other;
        [a setQueryGenerationFromToken:current error:NULL];
        CHECK([c setQueryGenerationFromToken:a.queryGenerationToken error:&error], "a token of another coordinator is taken");
        NSQueryGenerationToken *abstract = [[NSQueryGenerationToken alloc] init];
        CHECK_EQUAL(raised(^{ NSError *e = nil; [a setQueryGenerationFromToken:abstract error:&e]; }).length > 0 ? @"raises" : @"none", @"raises", "a token that is not the current one is refused");
        CHECK([abstract copy] == abstract, "and copies to itself");

        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        context.persistentStoreCoordinator = other;
        NSManagedObject *database = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
        [database setValue:@"a" forKey:@"name"];
        [database setValue:@1 forKey:@"rank"];
        NSManagedObject *conflicting = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
        [conflicting setValue:@"a" forKey:@"name"];
        NSConstraintConflict *conflict = [[NSConstraintConflict alloc] initWithConstraint:@[@"name", @"rank"] databaseObject:database databaseSnapshot:@{@"name": @"a"} conflictingObjects:@[conflicting] conflictingSnapshots:@[@{@"name": @"a"}]];
        CHECK_EQUAL([conflict.constraint description], @"(\n    name,\n    rank\n)", "the conflict keeps its constraint");
        CHECK([conflict.constraintValues[@"name"] isEqual:@"a"] && [conflict.constraintValues[@"rank"] isEqual:[NSNull null]], "the values come from the last conflicting object");
        CHECK(conflict.databaseObject == database && conflict.conflictingObjects.count == 1 && conflict.conflictingSnapshots.count == 1 && [conflict.databaseSnapshot[@"name"] isEqual:@"a"], "and the rest");
        CHECK([conflict.description hasPrefix:@"NSConstraintConflict (0x"] && [conflict.description rangeOfString:@"for constraint (\n    name,\n    rank\n): database: 0x"].location != NSNotFound && [conflict.description rangeOfString:@"conflictedObjects: ("].location != NSNotFound, "the description");
        NSString *encoding = raised(^{ [(id)conflict encodeWithCoder:[[NSKeyedArchiver alloc] initForWritingWithMutableData:[NSMutableData data]]]; });
        CHECK([encoding hasPrefix:@"NSInvalidArgumentException: CoreData does not support encoding of conflict objects."], "a conflict is not encoded");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
