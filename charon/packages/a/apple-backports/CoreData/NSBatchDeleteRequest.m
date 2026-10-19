#import <CoreData/CoreData.h>

@interface NSFetchRequest (CharonInUse)
- (void)_incrementInUseCounter;
@end

@implementation NSBatchDeleteRequest {
    NSBatchDeleteRequestResultType _resultType;
    NSFetchRequest *_deleteTarget;
}

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetch
{
    if (!fetch)
        [NSException raise:NSInvalidArgumentException format:@"Must supply a fetch request during initialization"];
    if (![fetch entityName])
        [NSException raise:NSInvalidArgumentException format:@"Fetch must have an entity"];
    self = [super init];
    if (self) {
        NSFetchRequest *target = [fetch copy];
        target.includesPropertyValues = NO;
        target.resultType = NSManagedObjectIDResultType;
        target.propertiesToFetch = nil;
        target.relationshipKeyPathsForPrefetching = nil;
        target.shouldRefreshRefetchedObjects = NO;
        target.fetchBatchSize = 0;
        target.includesPendingChanges = NO;
        if ([target respondsToSelector:@selector(_incrementInUseCounter)])
            [target _incrementInUseCounter];
        _deleteTarget = target;
    }
    return self;
}

- (NSFetchRequest *)fetchRequest
{
    return _deleteTarget;
}

- (NSBatchDeleteRequestResultType)resultType
{
    return _resultType;
}

- (void)setResultType:(NSBatchDeleteRequestResultType)resultType
{
    _resultType = resultType;
}

- (NSPersistentStoreRequestType)requestType
{
    return (NSPersistentStoreRequestType)7;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<NSBatchDeleteRequest : resultType : %ld, fetch :%@ >", (long)_resultType, _deleteTarget];
}

@end
