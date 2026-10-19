#import <CallKit/CallKit.h>
#include <dlfcn.h>
#import "check.h"

// The one thing no host, and no build gate, can answer: whether the SpringBoard side (packages/a/apple-callkit-screen,
// filtered to com.apple.springboard) actually raises a window over SpringBoard's own, and whether a tap on it reaches
// back through the file-and-notification protocol into this application's own CXProvider delegate. Everything else
// about that path - the protocol, the payload, the two dylibs' packaging - is proven without a device; this is not.
//
// Run against a real iPhone 4S (6.1.3) with org.charon.callkit-screen installed and SpringBoard respring'd to pick it
// up. This is a plain command-line tool: CharonCallScreen's notify_register_dispatch needs a run loop pumped, not a
// UIApplication, and reporting an incoming call needs no window of its own - the window is SpringBoard's.
//
// Nothing here taps anything. `revtouch tap X Y` on the points this test logs, once for each case, is the only way a
// touch reaches the device; the coordinates are the buttons' centres for a 320x480pt screen (iPhone 4S), fixed because
// the buttons are drawn at a fixed layout, not measured.

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

@interface CharonScreenDelegate : NSObject <CXProviderDelegate>
@property (nonatomic) NSMutableArray<NSString *> *log;
@end

@implementation CharonScreenDelegate
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

static CXProvider *providerWith(CharonScreenDelegate *delegate)
{
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Charon"];
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
    CharonScreenDelegate *delegate = [[CharonScreenDelegate alloc] init];
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
    charon_check(arrived, [NSString stringWithFormat:@"the screen turns the tap on %@ into %@", label, expected].UTF8String,
                 arrived ? nil : [NSString stringWithFormat:@"delegate log: %@", delegate.log]);

    [provider invalidate];
    spin(0.1);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of([CXProvider class]), @"libCallKitBackports.dylib", "CXProvider comes from the backports");
        oneCall(@"Charon Screen Test - decline", @"end", 20);
        oneCall(@"Charon Screen Test - answer", @"answer", 20);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
