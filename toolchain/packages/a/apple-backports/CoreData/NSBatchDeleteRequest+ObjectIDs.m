#import <CoreData/CoreData.h>

@implementation NSBatchDeleteRequest (CharonObjectIDs)

- (instancetype)initWithObjectIDs:(NSArray<NSManagedObjectID *> *)objectIDs
{
    if (!objectIDs.count)
        [NSException raise:NSInvalidArgumentException format:@"Must supply a non-zero number of objectIDs to request during initialization"];
    NSEntityDescription *root = [objectIDs.lastObject entity];
    while (root.superentity)
        root = root.superentity;
    for (NSManagedObjectID *objectID in objectIDs) {
        NSEntityDescription *entity = objectID.entity;
        while (entity.superentity)
            entity = entity.superentity;
        if (entity != root)
            [[NSException exceptionWithName:NSInvalidArgumentException reason:@"mismatched objectIDs in batch delete initializer" userInfo:@{@"objectIDs": objectIDs}] raise];
    }
    NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
    fetch.entity = root;
    fetch.predicate = [NSPredicate predicateWithFormat:@"SELF IN %@", objectIDs];
    fetch.includesPendingChanges = NO;
    fetch.resultType = NSManagedObjectIDResultType;
    return [self initWithFetchRequest:fetch];
}

@end
