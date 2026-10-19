#import <CallKit/CallKit.h>
#import <objc/runtime.h>
#import "callkit-cases.h"

// Every case here has to answer the same in the host's CallKit and in the
// port's classes, so nothing may depend on a call service being there: the
// host runs these without the VoIP entitlement, and a request that reaches
// callservicesd comes back refused. What is left is what an application reads
// off the objects themselves, which is most of what CallKit is before a call
// starts.

static NSString *flag(BOOL value)
{
    return value ? @"1" : @"0";
}

// The host test compiles the port's classes under names of their own, so a
// class name is recorded without that prefix and the two sides can be
// compared.
static NSString *named(Class cls)
{
    NSString *name = NSStringFromClass(cls);
    return [name hasPrefix:@"Charon"] ? [name substringFromIndex:6] : name;
}

static NSUUID *fixed(unsigned char last)
{
    unsigned char bytes[16] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, last};
    return [[NSUUID alloc] initWithUUIDBytes:bytes];
}

static void domains(CallKitRecorder record)
{
    record(@"domain.base", CXErrorDomain);
    record(@"domain.incoming", CXErrorDomainIncomingCall);
    record(@"domain.transaction", CXErrorDomainRequestTransaction);
    record(@"domain.directory", CXErrorDomainCallDirectoryManager);
    record(@"domain.notificationExtension", CXErrorDomainNotificationServiceExtension);
}

static void configuration(CallKitRecorder record)
{
    CXProviderConfiguration *made = [[CXProviderConfiguration alloc] init];
    record(@"configuration.defaults", [NSString stringWithFormat:@"groups=%lu perGroup=%lu video=%@ recents=%@ handles=%lu ringtone=%@ icon=%@",
                                       (unsigned long)made.maximumCallGroups, (unsigned long)made.maximumCallsPerCallGroup,
                                       flag(made.supportsVideo), flag(made.includesCallsInRecents),
                                       (unsigned long)made.supportedHandleTypes.count, flag(made.ringtoneSound != nil), flag(made.iconTemplateImageData != nil)]);

    CXProviderConfiguration *titled = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Charon"];
    record(@"configuration.titled", [NSString stringWithFormat:@"%@ groups=%lu", titled.localizedName, (unsigned long)titled.maximumCallGroups]);
    record(@"configuration.unnamed", flag(made.localizedName == nil));

    titled.maximumCallGroups = 7;
    titled.maximumCallsPerCallGroup = 9;
    titled.supportsVideo = YES;
    titled.includesCallsInRecents = NO;
    titled.ringtoneSound = @"ring.caf";
    titled.supportedHandleTypes = [NSSet setWithObjects:@(CXHandleTypeGeneric), @(CXHandleTypePhoneNumber), nil];
    CXProviderConfiguration *copied = [titled copy];
    record(@"configuration.copy", [NSString stringWithFormat:@"same=%@ groups=%lu perGroup=%lu video=%@ recents=%@ handles=%lu",
                                   flag(copied == titled), (unsigned long)copied.maximumCallGroups,
                                   (unsigned long)copied.maximumCallsPerCallGroup, flag(copied.supportsVideo), flag(copied.includesCallsInRecents),
                                   (unsigned long)copied.supportedHandleTypes.count]);
    // Two fields the host answers for as the CallKit of iOS 14 and later,
    // which no longer carries them: the localized name is deprecated and a
    // ringtone is kept as a resolved URL. The port follows the iOS 10 header
    // it implements, so these two are expected to differ and run.sh holds
    // them apart by name.
    record(@"configuration.deprecatedName", [NSString stringWithFormat:@"set=%@ copied=%@", titled.localizedName, copied.localizedName]);
    record(@"configuration.ringtone", [NSString stringWithFormat:@"set=%@ copied=%@", titled.ringtoneSound, copied.ringtoneSound]);
    titled.maximumCallGroups = 1;
    record(@"configuration.copy.detached", [NSString stringWithFormat:@"%lu", (unsigned long)copied.maximumCallGroups]);

    CXProvider *provider = [[CXProvider alloc] initWithConfiguration:copied];
    record(@"provider.configuration", [NSString stringWithFormat:@"same=%@ groups=%lu pending=%lu",
                                       flag(provider.configuration == copied), (unsigned long)provider.configuration.maximumCallGroups,
                                       (unsigned long)provider.pendingTransactions.count]);
    record(@"provider.pendingOfClass", [NSString stringWithFormat:@"%lu",
                                        (unsigned long)[provider pendingCallActionsOfClass:[CXEndCallAction class] withCallUUID:fixed(1)].count]);
    [provider invalidate];
}

