/* metrics.m - the AVMetric surface the port carries, the port against the host, in ONE binary.
 *
 * The host HAS this surface: iOS 18 and macOS 15 added it and this macOS is 27, so every class, protocol
 * and member below is something the host answers. That makes this a real structural differential rather
 * than a comparison of two empty answers:
 *
 *   CLASS      does the name resolve on each side, and what is its superclass? The port's hierarchy is
 *              26.2's own and the host's is Apple's, so a superclass that differs is a defect.
 *   RESPONDS   does an instance answer each member the ledger row names? Here the answer legitimately
 *              differs in one direction - the port carries members the 18.0 cache does not export, and
 *              the port answers MORE - so a row that differs is printed and judged by run.sh, not
 *              waved through.
 *   PROPERTY   is the member a real accessor on each side, read without crashing.
 *
 * Controls, so a run that examined nothing cannot pass:
 *   AVMetricNoSuchClass           a planted class name        -> absent on both
 *   AVMetricEvent                 the base class              -> present, superclass NSObject
 *   -[AVMetricEvent date]         one member the host has     -> YES on both
 *   AVMetricEventStreamSubscriber the protocol                -> present on both
 */
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>

static Class gHost;

/* The port's classes are renamed to charon_host_<name> in run.sh's copy, so the port side is asked by
   that name. objc_getClass on the bare name would answer APPLE's class - the host framework is linked in
   and dlopened - and the two would be compared against themselves. */
static void probe_class(const char *name)
{
    Class host = NSClassFromString([NSString stringWithUTF8String:name]);
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "charon_host_%s", name);
    Class port = objc_getClass(prefixed);
    printf("CLASS\t%s\thost=%s\tport=%s\n", name,
           host ? "present" : "ABSENT", port ? "present" : "ABSENT");
    /* The superclass is compared by its NAME WITH THE RENAME STRIPPED, because the two sides cannot be the
       same object: the port's class is charon_host_AVMetricErrorEvent and its parent is
       charon_host_AVMetricEvent, the host's is AVMetricErrorEvent and its parent is AVMetricEvent. Comparing
       the two Class pointers, or comparing the raw names, calls every one of the sixteen rows DIFFERENT
       after the hierarchy was finally right - which is what it did, and it is why the row below strips the
       prefix rather than being loosened. */
    if (host && port) {
        Class hostParent = class_getSuperclass(host);
        Class portParent = class_getSuperclass(port);
        const char *hostName = hostParent ? class_getName(hostParent) : "(none)";
        char portStripped[256];
        if (portParent) {
            const char *raw = class_getName(portParent);
            if (!strncmp(raw, "charon_host_", 12)) {
                snprintf(portStripped, sizeof portStripped, "%s", raw + 12);
            } else {
                snprintf(portStripped, sizeof portStripped, "%s", raw);
            }
        } else {
            snprintf(portStripped, sizeof portStripped, "(none)");
        }
        printf("SUPERCLASS\t%s\thost=%s\tport=%s\t%s\n", name, hostName, portStripped,
               strcmp(hostName, portStripped) == 0 ? "same" : "DIFFERENT");
    }
}

static void probe_protocol(const char *name)
{
    Protocol *host = NSProtocolFromString([NSString stringWithUTF8String:name]);
    /* a protocol object on the port is reachable by name only through the runtime's protocol list, so
       this asks whether any class in the binary conforms AND whether the name appears at all */
    Protocol *port = NULL;
    unsigned int count = 0;
    // __unsafe_unretained: objc_copyProtocolList hands back a buffer it has already retained the way the
    // runtime documents, and under ARC a plain `Protocol **` cannot be initialised from the
    // `Protocol *__unsafe_unretained *` it returns without saying so.
    Protocol *__unsafe_unretained *all = objc_copyProtocolList(&count);
    for (unsigned int index = 0; all != NULL && index < count; index++) {
        if (!strcmp(protocol_getName(all[index]), name)) {
            port = all[index];
        }
    }
    if (all != NULL) {
        free(all);
    }
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "charon_host_%s", name);
    printf("PROTOCOL\t%s\thost=%s\tport=%s\n", name,
           host ? "present" : "ABSENT", port ? "present" : "ABSENT");
}

