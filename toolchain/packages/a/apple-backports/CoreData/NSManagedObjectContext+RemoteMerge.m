#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (CharonRelease)
+ (void)_mergeChangesFromRemoteContextSave:(NSDictionary *)changes intoContexts:(NSArray *)contexts;
@end

@implementation NSManagedObjectContext (CharonRemoteMerge)

+ (void)mergeChangesFromRemoteContextSave:(NSDictionary *)changeNotificationData intoContexts:(NSArray<NSManagedObjectContext *> *)contexts
{
    [self _mergeChangesFromRemoteContextSave:changeNotificationData intoContexts:contexts];
    for (NSManagedObjectContext *context in contexts) {
        if (context.concurrencyType == NSConfinementConcurrencyType)
            [context processPendingChanges];
        else
            [context performBlockAndWait:^{
                [context processPendingChanges];
            }];
    }
}

@end
