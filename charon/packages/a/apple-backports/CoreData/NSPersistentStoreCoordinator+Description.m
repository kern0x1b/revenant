#import "CharonCoreData.h"

@implementation NSPersistentStoreCoordinator (CharonDescription)

- (void)addPersistentStoreWithDescription:(NSPersistentStoreDescription *)storeDescription
                        completionHandler:(void (^)(NSPersistentStoreDescription *, NSError *))block
{
    NSPersistentStoreDescription *description = [storeDescription copy];
    void (^done)(NSPersistentStoreDescription *, NSError *) = [block copy];
    void (^work)(void) = ^{
        NSError *error = nil;
        [self addPersistentStoreWithType:description.type configuration:description.configuration URL:description.URL
                                 options:description.options error:&error];
        if (done)
            done(description, error);
    };
    if (description.shouldAddStoreAsynchronously)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), work);
    else
        work();
}

@end
