#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>

static Class gHost;

static void probe_class(const char *name)
{
    Class host = NSClassFromString([NSString stringWithUTF8String:name]);
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "charon_host_%s", name);
    Class port = objc_getClass(prefixed);
    printf("CLASS\t%s\thost=%s\tport=%s\n", name,
           host ? "present" : "ABSENT", port ? "present" : "ABSENT");
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
    Protocol *port = NULL;
    unsigned int count = 0;
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
