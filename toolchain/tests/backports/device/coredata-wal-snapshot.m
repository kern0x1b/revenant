#include <Foundation/Foundation.h>
#include <CoreData/CoreData.h>

static void report(NSString *name, BOOL held)
{
    printf("%s: %s\n", [name UTF8String], held ? "the read stayed on its snapshot" : "the read saw the write");
    fflush(stdout);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("release: %s\n", [[[UIDevice currentDevice] systemVersion] UTF8String]);
    fflush(stdout);

    NSURL *storeURL = [NSURL fileURLWithPath:@"/tmp/coredata-wal-probe.sqlite"];
    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:@"/tmp/coredata-wal-probe.sqlite-wal"] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:@"/tmp/coredata-wal-probe.sqlite-shm"] error:nil];

    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = @"Row";
    entity.managedObjectClassName = @"NSManagedObject";
    NSAttributeDescription *count = [[NSAttributeDescription alloc] init];
    count.name = @"count";
    count.attributeType = NSInteger32AttributeType;
    entity.properties = @[count];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
    model.entities = @[entity];

    NSError *error = nil;
    NSPersistentStoreCoordinator *coordinator =
        [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSDictionary *pragmas = @{@"journal_mode": @"WAL"};
    NSDictionary *options = @{NSSQLitePragmasOption: pragmas};
    NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:nil
                                                                 URL:storeURL
                                                             options:options
                                                               error:&error];
    if (!store) {
        printf("the store would not open: %s\n", [error.localizedDescription UTF8String]);
        printf("verdict: neither - the release refused the store, so the question is unmeasured\n");
        return 0;
    }
    printf("the store is open on a write-ahead log\n");
    fflush(stdout);

    NSManagedObjectContext *writer = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    writer.persistentStoreCoordinator = coordinator;
    for (int index = 0; index < 3; index++) {
        NSManagedObject *row = [NSEntityDescription insertNewObjectForEntityForName:@"Row" inManagedObjectContext:writer];
        [row setValue:@(index) forKey:@"count"];
    }
    if (![writer save:&error]) {
        printf("the first save failed: %s\n", [error.localizedDescription UTF8String]);
        printf("verdict: neither - the write did not go in\n");
        return 0;
    }
    printf("the first context wrote three rows\n");
    fflush(stdout);

    NSManagedObjectContext *reader = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    reader.persistentStoreCoordinator = coordinator;
    NSFetchRequest *before = [NSFetchRequest fetchRequestWithEntityName:@"Row"];
    before.fetchLimit = 1;
    NSError *beginError = nil;
    [reader beginReadWithError:&beginError];
    NSUInteger seen = [reader countForFetchRequest:before error:&error];
    if (error) {
        printf("the reader could not count: %s\n", [error.localizedDescription UTF8String]);
        printf("verdict: neither - the read transaction could not be begun\n");
        return 0;
    }
    printf("the second context is reading inside a read transaction and sees %lu rows\n", (unsigned long)seen);
    fflush(stdout);

    NSManagedObjectContext *second = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    second.persistentStoreCoordinator = coordinator;
    NSManagedObject *row = [NSEntityDescription insertNewObjectForEntityForName:@"Row" inManagedObjectContext:second];
    [row setValue:@(99) forKey:@"count"];
    if (![second save:&error]) {
        printf("the second write failed: %s\n", [error.localizedDescription UTF8String]);
    } else {
        printf("a fourth row was written while the read transaction was open\n");
    }
    fflush(stdout);

    NSUInteger after = [reader countForFetchRequest:before error:&error];
    [reader endRead];
    if (error) {
        printf("the reader could not count again: %s\n", [error.localizedDescription UTF8String]);
        printf("verdict: neither - the second read failed\n");
        return 0;
    }
    printf("the same read transaction now counts %lu rows\n", (unsigned long)after);
    BOOL held = after == seen;
    report(@"verdict", held);
    printf("%s\n", held ? "the release holds a snapshot across a write on a write-ahead log"
                         : "the release does not hold a snapshot, and a pinned context reads the latest rows");
    return 0;
}
