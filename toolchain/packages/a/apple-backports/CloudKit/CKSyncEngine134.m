#import <Foundation/Foundation.h>

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSyncEngine26.h"

static NSError *CharonCKSyncEngineNoAccount(void)
{
    return CharonCKError(CKErrorNotAuthenticated,
                         @"this release has no iCloud account, so the service is not reachable and"
                         " every request answers the transport's own refusal",
                         nil);
}

@implementation CKSyncEngine
{
    CKSyncEngineState *_state;
}

@synthesize state = _state;

- (instancetype)initWithConfiguration:(CKSyncEngineConfiguration *)configuration
{
    if (!configuration) {
        return nil;
    }
    CKSyncEngine *built = [CKSyncEngine alloc];
    if (!built) {
        return nil;
    }
    built->_state = [[CKSyncEngineState alloc] initForSyncEngine:built];
    return built;
}

- (CKDatabase *)database
{
    return nil;
}

- (void)fetchChangesWithCompletionHandler:(nullable void (^)(NSError *_Nullable))completionHandler
{
    if (completionHandler) {
        completionHandler(CharonCKSyncEngineNoAccount());
    }
}

- (void)fetchChangesWithOptions:(CKSyncEngineFetchChangesOptions *)options
             completionHandler:(nullable void (^)(NSError *_Nullable))completionHandler
{
    [self fetchChangesWithCompletionHandler:completionHandler];
}

- (void)sendChangesWithCompletionHandler:(nullable void (^)(NSError *_Nullable))completionHandler
{
    if (completionHandler) {
        completionHandler(CharonCKSyncEngineNoAccount());
    }
}

- (void)sendChangesWithOptions:(CKSyncEngineSendChangesOptions *)options
            completionHandler:(nullable void (^)(NSError *_Nullable))completionHandler
{
    [self sendChangesWithCompletionHandler:completionHandler];
}

- (void)cancelOperationsWithCompletionHandler:(nullable void (^)(void))completionHandler
{
    if (completionHandler) {
        completionHandler();
    }
}

@end
