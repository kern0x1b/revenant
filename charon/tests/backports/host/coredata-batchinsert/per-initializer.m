// What EACH initialiser and constructor does, measured on whichever NSBatchInsertRequest this
// binary has - the framework's own, or the port's. Every call is inside @try/@catch with VALID
// arguments, and every one prints the same line, so the two runs are comparable line for line and
// the diff between them is the finding.
//
//   xcrun clang -fobjc-arc -framework Foundation -framework CoreData per-initializer.m            # host
//   xcrun clang -fobjc-arc -framework Foundation -framework CoreData per-initializer.m <port.o>   # port
//
// Nothing is persisted: the store below is NSInMemoryStoreType and no store is even opened unless
// a line needs one. There is no CloudKit here.
//
// CONTROLS, and they are stated so a pass cannot be a pass for the wrong reason:
//   - alloc/init is KNOWN to raise on the host, with the reason '-init results in undefined
//     behavior for NSBatchInsertRequest'. If it does not, the measurement is wrong.
//   - a call with valid arguments that returns non-nil on the host must return non-nil here; the
//     listing prints it, so a port that answers nil where the host answers a request is red.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

static void report(const char *selector, id answer, NSException *raised, const char *reason)
{
    printf("%s\traised=%d\tanswer=%s\treason=%s\n",
           selector, raised != nil, answer ? (raised ? "-" : "non-nil") : "nil",
           reason ? reason : "-");
}

static NSArray<NSDictionary<NSString *, id> *> *rows(void)
{
    return @[@{@"name": @"one"}, @{@"name": @"two"}];
}

