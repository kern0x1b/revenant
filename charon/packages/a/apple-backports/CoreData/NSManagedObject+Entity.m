#import "CharonCoreData.h"

@implementation NSManagedObject (CharonEntity)

+ (NSEntityDescription *)entity
{
    NSString *name = NSStringFromClass(self);
    NSMutableArray *claims = [NSMutableArray array];
    for (NSManagedObjectModel *model in charon_registered_models())
        for (NSEntityDescription *entity in model.entities)
            if ([entity.managedObjectClassName isEqualToString:name])
                [claims addObject:entity];
    if (claims.count == 1)
        return claims[0];
    if (claims.count)
        NSLog(@"CoreData: warning: Multiple NSEntityDescriptions claim the NSManagedObject subclass '%@' so +entity is unable to disambiguate.", name);
    else
        NSLog(@"CoreData: error: No NSEntityDescriptions in any model claim the NSManagedObject subclass '%@' so +entity is confused.  Have you loaded your NSManagedObjectModel yet ?", name);
    NSLog(@"CoreData: error: +[%@ entity] Failed to find a unique match for an NSEntityDescription to a managed object subclass", name);
    return nil;
}

+ (NSFetchRequest *)fetchRequest
{
    return [NSFetchRequest fetchRequestWithEntityName:[self entity].name ?: @""];
}

- (instancetype)initWithContext:(NSManagedObjectContext *)context
{
    NSEntityDescription *entity = nil;
    NSString *name = NSStringFromClass([self class]);
    for (NSEntityDescription *candidate in context.persistentStoreCoordinator.managedObjectModel.entities)
        if ([candidate.managedObjectClassName isEqualToString:name]) {
            entity = candidate;
            break;
        }
    if (!context)
        entity = [[self class] entity];
    return [self initWithEntity:entity insertIntoManagedObjectContext:context];
}

@end
