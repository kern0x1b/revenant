#import "RevenantCoreData.h"
#import <objc/runtime.h>

@interface RevenantContextMerger : NSObject
- (instancetype)initWithContext:(NSManagedObjectContext *)context;
@end

@implementation RevenantContextMerger {
@private
    __weak NSManagedObjectContext *_context;
}

- (instancetype)initWithContext:(NSManagedObjectContext *)context
{
    if ((self = [super init])) {
        _context = context;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saved:)
                                                     name:NSManagedObjectContextDidSaveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)saved:(NSNotification *)notification
{
    NSManagedObjectContext *context = _context, *saved = notification.object;
    if (!context || saved == context)
        return;
    BOOL fromParent = context.parentContext ? saved == context.parentContext
                                            : !saved.parentContext && saved.persistentStoreCoordinator == context.persistentStoreCoordinator;
    if (!fromParent)
        return;
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:notification];
    }];
}

@end

static char revenant_merger_key;

@implementation NSManagedObjectContext (RevenantMerging)

- (BOOL)automaticallyMergesChangesFromParent
{
    return objc_getAssociatedObject(self, &revenant_merger_key) != nil;
}

- (void)setAutomaticallyMergesChangesFromParent:(BOOL)merges
{
    if (merges && self.concurrencyType == NSConfinementConcurrencyType)
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Automatic merging is not supported by contexts using NSConfinementConcurrencyType"
                                     userInfo:nil];
    if (merges == self.automaticallyMergesChangesFromParent)
        return;
    objc_setAssociatedObject(self, &revenant_merger_key, merges ? [[RevenantContextMerger alloc] initWithContext:self] : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
