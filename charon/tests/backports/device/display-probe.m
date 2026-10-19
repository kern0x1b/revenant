// display-probe.m - does a bare process (no UIApplicationMain) have a display, by the public routes, and what does a display
// link do there? Prints [UIScreen mainScreen], [UIScreen screens].count, the private +[CADisplay mainDisplay] that
// dynamics-watch.m used to decide with (for comparison only), and then, last because it may fault, one display link:
//     display-probe screen   -[UIScreen displayLinkWithTarget:selector:] (public since 4.0)
//     display-probe class    +[CADisplayLink displayLinkWithTarget:selector:]
// A second argument says what the process does first, each step adding to the one before, as dynamics-watch.m does a view before
// its animators start a link: `view` a UIView with a subview, `window` a UIWindow made key and visible over it, `turn` a
// CATransaction flush and a run loop turn of half a second after that, `wait` a view and then run loop turns of a quarter of a
// second until `[UIScreen screens]` is not empty, for at most 30 s (it prints when it was, or that it was not), `app` nothing but
// UIApplicationMain, the report coming from the launch callback. It prints the time each step took. Whether a layer tree, a window or a turn changes what the display
// and the link do is what these ask.
// A fault is caught to print the image, the offset in it and the fault address (the run's own verdict has only the pc), and the
// process exits 139.
// The build decides two things the program does not: the `apple_minimum` of the binary (LC_VERSION_MIN_IPHONEOS, which UIKit and
// dyld may branch on) and whether charon@apple-backports is linked. display-probe/xmake.lua takes both from the environment and
// tells the program (the first line it prints), display-probe/run.sh builds every combination for a release and runs it on the
// emulated device: `sh tests/backports/device/display-probe/run.sh 6.1.3`. Each run is a daemon target
// (`add_rules("@addon/charon/daemon")`, Foundation, UIKit, QuartzCore, CoreGraphics).
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <signal.h>
#import <stdio.h>
#import <string.h>
#import <unistd.h>
#import <sys/ucontext.h>

// What the build says of itself, from display-probe/xmake.lua: the apple_minimum it was built with and whether the package is linked.
#ifndef PROBE_MINIMUM
#define PROBE_MINIMUM "(not said)"
#endif
#ifndef PROBE_PACKAGE
#define PROBE_PACKAGE 0
#endif

@interface Ticker : NSObject
- (void)tick:(CADisplayLink *)link;
@end

@implementation Ticker
- (void)tick:(CADisplayLink *)link
{
}
@end

static void say(const char *text)
{
    write(STDOUT_FILENO, text, strlen(text));
}

static void locate(const char *what, uintptr_t address)
{
    Dl_info info;
    char line[512];
    if (dladdr((void *)address, &info) && info.dli_fname)
        snprintf(line, sizeof line, "  %s 0x%lx: image %s, base 0x%lx, offset +0x%lx, symbol %s\n", what, (unsigned long)address, info.dli_fname,
                 (unsigned long)info.dli_fbase, (unsigned long)(address - (uintptr_t)info.dli_fbase), info.dli_sname ? info.dli_sname : "(none)");
    else
        snprintf(line, sizeof line, "  %s 0x%lx: no image\n", what, (unsigned long)address);
    say(line);
}

static void fault(int signal_number, siginfo_t *info, void *context)
{
    ucontext_t *uc = context;
    char line[128];
    snprintf(line, sizeof line, "FAULT signal %d, fault address 0x%lx\n", signal_number, (unsigned long)info->si_addr);
    say(line);
    locate("pc", (uintptr_t)uc->uc_mcontext->__ss.__pc);
    locate("lr", (uintptr_t)uc->uc_mcontext->__ss.__lr);
    _exit(139);
}

