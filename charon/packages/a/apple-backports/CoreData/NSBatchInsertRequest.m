// NSBatchInsertRequest: the batch insert of Core Data, which the release does not have.
//
// The release's Core Data arrived in iOS 3.0, its batch DELETE and batch UPDATE arrived with the
// iOS 9.0 backports beside it - NSBatchDeleteRequest.m and NSBatchUpdateRequest.m are in this
// package - and the batch INSERT arrived at iOS 13.0 with nothing carrying it. The 16.4 header the
// port's headers are rendered from DECLARES the class, with an empty ivar block and SIX properties it has nowhere
// to keep (NSBatchInsertRequest.h:20,21,23,24,25,28), so the storage is in the class
// extension below and this file is only what that declaration does not carry. It is NOT in
// CharonCoreData.h: an ivar block may only appear in a class's one interface, the SDK has it, and a
// second @interface for this class is a duplicate definition.
// The types are the header's own (NSBatchInsertRequest.h:17-43), not the corpus's selector list,
// which spells labels and not types: both handlers RETURN BOOL, and objects: takes dictionaries on
// both the name and the entity form. The enum and NSBatchInsertRequestResultTypeCount are
// Apple's and are not redeclared here.
//
// What a batch insert DOES, and the boundary of this file. The handlers are called once per row BY
// THE STORE, and this port's store is the backports' coordinator over a release that has no batch
// insert at all: there is no C function to hand the request to. So this class is the request as a
// value - the entity, the rows, the handler, the result type - and it is what a program written
// against 13.0 configures. A caller that needs its rows in a store uses the store's own path, and
// the differential for this step is over exactly that: the request's own state, on the port's own
// in-memory store, with no write to any system store.

#import <CoreData/CoreData.h>
#import "CharonCoreData.h"

// The storage. The SDK declares the class with an EMPTY ivar block (NSBatchInsertRequest.h:17),
// so this extension is where its SIX properties are kept (NSBatchInsertRequest.h:20,21,23,24,25,28).
// It is here rather than in CharonCoreData.h because an ivar block may only appear in a class's one
// interface and the SDK has that one: a second @interface for NSBatchInsertRequest is "duplicate
// interface definition", which is exactly what the shared header produced.
@interface NSBatchInsertRequest () {
    NSString *_charonEntityName;
    NSEntityDescription *_charonEntity;
    NSArray<NSDictionary<NSString *, id> *> *_charonObjectsToInsert;
    BOOL (^_charonDictionaryHandler)(NSMutableDictionary<NSString *, id> *);
    BOOL (^_charonManagedObjectHandler)(NSManagedObject *);
    NSBatchInsertRequestResultType _charonResultType;
}
@end

@implementation NSBatchInsertRequest

@synthesize entityName = _charonEntityName;
@synthesize entity = _charonEntity;
@synthesize objectsToInsert = _charonObjectsToInsert;
@synthesize dictionaryHandler = _charonDictionaryHandler;
@synthesize managedObjectHandler = _charonManagedObjectHandler;
@synthesize resultType = _charonResultType;

#pragma mark - The initialiser the header deprecates -init in favour of

/// -init raises, and that is not a choice the port makes. Measured on the host, with
/// [[NSBatchInsertRequest alloc] init] inside @try/@catch:
///
///   init  raised=1  answer=nil  reason=-init results in undefined behavior for NSBatchInsertRequest
///
/// and the other NINE initialisers and constructors in the same listing answer raised=0 with a
/// non-nil request. So a batch insert request is made through initWithEntityName: or initWith: and
/// never through -init, and the reason text is Apple's own, word for word, because a program that
/// catches this reads it.
- (instancetype)init
{
    // The reason is the LITERAL, and not NSStringFromClass: the port binary renames the class
    // with -DNSBatchInsertRequest=CharonBatchInsertRequest so nothing links two definitions of it,
    // and a class-name substitution would then spell CharonBatchInsertRequest where Apple spells
    // NSBatchInsertRequest - a different answer for the same exception. Measured, the host's is
    // exactly: -init results in undefined behavior for NSBatchInsertRequest
    [NSException raise:NSInternalInconsistencyException
                format:@"-init results in undefined behavior for NSBatchInsertRequest"];
    return nil;
}

/* The release refuses -entity on a request that was made with a name, and the port answers what the
   release answers rather than what it finds convenient. Measured on the host, CoreData 120: a request
   built by +batchInsertRequestWithEntityName:objects: raises NSObjectInaccessibleException out of
   -entity, with the reason

       This batch insert request (0x78df0a4000) was created with a string name (Row), and cannot
       respond to -entity until used by an NSManagedObjectContext

   word for word, the address and the name being the request's own. So the reason is a format over
   this object and its name and NOT over the class name, which is what lets a binary that renames
   the class (see -init above) keep Apple's own words. A request made with an entity answers it --
   the host's answer for that form is entity=Row -- and a request with nothing to insert answers nil,
   because it has no name to have been made with either. */
