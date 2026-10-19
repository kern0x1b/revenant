#import <LocalAuthentication/LocalAuthentication.h>
#import "check.h"

int main(void)
{
    @autoreleasepool {
        LAContext *context = [[LAContext alloc] init];
        NSError *error = nil;
        BOOL can = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
        CHECK(!can && error.code == LAErrorBiometryNotAvailable && [error.domain isEqualToString:LAErrorDomain] && [error.localizedDescription isEqualToString:@"Biometry is not available on this device."], "biometry is not available, with the system's error");
        CHECK(error.code == LAErrorTouchIDNotAvailable, "which is the code an application of iOS 8 compares with");
        error = nil;
        can = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error];
        CHECK(!can && error.code == LAErrorNotInteractive, "the passcode cannot be asked for");
        CHECK([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:NULL] == NO, "a nil error is allowed");
        CHECK(context.evaluatedPolicyDomainState == nil && context.biometryType == LABiometryTypeNone, "no state and no biometry type");
        context.touchIDAuthenticationAllowableReuseDuration = 100;
        context.localizedFallbackTitle = @"Use PIN";
        CHECK(context.touchIDAuthenticationAllowableReuseDuration == 100 && [context.localizedFallbackTitle isEqualToString:@"Use PIN"], "the settings are kept");
        CHECK(LATouchIDAuthenticationMaximumAllowableReuseDuration == 300, "the longest reuse");
        __block NSError *reply = nil;
        __block BOOL success = YES, onMain = YES, replied = NO;
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"why" reply:^(BOOL ok, NSError *failure) {
            success = ok;
            reply = failure;
            onMain = [NSThread isMainThread];
            replied = YES;
        }];
        NSDate *end = [NSDate dateWithTimeIntervalSinceNow:3];
        while (!replied && end.timeIntervalSinceNow > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        CHECK(replied && !success && reply.code == LAErrorBiometryNotAvailable && !onMain, "an evaluation is answered with the error, off the main thread");
        NSString *raised = @"none";
        @try {
            [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"" reply:^(BOOL ok, NSError *failure) {}];
        } @catch (NSException *exception) {
            raised = exception.name;
        }
        CHECK([raised isEqualToString:NSInvalidArgumentException], "an empty reason is refused");
        raised = @"none";
        @try {
            [context canEvaluatePolicy:(LAPolicy)99 error:NULL];
        } @catch (NSException *exception) {
            raised = exception.name;
        }
        CHECK([raised isEqualToString:NSInvalidArgumentException], "an unknown policy is refused");
        CHECK([context setCredential:[@"x" dataUsingEncoding:NSUTF8StringEncoding] type:LACredentialTypeApplicationPassword] && [context isCredentialSet:LACredentialTypeApplicationPassword] && [context setCredential:nil type:LACredentialTypeApplicationPassword] && ![context isCredentialSet:LACredentialTypeApplicationPassword], "a credential is kept and taken away");
        [context invalidate];
        error = nil;
        can = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
        CHECK(!can && error.code == LAErrorInvalidContext, "an invalidated context says so");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
