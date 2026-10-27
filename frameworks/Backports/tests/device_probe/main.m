#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_types.h>
#import <netinet/in.h>
#import <sys/socket.h>

static NSString *const REVENANT_PROBE_LOG = @"/var/revenant/device-probe.txt";

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;

static void revenant_line(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [REVENANT_LOG appendFormat:@"%@\n", line];
}

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    revenant_line(@"%@ %@", ok ? @"PASS" : @"FAIL", name);
}

static void revenant_animation_checks(void)
{
    revenant_check([UIView inheritedAnimationDuration] == 0, @"inheritedAnimationDuration is zero outside an animation");

    __block NSTimeInterval outer = -1, inner = -1, restored = -1;
    [UIView animateWithDuration:0.5 animations:^{
        outer = [UIView inheritedAnimationDuration];
        [UIView animateWithDuration:0.25 animations:^{
            inner = [UIView inheritedAnimationDuration];
        }];
        restored = [UIView inheritedAnimationDuration];
    }];
    revenant_check(outer == 0.5, @"animateWithDuration:0.5 reports 0.5 inside its block");
    revenant_check(inner == 0.25, @"a nested animateWithDuration:0.25 reports 0.25 inside its block");
    revenant_check(restored == 0.5, @"the outer duration is restored after the nested block");
    revenant_check([UIView inheritedAnimationDuration] == 0, @"inheritedAnimationDuration is zero after the animation");

    __block NSTimeInterval keyframe = -1;
    [UIView animateKeyframesWithDuration:0.4 delay:0 options:0 animations:^{
        keyframe = [UIView inheritedAnimationDuration];
    } completion:nil];
    revenant_check(keyframe == 0.4, @"animateKeyframesWithDuration:0.4 reports 0.4 inside its block");

    [UIView beginAnimations:@"revenant" context:NULL];
    [UIView setAnimationDuration:0.3];
    NSTimeInterval classic = [UIView inheritedAnimationDuration];
    [UIView commitAnimations];
    revenant_check(classic == 0.3, @"beginAnimations with setAnimationDuration:0.3 reports 0.3");
    revenant_check([UIView inheritedAnimationDuration] == 0, @"commitAnimations pops the duration");
}

static void revenant_text_checks(void)
{
    UITextField *field = [[UITextField alloc] init];
    UITextInputMode *current = [UITextInputMode currentInputMode];
    UITextInputMode *mode = [field textInputMode];
    revenant_check(mode != nil, @"textInputMode is not nil");
    revenant_check([mode.primaryLanguage isEqualToString:current.primaryLanguage], @"textInputMode has the current primary language");
    revenant_line(@"INFO primaryLanguage %@ same object %d", current.primaryLanguage, mode == current);
}

static void revenant_metal_checks(UIWindow *window)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    revenant_check(device != nil, @"MTLCreateSystemDefaultDevice returns a device");
    if (!device)
        return;

    id<MTLBuffer> buffer = [device newBufferWithLength:256 options:MTLResourceStorageModeShared];
    MTLPurgeableState first = [buffer setPurgeableState:MTLPurgeableStateVolatile];
    MTLPurgeableState second = [buffer setPurgeableState:MTLPurgeableStateKeepCurrent];
    revenant_check(first == MTLPurgeableStateNonVolatile, @"setPurgeableState returns the previous state, NonVolatile for a new buffer");
    revenant_check(second == MTLPurgeableStateVolatile, @"KeepCurrent returns Volatile, the state set before it");

    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = device;
    layer.frame = CGRectMake(0, 0, 64, 64);
    [window.layer addSublayer:layer];
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    revenant_check(drawable != nil, @"nextDrawable returns a drawable");
    if (!drawable)
        return;

    __block BOOL presented = NO;
    __block id<MTLDrawable> received = nil;
    [drawable addPresentedHandler:^(id<MTLDrawable> presentedDrawable) {
        presented = YES;
        received = presentedDrawable;
    }];
    [drawable present];
    revenant_check(presented, @"the presented handler runs after present");
    revenant_check(received == drawable, @"the presented handler receives the drawable");
    revenant_check([drawable drawableID] > 0, @"drawableID is set");
    revenant_check([drawable presentedTime] > 0, @"presentedTime is set after present");
}

static void revenant_network_facts(void)
{
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&address);
    SCNetworkReachabilityFlags flags = 0;
    BOOL read = reachability != NULL && SCNetworkReachabilityGetFlags(reachability, &flags);
    revenant_check(read, @"SCNetworkReachability reads the default route flags");
    revenant_line(@"INFO reachability flags 0x%x reachable %d wwan %d", (unsigned)flags,
                  (flags & kSCNetworkReachabilityFlagsReachable) != 0, (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0);
    if (reachability)
        CFRelease(reachability);

    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) != 0)
        return;
    for (struct ifaddrs *entry = list; entry != NULL; entry = entry->ifa_next) {
        if (!(entry->ifa_flags & IFF_UP) || !entry->ifa_addr)
            continue;
        if (entry->ifa_addr->sa_family == AF_LINK && entry->ifa_data) {
            revenant_line(@"INFO link %s ifi_type %u", entry->ifa_name, (unsigned)((struct if_data *)entry->ifa_data)->ifi_type);
        }
        if (entry->ifa_addr->sa_family == AF_INET) {
            BOOL routable = ((struct sockaddr_in *)entry->ifa_addr)->sin_addr.s_addr != 0;
            revenant_line(@"INFO inet %s has address %d", entry->ifa_name, routable);
        }
    }
    freeifaddrs(list);
}

@interface RevenantProbeDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantProbeDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(revenantRun) withObject:nil afterDelay:1.0];
    return YES;
}

- (void)revenantRun
{
    REVENANT_LOG = [NSMutableString string];
    revenant_line(@"INFO %@ iOS %@", [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]);
    revenant_animation_checks();
    revenant_text_checks();
    revenant_metal_checks(self.window);
    revenant_network_facts();
    revenant_line(@"REVENANT-DONE failures %lu", (unsigned long)REVENANT_FAILURES);
    [REVENANT_LOG writeToFile:REVENANT_PROBE_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    exit(0);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantProbeDelegate class]));
    }
}
