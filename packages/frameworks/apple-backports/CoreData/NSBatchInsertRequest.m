#import <CoreData/CoreData.h>
#import "RevenantCoreData.h"

@interface NSBatchInsertRequest () {
    NSString *_revenantEntityName;
    NSEntityDescription *_revenantEntity;
    NSArray<NSDictionary<NSString *, id> *> *_revenantObjectsToInsert;
    BOOL (^_revenantDictionaryHandler)(NSMutableDictionary<NSString *, id> *);
    BOOL (^_revenantManagedObjectHandler)(NSManagedObject *);
    NSBatchInsertRequestResultType _revenantResultType;
}
@end

@implementation NSBatchInsertRequest

@synthesize entityName = _revenantEntityName;
@synthesize entity = _revenantEntity;
@synthesize objectsToInsert = _revenantObjectsToInsert;
@synthesize dictionaryHandler = _revenantDictionaryHandler;
@synthesize managedObjectHandler = _revenantManagedObjectHandler;
@synthesize resultType = _revenantResultType;

#pragma mark - The initialiser the header deprecates -init in favour of

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"-init results in undefined behavior for NSBatchInsertRequest"];
    return nil;
}

- (NSEntityDescription *)entity
{
    if (!_revenantEntity && _revenantEntityName) {
        [NSException raise:NSObjectInaccessibleException
                    format:@"This batch insert request (%p) was created with a string name (%@), and cannot respond to -entity until used by an NSManagedObjectContext",
                           (void *)self, _revenantEntityName];
    }
    return _revenantEntity;
}

- (instancetype)initWithEntityName:(NSString *)entityName
                          objects:(NSArray<NSDictionary<NSString *, id> *> *)dictionaries
{
    self = [super init];
    if (self && dictionaries.count) {
        _revenantEntityName = [entityName copy];
        _revenantObjectsToInsert = [dictionaries copy];
    }
    return self;
}

- (instancetype)initWithEntity:(NSEntityDescription *)entity
                       objects:(NSArray<NSDictionary<NSString *, id> *> *)dictionaries
{
    self = [super init];
    if (self && dictionaries.count) {
        _revenantEntity = entity;
        _revenantEntityName = [entity.name copy];
        _revenantObjectsToInsert = [dictionaries copy];
    }
    return self;
}

#pragma mark - With a handler

- (instancetype)initWithEntityName:(NSString *)entityName
                  dictionaryHandler:(BOOL (^)(NSMutableDictionary<NSString *, id> *))handler
{
    self = [self initWithEntityName:entityName objects:@[]];
    if (self) {
        _revenantEntityName = [entityName copy];
        _revenantDictionaryHandler = [handler copy];
    }
    return self;
}

- (instancetype)initWithEntityName:(NSString *)entityName
                 managedObjectHandler:(BOOL (^)(NSManagedObject *))handler
{
    self = [self initWithEntityName:entityName objects:@[]];
    if (self) {
        _revenantEntityName = [entityName copy];
        _revenantManagedObjectHandler = [handler copy];
    }
    return self;
}

- (instancetype)initWithEntity:(NSEntityDescription *)entity
               dictionaryHandler:(BOOL (^)(NSMutableDictionary<NSString *, id> *))handler
{
    self = [self initWithEntity:entity objects:@[]];
    if (self) {
        _revenantEntity = entity;
        _revenantEntityName = [entity.name copy];
        _revenantDictionaryHandler = [handler copy];
    }
    return self;
}

- (instancetype)initWithEntity:(NSEntityDescription *)entity
            managedObjectHandler:(BOOL (^)(NSManagedObject *))handler
{
    self = [self initWithEntity:entity objects:@[]];
    if (self) {
        _revenantEntity = entity;
        _revenantEntityName = [entity.name copy];
        _revenantManagedObjectHandler = [handler copy];
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
