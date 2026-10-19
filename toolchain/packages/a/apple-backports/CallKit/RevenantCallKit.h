#import <CallKit/CallKit.h>

typedef NS_ENUM(NSInteger, CharonCallEvent) {
    CharonCallEventAppeared,
    CharonCallEventChanged,
    CharonCallEventEnded
};

@interface CXAction ()
- (instancetype)charon_initWithUUID:(NSUUID *)UUID __attribute__((objc_method_family(init)));
@property (nonatomic, weak) CXProvider *charon_provider;
@property (nonatomic, weak) CXTransaction *charon_transaction;
@property (nonatomic, readonly) BOOL charon_fulfilled;
- (void)charon_setComplete:(BOOL)complete;
- (SEL)charon_performSelector;
+ (NSTimeInterval)charon_timeout;
- (void)charon_timedOut;
@end

@interface CXCallAction ()
@property (nonatomic) NSDate *charon_date;
- (void)charon_completeWithDate:(NSDate *)date;
@end

@interface CXCallUpdate ()
- (void)charon_applyOver:(CXCallUpdate *)previous;
@end

@interface CXTransaction ()
@property (nonatomic, weak) CXProvider *charon_provider;
- (void)charon_actionCompleted:(CXAction *)action;
@end

@interface CXCall ()
- (instancetype)charon_initWithUUID:(NSUUID *)UUID outgoing:(BOOL)outgoing __attribute__((objc_method_family(init)));
@property (nonatomic, weak) CXProvider *charon_provider;
@property (nonatomic, copy) CXCallUpdate *charon_update;
@property (nonatomic) NSDate *charon_dateStartedConnecting;
@property (nonatomic) NSDate *charon_dateConnected;
@property (nonatomic) NSDate *charon_dateEnded;
@property (nonatomic) CXCallEndedReason charon_endedReason;
@property (nonatomic) BOOL charon_muted;
@property (nonatomic, copy) NSUUID *charon_groupedWith;
- (void)charon_setOnHold:(BOOL)onHold;
- (void)charon_setHasConnected:(BOOL)hasConnected;
- (void)charon_setHasEnded:(BOOL)hasEnded;
- (CXCall *)charon_snapshot;
@end

@interface CXCallObserver ()
- (void)charon_callChanged:(CXCall *)call;
@end

@interface CXProvider ()
- (void)charon_execute:(CXTransaction *)transaction;
- (void)charon_removeTransaction:(CXTransaction *)transaction;
- (void)charon_actionTimedOut:(CXAction *)action;
- (BOOL)charon_isValid;
- (void)charon_audioSessionActivated:(id)session;
- (void)charon_audioSessionDeactivated:(id)session;
- (id<CXProviderDelegate>)charon_delegate;
- (void)charon_presentIncomingCall:(CXCall *)call;
@property (nonatomic, readonly) dispatch_queue_t charon_queue;
@end

@interface CharonCallBroker : NSObject

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

@interface CharonCallTelephony : NSObject
+ (instancetype)shared;
- (void)start;
@end

@interface CharonCallAudio : NSObject
+ (instancetype)shared;
- (void)callConnectedFor:(CXProvider *)provider;
- (void)callEndedFor:(CXProvider *)provider;
@end

@interface CharonCallScreen : NSObject
+ (instancetype)shared;
- (void)present:(CXCall *)call of:(CXProvider *)provider;
- (void)dismiss:(CXCall *)call;
@end

extern NSString *const charon_call_screen_folder;
extern NSError *charon_callkit_error(NSString *domain, NSInteger code);
