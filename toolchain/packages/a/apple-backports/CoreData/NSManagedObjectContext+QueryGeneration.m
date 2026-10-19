#import <CoreData/CoreData.h>
#import <objc/runtime.h>

static const char CharonQueryGenerationKey;

@interface NSQueryGenerationToken (CharonCoordinator)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
@end

@implementation NSManagedObjectContext (CharonQueryGeneration)

- (NSQueryGenerationToken *)queryGenerationToken
{
    return objc_getAssociatedObject(self, &CharonQueryGenerationKey);
}

- (BOOL)setQueryGenerationFromToken:(NSQueryGenerationToken *)token error:(NSError **)error
{
    if (!self.persistentStoreCoordinator) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:134060 userInfo:@{@"reason": @"Cannot set a query generation on an NSManagedObjectContext that does not have a coordinator"}];
        return NO;
    }
    if (token && token != [NSQueryGenerationToken currentQueryGenerationToken])
        (void)[token persistentStoreCoordinator];
    objc_setAssociatedObject(self, &CharonQueryGenerationKey, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

@end
