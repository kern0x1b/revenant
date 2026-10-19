#import <CoreData/CoreData.h>
#import "CharonAbstract.h"

@implementation NSPersistentHistoryChange

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (int64_t)changeID
{
    charon_abstract(self, _cmd);
    return -1;
}

- (NSManagedObjectID *)changedObjectID
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSPersistentHistoryChangeType)changeType
{
    charon_abstract(self, _cmd);
    return NSPersistentHistoryChangeTypeInsert;
}

- (NSDictionary *)tombstone
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSPersistentHistoryTransaction *)transaction
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSSet<NSPropertyDescription *> *)updatedProperties
{
    charon_abstract(self, _cmd);
    return nil;
}

@end
