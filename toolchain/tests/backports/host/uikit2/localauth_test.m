#import <LocalAuthentication/LocalAuthentication.h>
#import "check.h"

@interface CharonHostLAContext : NSObject
+ (BOOL)supportsSecureCoding;
- (BOOL)canEvaluatePolicy:(NSInteger)policy error:(NSError **)error;
- (void)evaluatePolicy:(NSInteger)policy localizedReason:(NSString *)reason reply:(void (^)(BOOL, NSError *))reply;
- (void)invalidate;
- (BOOL)setCredential:(NSData *)credential type:(NSInteger)type;
- (BOOL)isCredentialSet:(NSInteger)type;
@property (nonatomic, copy) NSString *localizedFallbackTitle;
@property (nonatomic, copy) NSString *localizedCancelTitle;
@property (nonatomic, strong) NSNumber *maxBiometryFailures;
@property (nonatomic, readonly) NSData *evaluatedPolicyDomainState;
@property (nonatomic) NSTimeInterval touchIDAuthenticationAllowableReuseDuration;
@property (nonatomic, copy) NSString *localizedReason;
@end

static void spin(NSTimeInterval seconds)
{
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"none";
}

static NSString *describe(NSError *error)
{
    return error ? [NSString stringWithFormat:@"%@ %ld %@ %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo[NSDebugDescriptionErrorKey]] : @"nil";
}

int main(void)
{
    @autoreleasepool {
        CharonHostLAContext *ours = [[CharonHostLAContext alloc] init];
        LAContext *system = [[LAContext alloc] init];
        charon_check(ours.localizedFallbackTitle == nil && ours.localizedCancelTitle == nil && ours.maxBiometryFailures == nil && ours.evaluatedPolicyDomainState == nil && ours.localizedReason == nil && ours.touchIDAuthenticationAllowableReuseDuration == 0
                     && system.localizedFallbackTitle == nil && system.localizedCancelTitle == nil && system.maxBiometryFailures == nil && system.evaluatedPolicyDomainState == nil && system.localizedReason == nil && system.touchIDAuthenticationAllowableReuseDuration == 0,
                     "a new context has no titles, no state and no reuse", @"a field differs");
        ours.localizedFallbackTitle = @"Use PIN";
        system.localizedFallbackTitle = @"Use PIN";
        ours.localizedCancelTitle = @"Stop";
        system.localizedCancelTitle = @"Stop";
        ours.maxBiometryFailures = @3;
        system.maxBiometryFailures = @3;
        ours.touchIDAuthenticationAllowableReuseDuration = 100;
        system.touchIDAuthenticationAllowableReuseDuration = 100;
        charon_check([ours.localizedFallbackTitle isEqual:system.localizedFallbackTitle] && [ours.localizedCancelTitle isEqual:system.localizedCancelTitle] && [ours.maxBiometryFailures isEqual:system.maxBiometryFailures] && ours.touchIDAuthenticationAllowableReuseDuration == system.touchIDAuthenticationAllowableReuseDuration, "the titles, the failures and the reuse are kept", @"a field differs");
        ours.touchIDAuthenticationAllowableReuseDuration = 100000;
        system.touchIDAuthenticationAllowableReuseDuration = 100000;
        charon_check(ours.touchIDAuthenticationAllowableReuseDuration == system.touchIDAuthenticationAllowableReuseDuration, "a reuse over the maximum is kept as it is", @"it is clamped");
        charon_check(LATouchIDAuthenticationMaximumAllowableReuseDuration == 300, "the maximum reuse", @"it differs");
        charon_check([LAErrorDomain isEqualToString:@"com.apple.LocalAuthentication"], "the error domain", @"it differs");

        for (NSNumber *policy in @[@99, @0, @5, @-1]) {
            NSString *one = raised(^{ [ours canEvaluatePolicy:policy.integerValue error:NULL]; });
            NSString *two = raised(^{ [system canEvaluatePolicy:(LAPolicy)policy.integerValue error:NULL]; });
            charon_check([one isEqualToString:two] && ![one isEqualToString:@"none"], [[NSString stringWithFormat:@"an unknown policy %@ raises the same exception", policy] UTF8String], ([NSString stringWithFormat:@"%@ != %@", one, two]));
        }
        for (NSString *reason in @[@"", @"x"]) {
            if (!reason.length) {
                NSString *one = raised(^{ [ours evaluatePolicy:1 localizedReason:reason reply:^(BOOL s, NSError *e) {}]; });
                NSString *two = raised(^{ [system evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:reason reply:^(BOOL s, NSError *e) {}]; });
                charon_check([one isEqualToString:two] && ![one isEqualToString:@"none"], "an empty reason raises the same exception", ([NSString stringWithFormat:@"%@ != %@", one, two]));
            }
        }
        charon_check([raised(^{ [ours evaluatePolicy:1 localizedReason:@"why" reply:nil]; }) isEqualToString:raised(^{ [system evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"why" reply:nil]; })], "no reply is allowed", @"it differs");

        CharonHostLAContext *invalidOurs = [[CharonHostLAContext alloc] init];
        LAContext *invalidSystem = [[LAContext alloc] init];
        [invalidOurs invalidate];
        [invalidSystem invalidate];
        for (NSNumber *policy in @[@1, @2]) {
            NSError *one = nil, *two = nil;
            BOOL first = [invalidOurs canEvaluatePolicy:policy.integerValue error:&one];
            BOOL second = [invalidSystem canEvaluatePolicy:(LAPolicy)policy.integerValue error:&two];
            charon_check(first == second && [describe(one) isEqualToString:describe(two)], [[NSString stringWithFormat:@"an invalidated context refuses policy %@ as the system's does", policy] UTF8String], ([NSString stringWithFormat:@"%@ != %@", describe(one), describe(two)]));
        }
        __block NSString *ourReply = nil, *systemReply = nil;
        __block BOOL ourMain = YES, systemMain = YES;
        [invalidOurs evaluatePolicy:1 localizedReason:@"why" reply:^(BOOL success, NSError *error) { ourReply = [NSString stringWithFormat:@"%d %@", success, describe(error)]; ourMain = [NSThread isMainThread]; }];
        [invalidSystem evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"why" reply:^(BOOL success, NSError *error) { systemReply = [NSString stringWithFormat:@"%d %@", success, describe(error)]; systemMain = [NSThread isMainThread]; }];
        spin(0.5);
        charon_check(ourReply && [ourReply isEqualToString:systemReply], "an invalidated context answers the same reply", ([NSString stringWithFormat:@"%@ != %@", ourReply, systemReply]));
        charon_check(ourMain == systemMain && !ourMain, "and replies off the main thread", @"it replies on the main thread");

        CharonHostLAContext *credentialOurs = [[CharonHostLAContext alloc] init];
        LAContext *credentialSystem = [[LAContext alloc] init];
        for (NSNumber *type in @[@0, @-1, @1, @2, @-3, @77]) {
            NSString *(^run)(id) = ^NSString *(id context) {
                NSInteger t = type.integerValue;
                @try {
                    BOOL set = [context setCredential:[@"x" dataUsingEncoding:NSUTF8StringEncoding] type:t];
                    BOOL isSet = [context isCredentialSet:t];
                    BOOL removed = [context setCredential:nil type:t];
                    BOOL after = [context isCredentialSet:t];
                    return [NSString stringWithFormat:@"%d %d %d %d", set, isSet, removed, after];
                } @catch (NSException *exception) {
                    return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
                }
            };
            NSString *one = run(credentialOurs), *two = run(credentialSystem);
            charon_check([one isEqualToString:two], [[NSString stringWithFormat:@"credential type %@", type] UTF8String], ([NSString stringWithFormat:@"%@ != %@", one, two]));
        }
        charon_check([credentialOurs setCredential:[NSData data] type:0] == [credentialSystem setCredential:[NSData data] type:LACredentialTypeApplicationPassword] && [credentialOurs isCredentialSet:0] == [credentialSystem isCredentialSet:LACredentialTypeApplicationPassword], "an empty credential is a credential", @"it differs");
        charon_check([(id)[LAContext class] supportsSecureCoding] == [(id)[CharonHostLAContext class] supportsSecureCoding], "the class supports secure coding as the system's does", @"it does not");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
