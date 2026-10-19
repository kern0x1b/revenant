#import <CoreData/CoreData.h>
#include <dlfcn.h>
#import "check.h"

@interface CharonItem : NSManagedObject
@end

@implementation CharonItem
@end

@interface CharonStray : NSManagedObject
@end

@implementation CharonStray
@end

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static NSManagedObjectModel *model_named(NSString *entityName)
{
    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = entityName;
    entity.managedObjectClassName = @"CharonItem";
    NSAttributeDescription *title = [[NSAttributeDescription alloc] init];
    title.name = @"title";
    title.attributeType = NSStringAttributeType;
    title.optional = YES;
    entity.properties = @[title];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
    model.entities = @[entity];
    return model;
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of((__bridge const void *)[NSPersistentContainer class]), @"libCoreDataBackports.dylib",
                    "NSPersistentContainer comes from the backports library");
        CHECK_EQUAL(image_of((const void *)[NSFetchRequest instanceMethodForSelector:@selector(execute:)]),
                    @"libCoreDataBackports.dylib", "and -execute: of a fetch request");
        CHECK(NSClassFromString(@"NSQueryGenerationToken") == Nil
              && ![NSManagedObjectContext instancesRespondToSelector:NSSelectorFromString(@"queryGenerationToken")],
              "query generations, which the store of iOS 6 cannot keep, are not there");

        NSPersistentStoreDescription *plain = [[NSPersistentStoreDescription alloc] init];
        CHECK([plain.URL.path isEqual:@"/dev/null"] && [plain.type isEqual:NSSQLiteStoreType] && !plain.readOnly
              && plain.timeout == 240 && plain.shouldMigrateStoreAutomatically && plain.shouldInferMappingModelAutomatically
              && !plain.shouldAddStoreAsynchronously && plain.sqlitePragmas.count == 0,
              "a fresh description is SQLite at /dev/null, migrating and inferring, as the newest release has it");
        [plain setValue:@"DELETE" forPragmaNamed:@"journal_mode"];
        plain.readOnly = YES;
        NSDictionary *pragmas = (NSDictionary *)plain.options[NSSQLitePragmasOption];
        CHECK([pragmas[@"journal_mode"] isEqual:@"DELETE"] && [(NSNumber *)plain.options[NSReadOnlyPersistentStoreOption] boolValue],
              "and its properties are the options it hands the coordinator");
        NSPersistentStoreDescription *copied = [plain copy];
        CHECK(copied != plain && [copied isEqual:plain] && copied.hash == plain.hash, "a copy is equal, not the same");

        CHECK_EQUAL(raised(^{ (void)[[NSPersistentContainer alloc] init]; }),
                    @"NSGenericException: Failed to call designated initializer on 'NSPersistentContainer' \n",
                    "a container made with -init raises");
        NSPersistentContainer *nameless = [NSPersistentContainer persistentContainerWithName:@"NoSuchModel"];
        CHECK(nameless.managedObjectModel && nameless.managedObjectModel.entities.count == 0,
              "a model that is not found leaves an empty one, not none");
        NSString *support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
        CHECK_EQUAL([[NSPersistentContainer.defaultDirectoryURL path] stringByStandardizingPath], [support stringByStandardizingPath],
                    "the default folder is Application Support");
        BOOL folder = NO;
        CHECK([[NSFileManager defaultManager] fileExistsAtPath:support isDirectory:&folder] && folder, "and it is made if it is not there");

        NSPersistentContainer *container = [NSPersistentContainer persistentContainerWithName:@"Charon" managedObjectModel:model_named(@"Item")];
        CHECK([[[container.persistentStoreDescriptions.firstObject URL] lastPathComponent] isEqual:@"Charon.sqlite"],
              "a container stores its data under its name, beside the others");
        CHECK(container.viewContext.concurrencyType == NSMainQueueConcurrencyType
              && container.viewContext.persistentStoreCoordinator == container.persistentStoreCoordinator
              && !container.viewContext.automaticallyMergesChangesFromParent, "its view context works on the main queue");

        NSString *folderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-coredata"];
        [[NSFileManager defaultManager] removeItemAtPath:folderPath error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:NULL];
        container.persistentStoreDescriptions = @[[NSPersistentStoreDescription persistentStoreDescriptionWithURL:
                                                      [NSURL fileURLWithPath:[folderPath stringByAppendingPathComponent:@"Charon.sqlite"]]]];
        __block NSInteger loads = 0;
        __block NSError *loadError = nil;
        __block BOOL loadedOnMain = NO;
        [container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *description, NSError *error) {
            loads++;
            loadError = error;
            loadedOnMain = [NSThread isMainThread];
        }];
        CHECK(loads == 1 && !loadError && loadedOnMain && container.persistentStoreCoordinator.persistentStores.count == 1,
              "the SQLite store loads at once, on the calling thread, when it is not asked to load asynchronously");

        CHECK([[CharonItem entity].name isEqual:@"Item"], "+entity finds the one entity whose class it is");
        CHECK([[CharonItem fetchRequest].entityName isEqual:@"Item"], "+fetchRequest asks for that entity by name");
        CharonItem *item = [[CharonItem alloc] initWithContext:container.viewContext];
        [item setValue:@"first" forKey:@"title"];
        CHECK(item.isInserted && [item.entity.name isEqual:@"Item"], "-initWithContext: inserts into the context");
        CHECK([raised(^{ (void)[[CharonStray alloc] initWithContext:container.viewContext]; }) hasPrefix:@"NSInvalidArgumentException"],
              "a class no entity claims is refused, as the release refuses an object with no entity");
        NSError *saveError = nil;
        CHECK([container.viewContext save:&saveError], "and the view context saves");

        NSError *outside = nil;
        CHECK([[CharonItem fetchRequest] execute:&outside] == nil && outside.code == NSCoreDataError
              && [outside.userInfo[@"message"] isEqual:@"Cannot fetch without an NSManagedObjectContext in scope"],
              "-execute: outside a context's block is refused as iOS 10 refuses it");
        __block NSUInteger inside = 0;
        [container.viewContext performBlockAndWait:^{
            inside = [[CharonItem fetchRequest] execute:NULL].count;
        }];
        CHECK(inside == 1, "and inside one it fetches in that context");
        __block BOOL nestedInner = NO, nestedOuter = NO, otherThread = YES;
        NSManagedObjectContext *nested = [container newBackgroundContext];
        [container.viewContext performBlockAndWait:^{
            [nested performBlockAndWait:^{
                nestedInner = [[CharonItem fetchRequest] execute:NULL] != nil;
            }];
            nestedOuter = [[CharonItem fetchRequest] execute:NULL] != nil;
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                otherThread = [[CharonItem fetchRequest] execute:NULL] != nil;
                dispatch_semaphore_signal(done);
            });
            dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        }];
        CHECK(nestedInner && nestedOuter && !otherThread,
              "a block inside another context's block fetches in its own, the outer one is back after it, and another thread has none");
        NSString *thrown = raised(^{
            [container.viewContext performBlockAndWait:^{
                @throw [NSException exceptionWithName:@"CharonThrown" reason:@"inside a block" userInfo:nil];
            }];
        });
        NSError *afterThrow = nil;
        CHECK([thrown hasPrefix:@"CharonThrown"] && [[CharonItem fetchRequest] execute:&afterThrow] == nil && afterThrow.code == NSCoreDataError,
              "a block that raises leaves no context in scope behind it");

        container.viewContext.automaticallyMergesChangesFromParent = YES;
        CHECK(container.viewContext.automaticallyMergesChangesFromParent, "the view context can merge automatically");
        __block BOOL backgroundOnMain = YES, backgroundSaved = NO;
        [container performBackgroundTask:^(NSManagedObjectContext *background) {
            backgroundOnMain = [NSThread isMainThread];
            CharonItem *second = [[CharonItem alloc] initWithContext:background];
            [second setValue:@"second" forKey:@"title"];
            backgroundSaved = [background save:NULL];
        }];
        CHECK(wait_until(^{ return backgroundSaved; }, 10) && !backgroundOnMain, "a background task runs off the main thread and saves");
        __block NSUInteger merged = 0;
        CHECK(wait_until(^{
                  [container.viewContext performBlockAndWait:^{
                      merged = [container.viewContext countForFetchRequest:[CharonItem fetchRequest] error:NULL];
                  }];
                  return (BOOL)(merged == 2);
              }, 10), "and the view context sees what it saved");
        NSManagedObjectContext *background = [container newBackgroundContext];
        CHECK(background.concurrencyType == NSPrivateQueueConcurrencyType && background.persistentStoreCoordinator == container.persistentStoreCoordinator,
              "a new background context works on its own queue, on the same coordinator");

        CHECK_EQUAL(raised(^{
                        NSManagedObjectContext *confined = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
                        confined.automaticallyMergesChangesFromParent = YES;
                    }),
                    @"NSInvalidArgumentException: Automatic merging is not supported by contexts using NSConfinementConcurrencyType",
                    "a confined context refuses to merge automatically");
        CHECK(NSMergePolicy.errorMergePolicy == NSErrorMergePolicy && NSMergePolicy.overwriteMergePolicy == NSOverwriteMergePolicy
              && NSMergePolicy.mergeByPropertyObjectTrumpMergePolicy == NSMergeByPropertyObjectTrumpMergePolicy,
              "the merge policies are the release's own");

        NSPersistentContainer *asynchronous = [NSPersistentContainer persistentContainerWithName:@"Async" managedObjectModel:model_named(@"Other")];
        NSPersistentStoreDescription *memory = [[NSPersistentStoreDescription alloc] init];
        memory.type = NSInMemoryStoreType;
        memory.shouldAddStoreAsynchronously = YES;
        asynchronous.persistentStoreDescriptions = @[memory];
        __block BOOL asyncLoaded = NO, asyncOnMain = YES;
        [asynchronous loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *description, NSError *error) {
            asyncOnMain = [NSThread isMainThread];
            asyncLoaded = error == nil;
        }];
        CHECK(wait_until(^{ return asyncLoaded; }, 10) && !asyncOnMain, "a store asked to load asynchronously loads off the main thread");
        CHECK([CharonItem entity] == nil, "once two models claim the class, +entity cannot choose and answers nil");

        [[NSFileManager defaultManager] removeItemAtPath:folderPath error:NULL];
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