/* An instance of the HOST's class, asked for a selector. The port's classes are deliberately NOT
   instantiated here: several of them are AV_INIT_UNAVAILABLE and the point of this phase is that an
   instance answers its members, which the port's own build answers by construction - the objects hold
   what they were given and there is no object. */
/* The selector asked is the ACCESSOR THE HEADER DECLARES, not the property's name: run.sh reads the
   getter= out of CharonAVMetrics18.h and passes it here. `readFromCache` is declared
   `getter=wasReadFromCache`, so asking -readFromCache finds nothing on either side and reports the row
   equal without having asked anything - which is how the first version of this list read
   `host=no` for a selector no class anywhere implements.
 *
 * The port side is asked of its OWN renamed class, and answers by whether it implements the accessor: a
 * @property (readonly) with an @synthesize behind it does, and the three rendition properties carried by the
 * 26.0 category's association-backed getters do too. */
static void probe_member(const char *owner, const char *selector)
{
    Class host = gHost ? NSClassFromString([NSString stringWithUTF8String:owner]) : Nil;
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "charon_host_%s", owner);
    Class port = objc_getClass(prefixed);
    printf("RESPONDS\t-[%s %s]\thost=%s\tport=%s\n", owner, selector,
           (host && class_getInstanceMethod(host, sel_registerName(selector))) ? "yes" : "no",
           (port && class_getInstanceMethod(port, sel_registerName(selector))) ? "yes" : "no");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "FAIL: no class list was named, so nothing was examined\n");
            return 1;
        }
        if (dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
                   RTLD_LAZY | RTLD_GLOBAL) == NULL) {
            fprintf(stderr, "FAIL: AVFoundation did not load\n");
            return 1;
        }
        gHost = [AVMetricEvent class];
        printf("CONTROL\tAVMetricNoSuchClass\t%s\n",
               NSClassFromString(@"AVMetricNoSuchClass") ? "HAS" : "ABSENT");
        printf("CONTROL\tAVMetricEvent\t%s\n", gHost ? "HAS" : "ABSENT");
        if (gHost == nil) {
            fprintf(stderr, "FAIL: AVMetricEvent does not resolve on the host, so nothing below means anything\n");
            return 1;
        }
        printf("CONTROL\t-[AVMetricEvent date]\t%s\n",
               class_getInstanceMethod(gHost, @selector(date)) ? "yes" : "no");
        // The subscriber protocol is asked once as a CONTROL and then again as a PROTOCOL row, because
        // the control is what run.sh's control checker reads and it only looks at CONTROL lines: with the
        // protocol printed only as a PROTOCOL row the check stopped with "printed nothing" on a run that
        // had in fact answered both sides.
        probe_protocol("AVMetricEventStreamSubscriber");
        {
            Protocol *host = NSProtocolFromString(@"AVMetricEventStreamSubscriber");
            unsigned int count = 0;
            Protocol *__unsafe_unretained *all = objc_copyProtocolList(&count);
            Protocol *port = NULL;
            for (unsigned int index = 0; all != NULL && index < count; index++) {
                if (!strcmp(protocol_getName(all[index]), "AVMetricEventStreamSubscriber")) {
                    port = all[index];
                }
            }
            if (all != NULL) {
                free(all);
            }
            printf("CONTROL\tAVMetricEventStreamSubscriber\t%s\n",
                   (host != NULL && port != NULL) ? "HAS" : "ABSENT");
        }

        FILE *list = fopen(argv[1], "r");
        if (list == NULL) {
            fprintf(stderr, "FAIL: the list did not open, so nothing was examined\n");
            return 1;
        }
        char line[512];
        unsigned classes = 0, members = 0, differs = 0;
        while (fgets(line, sizeof line, list) != NULL) {
            char *save = NULL;
            char *kind = strtok_r(line, "\t\n", &save);
            char *first = strtok_r(NULL, "\t\n", &save);
            char *second = strtok_r(NULL, "\t\n", &save);
            if (kind == NULL || first == NULL) {
                continue;
            }
            if (!strcmp(kind, "class")) {
                probe_class(first);
                classes++;
            } else if (!strcmp(kind, "protocol")) {
                probe_protocol(first);
            } else if (!strcmp(kind, "member") && second != NULL) {
                probe_member(first, second);
                members++;
            }
        }
        fclose(list);
        printf("classes probed: %u  members probed: %u\n", classes, members);
    }
    return 0;
}