- (NSEntityDescription *)entity
{
    if (!_charonEntity && _charonEntityName) {
        [NSException raise:NSObjectInaccessibleException
                    format:@"This batch insert request (%p) was created with a string name (%@), and cannot respond to -entity until used by an NSManagedObjectContext",
                           (void *)self, _charonEntityName];
    }
    return _charonEntity;
}

- (instancetype)initWithEntityName:(NSString *)entityName
                          objects:(NSArray<NSDictionary<NSString *, id> *> *)dictionaries
{
    self = [super init];
    /* A request with nothing to insert keeps neither the name nor the rows. Measured on the host,
       CoreData 120, both forms of this initialiser with one row, two rows, an empty array and nil:
       the rows answer the count and NOTHING else is set -- entityName=(nil), entity=(null) -- while
       one row or more gives entityName=Row. So the release drops what there is nothing to insert
       into, and a port that kept the name would answer a question the release answers differently.
       The handler forms below keep their name because they take no rows at all and the host's answer
       for them is entityName=Row (reference-host.tsv). */
    if (self && dictionaries.count) {
        _charonEntityName = [entityName copy];
        _charonObjectsToInsert = [dictionaries copy];
    }
    return self;
}

- (instancetype)initWithEntity:(NSEntityDescription *)entity
                       objects:(NSArray<NSDictionary<NSString *, id> *> *)dictionaries
{
    self = [super init];
    // The same rule as the name form above, and measured the same way: no rows, no entity and no
    // name. With rows the host's answer is entityName=Row entity=Row objects=2, so the NAME is set
    // from the entity's and not only the entity.
    if (self && dictionaries.count) {
        _charonEntity = entity;
        _charonEntityName = [entity.name copy];
        _charonObjectsToInsert = [dictionaries copy];
    }
    return self;
}

#pragma mark - With a handler

- (instancetype)initWithEntityName:(NSString *)entityName
                  dictionaryHandler:(BOOL (^)(NSMutableDictionary<NSString *, id> *))handler
{
    self = [self initWithEntityName:entityName objects:@[]];
    if (self) {
        _charonEntityName = [entityName copy];
        _charonDictionaryHandler = [handler copy];
    }
    return self;
}

- (instancetype)initWithEntityName:(NSString *)entityName
                 managedObjectHandler:(BOOL (^)(NSManagedObject *))handler
{
    self = [self initWithEntityName:entityName objects:@[]];
    if (self) {
        _charonEntityName = [entityName copy];
        _charonManagedObjectHandler = [handler copy];
    }
    return self;
}

- (instancetype)initWithEntity:(NSEntityDescription *)entity
               dictionaryHandler:(BOOL (^)(NSMutableDictionary<NSString *, id> *))handler
{
    self = [self initWithEntity:entity objects:@[]];
    if (self) {
        // ONE block, ONE assignment, and the entity beside it. This carried three, and the first put the handler in the
        // OTHER ivar, so a request built here had BOTH handler ivars set and nothing said so.
        // initWithEntity:objects: stores the entity and its name when there are rows, and this form
        // has none by construction, so it stores them here: the host's answer for it is entity=Row.
        _charonEntity = entity;
        _charonEntityName = [entity.name copy];
        _charonDictionaryHandler = [handler copy];
    }
    return self;
}

- (instancetype)initWithEntity:(NSEntityDescription *)entity
            managedObjectHandler:(BOOL (^)(NSManagedObject *))handler
{
    self = [self initWithEntity:entity objects:@[]];
    if (self) {
        // ONE block, ONE assignment. This carried three, and the first put the handler in the
        // OTHER ivar, so a request built here had BOTH handler ivars set and nothing said so.
        // initWithEntity:objects: stores the entity and its name when there are rows, and this form
        // has none by construction, so it stores them here: the host's answer for it is entity=Row.
        _charonEntity = entity;
        _charonEntityName = [entity.name copy];
        _charonManagedObjectHandler = [handler copy];
    }
    return self;
}

#pragma mark - The three class constructors the header declares

+ (instancetype)batchInsertRequestWithEntityName:(NSString *)entityName
                                         objects:(NSArray<NSDictionary<NSString *, id> *> *)dictionaries
{
    return [[self alloc] initWithEntityName:entityName objects:dictionaries];
}

+ (instancetype)batchInsertRequestWithEntityName:(NSString *)entityName
                               dictionaryHandler:(BOOL (^)(NSMutableDictionary<NSString *, id> *))handler
{
    return [[self alloc] initWithEntityName:entityName dictionaryHandler:handler];
}

+ (instancetype)batchInsertRequestWithEntityName:(NSString *)entityName
                            managedObjectHandler:(BOOL (^)(NSManagedObject *))handler
{
    return [[self alloc] initWithEntityName:entityName managedObjectHandler:handler];
}

@end
