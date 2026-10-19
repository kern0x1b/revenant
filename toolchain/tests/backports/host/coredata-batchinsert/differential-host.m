#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

int main(void) { @autoreleasepool {
    NSManagedObjectModel *model = [NSManagedObjectModel new];
    NSEntityDescription *entity = [NSEntityDescription new];
    entity.name = @"Row";
    entity.managedObjectClassName = @"NSManagedObject";
    entity.properties = @[];
    model.entities = @[entity];
    NSPersistentStoreCoordinator *coordinator =
        [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSError *storeError = nil;
    NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSInMemoryStoreType
                                                          configuration:nil
                                                                    URL:nil
                                                                options:nil
                                                                  error:&storeError];
    printf("in-memory store\t%s\n", store ? "added" : "FAILED");

    @try {
        NSBatchInsertRequest *bare = [[NSBatchInsertRequest alloc] init];
        printf("init.raised\t0\n");
        printf("init.entityName\t%s\n", bare.entityName ? bare.entityName.UTF8String : "(nil)");
    } @catch (NSException *exception) {
        printf("init.raised\t1\n");
        printf("init.reason\t%s\n", exception.reason.UTF8String);
    }

    NSBatchInsertRequest *byName = [NSBatchInsertRequest
        batchInsertRequestWithEntityName:@"Row"
                                   objects:@[@{@"name": @"one"}, @{@"name": @"two"}]];
    printf("byName.entityName\t%s\n", byName.entityName.UTF8String);
    printf("byName.objects\t%lu\n", (unsigned long)byName.objectsToInsert.count);
    printf("byName.firstRow.name\t%s\n",
           [byName.objectsToInsert.firstObject[@"name"] UTF8String]);

    NSBatchInsertRequest *byEntity = [[NSBatchInsertRequest alloc] initWithEntity:entity
                                                                         objects:@[@{@"name": @"one"},
                                                                                   @{@"name": @"two"}]];
    printf("byEntity.entityName\t%s\n", byEntity.entityName ? byEntity.entityName.UTF8String : "(nil)");
    printf("byEntity.entity\t%s\n", byEntity.entity.name.UTF8String);

    NSArray *rows = @[@{@"name": @"one"}, @{@"name": @"two"}];
    NSArray *none = @[];
    struct { const char *label; NSArray *objects; NSString *name; NSEntityDescription *by; } empty[] = {
        {"name.empty", none, @"Row", nil}, {"name.nil", nil, @"Row", nil},
        {"entity.empty", none, nil, entity}, {"entity.nil", nil, nil, entity},
    };
    for (size_t index = 0; index < sizeof(empty) / sizeof(empty[0]); index++) {
        NSBatchInsertRequest *request = empty[index].by
            ? [[NSBatchInsertRequest alloc] initWithEntity:empty[index].by objects:empty[index].objects]
            : [[NSBatchInsertRequest alloc] initWithEntityName:empty[index].name objects:empty[index].objects];
        printf("%s.entityName\t%s\n", empty[index].label,
               request.entityName ? request.entityName.UTF8String : "(nil)");
        @try {
            NSEntityDescription *held = request.entity;
            printf("%s.entity\t%s\n", empty[index].label,
                   held ? (held.name ? held.name.UTF8String : "(nil)") : "(null)");
        } @catch (NSException *exception) {
            printf("%s.entity\traised=%s\n", empty[index].label, exception.reason.UTF8String);
        }
        printf("%s.objects\t%lu\n", empty[index].label, (unsigned long)request.objectsToInsert.count);
    }

    @try {
        NSEntityDescription *refused = byName.entity;
        printf("nameMade.entity\t%s\n", refused ? "answered" : "(null)");
    } @catch (NSException *exception) {
        NSRegularExpression *address = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+"
                                                                                 options:0
                                                                                   error:NULL];
        NSString *reason = [address stringByReplacingMatchesInString:exception.reason
                                                              options:0
                                                                range:NSMakeRange(0, exception.reason.length)
                                                         withTemplate:@"0xADDRESS"];
        printf("nameMade.entity\traised=%s\treason=%s\n", exception.name.UTF8String, reason.UTF8String);
    }

    __block NSUInteger called = 0;
    BOOL (^dictionaryHandler)(NSMutableDictionary<NSString *, id> *) =
        ^BOOL(NSMutableDictionary<NSString *, id> *obj) { called++; return YES; };
    BOOL (^managedObjectHandler)(NSManagedObject *) =
        ^BOOL(NSManagedObject *obj) { called++; return YES; };
    NSBatchInsertRequest *withHandler = [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row"
                                                                            dictionaryHandler:dictionaryHandler];
    printf("dictionaryHandler.present\t%s\n", withHandler.dictionaryHandler ? "true" : "false");
    printf("dictionaryHandler.called\t%lu\n", (unsigned long)called);
    NSBatchInsertRequest *withObjectHandler =
        [NSBatchInsertRequest batchInsertRequestWithEntityName:@"Row"
                                       managedObjectHandler:managedObjectHandler];
    printf("managedObjectHandler.present\t%s\n", withObjectHandler.managedObjectHandler ? "true" : "false");
    printf("managedObjectHandler.called\t%lu\n", (unsigned long)called);

    byName.resultType = NSBatchInsertRequestResultTypeObjectIDs;
    printf("byName.resultType.set\t%ld\n", (long)byName.resultType);
    printf("ResultTypeCount\t%ld\n", (long)NSBatchInsertRequestResultTypeCount);
    return 0;
} }
