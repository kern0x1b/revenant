#import <CoreData/CoreData.h>
#import "RevenantAbstract.h"

@implementation NSPersistentHistoryChange

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (int64_t)changeID
{
    revenant_abstract(self, _cmd);
    return -1;
}

- (NSManagedObjectID *)changedObjectID
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSPersistentHistoryChangeType)changeType
{
    revenant_abstract(self, _cmd);
    return NSPersistentHistoryChangeTypeInsert;
}

- (NSDictionary *)tombstone
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSPersistentHistoryTransaction *)transaction
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSSet<NSPropertyDescription *> *)updatedProperties
{
    revenant_abstract(self, _cmd);
    return nil;
}

@end
