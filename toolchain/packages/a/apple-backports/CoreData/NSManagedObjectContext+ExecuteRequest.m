#import <CoreData/CoreData.h>
#import "RevenantStoreCoordinator.h"

@interface NSBatchDeleteResult (RevenantInit)
- (instancetype)initWithResultType:(NSBatchDeleteRequestResultType)resultType andObject:(id)result;
@end

static NSBatchDeleteResult *revenant_batch_delete(NSManagedObjectContext *context, NSBatchDeleteRequest *request, NSError **error)
{
    NSFetchRequest *fetch = [request.fetchRequest copy];
    fetch.resultType = NSManagedObjectResultType;
    if (request.affectedStores)
        fetch.affectedStores = request.affectedStores;
    NSManagedObjectContext *worker = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    worker.persistentStoreCoordinator = revenant_store_coordinator(context);
    __block id outcome = nil;
    __block NSError *failure = nil;
    [worker performBlockAndWait:^{
        NSArray *objects = [worker executeFetchRequest:fetch error:&failure];
        if (!objects)
            return;
        NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:objects.count];
        for (NSManagedObject *object in objects) {
            [identifiers addObject:object.objectID];
            [worker deleteObject:object];
        }
        if (objects.count && ![worker save:&failure])
            return;
        if (request.resultType == NSBatchDeleteResultTypeObjectIDs)
            outcome = [identifiers copy];
        else if (request.resultType == NSBatchDeleteResultTypeCount)
            outcome = @(identifiers.count);
        else
            outcome = @YES;
    }];
    if (!outcome) {
        if (error)
            *error = failure;
        return nil;
    }
    return [[NSBatchDeleteResult alloc] initWithResultType:request.resultType andObject:outcome];
}

@interface NSBatchUpdateRequest (RevenantExecute)
- (id)revenantExecuteInContext:(NSManagedObjectContext *)context error:(NSError **)error;
@end

@interface NSAsynchronousFetchRequest (RevenantExecute)
- (id)revenantExecuteInContext:(NSManagedObjectContext *)context error:(NSError **)error;
@end

@implementation NSManagedObjectContext (RevenantExecuteRequest)

- (id)executeRequest:(NSPersistentStoreRequest *)request error:(NSError **)error
{
    if ([request isKindOfClass:[NSFetchRequest class]])
        return [self executeFetchRequest:(NSFetchRequest *)request error:error];
    if ([request isKindOfClass:[NSAsynchronousFetchRequest class]])
        return [(NSAsynchronousFetchRequest *)request revenantExecuteInContext:self error:error];
    if (request.requestType == 6)
        return [(NSBatchUpdateRequest *)request revenantExecuteInContext:self error:error];
    if (request.requestType == 7)
        return revenant_batch_delete(self, (NSBatchDeleteRequest *)request, error);
    return [self.persistentStoreCoordinator executeRequest:request withContext:self error:error];
}

@end
