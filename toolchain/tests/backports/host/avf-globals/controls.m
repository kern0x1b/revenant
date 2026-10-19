#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RevenantAVFoundationProtocols.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PORT_PREFIX "revenant_host_"

static void probe_class(const char *name)
{
    Class host = NSClassFromString([NSString stringWithUTF8String:name]);
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "%s%s", PORT_PREFIX, name);
    Class port = objc_getClass(prefixed);
    printf("CLASS\t%s\thost=%s\tport=%s\n", name,
           host ? "present" : "ABSENT", port ? "present" : "ABSENT");
    if (host && port) {
        Class hostParent = class_getSuperclass(host);
        Class portParent = class_getSuperclass(port);
        const char *hostName = hostParent ? class_getName(hostParent) : "(none)";
        const char *portRaw = portParent ? class_getName(portParent) : "(none)";
        char portName[256];
        if (!strncmp(portRaw, PORT_PREFIX, strlen(PORT_PREFIX))) {
            snprintf(portName, sizeof portName, "%s", portRaw + strlen(PORT_PREFIX));
        } else {
            snprintf(portName, sizeof portName, "%s", portRaw);
        }
        printf("SUPERCLASS\t%s\thost=%s\tport=%s\t%s\n", name, hostName, portName,
               strcmp(hostName, portName) == 0 ? "same" : "DIFFERENT");
    }
}

static Protocol *port_protocol(const char *name)
{
    unsigned count = 0;
    Protocol *__unsafe_unretained *all = objc_copyProtocolList(&count);
    Protocol *found = NULL;
    for (unsigned index = 0; all != NULL && index < count; index++) {
        if (!strcmp(protocol_getName(all[index]), name)) {
            found = all[index];
        }
    }
    if (all != NULL) {
        free(all);
    }
    return found;
}

static void probe_member(const char *owner, const char *selector)
{
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "%s%s", PORT_PREFIX, owner);
    Class host = NSClassFromString([NSString stringWithUTF8String:owner]);
    Class port = objc_getClass(prefixed);
    int classMethod = selector[0] == '+';
    const char *name = (selector[0] == '+' || selector[0] == '-') ? selector + 1 : selector;
    SEL asked = sel_registerName(name);
    printf("RESPONDS\t%c[%s %s]\thost=%s\tport=%s\n", classMethod ? '+' : '-', owner, name,
           (host && (classMethod ? class_getClassMethod(host, asked) : class_getInstanceMethod(host, asked))) ? "yes" : "no",
           (port && (classMethod ? class_getClassMethod(port, asked) : class_getInstanceMethod(port, asked))) ? "yes" : "no");
}

static void answer_of(id object, SEL selector, char *out, size_t room)
{
    @autoreleasepool {
        @try {
            if (selector == @selector(canAddControl:)) {
                snprintf(out, room, "%d", (int)((BOOL (*)(id, SEL, id))objc_msgSend)(object, selector, nil));
            } else if (selector == @selector(addControl:) || selector == @selector(removeControl:)) {
                ((void (*)(id, SEL, id))objc_msgSend)(object, selector, nil);
                snprintf(out, room, "returned");
            } else if (selector == @selector(setControlsDelegate:queue:)) {
                ((void (*)(id, SEL, id, id))objc_msgSend)(object, selector, nil, nil);
                snprintf(out, room, "returned");
            } else {
                snprintf(out, room, "returned");
            }
        } @catch (NSException *exception) {
            snprintf(out, room, "%s: %s", exception.name.UTF8String,
                     exception.reason ? exception.reason.UTF8String : "(no reason)");
        }
    }
}

@interface RevenantControlsProbeDelegate : NSObject <AVCaptureSessionControlsDelegate>
@end

@implementation RevenantControlsProbeDelegate
- (void)sessionControlsDidBecomeActive:(AVCaptureSession *)session {}
- (void)sessionControlsDidBecomeInactive:(AVCaptureSession *)session {}
- (void)sessionControlsWillEnterFullscreenAppearance:(AVCaptureSession *)session {}
- (void)sessionControlsWillExitFullscreenAppearance:(AVCaptureSession *)session {}
@end

