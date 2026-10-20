#import <CoreData/CoreData.h>
#import "RevenantAbstract.h"

@implementation NSPersistentHistoryTransaction

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSDate *)timestamp
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSArray<NSPersistentHistoryChange *> *)changes
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (int64_t)transactionNumber
{
    revenant_abstract(self, _cmd);
    return -1;
}

- (NSString *)storeID
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSString *)bundleID
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSString *)processID
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSString *)contextName
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSString *)author
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSPersistentHistoryToken *)token
{
    revenant_abstract(self, _cmd);
    return nil;
}

- (NSNotification *)objectIDNotification
{
    revenant_abstract(self, _cmd);
    return nil;
}

@end