static void handles(CallKitRecorder record)
{
    CXHandle *phone = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+15551234"];
    CXHandle *same = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+15551234"];
    CXHandle *other = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"+15551234"];
    CXHandle *mail = [[CXHandle alloc] initWithType:CXHandleTypeEmailAddress value:@"a@b.c"];
    record(@"handle.values", [NSString stringWithFormat:@"%ld %@ %ld %@ %ld %@", (long)phone.type, phone.value,
                              (long)other.type, other.value, (long)mail.type, mail.value]);
    // The hashes themselves are each implementation's own, so what is recorded
    // is that equal handles hash alike and unequal ones do not - which is all
    // a hash owes.
    record(@"handle.equality", [NSString stringWithFormat:@"same=%@ isEqual=%@ hash=%@ type=%@ self=%@",
                                flag([phone isEqualToHandle:same]), flag([phone isEqual:same]), flag(phone.hash == same.hash),
                                flag([phone isEqualToHandle:other]), flag([phone isEqualToHandle:phone])]);
    record(@"handle.hashSpread", [NSString stringWithFormat:@"type=%@ value=%@ both=%@",
                                  flag(phone.hash != other.hash), flag(phone.hash != mail.hash),
                                  flag(other.hash != mail.hash)]);
    record(@"handle.notAHandle", flag([phone isEqual:@"+15551234"]));
    CXHandle *copied = [phone copy];
    record(@"handle.copy", [NSString stringWithFormat:@"same=%@ equal=%@", flag(copied == phone), flag([copied isEqualToHandle:phone])]);
    record(@"handle.secureCoding", flag([CXHandle supportsSecureCoding]));

    NSError *failure = nil;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:phone requiringSecureCoding:YES error:&failure];
    CXHandle *read = archive ? [NSKeyedUnarchiver unarchivedObjectOfClass:[CXHandle class] fromData:archive error:&failure] : nil;
    record(@"handle.roundTrip", [NSString stringWithFormat:@"archived=%@ equal=%@ error=%@",
                                 flag(archive != nil), flag([read isEqualToHandle:phone]), flag(failure != nil)]);
}

