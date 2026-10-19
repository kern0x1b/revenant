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
    NSEntityDescription *entity = [NSEntityDescription new];
    entity.name = @"Row";
    entity.managedObjectClassName = @"NSManagedObject";
    BOOL (^dictionaryHandler)(NSMutableDictionary<NSString *, id> *) =
        ^BOOL(NSMutableDictionary<NSString *, id> *obj) { return YES; };
    BOOL (^managedObjectHandler)(NSManagedObject *) = ^BOOL(NSManagedObject *obj) { return YES; };

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

    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntityName:@"Row" objects:rows()];
        report("initWithEntityName:objects:", a, nil, "-");
        printf("initWithEntityName:objects:.detail\tentityName=%s\tobjects=%lu\tresultType=%ld\n",
               a.entityName ? a.entityName.UTF8String : "-",
               (unsigned long)a.objectsToInsert.count, (long)a.resultType);
    } @catch (NSException *e) {
        report("initWithEntityName:objects:", nil, e, e.reason.UTF8String);
    }

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

    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntityName:@"Row" dictionaryHandler:dictionaryHandler];
        report("initWithEntityName:dictionaryHandler:", a, nil, "-");
        printf("initWithEntityName:dictionaryHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.dictionaryHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntityName:dictionaryHandler:", nil, e, e.reason.UTF8String);
    }

    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntityName:@"Row" managedObjectHandler:managedObjectHandler];
        report("initWithEntityName:managedObjectHandler:", a, nil, "-");
        printf("initWithEntityName:managedObjectHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntityName:managedObjectHandler:", nil, e, e.reason.UTF8String);
    }

    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntity:entity dictionaryHandler:dictionaryHandler];
        report("initWithEntity:dictionaryHandler:", a, nil, "-");
        printf("initWithEntity:dictionaryHandler:.detail\tentity=%s\tdictionaryHandler=%s\tmanagedObjectHandler=%s\n",
               a.entity ? a.entity.name.UTF8String : "-",
               a.dictionaryHandler ? "set" : "unset", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntity:dictionaryHandler:", nil, e, e.reason.UTF8String);
    }

    @try {
        NSBatchInsertRequest *a = [[NSBatchInsertRequest alloc] initWithEntity:entity managedObjectHandler:managedObjectHandler];
        report("initWithEntity:managedObjectHandler:", a, nil, "-");
        printf("initWithEntity:managedObjectHandler:.detail\tentity=%s\tdictionaryHandler=%s\tmanagedObjectHandler=%s\n",
               a.entity ? a.entity.name.UTF8String : "-",
               a.dictionaryHandler ? "set" : "unset", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("initWithEntity:managedObjectHandler:", nil, e, e.reason.UTF8String);
    }

    @try {
        NSBatchInsertRequest *a = [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row" objects:rows()];
        report("+batchInsertRequestWithEntityName:objects:", a, nil, "-");
        printf("+batchInsertRequestWithEntityName:objects:.detail\tentityName=%s\tobjects=%lu\n",
               a.entityName ? a.entityName.UTF8String : "-", (unsigned long)a.objectsToInsert.count);
    } @catch (NSException *e) {
        report("+batchInsertRequestWithEntityName:objects:", nil, e, e.reason.UTF8String);
    }

    @try {
        NSBatchInsertRequest *a = [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row" dictionaryHandler:dictionaryHandler];
        report("+batchInsertRequestWithEntityName:dictionaryHandler:", a, nil, "-");
        printf("+batchInsertRequestWithEntityName:dictionaryHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.dictionaryHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("+batchInsertRequestWithEntityName:dictionaryHandler:", nil, e, e.reason.UTF8String);
    }

    @try {
        NSBatchInsertRequest *a = [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row"
                                                                        managedObjectHandler:managedObjectHandler];
        report("+batchInsertRequestWithEntityName:managedObjectHandler:", a, nil, "-");
        printf("+batchInsertRequestWithEntityName:managedObjectHandler:.detail\tentityName=%s\thandler=%s\n",
               a.entityName ? a.entityName.UTF8String : "-", a.managedObjectHandler ? "set" : "unset");
    } @catch (NSException *e) {
        report("+batchInsertRequestWithEntityName:managedObjectHandler:", nil, e, e.reason.UTF8String);
    }

    printf("enum.count\t%ld\n", (long)NSBatchInsertRequestResultTypeCount);
    printf("enum.StatusOnly\t%ld\n", (long)NSBatchInsertRequestResultTypeStatusOnly);
    printf("enum.ObjectIDs\t%ld\n", (long)NSBatchInsertRequestResultTypeObjectIDs);
    return 0;
} }
