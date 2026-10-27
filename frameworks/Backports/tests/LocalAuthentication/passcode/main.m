#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "RevenantPasscode.h"

static int32_t stubStatus = 0;
static BOOL stubReachable = YES;
static int stubCalls = 0;
static NSString *stubBytes = nil;

bool RevenantPasscodeUnlockDevice(NSData *passcode, int32_t *status)
{
    stubCalls++;
    stubBytes = [[NSString alloc] initWithData:passcode encoding:NSUTF8StringEncoding];
    if (!stubReachable)
        return false;
    *status = stubStatus;
    return true;
}

static const char *name(RevenantPasscodeResult result)
{
    switch (result) {
    case RevenantPasscodeAccepted:
        return "accepted";
    case RevenantPasscodeRejected:
        return "rejected";
    case RevenantPasscodeUnavailable:
        return "unavailable";
    case RevenantPasscodeCancelled:
        return "cancelled";
    }
    return "unknown";
}

static void verify(const char *label, NSString *text, int32_t status, BOOL reachable)
{
    stubStatus = status;
    stubReachable = reachable;
    stubCalls = 0;
    stubBytes = nil;
    RevenantPasscodeResult result = RevenantPasscodeVerify(text, RevenantPasscodeStyleSimple);
    printf("verify %s %s calls=%d bytes=%s\n", label, name(result), stubCalls, stubBytes ? stubBytes.UTF8String : "-");
}

static const char *style(RevenantPasscodeStyle style)
{
    return style == RevenantPasscodeStyleSimple ? "simple" : "complex";
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        printf("map 0=%s -2=%s -1=%s -3=%s -8=%s -9=%s\n", name(RevenantPasscodeMapStatus(0)), name(RevenantPasscodeMapStatus(-2)),
               name(RevenantPasscodeMapStatus(-1)), name(RevenantPasscodeMapStatus(-3)), name(RevenantPasscodeMapStatus(-8)),
               name(RevenantPasscodeMapStatus(-9)));
        printf("style 0=%s 1=%s 2=%s 7=%s current=%s\n", style(RevenantPasscodeStyleForUnlockScreenType(0)),
               style(RevenantPasscodeStyleForUnlockScreenType(1)), style(RevenantPasscodeStyleForUnlockScreenType(2)),
               style(RevenantPasscodeStyleForUnlockScreenType(7)), style(RevenantPasscodeCurrentStyle()));
        printf("valid simple 1234=%d 123=%d 12a4=%d 12345=%d empty=%d\n", RevenantPasscodeIsValid(@"1234", RevenantPasscodeStyleSimple),
               RevenantPasscodeIsValid(@"123", RevenantPasscodeStyleSimple), RevenantPasscodeIsValid(@"12a4", RevenantPasscodeStyleSimple),
               RevenantPasscodeIsValid(@"12345", RevenantPasscodeStyleSimple), RevenantPasscodeIsValid(@"", RevenantPasscodeStyleSimple));
        printf("valid complex abc!=%d empty=%d\n", RevenantPasscodeIsValid(@"abc!", RevenantPasscodeStyleComplex),
               RevenantPasscodeIsValid(@"", RevenantPasscodeStyleComplex));
        verify("accepted", @"1234", 0, YES);
        verify("refused", @"1234", -2, YES);
        verify("rejected", @"1234", -1, YES);
        verify("rejected-3", @"1234", -3, YES);
        verify("unreachable", @"1234", 0, NO);
        verify("short", @"123", 0, YES);
        verify("letters", @"12a4", 0, YES);
        printf("outcome cancelled=%s\n", name(RevenantPasscodeOutcome(YES, @"1234", RevenantPasscodeStyleSimple)));
        printf("outcome ok=%s\n", name(RevenantPasscodeOutcome(NO, @"1234", RevenantPasscodeStyleSimple)));
        LAContext *context = [[LAContext alloc] init];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block BOOL success = YES;
        __block NSInteger code = 0;
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:@"Unlock" reply:^(BOOL ok, NSError *replyError) {
            success = ok;
            code = replyError.code;
            dispatch_semaphore_signal(done);
        }];
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        printf("la evaluate=%d code=%ld\n", success, (long)code);
        dispatch_semaphore_t presented = dispatch_semaphore_create(0);
        RevenantPasscodePresent(@"Unlock", RevenantPasscodeStyleSimple, ^(RevenantPasscodeResult result) {
            printf("present %s\n", name(result));
            dispatch_semaphore_signal(presented);
        });
        dispatch_semaphore_wait(presented, DISPATCH_TIME_FOREVER);
    }
    return 0;
}
