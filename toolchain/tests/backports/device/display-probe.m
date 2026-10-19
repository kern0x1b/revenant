#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <signal.h>
#import <stdio.h>
#import <string.h>
#import <unistd.h>
#import <sys/ucontext.h>

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
               PROBE_MINIMUM, PROBE_PACKAGE ? "revenant@apple-backports linked" : "no backports library", argc > 1 ? argv[1] : "(none)",
               argc > 2 ? argv[2] : "(none)");
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
