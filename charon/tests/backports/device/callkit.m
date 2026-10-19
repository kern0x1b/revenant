#import <CallKit/CallKit.h>
#import <CoreTelephony/CTCallCenter.h>
#import <AVFoundation/AVAudioSession.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"
#import "callkit-cases.h"
#import "callkit-expectations.h"

// The host cannot run a transaction - a tool without the VoIP entitlement
// never gets past CallKit's own check - so the machinery is held here: a
// provider, a call controller and an observer of one process, the calls they
// make between them, and the order the delegate is called in.

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

@interface CharonCallDelegate : NSObject <CXProviderDelegate, CXCallObserverDelegate>
@property (nonatomic) NSMutableArray<NSString *> *log;
@property (nonatomic) BOOL takesTransactions;
@property (nonatomic) BOOL failsEverything;
@property (nonatomic) BOOL leavesActionsAlone;
@property (nonatomic) AVAudioSession *activated;
@property (nonatomic) AVAudioSession *deactivated;
@end

@implementation CharonCallDelegate

- (instancetype)init
{
    if ((self = [super init]))
        _log = [NSMutableArray array];
    return self;
}

- (void)finish:(CXAction *)action
{
    if (_leavesActionsAlone)
        return;
    if (_failsEverything)
        [action fail];
    else
        [action fulfill];
}

- (void)providerDidReset:(CXProvider *)provider { [_log addObject:@"reset"]; }
- (void)providerDidBegin:(CXProvider *)provider { [_log addObject:@"begin"]; }

- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction
{
    if (!_takesTransactions)
        return NO;
    [_log addObject:[NSString stringWithFormat:@"execute(%lu)", (unsigned long)transaction.actions.count]];
    for (CXAction *action in transaction.actions)
        [self finish:action];
    return YES;
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action
{
    [_log addObject:@"start"];
    [self finish:action];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
    [_log addObject:@"answer"];
    [self finish:action];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action
{
    [_log addObject:@"end"];
    [self finish:action];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action
{
    [_log addObject:[NSString stringWithFormat:@"held(%d)", action.isOnHold]];
    [self finish:action];
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action
{
    [_log addObject:@"timedOut"];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession
{
    _activated = audioSession;
    [_log addObject:@"audioActivated"];
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
    _deactivated = audioSession;
    [_log addObject:@"audioDeactivated"];
}

- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call
{
    [_log addObject:[NSString stringWithFormat:@"changed(out=%d connected=%d held=%d ended=%d)",
                     call.isOutgoing, call.hasConnected, call.isOnHold, call.hasEnded]];
}

@end

static void compare(void)
{
    NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:callkit_expectations length:strlen(callkit_expectations)] options:0 error:NULL];
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    callkit_run(^(NSString *name, NSString *value) { records[name] = value; });
    for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if ([expected[name] isEqualToString:records[name]])
            charon_check(YES, name.UTF8String, nil);
        else
            charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
    }
    CHECK(records.count == expected.count, "the device answers every record the host did and no other");
}

static void from_the_backports(void)
{
    CHECK_EQUAL(image_of([CXProvider class]), @"libCallKitBackports.dylib", "CXProvider comes from the backports");
    CHECK_EQUAL(image_of([CXCallController class]), @"libCallKitBackports.dylib", "CXCallController comes from the backports");
    CHECK_EQUAL(image_of([CXHandle class]), @"libCallKitBackports.dylib", "CXHandle comes from the backports");
    CHECK_EQUAL(image_of(NSClassFromString(@"CXCallDirectoryManager")), @"libCallKitBackports.dylib", "the call directory manager comes from the backports");
    CHECK_EQUAL(image_of(NSClassFromString(@"CXCallDirectoryProvider")), @"libCallKitBackports.dylib", "and so does the call directory provider");
    CHECK_EQUAL(image_of(NSClassFromString(@"CXCallDirectoryExtensionContext")), @"libCallKitBackports.dylib", "and its context");
    CHECK_EQUAL(image_of(class_getSuperclass(NSClassFromString(@"CXCallDirectoryExtensionContext"))), @"libFoundationBackports.dylib",
                "whose NSExtensionContext is the package's on iOS 6");
    Method push = class_getClassMethod([CXProvider class], @selector(reportNewIncomingVoIPPushPayload:completion:));
    Dl_info pushImage;
    CHECK(push && dladdr((const void *)method_getImplementation(push), &pushImage) && [@(pushImage.dli_fname).lastPathComponent isEqualToString:@"libCallKitBackports.dylib"],
          "the iOS 14.5 push report is there, from the backports");
}

static CXProvider *provider_with(CharonCallDelegate *delegate)
{
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Charon"];
    CXProvider *provider = [[CXProvider alloc] initWithConfiguration:configuration];
    [provider setDelegate:delegate queue:dispatch_get_main_queue()];
    spin(0.1);
    return provider;
}

static void an_incoming_call(void)
{
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    CXProvider *provider = provider_with(delegate);
    CHECK([delegate.log containsObject:@"begin"], "a delegate is told the provider began");

    CXCallObserver *observer = [[CXCallObserver alloc] init];
    [observer setDelegate:delegate queue:dispatch_get_main_queue()];

    NSUUID *call = [NSUUID UUID];
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+15551234"];
    update.localizedCallerName = @"Caller";
    __block int reported = 0;
    __block NSError *failure = nil;
    [provider reportNewIncomingCallWithUUID:call update:update completion:^(NSError *error) { reported++; failure = error; }];
    spin(0.1);
    CHECK(reported == 1 && failure == nil, "an incoming call is reported without an error");
    CHECK(observer.calls.count == 1, "and the observer sees one call");
    CHECK(!observer.calls.firstObject.isOutgoing && !observer.calls.firstObject.hasConnected, "incoming and not yet connected");
    CHECK([observer.calls.firstObject.UUID isEqual:call], "under the UUID it was reported with");

    __block NSError *second = nil;
    [provider reportNewIncomingCallWithUUID:call update:update completion:^(NSError *error) { second = error; }];
    spin(0.1);
    CHECK_EQUAL(second.domain, CXErrorDomainIncomingCall, "the same UUID twice fails in the incoming call domain");
    CHECK(second.code == CXErrorCodeIncomingCallErrorCallUUIDAlreadyExists, "as CallUUIDAlreadyExists");
    CHECK(observer.calls.count == 1, "and no second call is made");

    CXCallController *controller = [[CXCallController alloc] init];
    __block int answered = 0;
    [delegate.log removeAllObjects];
    [controller requestTransactionWithAction:[[CXAnswerCallAction alloc] initWithCallUUID:call] completion:^(NSError *error) { answered = error ? -1 : 1; }];
    spin(0.2);
    CHECK(answered == 1, "answering is requested without an error");
    CHECK([delegate.log containsObject:@"answer"], "the delegate is asked to answer");
    CHECK(observer.calls.firstObject.hasConnected, "and the call is connected once the action is fulfilled");

    [delegate.log removeAllObjects];
    [controller requestTransactionWithAction:[[CXSetHeldCallAction alloc] initWithCallUUID:call onHold:YES] completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CHECK([delegate.log containsObject:@"held(1)"], "the delegate is asked to hold");
    CHECK(observer.calls.firstObject.isOnHold, "and the call is held");

    [delegate.log removeAllObjects];
    [controller requestTransactionWithAction:[[CXEndCallAction alloc] initWithCallUUID:call] completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CHECK([delegate.log containsObject:@"end"], "the delegate is asked to end");
    CHECK(observer.calls.count == 0, "and the call is gone");

    [provider invalidate];
    spin(0.1);
}

static void an_outgoing_call(void)
{
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    CXProvider *provider = provider_with(delegate);
    CXCallController *controller = [[CXCallController alloc] init];
    NSUUID *call = [NSUUID UUID];
    CXStartCallAction *start = [[CXStartCallAction alloc] initWithCallUUID:call
                                                                    handle:[[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+15551234"]];
    __block int requested = 0;
    [controller requestTransactionWithAction:start completion:^(NSError *error) { requested = error ? -1 : 1; }];
    spin(0.2);
    CHECK(requested == 1, "starting a call is requested without an error");
    CHECK([delegate.log containsObject:@"start"], "the delegate is asked to start it");
    CHECK(controller.callObserver.calls.count == 1, "the call is there as soon as the transaction is requested");
    CHECK(controller.callObserver.calls.firstObject.isOutgoing, "and it is outgoing");
    CHECK(!controller.callObserver.calls.firstObject.hasConnected, "fulfilling the start action does not connect it");

    [provider reportOutgoingCallWithUUID:call startedConnectingAtDate:nil];
    [provider reportOutgoingCallWithUUID:call connectedAtDate:nil];
    spin(0.1);
    CHECK(controller.callObserver.calls.firstObject.hasConnected, "reporting it connected does");

    __block NSError *again = nil;
    [controller requestTransactionWithAction:[[CXStartCallAction alloc] initWithCallUUID:call
                                                                                  handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"x"]]
                                  completion:^(NSError *error) { again = error; }];
    spin(0.1);
    CHECK(again.code == CXErrorCodeRequestTransactionErrorCallUUIDAlreadyExists, "starting the same call again is refused as CallUUIDAlreadyExists");

    [provider reportCallWithUUID:call endedAtDate:nil reason:CXCallEndedReasonRemoteEnded];
    spin(0.1);
    CHECK(controller.callObserver.calls.count == 0, "reporting the call ended takes it away");

    [provider invalidate];
    spin(0.1);
}

static void refusals(void)
{
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    CXProvider *provider = provider_with(delegate);
    CXCallController *controller = [[CXCallController alloc] init];

    __block NSError *empty = nil;
    [controller requestTransaction:[[CXTransaction alloc] initWithActions:@[]] completion:^(NSError *error) { empty = error; }];
    spin(0.1);
    CHECK_EQUAL(empty.domain, CXErrorDomainRequestTransaction, "an empty transaction fails in the transaction domain");
    CHECK(empty.code == CXErrorCodeRequestTransactionErrorEmptyTransaction, "as EmptyTransaction");

    __block NSError *unknown = nil;
    [controller requestTransactionWithAction:[[CXEndCallAction alloc] initWithCallUUID:[NSUUID UUID]] completion:^(NSError *error) { unknown = error; }];
    spin(0.1);
    CHECK(unknown.code == CXErrorCodeRequestTransactionErrorUnknownCallUUID, "ending a call that is not there is UnknownCallUUID");
    CHECK(unknown.userInfo.count == 0, "and the error carries no user info, as CallKit's do not");

    CXProviderConfiguration *narrow = provider.configuration;
    narrow.maximumCallGroups = 1;
    provider.configuration = narrow;
    [controller requestTransactionWithAction:[[CXStartCallAction alloc] initWithCallUUID:[NSUUID UUID]
                                                                                  handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"a"]]
                                  completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    __block NSError *full = nil;
    [controller requestTransactionWithAction:[[CXStartCallAction alloc] initWithCallUUID:[NSUUID UUID]
                                                                                  handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"b"]]
                                  completion:^(NSError *error) { full = error; }];
    spin(0.1);
    CHECK(full.code == CXErrorCodeRequestTransactionErrorMaximumCallGroupsReached, "a second call group past the configuration is MaximumCallGroupsReached");

    [provider invalidate];
    spin(0.1);
    CHECK([delegate.log containsObject:@"reset"], "invalidating tells the delegate the provider reset");
    CHECK(controller.callObserver.calls.count == 0, "and ends the calls it held");
}

static void a_whole_transaction(void)
{
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    delegate.takesTransactions = YES;
    CXProvider *provider = provider_with(delegate);
    CXCallController *controller = [[CXCallController alloc] init];
    NSUUID *call = [NSUUID UUID];
    [controller requestTransactionWithAction:[[CXStartCallAction alloc] initWithCallUUID:call
                                                                                  handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"a"]]
                                  completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CHECK([delegate.log containsObject:@"execute(1)"], "a delegate that takes transactions is given the transaction whole");
    CHECK(![delegate.log containsObject:@"start"], "and not the actions one by one");

    [delegate.log removeAllObjects];
    CXTransaction *both = [[CXTransaction alloc] initWithActions:@[[[CXSetHeldCallAction alloc] initWithCallUUID:call onHold:YES],
                                                                   [[CXEndCallAction alloc] initWithCallUUID:call]]];
    [controller requestTransaction:both completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CHECK([delegate.log containsObject:@"execute(2)"], "two actions reach it as one transaction");
    CHECK(both.isComplete, "which is complete once both actions are");
    CHECK(provider.pendingTransactions.count == 0, "and is no longer pending");

    [provider invalidate];
    spin(0.1);
}

static void a_failed_action(void)
{
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    delegate.failsEverything = YES;
    CXProvider *provider = provider_with(delegate);
    CXCallController *controller = [[CXCallController alloc] init];
    NSUUID *call = [NSUUID UUID];
    [controller requestTransactionWithAction:[[CXStartCallAction alloc] initWithCallUUID:call
                                                                                  handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"a"]]
                                  completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CHECK([delegate.log containsObject:@"start"], "the delegate is asked to start the call");
    CHECK(controller.callObserver.calls.count == 0, "and failing the start action ends the call it was for");

    [provider invalidate];
    spin(0.1);
}

static void an_unanswered_method(void)
{
    // The delegate answers no performPlayDTMFCallAction:, so nothing is going
    // to perform it and the action fails at once rather than hanging.
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    CXProvider *provider = provider_with(delegate);
    CXCallController *controller = [[CXCallController alloc] init];
    NSUUID *call = [NSUUID UUID];
    [controller requestTransactionWithAction:[[CXStartCallAction alloc] initWithCallUUID:call
                                                                                  handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"a"]]
                                  completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CXPlayDTMFCallAction *dtmf = [[CXPlayDTMFCallAction alloc] initWithCallUUID:call digits:@"1" type:CXPlayDTMFCallActionTypeSingleTone];
    [controller requestTransactionWithAction:dtmf completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CHECK(dtmf.isComplete, "an action the delegate does not answer for finishes at once");
    CHECK(controller.callObserver.calls.count == 1, "and the call it named is left alone, which is what failing it does");

    [provider invalidate];
    spin(0.1);
}

static void a_timeout(void)
{
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    delegate.leavesActionsAlone = YES;
    CXProvider *provider = provider_with(delegate);
    CXCallController *controller = [[CXCallController alloc] init];
    NSUUID *call = [NSUUID UUID];
    [controller requestTransactionWithAction:[[CXStartCallAction alloc] initWithCallUUID:call
                                                                                  handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"a"]]
                                  completion:^(NSError *error) { (void)error; }];
    spin(0.2);
    CXSetHeldCallAction *held = [[CXSetHeldCallAction alloc] initWithCallUUID:call onHold:YES];
    CHECK([held.timeoutDate timeIntervalSinceNow] > 4.0 && [held.timeoutDate timeIntervalSinceNow] <= 5.0, "a hold action has five seconds");
    [controller requestTransactionWithAction:held completion:^(NSError *error) { (void)error; }];
    spin(0.3);
    CHECK(!held.isComplete, "a delegate that neither fulfils nor fails leaves the action open");
    spin(5.2);
    CHECK(held.isComplete, "until its deadline, when it finishes");
    CHECK([delegate.log containsObject:@"timedOut"], "and the delegate is told it timed out");
    CHECK(!controller.callObserver.calls.firstObject.isOnHold, "a timed out hold does not hold the call");

    [provider invalidate];
    spin(0.1);
}


// CallKit activates the audio session when a call of the application connects
// and deactivates it when the last one has gone, and tells the delegate each
// time; the application sets its own category and mode, and nothing here
// touches those.
static void the_audio_session(void)
{
    CharonCallDelegate *delegate = [[CharonCallDelegate alloc] init];
    CXProvider *provider = provider_with(delegate);
    CXCallController *controller = [[CXCallController alloc] init];
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSString *category = session.category;

    NSUUID *call = [NSUUID UUID];
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"a"];
    [provider reportNewIncomingCallWithUUID:call update:update completion:^(NSError *error) { (void)error; }];
    spin(0.1);
    CHECK(delegate.activated == nil, "reporting a call does not activate the audio session");

    [controller requestTransactionWithAction:[[CXAnswerCallAction alloc] initWithCallUUID:call]
                                  completion:^(NSError *error) { (void)error; }];
    spin(0.3);
    CHECK(delegate.activated == session, "answering it activates the shared audio session");
    CHECK([delegate.log containsObject:@"audioActivated"], "and the delegate is told");
    CHECK_EQUAL(session.category, category, "the category is the application's own and is not changed");

    [controller requestTransactionWithAction:[[CXEndCallAction alloc] initWithCallUUID:call]
                                  completion:^(NSError *error) { (void)error; }];
    spin(0.3);
    CHECK(delegate.deactivated == session, "ending the last call deactivates it");
    CHECK([delegate.log containsObject:@"audioDeactivated"], "and the delegate is told that too");

    [provider invalidate];
    spin(0.1);
}

// The observer watches the release's own calls as well. Nothing here can
// place a cellular call, so what is held is that the watch is live, that it
// reports nothing when there is no call, and that an action on a call no
// provider of this process owns is refused rather than handed to a delegate
// that never made it.
static void the_release_own_calls(void)
{
    CHECK(NSClassFromString(@"CTCallCenter") != Nil, "the release has CTCallCenter, which is what the observer watches");
    CXCallObserver *observer = [[CXCallObserver alloc] init];
    spin(0.2);
    CTCallCenter *centre = [[CTCallCenter alloc] init];
    NSUInteger cellular = centre.currentCalls.count;
    CHECK(observer.calls.count == cellular, "the observer reports exactly the calls CoreTelephony holds");
    if (cellular == 0)
        charon_check(YES, "no call is in progress, so the cellular path is only held to being live", nil);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        compare();
        from_the_backports();
        an_incoming_call();
        an_outgoing_call();
        refusals();
        a_whole_transaction();
        a_failed_action();
        an_unanswered_method();
        a_timeout();
        the_audio_session();
        the_release_own_calls();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
