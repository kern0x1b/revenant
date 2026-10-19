#import "CharonCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CXCallController {
    dispatch_queue_t _queue;
    CXCallObserver *_callObserver;
}

@dynamic callObserver;

- (instancetype)init
{
    return [self initWithQueue:dispatch_get_main_queue()];
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue
{
    if ((self = [super init])) {
        _queue = queue ?: dispatch_get_main_queue();
        _callObserver = [[CXCallObserver alloc] init];
    }
    return self;
}

- (CXCallObserver *)callObserver
{
    return _callObserver;
}

// What a transaction is refused for, in the order CallKit refuses it. The
// completion of a request says whether the transaction was taken, not whether
// its actions were performed: an action that was taken and then failed is
// told to the delegate of the provider, and the completion has already run
// with no error by then.
- (NSError *)charon_refuse:(CXTransaction *)transaction provider:(CXProvider *)provider
{
    if (transaction.actions.count == 0)
        return charon_callkit_error(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionErrorEmptyTransaction);
    if (!provider)
        return charon_callkit_error(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionErrorUnknownCallProvider);
    CharonCallBroker *broker = [CharonCallBroker shared];
    NSUInteger groups = [broker groupsOfProvider:provider];
    NSUInteger maximum = provider.configuration.maximumCallGroups;
    for (CXAction *action in transaction.actions) {
        if (![action isKindOfClass:[CXCallAction class]])
            return charon_callkit_error(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionErrorInvalidAction);
        NSUUID *callUUID = ((CXCallAction *)action).callUUID;
        CXCall *call = [broker callWithUUID:callUUID];
        if ([action isKindOfClass:[CXStartCallAction class]]) {
            if (call)
                return charon_callkit_error(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionErrorCallUUIDAlreadyExists);
            if (maximum > 0 && groups >= maximum)
                return charon_callkit_error(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionErrorMaximumCallGroupsReached);
            groups++;
        } else if (!call) {
            return charon_callkit_error(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionErrorUnknownCallUUID);
        } else if (call.charon_provider != provider) {
            // A cellular call of the release, which the observer reports and
            // no provider of this process owns. CallKit would take the action
            // to whatever is hosting the call; here there is nothing to take
            // it to, and saying no provider knows the call is what is true.
            return charon_callkit_error(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionErrorUnknownCallProvider);
        }
    }
    return nil;
}

- (void)requestTransaction:(CXTransaction *)transaction completion:(void (^)(NSError *))completion
{
    CXProvider *provider = [[CharonCallBroker shared] anyProvider];
    NSError *refused = [self charon_refuse:transaction provider:provider];
    if (!refused) {
        for (CXAction *action in transaction.actions) {
            if (![action isKindOfClass:[CXStartCallAction class]])
                continue;
            CXStartCallAction *start = (CXStartCallAction *)action;
            CXCall *call = [[CXCall alloc] charon_initWithUUID:start.callUUID outgoing:YES];
            call.charon_provider = provider;
            CXCallUpdate *update = [[CXCallUpdate alloc] init];
            update.remoteHandle = start.handle;
            update.hasVideo = start.isVideo;
            call.charon_update = update;
            [[CharonCallBroker shared] addCall:call];
        }
        [provider charon_execute:transaction];
    }
    if (!completion)
        return;
    dispatch_async(_queue, ^{
        completion(refused);
    });
}

- (void)requestTransactionWithActions:(NSArray<CXAction *> *)actions completion:(void (^)(NSError *))completion
{
    [self requestTransaction:[[CXTransaction alloc] initWithActions:actions] completion:completion];
}

- (void)requestTransactionWithAction:(CXAction *)action completion:(void (^)(NSError *))completion
{
    [self requestTransaction:[[CXTransaction alloc] initWithActions:action ? @[action] : @[]] completion:completion];
}

@end
