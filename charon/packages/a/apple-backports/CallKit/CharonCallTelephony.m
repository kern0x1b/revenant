#import "CharonCallKit.h"
#import <CoreTelephony/CTCall.h>
#import <CoreTelephony/CTCallCenter.h>

@implementation CharonCallTelephony {
    CTCallCenter *_center;
    NSMutableDictionary<NSString *, CXCall *> *_calls;
}

+ (instancetype)shared
{
    static CharonCallTelephony *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonCallTelephony alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init]))
        _calls = [NSMutableDictionary dictionary];
    return self;
}

- (void)start
{
    @synchronized (self) {
        if (_center || !NSClassFromString(@"CTCallCenter"))
            return;
        _center = [[CTCallCenter alloc] init];
    }
    for (CTCall *call in _center.currentCalls)
        [self apply:call];
    __weak CharonCallTelephony *weak = self;
    _center.callEventHandler = ^(CTCall *call) {
        [weak apply:call];
    };
}

- (void)apply:(CTCall *)call
{
    NSString *identifier = call.callID;
    NSString *state = call.callState;
    if (!identifier || !state)
        return;
    CXCall *known;
    @synchronized (self) {
        known = _calls[identifier];
    }
    if ([state isEqualToString:CTCallStateDisconnected]) {
        if (!known)
            return;
        @synchronized (self) {
            [_calls removeObjectForKey:identifier];
        }
        known.charon_dateEnded = [NSDate date];
        known.charon_endedReason = CXCallEndedReasonRemoteEnded;
        [[CharonCallBroker shared] removeCall:known];
        return;
    }
    if (!known) {
        known = [[CXCall alloc] charon_initWithUUID:[NSUUID UUID] outgoing:[state isEqualToString:CTCallStateDialing]];
        @synchronized (self) {
            _calls[identifier] = known;
        }
        [[CharonCallBroker shared] addCall:known];
    }
    if ([state isEqualToString:CTCallStateConnected] && !known.hasConnected) {
        known.charon_dateConnected = [NSDate date];
        [known charon_setHasConnected:YES];
        [[CharonCallBroker shared] callChanged:known];
    }
}

@end