static void actions(CallKitRecorder record)
{
    NSUUID *callUUID = fixed(1);
    CXStartCallAction *start = [[CXStartCallAction alloc] initWithCallUUID:callUUID
                                                                    handle:[[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+1"]];
    record(@"action.identity", [NSString stringWithFormat:@"callUUID=%@ ownUUID=%@ ownNonNil=%@",
                                flag([start.callUUID isEqual:callUUID]), flag([start.UUID isEqual:callUUID]), flag(start.UUID != nil)]);
    record(@"action.defaults", [NSString stringWithFormat:@"complete=%@ video=%@ contact=%@ handle=%@",
                                flag(start.isComplete), flag(start.isVideo), flag(start.contactIdentifier != nil), start.handle.value]);

    // The deadline is the action's own, from the moment it was made, and it is
    // there before any provider has seen the action.
    NSUUID *another = fixed(9);
    NSArray *timed = @[[[CXAction alloc] init],
                       [[CXStartCallAction alloc] initWithCallUUID:another handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"t"]],
                       [[CXAnswerCallAction alloc] initWithCallUUID:another],
                       [[CXEndCallAction alloc] initWithCallUUID:another],
                       [[CXSetHeldCallAction alloc] initWithCallUUID:another onHold:YES],
                       [[CXSetMutedCallAction alloc] initWithCallUUID:another muted:YES],
                       [[CXSetGroupCallAction alloc] initWithCallUUID:another callUUIDToGroupWith:nil],
                       [[CXPlayDTMFCallAction alloc] initWithCallUUID:another digits:@"1" type:CXPlayDTMFCallActionTypeSingleTone]];
    NSMutableArray *deadlines = [NSMutableArray array];
    for (CXAction *action in timed)
        [deadlines addObject:[NSString stringWithFormat:@"%@=%ld", named([action class]), (long)([action.timeoutDate timeIntervalSinceNow] + 0.5)]];
    record(@"action.timeouts", [deadlines componentsJoinedByString:@" "]);

    // Nothing holds this action, so nothing performs it, and fulfilling or
    // failing it leaves it as it was.
    [start fulfill];
    record(@"action.fulfillUnheld", flag(start.isComplete));
    [start fail];
    record(@"action.failUnheld", flag(start.isComplete));
    [start fulfillWithDateStarted:[NSDate dateWithTimeIntervalSince1970:0]];
    record(@"action.fulfillWithDateUnheld", flag(start.isComplete));

    start.contactIdentifier = @"person";
    start.video = YES;
    CXStartCallAction *copied = [start copy];
    record(@"action.copy", [NSString stringWithFormat:@"same=%@ class=%@ uuid=%@ callUUID=%@ contact=%@ video=%@ handle=%@",
                            flag(copied == start), named([copied class]), flag([copied.UUID isEqual:start.UUID]),
                            flag([copied.callUUID isEqual:start.callUUID]), copied.contactIdentifier, flag(copied.isVideo), copied.handle.value]);

    CXAnswerCallAction *answer = [[CXAnswerCallAction alloc] initWithCallUUID:callUUID];
    CXEndCallAction *end = [[CXEndCallAction alloc] initWithCallUUID:callUUID];
    CXSetHeldCallAction *held = [[CXSetHeldCallAction alloc] initWithCallUUID:callUUID onHold:YES];
    CXSetMutedCallAction *muted = [[CXSetMutedCallAction alloc] initWithCallUUID:callUUID muted:YES];
    CXSetGroupCallAction *grouped = [[CXSetGroupCallAction alloc] initWithCallUUID:callUUID callUUIDToGroupWith:fixed(2)];
    CXPlayDTMFCallAction *dtmf = [[CXPlayDTMFCallAction alloc] initWithCallUUID:callUUID digits:@"123" type:CXPlayDTMFCallActionTypeSoftPause];
    record(@"action.kinds", [NSString stringWithFormat:@"answer=%@ end=%@ held=%@ muted=%@ group=%@ digits=%@ type=%ld",
                             flag([answer.callUUID isEqual:callUUID]), flag([end.callUUID isEqual:callUUID]),
                             flag(held.isOnHold), flag(muted.isMuted), flag([grouped.callUUIDToGroupWith isEqual:fixed(2)]),
                             dtmf.digits, (long)dtmf.type]);
    held.onHold = NO;
    muted.muted = NO;
    grouped.callUUIDToGroupWith = nil;
    dtmf.digits = @"45";
    dtmf.type = CXPlayDTMFCallActionTypeHardPause;
    record(@"action.setters", [NSString stringWithFormat:@"held=%@ muted=%@ group=%@ digits=%@ type=%ld",
                               flag(held.isOnHold), flag(muted.isMuted), flag(grouped.callUUIDToGroupWith != nil), dtmf.digits, (long)dtmf.type]);
    record(@"action.classes", [NSString stringWithFormat:@"%@ %@ %@ %@",
                               named([CXStartCallAction superclass]), named([CXCallAction superclass]),
                               named([CXAction superclass]), flag([start isKindOfClass:[CXCallAction class]])]);
    record(@"action.secureCoding", flag([CXAction supportsSecureCoding]));
}

static void transactions(CallKitRecorder record)
{
    CXTransaction *empty = [[CXTransaction alloc] initWithActions:@[]];
    record(@"transaction.empty", [NSString stringWithFormat:@"complete=%@ actions=%lu uuid=%@",
                                  flag(empty.isComplete), (unsigned long)empty.actions.count, flag(empty.UUID != nil)]);

    CXEndCallAction *end = [[CXEndCallAction alloc] initWithCallUUID:fixed(3)];
    CXTransaction *one = [[CXTransaction alloc] initWithAction:end];
    record(@"transaction.one", [NSString stringWithFormat:@"complete=%@ actions=%lu identical=%@",
                                flag(one.isComplete), (unsigned long)one.actions.count, flag(one.actions.firstObject == end)]);

    CXTransaction *built = [[CXTransaction alloc] initWithActions:@[]];
    [built addAction:end];
    [built addAction:[[CXSetHeldCallAction alloc] initWithCallUUID:fixed(3) onHold:YES]];
    record(@"transaction.added", [NSString stringWithFormat:@"actions=%lu complete=%@", (unsigned long)built.actions.count, flag(built.isComplete)]);

    CXTransaction *copied = [built copy];
    record(@"transaction.copy", [NSString stringWithFormat:@"same=%@ actions=%lu firstIdentical=%@ firstClass=%@ uuid=%@",
                                 flag(copied == built), (unsigned long)copied.actions.count, flag(copied.actions.firstObject == end),
                                 named([copied.actions.firstObject class]), flag([copied.UUID isEqual:built.UUID])]);
    record(@"transaction.secureCoding", flag([CXTransaction supportsSecureCoding]));
}

static void updates(CallKitRecorder record)
{
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    record(@"update.defaults", [NSString stringWithFormat:@"handle=%@ name=%@ hold=%@ group=%@ ungroup=%@ dtmf=%@ video=%@",
                                flag(update.remoteHandle != nil), flag(update.localizedCallerName != nil),
                                flag(update.supportsHolding), flag(update.supportsGrouping), flag(update.supportsUngrouping),
                                flag(update.supportsDTMF), flag(update.hasVideo)]);
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"who"];
    update.localizedCallerName = @"Who";
    update.supportsHolding = YES;
    update.supportsGrouping = YES;
    update.supportsUngrouping = YES;
    update.supportsDTMF = YES;
    update.hasVideo = YES;
    CXCallUpdate *copied = [update copy];
    record(@"update.copy", [NSString stringWithFormat:@"same=%@ handle=%@ name=%@ hold=%@ group=%@ ungroup=%@ dtmf=%@ video=%@",
                            flag(copied == update), copied.remoteHandle.value, copied.localizedCallerName,
                            flag(copied.supportsHolding), flag(copied.supportsGrouping), flag(copied.supportsUngrouping),
                            flag(copied.supportsDTMF), flag(copied.hasVideo)]);
    update.localizedCallerName = @"Other";
    record(@"update.copy.detached", copied.localizedCallerName);
}

static void controllers(CallKitRecorder record)
{
    CXCallController *controller = [[CXCallController alloc] init];
    record(@"controller.observer", [NSString stringWithFormat:@"nonNil=%@ stable=%@ calls=%lu",
                                    flag(controller.callObserver != nil), flag(controller.callObserver == controller.callObserver),
                                    (unsigned long)controller.callObserver.calls.count]);
    CXCallController *queued = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
    record(@"controller.queued", [NSString stringWithFormat:@"nonNil=%@ shared=%@",
                                  flag(queued.callObserver != nil), flag(queued.callObserver == controller.callObserver)]);
    CXCallObserver *observer = [[CXCallObserver alloc] init];
    record(@"observer.empty", [NSString stringWithFormat:@"%lu", (unsigned long)observer.calls.count]);
    [observer setDelegate:nil queue:nil];
    record(@"observer.nilDelegate", [NSString stringWithFormat:@"%lu", (unsigned long)observer.calls.count]);
}

static void wait_for(BOOL (^done)(void))
{
    for (int i = 0; i < 250 && !done(); i++)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static NSString *described(NSError *error)
{
    return error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code] : @"none";
}

// A call directory is an extension the host's CallKit manages through a service of its own, which macOS does not
// run: its answers for an identifier are what a process with no such service gets, and are named divergent in the
// host test. The queue the answers come on is the host's to tell.
static void directoryManager(CallKitRecorder record)
{
    CXCallDirectoryManager *manager = [CXCallDirectoryManager sharedInstance];
    record(@"directoryManager.shared", [NSString stringWithFormat:@"same=%@ class=%@", flag(manager == [CXCallDirectoryManager sharedInstance]), named([manager class])]);
    NSString *identifier = @"space.kern0x1b.charon.CallDirectory";
    __block BOOL reloaded = NO, reloadedOnMain = NO, answered = NO, answeredOnMain = NO;
    __block NSError *reloadError = nil, *statusError = nil;
    __block CXCallDirectoryEnabledStatus status = (CXCallDirectoryEnabledStatus)-1;
    [manager reloadExtensionWithIdentifier:identifier completionHandler:^(NSError *error) {
        reloadError = error;
        reloadedOnMain = [NSThread isMainThread];
        reloaded = YES;
    }];
    wait_for(^{ return reloaded; });
    [manager getEnabledStatusForExtensionWithIdentifier:identifier completionHandler:^(CXCallDirectoryEnabledStatus enabledStatus, NSError *error) {
        status = enabledStatus;
        statusError = error;
        answeredOnMain = [NSThread isMainThread];
        answered = YES;
    }];
    wait_for(^{ return answered; });
    record(@"directoryManager.reload", [NSString stringWithFormat:@"answered=%@ error=%@", flag(reloaded), described(reloadError)]);
    record(@"directoryManager.status", [NSString stringWithFormat:@"answered=%@ status=%ld error=%@", flag(answered), (long)status, described(statusError)]);
    record(@"directoryManager.queues", [NSString stringWithFormat:@"reload main=%@ status main=%@", flag(reloadedOnMain), flag(answeredOnMain)]);
    [manager reloadExtensionWithIdentifier:identifier completionHandler:nil];
    record(@"directoryManager.nilCompletion", @"returned");
    if ([manager respondsToSelector:@selector(openSettingsWithCompletionHandler:)]) {
        __block BOOL opened = NO;
        __block NSError *settingsError = nil;
        [manager openSettingsWithCompletionHandler:^(NSError *error) {
            settingsError = error;
            opened = YES;
        }];
        wait_for(^{ return opened; });
        record(@"directoryManager.settings", [NSString stringWithFormat:@"answered=%@ error=%@", flag(opened), described(settingsError)]);
    } else {
        record(@"directoryManager.settings", @"not answered");
    }
}

// What an extension's principal class and its context are without a host to hand them a request: the host's own
// answer for a context an application makes itself.
static void directoryExtension(CallKitRecorder record)
{
    CXCallDirectoryExtensionContext *context = [[CXCallDirectoryExtensionContext alloc] init];
    record(@"directoryContext.made", [NSString stringWithFormat:@"class=%@ super=%@ incremental=%@ delegate=%@ items=%lu",
                                      named([context class]), named(class_getSuperclass([context class])), flag(context.isIncremental),
                                      flag(context.delegate != nil), (unsigned long)context.inputItems.count]);
    [context addBlockingEntryWithNextSequentialPhoneNumber:18005550100];
    [context addIdentificationEntryWithNextSequentialPhoneNumber:18005550101 label:@"Charon"];
    record(@"directoryContext.entries", @"returned");
    NSMutableArray *removals = [NSMutableArray array];
    NSArray *blocks = @[^{ [context removeBlockingEntryWithPhoneNumber:18005550100]; }, ^{ [context removeIdentificationEntryWithPhoneNumber:18005550101]; },
                        ^{ [context removeAllBlockingEntries]; }, ^{ [context removeAllIdentificationEntries]; }];
    for (dispatch_block_t removal in blocks) {
        @try {
            removal();
            [removals addObject:@"returned"];
        } @catch (NSException *exception) {
            [removals addObject:[NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]];
        }
    }
    record(@"directoryContext.removals", [removals componentsJoinedByString:@" | "]);
    __block BOOL completed = NO;
    [context completeRequestWithCompletionHandler:^(BOOL expired) {
        completed = YES;
    }];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    record(@"directoryContext.complete", [NSString stringWithFormat:@"answered=%@", flag(completed)]);
    CXCallDirectoryProvider *provider = [[CXCallDirectoryProvider alloc] init];
    [provider beginRequestWithExtensionContext:context];
    record(@"directoryProvider.begin", [NSString stringWithFormat:@"class=%@ super=%@ returned", named([provider class]), named(class_getSuperclass([provider class]))]);
}

// The VoIP push report of iOS 14.5 belongs to a Notification Service Extension; the host answers a process that is
// none and holds no notification filtering entitlement, as every caller on iOS 6 is.
static void voipPush(CallKitRecorder record)
{
    for (NSDictionary *payload in @[@{@"aps": @{}}, @{}]) {
        __block int calls = 0;
        __block NSError *given = nil;
        __block BOOL onMain = NO;
        [CXProvider reportNewIncomingVoIPPushPayload:payload completion:^(NSError *error) {
            given = error;
            onMain = [NSThread isMainThread];
            calls++;
        }];
        BOOL beforeReturn = calls > 0;
        wait_for(^{ return (BOOL)(calls > 1); });
        record([NSString stringWithFormat:@"provider.voipPush.%lu", (unsigned long)payload.count],
               [NSString stringWithFormat:@"calls=%d beforeReturn=%@ main=%@ error=%@ userInfo=%lu", calls, flag(beforeReturn), flag(onMain),
                                          described(given), (unsigned long)given.userInfo.count]);
    }
    __block int calls = 0;
    __block BOOL onMain = YES, beforeReturn = NO, done = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [CXProvider reportNewIncomingVoIPPushPayload:@{} completion:^(NSError *error) {
            onMain = [NSThread isMainThread];
            calls++;
        }];
        beforeReturn = calls > 0;
        done = YES;
    });
    wait_for(^{ return done; });
    record(@"provider.voipPush.offMain", [NSString stringWithFormat:@"calls=%d beforeReturn=%@ main=%@", calls, flag(beforeReturn), flag(onMain)]);
    [CXProvider reportNewIncomingVoIPPushPayload:@{} completion:nil];
    record(@"provider.voipPush.nilCompletion", @"returned");
}

void callkit_run(CallKitRecorder record)
{
    domains(record);
    configuration(record);
    handles(record);
    actions(record);
    transactions(record);
    updates(record);
    controllers(record);
    directoryManager(record);
    directoryExtension(record);
    voipPush(record);
}
