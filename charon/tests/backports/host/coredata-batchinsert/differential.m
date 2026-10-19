// The differential for NSBatchInsertRequest: the request's own state, on an IN-MEMORY store, which
// is the process's own and writes nothing to this machine.
//
//   xcrun clang -fobjc-arc -framework Foundation -framework CoreData differential.m \
//       <the port's .m and its package header> -I <the package> -o differential
//   ./differential
//
// Every line is key<TAB>value, so the verdict is a diff and not a pattern read out of prose.
//
// WHAT IS COMPARED, and what cannot be. The request is a VALUE: an entity, a name, rows, a handler
// and a result type. A batch insert RUNS inside the store, through a C function the release does
// not have, so what this compares is the request's configuration and the store it is configured
// for - which is the whole of the class this port adds. The handlers are NOT called: a store calls
// them once per row, and there is no batch insert in the store to call them, which is stated in
// the class's own comment rather than papered over by calling them here.
//
// FORBIDDEN, and not called: nothing on this machine is written outside the process's own memory.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

// The class is the framework's own; this extension is the PORT's storage for it, and it has to be
// an extension and not a redeclaration for the reason the class's own file records: an ivar block
// may only appear in a class's one interface.
@interface NSBatchInsertRequest () {
    NSString *_charonEntityName;
    NSEntityDescription *_charonEntity;
    NSArray<NSDictionary<NSString *, id> *> *_charonObjectsToInsert;
    BOOL (^_charonDictionaryHandler)(NSMutableDictionary<NSString *, id> *);
    BOOL (^_charonManagedObjectHandler)(NSManagedObject *);
    NSBatchInsertRequestResultType _charonResultType;
}
@end

int main(void) { @autoreleasepool {
    // An in-memory store: the process's own, and nothing on this machine is written.
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

    // 1. -init, which is NOT a way to make one of these: both sides raise, and there is no request
    //    behind the exception, so the question is whether it raised and what it said. The three lines
    //    that stood here read entityName, objects and resultType off a bare request that does not
    //    exist: Apple's own -init raises NSInternalInconsistencyException with the reason
    //    "-init results in undefined behavior for NSBatchInsertRequest" (measured here, the same
    //    listing per-initializer.m takes), so on the host side they were never reached and on the
    //    port's side they killed the process. per-initializer.m is where the state of a request that
    //    WAS made is compared, over the twenty-two lines it prints.
    @try {
        NSBatchInsertRequest *bare = [[NSBatchInsertRequest alloc] init];
        printf("init.raised\t0\n");
        printf("init.entityName\t%s\n", bare.entityName ? bare.entityName.UTF8String : "(nil)");
    } @catch (NSException *exception) {
        printf("init.raised\t1\n");
        printf("init.reason\t%s\n", exception.reason.UTF8String);
    }

    // 2. The rows, by name.
    NSBatchInsertRequest *byName = [NSBatchInsertRequest
        batchInsertRequestWithEntityName:@"Row"
                                   objects:@[@{@"name": @"one"}, @{@"name": @"two"}]];
    printf("byName.entityName\t%s\n", byName.entityName.UTF8String);
    printf("byName.objects\t%lu\n", (unsigned long)byName.objectsToInsert.count);
    printf("byName.firstRow.name\t%s\n",
           [byName.objectsToInsert.firstObject[@"name"] UTF8String]);

    // 3. The entity form, with the ROWS it is for: both sides answer entityName=Row and entity=Row,
    //    which is what the committed twenty-two-line reference (reference-host.tsv, CoreData 120)
    //    records for this initialiser and what the port stores.
    NSBatchInsertRequest *byEntity = [[NSBatchInsertRequest alloc] initWithEntity:entity
                                                                         objects:@[@{@"name": @"one"},
                                                                                   @{@"name": @"two"}]];
    printf("byEntity.entityName\t%s\n", byEntity.entityName ? byEntity.entityName.UTF8String : "(nil)");
    printf("byEntity.entity\t%s\n", byEntity.entity.name.UTF8String);

    // 4. A request with NOTHING to insert, asked four ways: both initialiser forms with an empty
    //    array and with nil. Apple's own class keeps neither the name nor the entity then, and the
    //    port keeps neither either -- measured on the host over one row, two rows, an empty array and
    //    nil, and the port's own storage is what this compares. The rows answer their count whatever
    //    the rest is, so that line is here too.
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
            // The release's own refusal, by name: the address and the name in the reason are the
            // request's, so the two runs differ in that line and the diff says so on every line it
            // should -- a bare "raised" would hide a port that raised something else.
            printf("%s.entity\traised=%s\n", empty[index].label, exception.reason.UTF8String);
        }
        printf("%s.objects\t%lu\n", empty[index].label, (unsigned long)request.objectsToInsert.count);
    }

    // 5. -entity on a request that was made with a NAME and rows: the release raises, and the reason
    //    carries this request's own address and the name it was given, so the two runs differ in that
    //    one line by construction. What is compared is the refusal itself -- the exception's name and
    //    the reason with the address taken out of it -- because an address is not an answer.
    @try {
        NSEntityDescription *refused = byName.entity;
        printf("nameMade.entity\t%s\n", refused ? "answered" : "(null)");
    } @catch (NSException *exception) {
        // The address is the request's own and is not an answer, so it is taken out of the reason by
        // shape -- every 0x and the digits after it -- and what is left is Apple's own sentence.
        NSRegularExpression *address = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+"
                                                                                 options:0
                                                                                   error:NULL];
        NSString *reason = [address stringByReplacingMatchesInString:exception.reason
                                                              options:0
                                                                range:NSMakeRange(0, exception.reason.length)
                                                         withTemplate:@"0xADDRESS"];
        printf("nameMade.entity\traised=%s\treason=%s\n", exception.name.UTF8String, reason.UTF8String);
    }

    // 4. The handlers: both exist, and both RETURN BOOL. The block is stored, not called.
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

    // 5. The result type is settable and reads back what it was given.
    byName.resultType = NSBatchInsertRequestResultTypeObjectIDs;
    printf("byName.resultType.set\t%ld\n", (long)byName.resultType);
    printf("ResultTypeCount\t%ld\n", (long)NSBatchInsertRequestResultTypeCount);
    return 0;
} }
