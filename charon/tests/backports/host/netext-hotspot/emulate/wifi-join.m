// wifi-join.m - what the 6.1.3 release answers when an application with no entitlements drives its Wi-Fi join
// route, measured on the release itself (xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/wifijoin613).
// facts/NetworkExtension/Hotspot.md names the route: the private AirPortAssistant WiFiUtils class, reached by
// loading its framework at run time. This probe links no NetworkExtension and no package of this repository's.
//
// A command-line program, built as a daemon target (@addon/charon/daemon; Foundation; -fobjc-arc). Output is one
// tab-separated line per answer, so two runs can be diffed:
//   class.*       the NEHotspot classes the release has (nil for each on 6.1.3)
//   dlopen        whether the AirPortAssistant image loads for this process, and the dlerror if not
//   method.*      the selectors of WiFiUtils, class and instance, with their type encodings
//   interfaces    what CaptiveNetwork names as Wi-Fi interfaces (nil or empty means the guest has none)
//   call.*        each join-route selector driven with a name that is not a network of this guest
//   async.*       what the calls posted back during a bounded run loop wait
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <objc/message.h>

extern CFArrayRef CNCopySupportedInterfaces(void);

static void wait_for(NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static void klass(const char *label, NSString *name)
{
    printf("class.%s\t%p\n", label, (__bridge void *)NSClassFromString(name));
}

static void methods(const char *label, Class cls)
{
    unsigned int count = 0;
    Method *list = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        printf("method.%s\t%s\t%s\n", label, sel_getName(method_getName(list[i])), method_getTypeEncoding(list[i]));
    }
    free(list);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);

    klass("NEHotspotNetwork", @"NEHotspotNetwork");
    klass("NEHotspotConfiguration", @"NEHotspotConfiguration");
    klass("NEHotspotConfigurationManager", @"NEHotspotConfigurationManager");
    klass("NEHotspotHelper", @"NEHotspotHelper");

    void *image = dlopen("/System/Library/PrivateFrameworks/AirPortAssistant.framework/AirPortAssistant", RTLD_NOW);
    printf("dlopen\t%s\n", image ? "ok" : dlerror());

    Class wifi = NSClassFromString(@"WiFiUtils");
    klass("WiFiUtils", @"WiFiUtils");
    if (!wifi) {
        return 0;
    }
    methods("class", object_getClass(wifi));
    methods("instance", wifi);

    CFArrayRef interfaces = CNCopySupportedInterfaces();
    printf("interfaces\t%s\n", interfaces ? [[(__bridge NSArray *)interfaces description] UTF8String] : "(nil)");
    if (interfaces) {
        CFRelease(interfaces);
    }

    id instance = [[wifi alloc] init];
    printf("instance\t%p\n", (__bridge void *)instance);
    SEL current = NSSelectorFromString(@"getCurrentAssociationInfo");
    if ([instance respondsToSelector:current]) {
        id answer = ((id (*)(id, SEL))objc_msgSend)(instance, current);
        printf("call.getCurrentAssociationInfo\t%s\n", answer ? [[answer description] UTF8String] : "(nil)");
    }

    // The three join selectors, each with a name that is not a network of this guest, no password, and
    // rememberChoice NO, so a join that happens is remembered by nothing.
    NSString *name = @"charon-probe-no-such-network";
    SEL byName = NSSelectorFromString(@"joinNetworkWithNameAsync:password:rememberChoice:");
    if ([instance respondsToSelector:byName]) {
        printf("call.joinNetworkWithNameAsync\tstart\n");
        ((void (*)(id, SEL, id, id, BOOL))objc_msgSend)(instance, byName, name, nil, NO);
        printf("call.joinNetworkWithNameAsync\treturned\n");
    } else {
        printf("call.joinNetworkWithNameAsync\tnot implemented\n");
    }
    wait_for(10.0);
    printf("async.window\t10 s run loop\n");
    return 0;
}