static BOOL read_bool(id object, SEL selector)
{
    return (BOOL)((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
}

static id read_object(id object, SEL selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static void probe_answers(id host, id port)
{
    char hostAnswer[512], portAnswer[512];

#define ASK(label, selector) \
    do { \
        answer_of(host, selector, hostAnswer, sizeof hostAnswer); \
        answer_of(port, selector, portAnswer, sizeof portAnswer); \
        printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", label, hostAnswer, portAnswer); \
    } while (0)

    printf("ANSWER\t-supportsControls\thost=[%d]\tport=[%d]\n", (int)read_bool(host, @selector(supportsControls)),
           (int)read_bool(port, @selector(supportsControls)));
    printf("ANSWER\t-maxControlsCount\thost=[%ld]\tport=[%ld]\n",
           (long)((NSInteger (*)(id, SEL))objc_msgSend)(host, @selector(maxControlsCount)),
           (long)((NSInteger (*)(id, SEL))objc_msgSend)(port, @selector(maxControlsCount)));
    id hostControls = read_object(host, @selector(controls));
    id portControls = read_object(port, @selector(controls));
    printf("ANSWER\t-controls\thost=[%lu of %s]\tport=[%lu of %s]\n", (unsigned long)[hostControls count],
           [[hostControls class] description].UTF8String, (unsigned long)[portControls count],
           [[portControls class] description].UTF8String);
    printf("ANSWER\t-controlsDelegate\thost=[%s]\tport=[%s]\n",
           read_object(host, @selector(controlsDelegate)) ? "non-nil" : "nil",
           read_object(port, @selector(controlsDelegate)) ? "non-nil" : "nil");
    printf("ANSWER\t-controlsDelegateCallbackQueue\thost=[%s]\tport=[%s]\n",
           read_object(host, @selector(controlsDelegateCallbackQueue)) ? "non-nil" : "nil",
           read_object(port, @selector(controlsDelegateCallbackQueue)) ? "non-nil" : "nil");
    ASK("-canAddControl: nil", @selector(canAddControl:));
    ASK("-addControl: nil", @selector(addControl:));
    ASK("-removeControl: nil", @selector(removeControl:));
    ASK("-setControlsDelegate: nil queue: NULL", @selector(setControlsDelegate:queue:));
#undef ASK
    printf("ANSWER\t-configuresApplicationAudioSessionToMixWithOthers default\tport=[%d]\t"
           "host=[not asked: API_UNAVAILABLE(macos)]\n",
           (int)read_bool(port, @selector(configuresApplicationAudioSessionToMixWithOthers)));
    ((void (*)(id, SEL, BOOL))objc_msgSend)(port, @selector(setConfiguresApplicationAudioSessionToMixWithOthers:), YES);
    id other = [[port class] new];
    printf("ANSWER\t-configuresApplicationAudioSessionToMixWithOthers after YES\tport=[%d on the session, "
           "%d on a second one]\n",
           (int)read_bool(port, @selector(configuresApplicationAudioSessionToMixWithOthers)),
           (int)read_bool(other, @selector(configuresApplicationAudioSessionToMixWithOthers)));
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "FAIL: no member list was named, so nothing was examined\n");
            return 1;
        }
        if (dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation",
                   RTLD_LAZY | RTLD_GLOBAL) == NULL) {
            fprintf(stderr, "FAIL: AVFoundation did not load\n");
            return 1;
        }
        Class hostControl = NSClassFromString(@"AVCaptureControl");
        printf("CONTROL\tAVCaptureNoSuchClass\t%s\n",
               NSClassFromString(@"AVCaptureNoSuchClass") ? "HAS" : "ABSENT");
        printf("CONTROL\tAVCaptureControl\t%s\n", hostControl ? "HAS" : "ABSENT");
        if (hostControl == nil) {
            fprintf(stderr, "FAIL: AVCaptureControl does not resolve on the host, so nothing below means "
                            "anything\n");
            return 1;
        }
        printf("CONTROL\t-[AVCaptureControl isEnabled]\t%s\n",
               class_getInstanceMethod(hostControl, @selector(isEnabled)) ? "yes" : "no");
        Class portControl = objc_getClass(PORT_PREFIX "AVCaptureControl");
        Class portSession = objc_getClass(PORT_PREFIX "AVCaptureSession");
        printf("CONTROL\trevenant_host_AVCaptureControl\t%s\n", portControl ? "HAS" : "ABSENT");
        printf("CONTROL\trevenant_host_AVCaptureSession\t%s\n", portSession ? "HAS" : "ABSENT");
        if (portControl == NULL || portSession == NULL) {
            fprintf(stderr, "FAIL: the port's own objects are not in this binary, so every port row below "
                            "would be read off a class that is not there\n");
            return 1;
        }
        Protocol *portControlsDelegate = port_protocol("AVCaptureSessionControlsDelegate");
        printf("CONTROL\tAVCaptureSessionControlsDelegate\tport=%s\thost=%s\n",
               portControlsDelegate ? "HAS" : "ABSENT",
               NSProtocolFromString(@"AVCaptureSessionControlsDelegate") ? "HAS" : "ABSENT");
        if (portControlsDelegate == NULL) {
            fprintf(stderr, "FAIL: the port carries no protocol object for AVCaptureSessionControlsDelegate, "
                            "so the four protocol methods are not declared in this build\n");
            return 1;
        }
        printf("CONTROL\tAVCaptureSessionControlsDelegate conformed\t%s\n",
               [[RevenantControlsProbeDelegate new] conformsToProtocol:
                   (Protocol *)objc_getProtocol("AVCaptureSessionControlsDelegate")] ? "yes" : "no");

        FILE *list = fopen(argv[1], "r");
        if (list == NULL) {
            fprintf(stderr, "FAIL: the list did not open, so nothing was examined\n");
            return 1;
        }
        char line[512];
        unsigned classes = 0, members = 0, skipped = 0;
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
                printf("PROTOCOL\t%s\tport=%s\n", first, port_protocol(first) ? "present" : "ABSENT");
            } else if (!strcmp(kind, "member") && second != NULL) {
                probe_member(first, second);
                members++;
            } else if (!strcmp(kind, "protocolmethod") && second != NULL) {
                printf("SKIPPED\t-[%s %s]\tits owner is a protocol, not a class: read out of this binary's "
                       "metadata below\n", first, second);
                skipped++;
            }
        }
        fclose(list);

        probe_answers([AVCaptureSession new], [portSession new]);
        printf("classes probed: %u  members probed: %u  protocol methods read from the metadata: %u\n",
               classes, members, skipped);
    }
    return 0;
}
