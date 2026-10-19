#import <CallKit/CallKit.h>

typedef NS_ENUM(NSInteger, RevenantCallEvent) {
    RevenantCallEventAppeared,
    RevenantCallEventChanged,
    RevenantCallEventEnded
};

@interface CXAction ()
- (instancetype)revenant_initWithUUID:(NSUUID *)UUID __attribute__((objc_method_family(init)));
@property (nonatomic, weak) CXProvider *revenant_provider;
@property (nonatomic, weak) CXTransaction *revenant_transaction;
@property (nonatomic, readonly) BOOL revenant_fulfilled;
- (void)revenant_setComplete:(BOOL)complete;
- (SEL)revenant_performSelector;
+ (NSTimeInterval)revenant_timeout;
- (void)revenant_timedOut;
@end

@interface CXCallAction ()
@property (nonatomic) NSDate *revenant_date;
- (void)revenant_completeWithDate:(NSDate *)date;
@end

@interface CXCallUpdate ()
- (void)revenant_applyOver:(CXCallUpdate *)previous;
@end

@interface CXTransaction ()
@property (nonatomic, weak) CXProvider *revenant_provider;
- (void)revenant_actionCompleted:(CXAction *)action;
@end

@interface CXCall ()
- (instancetype)revenant_initWithUUID:(NSUUID *)UUID outgoing:(BOOL)outgoing __attribute__((objc_method_family(init)));
@property (nonatomic, weak) CXProvider *revenant_provider;
@property (nonatomic, copy) CXCallUpdate *revenant_update;
@property (nonatomic) NSDate *revenant_dateStartedConnecting;
@property (nonatomic) NSDate *revenant_dateConnected;
@property (nonatomic) NSDate *revenant_dateEnded;
@property (nonatomic) CXCallEndedReason revenant_endedReason;
@property (nonatomic) BOOL revenant_muted;
@property (nonatomic, copy) NSUUID *revenant_groupedWith;
- (void)revenant_setOnHold:(BOOL)onHold;
- (void)revenant_setHasConnected:(BOOL)hasConnected;
- (void)revenant_setHasEnded:(BOOL)hasEnded;
- (CXCall *)revenant_snapshot;
@end

@interface CXCallObserver ()
- (void)revenant_callChanged:(CXCall *)call;
@end

@interface CXProvider ()
- (void)revenant_execute:(CXTransaction *)transaction;
- (void)revenant_removeTransaction:(CXTransaction *)transaction;
- (void)revenant_actionTimedOut:(CXAction *)action;
- (BOOL)revenant_isValid;
- (void)revenant_audioSessionActivated:(id)session;
- (void)revenant_audioSessionDeactivated:(id)session;
- (id<CXProviderDelegate>)revenant_delegate;
- (void)revenant_presentIncomingCall:(CXCall *)call;
@property (nonatomic, readonly) dispatch_queue_t revenant_queue;
@end

@interface RevenantCallBroker : NSObject

+ (instancetype)shared;

- (void)addProvider:(CXProvider *)provider;
- (void)removeProvider:(CXProvider *)provider;
- (CXProvider *)anyProvider;

- (void)addObserver:(CXCallObserver *)observer;
- (void)removeObserver:(CXCallObserver *)observer;

- (NSArray<CXCall *> *)calls;
- (CXCall *)callWithUUID:(NSUUID *)UUID;
- (NSArray<CXCall *> *)callsOfProvider:(CXProvider *)provider;

- (BOOL)addCall:(CXCall *)call;
- (void)applyAction:(CXAction *)action;
- (void)removeCall:(CXCall *)call;
- (void)callChanged:(CXCall *)call;
- (void)callConnected:(CXCall *)call;

- (NSUInteger)groupsOfProvider:(CXProvider *)provider;

@end

@interface RevenantCallTelephony : NSObject
+ (instancetype)shared;
- (void)start;
@end

@interface RevenantCallAudio : NSObject
+ (instancetype)shared;
- (void)callConnectedFor:(CXProvider *)provider;
- (void)callEndedFor:(CXProvider *)provider;
@end

@interface RevenantCallScreen : NSObject
+ (instancetype)shared;
- (void)present:(CXCall *)call of:(CXProvider *)provider;
- (void)dismiss:(CXCall *)call;
@end

extern NSString *const revenant_call_screen_folder;
extern NSError *revenant_callkit_error(NSString *domain, NSInteger code);
