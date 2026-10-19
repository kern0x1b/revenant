#import <CoreData/CoreData.h>
#import "CharonCoreData.h"

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

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"-init results in undefined behavior for NSBatchInsertRequest"];
    return nil;
}

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
