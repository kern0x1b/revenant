#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import "check.h"

// The port's ATTrackingManager against the host's own, asked the same questions. The host is macOS,
// which does not run the tracking authorization system: the header itself says a status asked in
// macOS is always notDetermined, and a request is answered at once. That is the answer a release
// without the system gives, so the two must agree on the status, on the thread the handler runs on
// and on the fact that it runs before the call returns.

@interface CharonHostATTrackingManager : NSObject
+ (ATTrackingManagerAuthorizationStatus)trackingAuthorizationStatus;
+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(ATTrackingManagerAuthorizationStatus status))completion;
@end

@interface SystemATTrackingManager : NSObject
+ (ATTrackingManagerAuthorizationStatus)trackingAuthorizationStatus;
+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(ATTrackingManagerAuthorizationStatus status))completion;
@end

@interface Answer : NSObject
@property (nonatomic) unsigned long status;
@property (nonatomic) int on_main;
@property (nonatomic) int before_return;
@property (nonatomic) int calls;
@end

@implementation Answer
@end

static Answer *ask(id manager)
{
    Answer *answer = [[Answer alloc] init];
    __block int returned = 0;
    [(id)manager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
        answer.status = (unsigned long)status;
        answer.on_main = [NSThread isMainThread] ? 1 : 0;
        answer.before_return = returned ? 0 : 1;
        answer.calls++;
    }];
    returned = 1;
    return answer;
}

static NSString *describe(Answer *answer)
{
    return [NSString stringWithFormat:@"status %lu, on main %d, before the call returned %d, %d call(s)",
            answer.status, answer.on_main, answer.before_return, answer.calls];
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    unsigned long port_status = (unsigned long)[CharonHostATTrackingManager trackingAuthorizationStatus];
    unsigned long system_status = (unsigned long)[ATTrackingManager trackingAuthorizationStatus];
    charon_check(port_status == system_status, "the status asked without a request is the host's",
                 [NSString stringWithFormat:@"port %lu, host %lu", port_status, system_status]);
    charon_check(port_status == ATTrackingManagerAuthorizationStatusNotDetermined,
                 "the status is notDetermined, the value a platform without the system answers",
                 [NSString stringWithFormat:@"port %lu", port_status]);

    Answer *port = ask([CharonHostATTrackingManager class]);
    Answer *system = ask([ATTrackingManager class]);
    charon_check([describe(port) isEqualToString:describe(system)], "a request is answered as the host answers it",
                 [NSString stringWithFormat:@"port %@, host %@", describe(port), describe(system)]);
    charon_check(port.calls == 1, "the handler is called once", [NSString stringWithFormat:@"%d calls", port.calls]);
    charon_check(port.on_main == system.on_main, "the handler runs on the thread that asked",
                 [NSString stringWithFormat:@"port %d, host %d", port.on_main, system.on_main]);
    charon_check(port.before_return == system.before_return, "the handler runs before the call returns",
                 [NSString stringWithFormat:@"port %d, host %d", port.before_return, system.before_return]);

    Answer *again = ask([CharonHostATTrackingManager class]);
    charon_check(again.calls == 1 && again.status == port.status,
                 "a second request is answered the same way, since nothing is remembered",
                 [NSString stringWithFormat:@"%@", describe(again)]);

    [CharonHostATTrackingManager requestTrackingAuthorizationWithCompletionHandler:nil];
    charon_check(YES, "a nil completion handler is allowed", @"raised");

    Class port_class = NSClassFromString(@"CharonHostATTrackingManager");
    Class system_class = NSClassFromString(@"ATTrackingManager");
    charon_check(port_class != Nil && system_class != Nil, "both classes are there to ask",
                 [NSString stringWithFormat:@"port %@, host %@", port_class, system_class]);
    charon_check([port_class superclass] == [system_class superclass], "the port's class stands where the host's does",
                 [NSString stringWithFormat:@"port %@, host %@", NSStringFromClass([port_class superclass]), NSStringFromClass([system_class superclass])]);
    charon_check([port_class instancesRespondToSelector:NSSelectorFromString(@"init")],
                 "+new and -init answer, being NSObject's as they are in the host's framework",
                 @"the port's class does not answer -init");

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