// What the process's display is, by the public routes and the private one for comparison, then one display link (last: it may fault).
static void report_and_link(BOOL screen)
{
    UIScreen *mainScreen = [UIScreen mainScreen];
    printf("UIScreen mainScreen: %s\n", mainScreen ? [[mainScreen description] UTF8String] : "nil");
    printf("UIScreen screens: count %lu\n", (unsigned long)[[UIScreen screens] count]);
    Class display = NSClassFromString(@"CADisplay");
    id mainDisplay = [display respondsToSelector:@selector(mainDisplay)] ? [display performSelector:@selector(mainDisplay)] : nil;
    printf("private +[CADisplay mainDisplay]: %s\n", display ? (mainDisplay ? "an object" : "nil") : "no such class");
    printf("next: %s\n", screen ? "-[UIScreen displayLinkWithTarget:selector:]" : "+[CADisplayLink displayLinkWithTarget:selector:]");
    fflush(stdout);

    struct sigaction action;
    memset(&action, 0, sizeof action);
    action.sa_sigaction = fault;
    action.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGBUS, &action, NULL);

    Ticker *ticker = [Ticker new];
    CADisplayLink *link = screen ? [mainScreen displayLinkWithTarget:ticker selector:@selector(tick:)]
                                 : [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
    printf("display link: %s\n", link ? "an object" : "nil");
}

// The process as an application: UIApplicationMain, and the report from the launch callback. On the emulator a program run
// as a command does not go through SpringBoard's launch, so the callback may never come; the run's own timeout says so.
static BOOL g_screen;

@interface ProbeDelegate : NSObject <UIApplicationDelegate>
@end

@implementation ProbeDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    printf("in application:didFinishLaunchingWithOptions:\n");
    report_and_link(g_screen);
    exit(0);
}
@end

static double seconds(void)
{
    return CFAbsoluteTimeGetCurrent();
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        g_screen = argc > 1 && strcmp(argv[1], "screen") == 0;
        const char *prepare = argc > 2 ? argv[2] : "";
        printf("display probe: running on %s, built with apple_minimum %s, %s, mode %s %s\n", [[[UIDevice currentDevice] systemVersion] UTF8String],
               PROBE_MINIMUM, PROBE_PACKAGE ? "charon@apple-backports linked" : "no backports library", argc > 1 ? argv[1] : "(none)",
               argc > 2 ? argv[2] : "(none)");
        // What is made before the report, one step more each: a UIView with a subview (`view`), a UIWindow made key and
        // visible over it (`window`), a run loop turn with a CATransaction flush after that (`turn`).
        BOOL polling = strcmp(prepare, "wait") == 0;
        BOOL view = strcmp(prepare, "view") == 0 || polling || strcmp(prepare, "window") == 0 || strcmp(prepare, "turn") == 0;
        BOOL window = strcmp(prepare, "window") == 0 || strcmp(prepare, "turn") == 0;
        BOOL turn = strcmp(prepare, "turn") == 0;
        UIView *superview = nil;
        UIWindow *win = nil;
        if (view) {
            double began = seconds();
            superview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 800)];
            [superview addSubview:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)]];
            printf("a UIView with a subview made first, %.3f s\n", seconds() - began);
        }
        if (window) {
            double began = seconds();
            @try {
                win = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
                [win addSubview:superview];
                [win makeKeyAndVisible];
                printf("a UIWindow made key and visible, %.3f s\n", seconds() - began);
            } @catch (NSException *exception) {
                printf("a UIWindow made key and visible raised %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
            }
        }
        if (turn) {
            double began = seconds();
            [CATransaction flush];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            printf("a CATransaction flush and a run loop turn of 0.5 s, %.3f s\n", seconds() - began);
        }
        if (polling) {
            double began = seconds();
            NSUInteger count = [[UIScreen screens] count];
            while (count == 0 && seconds() - began < 30) {
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
                count = [[UIScreen screens] count];
            }
            printf("waited %.3f s: UIScreen screens count %lu\n", seconds() - began, (unsigned long)count);
        }
        if (strcmp(prepare, "app") == 0) {
            printf("UIApplicationMain\n");
            fflush(stdout);
            return UIApplicationMain(argc, argv, nil, @"ProbeDelegate");
        }
        report_and_link(g_screen);
        (void)win;
    }
    return 0;
}
