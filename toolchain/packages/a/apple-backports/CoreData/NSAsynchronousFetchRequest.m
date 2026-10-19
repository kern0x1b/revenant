#import <CoreData/CoreData.h>
#import <dispatch/dispatch.h>
#import "CharonStoreCoordinator.h"

@implementation NSPersistentStoreAsynchronousResult {
@public
    NSManagedObjectContext *_context;
    NSProgress *_progress;
    NSError *_error;
    int32_t _cancelled;
}

- (NSManagedObjectContext *)managedObjectContext
{
    return _context;
}

- (NSProgress *)progress
{
    return _progress;
}

- (NSError *)operationError
{
    return _error;
}

- (void)cancel
{
    __atomic_store_n(&_cancelled, 1, __ATOMIC_SEQ_CST);
    [_progress cancel];
}

@end

@implementation NSAsynchronousFetchResult {
@public
    NSAsynchronousFetchRequest *_fetchRequest;
    NSArray *_finalResult;
}

- (NSAsynchronousFetchRequest *)fetchRequest
{
    return _fetchRequest;
}

- (NSArray *)finalResult
{
    return _finalResult;
}

@end

static id charon_execute_async_fetch(NSManagedObjectContext *context, NSAsynchronousFetchRequest *request);

@implementation NSAsynchronousFetchRequest {
    NSFetchRequest *_fetchRequest;
    void (^_completion)(NSAsynchronousFetchResult *);
    NSInteger _estimatedResultCount;
}

- (instancetype)initWithFetchRequest:(NSFetchRequest *)request completionBlock:(void (^)(NSAsynchronousFetchResult *))block
{
    self = [super init];
    if (self) {
        _fetchRequest = request;
        _completion = [block copy];
        if (request.affectedStores)
            self.affectedStores = request.affectedStores;
    }
    return self;
}

- (NSFetchRequest *)fetchRequest
{
    return _fetchRequest;
}

- (void (^)(NSAsynchronousFetchResult *))completionBlock
{
    return _completion;
}

- (NSInteger)estimatedResultCount
{
    return _estimatedResultCount;
}

- (void)setEstimatedResultCount:(NSInteger)estimatedResultCount
{
    _estimatedResultCount = estimatedResultCount;
}

- (NSPersistentStoreRequestType)requestType
{
    return NSFetchRequestType;
}

- (id)charonExecuteInContext:(NSManagedObjectContext *)context error:(NSError **)error
{
    return charon_execute_async_fetch(context, self);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ with fetch request %@", [super description], _fetchRequest];
}

@end

static NSArray *charon_load(NSManagedObjectContext *context, NSArray *identifiers)
{
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:identifiers.count];
    for (NSManagedObjectID *identifier in identifiers)
        [objects addObject:[context objectWithID:identifier]];
    return objects;
}

static id charon_execute_async_fetch(NSManagedObjectContext *context, NSAsynchronousFetchRequest *request)
{
    NSFetchRequest *fetch = request.fetchRequest;
    id entity = fetch.entityName ? charon_store_coordinator(context).managedObjectModel.entitiesByName[fetch.entityName] : nil;
    if (!entity)
        [NSException raise:NSInvalidArgumentException format:@"%@ A fetch request must have an entity.", @"_executeAsynchronousFetchRequest:"];
    if (context.concurrencyType == NSConfinementConcurrencyType)
        [NSException raise:NSInvalidArgumentException format:@"NSConfinementConcurrencyType context %@ cannot support asynchronous fetch request %@.", context, request];
    if (fetch.resultType == NSCountResultType) {
        NSError *failure = nil;
        NSUInteger count = [context countForFetchRequest:fetch error:&failure];
        return count == NSNotFound ? nil : @[@(count)];
    }
    NSProgress *parent = [NSProgress currentProgress];
    NSProgress *progress = nil;
    if (parent) {
        progress = [NSProgress progressWithTotalUnitCount:request.estimatedResultCount > 0 ? request.estimatedResultCount : -1];
        progress.kind = @"managed objects";
    }
    NSAsynchronousFetchResult *result = [[NSAsynchronousFetchResult alloc] init];
    result->_fetchRequest = request;
    result->_context = context;
    result->_progress = progress;
    __weak NSAsynchronousFetchResult *weak = result;
    progress.cancellationHandler = ^{
        NSAsynchronousFetchResult *strong = weak;
        if (strong)
            __atomic_store_n(&strong->_cancelled, 1, __ATOMIC_SEQ_CST);
    };
    void (^completion)(NSAsynchronousFetchResult *) = request.completionBlock;
    NSFetchRequest *original = [fetch copy];
    NSFetchRequestResultType type = fetch.resultType;
    BOOL inContext = context.hasChanges && fetch.includesPendingChanges;
    void (^finish)(NSArray *, NSError *) = ^(NSArray *objects, NSError *failure) {
        [context performBlock:^{
            NSArray *final = objects;
            if (__atomic_load_n(&result->_cancelled, __ATOMIC_SEQ_CST))
                final = @[];
            else if (final && type == NSManagedObjectResultType && !inContext)
                final = charon_load(context, final);
            result->_finalResult = final;
            result->_error = failure;
            if (final) {
                result->_progress.totalUnitCount = final.count;
                result->_progress.completedUnitCount = final.count;
            }
            if (completion)
                completion(result);
        }];
    };
    if (inContext) {
        [context performBlock:^{
            if (__atomic_load_n(&result->_cancelled, __ATOMIC_SEQ_CST)) {
                finish(@[], nil);
                return;
            }
            NSError *failure = nil;
            @try {
                NSArray *objects = [context executeFetchRequest:original error:&failure];
                finish(objects, failure);
            } @catch (NSException *exception) {
                NSLog(@"CoreData: error: asynchronous fetch failed: %@", exception);
            }
        }];
        return result;
    }
    NSPersistentStoreCoordinator *coordinator = charon_store_coordinator(context);
    NSManagedObjectContext *worker = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    worker.persistentStoreCoordinator = coordinator;
    NSFetchRequest *stored = [original copy];
    if (type == NSManagedObjectResultType)
        stored.resultType = NSManagedObjectIDResultType;
    stored.includesPendingChanges = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (__atomic_load_n(&result->_cancelled, __ATOMIC_SEQ_CST)) {
            finish(@[], nil);
            return;
        }
        [worker performBlock:^{
            NSError *failure = nil;
            @try {
                NSArray *objects = [worker executeFetchRequest:stored error:&failure];
                finish(objects, failure);
            } @catch (NSException *exception) {
                NSLog(@"CoreData: error: asynchronous fetch failed: %@", exception);
            }
        }];
    });
    return result;
}
