#import "CharonCoreData.h"

@implementation NSFetchRequest (CharonExecute)

- (NSArray *)execute:(NSError **)error
{
    NSManagedObjectContext *context = charon_current_context();
    if ([context isKindOfClass:[NSManagedObjectContext class]])
        return [context executeFetchRequest:self error:error];
    if (error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoreDataError
                                 userInfo:@{@"message": @"Cannot fetch without an NSManagedObjectContext in scope"}];
    return nil;
}

@end
