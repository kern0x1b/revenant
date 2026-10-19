#import <CoreData/CoreData.h>
#import "CharonAbstract.h"

@implementation NSPersistentHistoryTransaction

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSDate *)timestamp
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSArray<NSPersistentHistoryChange *> *)changes
{
    charon_abstract(self, _cmd);
    return nil;
}

- (int64_t)transactionNumber
{
    charon_abstract(self, _cmd);
    return -1;
}

- (NSString *)storeID
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSString *)bundleID
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSString *)processID
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSString *)contextName
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSString *)author
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSPersistentHistoryToken *)token
{
    charon_abstract(self, _cmd);
    return nil;
}

- (NSNotification *)objectIDNotification
{
    charon_abstract(self, _cmd);
    return nil;
}

@end
