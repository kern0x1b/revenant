#import <CoreData/CoreData.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"

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
    m.entities = @[item];
    return m;
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@", exception.name];
    }
    return @"ok";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        CHECK_EQUAL(image_of((void *)method_getImplementation(class_getClassMethod([NSManagedObjectContext class], @selector(mergeChangesFromRemoteContextSave:intoContexts:)))), @"libCoreDataBackports.dylib", "the method comes from the backports");
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"coredata9merge-%d.sqlite", getpid()]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model()];
        [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:path] options:nil error:NULL];
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        context.persistentStoreCoordinator = coordinator;
        NSManagedObjectContext *other = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        other.persistentStoreCoordinator = coordinator;
        for (int i = 0; i < 4; i++) {
            NSManagedObject *item = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
            [item setValue:[NSString stringWithFormat:@"n%d", i] forKey:@"name"];
            [item setValue:@(i) forKey:@"rank"];
        }
        [context save:NULL];
        NSFetchRequest *all = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
        all.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES]];
        NSArray *objects = [context executeFetchRequest:all error:NULL];
        NSManagedObject *o0 = objects[0], *o1 = objects[1], *o2 = objects[2], *o3 = objects[3];
        for (NSManagedObject *object in objects)
            (void)[object valueForKey:@"name"];
        NSMutableArray *notifications = [NSMutableArray array];
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:context queue:nil usingBlock:^(NSNotification *n) {
            [notifications addObject:[[n.userInfo allKeys] sortedArrayUsingSelector:@selector(compare:)]];
        }];
        [other performBlockAndWait:^{
            NSBatchUpdateRequest *update = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Item"];
            update.propertiesToUpdate = @{@"name": @"changed"};
            [other executeRequest:update error:NULL];
        }];
        [o1 setValue:@"local" forKey:@"name"];
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSUpdatedObjectsKey: @[o0.objectID, o1.objectID, o2.objectID]} intoContexts:@[context]];
        CHECK_EQUAL([o0 valueForKey:@"name"], @"changed", "an updated object shows the new value");
        CHECK_EQUAL([o2 valueForKey:@"name"], @"changed", "so does another");
        CHECK_EQUAL([o1 valueForKey:@"name"], @"local", "a local edit is kept");
        CHECK(o1.hasChanges, "and is still a change");
        CHECK_EQUAL([o3 valueForKey:@"name"], @"n3", "an object not named is left as it was");
        CHECK(notifications.count == 1, "one change notification");
        CHECK([notifications[0] containsObject:@"updated"] && [notifications[0] containsObject:@"refreshed"], "with the updated and refreshed objects");
        [notifications removeAllObjects];
        [other performBlockAndWait:^{
            NSBatchUpdateRequest *update = [NSBatchUpdateRequest batchUpdateRequestWithEntityName:@"Item"];
            update.propertiesToUpdate = @{@"rank": @55};
            update.predicate = [NSPredicate predicateWithFormat:@"rank == 3"];
            [other executeRequest:update error:NULL];
        }];
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSUpdatedObjectsKey: @[o3.objectID.URIRepresentation]} intoContexts:@[context]];
        CHECK_EQUAL([o3 valueForKey:@"rank"], @55, "a URL names an object as its ID does");
        [notifications removeAllObjects];
        [other performBlockAndWait:^{
            NSFetchRequest *doomed = [NSFetchRequest fetchRequestWithEntityName:@"Item"];
            doomed.predicate = [NSPredicate predicateWithFormat:@"rank == 55"];
            [other executeRequest:[[NSBatchDeleteRequest alloc] initWithFetchRequest:doomed] error:NULL];
        }];
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSDeletedObjectsKey: @[o3.objectID]} intoContexts:@[context]];
        CHECK(o3.isDeleted, "a deleted object is marked deleted");
        CHECK(notifications.count == 1 && [notifications[0] containsObject:@"deleted"], "with a deleted key");
        [notifications removeAllObjects];
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{} intoContexts:@[context]];
        CHECK(notifications.count == 0, "an empty dictionary changes nothing");
        CHECK_EQUAL(raised(^{ [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSUpdatedObjectsKey: @[o0.objectID]} intoContexts:@[]]; }), @"ok", "no contexts is fine");
        CHECK_EQUAL(raised(^{ [NSManagedObjectContext mergeChangesFromRemoteContextSave:nil intoContexts:@[context]]; }), @"ok", "a nil dictionary is fine");
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
