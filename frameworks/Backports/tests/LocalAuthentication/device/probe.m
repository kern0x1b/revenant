#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <stdio.h>

static void report(const char *label, LAPolicy policy)
{
    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;
    BOOL can = [context canEvaluatePolicy:policy error:&error];
    printf("probe: %s canEvaluatePolicy=%d code=%ld domain=%s description=%s\n", label, can, (long)error.code,
           error.domain.UTF8String, error.localizedDescription.UTF8String);
}

static void evaluate(const char *label, LAPolicy policy)
{
    LAContext *context = [[LAContext alloc] init];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block BOOL granted = YES;
    __block NSInteger code = 0;
    [context evaluatePolicy:policy localizedReason:@"probe" reply:^(BOOL success, NSError *error) {
        granted = success;
        code = error.code;
        dispatch_semaphore_signal(done);
    }];
    long timedOut = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    printf("probe: %s evaluatePolicy success=%d code=%ld timedOut=%ld\n", label, granted, (long)code, timedOut);
}

int main(void)
{
    @autoreleasepool {
        report("biometrics", LAPolicyDeviceOwnerAuthenticationWithBiometrics);
        report("device-owner", LAPolicyDeviceOwnerAuthentication);
        evaluate("biometrics", LAPolicyDeviceOwnerAuthenticationWithBiometrics);
        evaluate("device-owner", LAPolicyDeviceOwnerAuthentication);
    }
    return 0;
}
