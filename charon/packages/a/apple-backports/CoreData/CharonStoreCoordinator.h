#import <CoreData/CoreData.h>

static inline NSPersistentStoreCoordinator *charon_store_coordinator(NSManagedObjectContext *context)
{
    NSManagedObjectContext *root = context;
    while (root.parentContext)
        root = root.parentContext;
    return root.persistentStoreCoordinator;
}