int main(void) { @autoreleasepool {
    // The entity and the two handlers, built ONCE and valid, so no line fails for a missing
    // argument instead of for the thing being measured.
    NSEntityDescription *entity = [NSEntityDescription new];
    entity.name = @"Row";
    entity.managedObjectClassName = @"NSManagedObject";
    BOOL (^dictionaryHandler)(NSMutableDictionary<NSString *, id> *) =
        ^BOOL(NSMutableDictionary<NSString *, id> *obj) { return YES; };
    BOOL (^managedObjectHandler)(NSManagedObject *) = ^BOOL(NSManagedObject *obj) { return YES; };

    // - init. The control: known to raise on the host.
    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] init];
        report("init", a, nil, "-");
        printf("init.detail\tentityName=%s\tentity=%s\tobjects=%lu\tresultType=%ld\n",
               a.entityName ? a.entityName.UTF8String : "-",
               a.entity ? a.entity.name.UTF8String : "-",
               (unsigned long)a.objectsToInsert.count, (long)a.resultType);
    } @catch (NSException *e) {
        report("init", nil, e, e.reason.UTF8String);
    }

    // - initWithEntityName:objects:
    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntityName:@"Row" objects:rows()];
        report("initWithEntityName:objects:", a, nil, "-");
        printf("initWithEntityName:objects:.detail\tentityName=%s\tobjects=%lu\tresultType=%ld\n",
               a.entityName ? a.entityName.UTF8String : "-",
               (unsigned long)a.objectsToInsert.count, (long)a.resultType);
    } @catch (NSException *e) {
        report("initWithEntityName:objects:", nil, e, e.reason.UTF8String);
    }

    // - initWithEntity:objects:
    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntity:entity objects:rows()];
        report("initWithEntity:objects:", a, nil, "-");
        printf("initWithEntity:objects:.detail\tentityName=%s\tentity=%s\tobjects=%lu\tresultType=%ld\n",
               a.entityName ? a.entityName.UTF8String : "-",
               a.entity ? a.entity.name.UTF8String : "-",
               (unsigned long)a.objectsToInsert.count, (long)a.resultType);
    } @catch (NSException *e) {
        report("initWithEntity:objects:", nil, e, e.reason.UTF8String);
    }

    // - initWithEntityName:dictionaryHandler:
    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntityName:@"Row" dictionaryHandler:dictionaryHandler];
        report("initWithEntityName:dictionaryHandler:", a, nil, "-");
        printf("initWithEntityName:dictionaryHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.dictionaryHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntityName:dictionaryHandler:", nil, e, e.reason.UTF8String);
    }

    // - initWithEntityName:managedObjectHandler:
    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntityName:@"Row" managedObjectHandler:managedObjectHandler];
        report("initWithEntityName:managedObjectHandler:", a, nil, "-");
        printf("initWithEntityName:managedObjectHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntityName:managedObjectHandler:", nil, e, e.reason.UTF8String);
    }

    // - initWithEntity:dictionaryHandler:
    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntity:entity dictionaryHandler:dictionaryHandler];
        report("initWithEntity:dictionaryHandler:", a, nil, "-");
        // BOTH handler ivars, because the defect was that a request built here had BOTH set and
        // nothing said so: one key would not have seen it.
        printf("initWithEntity:dictionaryHandler:.detail\tentity=%s\tdictionaryHandler=%s\tmanagedObjectHandler=%s\n",
               a.entity ? a.entity.name.UTF8String : "-",
               a.dictionaryHandler ? "set" : "unset", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntity:dictionaryHandler:", nil, e, e.reason.UTF8String);
    }

    // - initWithEntity:managedObjectHandler:
    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntity:entity managedObjectHandler:managedObjectHandler];
        report("initWithEntity:managedObjectHandler:", a, nil, "-");
        // BOTH handler ivars, because the defect was that a request built here had BOTH set and
        // nothing said so: one key would not have seen it.
        printf("initWithEntity:managedObjectHandler:.detail\tentity=%s\tdictionaryHandler=%s\tmanagedObjectHandler=%s\n",
               a.entity ? a.entity.name.UTF8String : "-",
               a.dictionaryHandler ? "set" : "unset", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntity:managedObjectHandler:", nil, e, e.reason.UTF8String);
    }

    // + batchInsertRequestWithEntityName:objects:
    @try {
        NSBatchInsertRequest *a = [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row" objects:rows()];
        report("+batchInsertRequestWithEntityName:objects:", a, nil, "-");
        printf("+batchInsertRequestWithEntityName:objects:.detail\tentityName=%s\tobjects=%lu\n",
               a.entityName ? a.entityName.UTF8String : "-", (unsigned long)a.objectsToInsert.count);
    } @catch (NSException *e) {
        report("+batchInsertRequestWithEntityName:objects:", nil, e, e.reason.UTF8String);
    }

    // + batchInsertRequestWithEntityName:dictionaryHandler:
    @try {
        NSBatchInsertRequest *a = [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row" dictionaryHandler:dictionaryHandler];
        report("+batchInsertRequestWithEntityName:dictionaryHandler:", a, nil, "-");
        printf("+batchInsertRequestWithEntityName:dictionaryHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.dictionaryHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("+batchInsertRequestWithEntityName:dictionaryHandler:", nil, e, e.reason.UTF8String);
    }

    // + batchInsertRequestWithEntityName:managedObjectHandler:
    @try {
        NSBatchInsertRequest *a = [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row"
                                                                        managedObjectHandler:managedObjectHandler];
        report("+batchInsertRequestWithEntityName:managedObjectHandler:", a, nil, "-");
        printf("+batchInsertRequestWithEntityName:managedObjectHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("+batchInsertRequestWithEntityName:managedObjectHandler:", nil, e, e.reason.UTF8String);
    }

    // The result type, which is a property and not a construction: the count and the two values.
    printf("enum.count\t%ld\n", (long)NSBatchInsertRequestResultTypeCount);
    printf("enum.StatusOnly\t%ld\n", (long)NSBatchInsertRequestResultTypeStatusOnly);
    printf("enum.ObjectIDs\t%ld\n", (long)NSBatchInsertRequestResultTypeObjectIDs);
    return 0;
} }
