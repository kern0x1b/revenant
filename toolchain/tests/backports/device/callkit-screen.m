#import <CallKit/CallKit.h>
#include <dlfcn.h>
#import "check.h"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

@interface RevenantScreenDelegate : NSObject <CXProviderDelegate>
@property (nonatomic) NSMutableArray<NSString *> *log;
@end

@implementation RevenantScreenDelegate
- (instancetype)init
{
    if ((self = [super init]))
        _log = [NSMutableArray array];
    return self;
}
- (void)providerDidBegin:(CXProvider *)provider { [_log addObject:@"begin"]; }
- (void)providerDidReset:(CXProvider *)provider { [_log addObject:@"reset"]; }
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
    [_log addObject:@"answer"];
    [action fulfill];
}
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action
{
    [_log addObject:@"end"];
    [action fulfill];
}
@end

static BOOL waitFor(NSMutableArray *log, NSString *event, NSTimeInterval timeout)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([deadline timeIntervalSinceNow] > 0) {
        if ([log containsObject:event])
            return YES;
        spin(0.2);
    }
    return [log containsObject:event];
}

static CXProvider *providerWith(RevenantScreenDelegate *delegate)
{
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Revenant"];
    CXProvider *provider = [[CXProvider alloc] initWithConfiguration:configuration];
    [provider setDelegate:delegate queue:dispatch_get_main_queue()];
    spin(0.1);
    return provider;
}

static void oneCall(NSString *label, NSString *expected, NSTimeInterval timeout)
{
    printf("== %s: tap %s within %.0fs (decline at 80,390; answer at 240,390 on a 320x480pt screen)\n",
           label.UTF8String, expected.UTF8String, timeout);
    fflush(stdout);
    RevenantScreenDelegate *delegate = [[RevenantScreenDelegate alloc] init];
    CXProvider *provider = providerWith(delegate);
    CHECK([delegate.log containsObject:@"begin"], "the delegate is told the provider began");

    NSUUID *call = [NSUUID UUID];
    CXCallUpdate *update = [[CXCallUpdate alloc] init];
    update.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:@"+15551234"];
    update.localizedCallerName = label;
    __block NSError *failure = nil;
    [provider reportNewIncomingCallWithUUID:call update:update completion:^(NSError *error) { failure = error; }];
    spin(0.2);
    CHECK(failure == nil, "the incoming call is reported without an error");

    BOOL arrived = waitFor(delegate.log, expected, timeout);
    revenant_check(arrived, [NSString stringWithFormat:@"the screen turns the tap on %@ into %@", label, expected].UTF8String,
                 arrived ? nil : [NSString stringWithFormat:@"delegate log: %@", delegate.log]);

    [provider invalidate];
    spin(0.1);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of([CXProvider class]), @"libCallKitBackports.dylib", "CXProvider comes from the backports");
        oneCall(@"Revenant Screen Test - decline", @"end", 20);
        oneCall(@"Revenant Screen Test - answer", @"answer", 20);
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures ? 1 : 0;
}
