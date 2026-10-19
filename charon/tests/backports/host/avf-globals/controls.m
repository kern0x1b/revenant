/* controls.m - the AVCaptureSession controls API the port carries, the port against the host, in ONE binary.
 *
 * The host HAS this API: iOS 18 and macOS 15 added it and this macOS is 27, so AVCaptureControl resolves,
 * all eleven of the session's controls selectors answer, and the answers are the ones a device without
 * CaptureControls gives (this Mac has no camera). That makes this a differential, not a comparison of two
 * empty answers:
 *
 *   CLASS      does the name resolve on each side, and what is its superclass? The port's is
 *              charon_host_AVCaptureControl with the prefix stripped before the comparison, because the two
 *              sides cannot be the same object.
 *   RESPONDS   does each side answer the accessor the registry row names, read out of the port's own
 *              header so a row whose getter= isEnabled is asked for -isEnabled? Both sides must answer: the
 *              claim this phase makes is that the port carries what Apple's own class carries.
 *   ANSWER     what each side answers for the calls whose value can be compared, including the exception
 *              name and the exception reason of the three that refuse. These are the rows that carry the
 *              family: a port that answered YES where Apple answers NO, or raised an exception of its own,
 *              differs here.
 *
 * What is NOT compared, and why:
 *   - configuresApplicationAudioSessionToMixWithOthers' VALUE: the header marks it API_UNAVAILABLE(macos)
 *     on this host, so no macOS caller may send it. The port's side is checked against the header's own
 *     documented default; Apple's is not asked.
 *   - the four sessionControls... methods: a protocol method is sent by the session, and no delegate can be
 *     set on this release, so neither side sends one. The phase checks that the protocol object exists on the
 *     port's side and that its required methods are the ones 26.2 declares.
 *
 * Controls, so a run that examined nothing cannot pass:
 *   AVCaptureNoSuchClass           a planted class name                  -> absent on both sides
 *   AVCaptureControl (host)        the class                              -> present, superclass NSObject
 *   -[AVCaptureControl isEnabled]  one member the host has               -> yes
 *   charon_host_AVCaptureControl   the port's renamed copy                -> present
 *   charon_host_AVCaptureSession   the port's renamed category owner     -> present
 *   AVCaptureSessionControlsDelegate  the protocol, on the port's side   -> present, and conformable
 */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CharonAVFoundationProtocols.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PORT_PREFIX "charon_host_"

static void probe_class(const char *name)
{
    Class host = NSClassFromString([NSString stringWithUTF8String:name]);
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "%s%s", PORT_PREFIX, name);
    Class port = objc_getClass(prefixed);
    printf("CLASS\t%s\thost=%s\tport=%s\n", name,
           host ? "present" : "ABSENT", port ? "present" : "ABSENT");
    if (host && port) {
        /* The superclass is compared by its NAME WITH THE RENAME STRIPPED, because the two sides cannot be the
           same object: the port's class is charon_host_AVCaptureControl and its superclass is named after the
           rename too if the rename reached it. */
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
    /* __unsafe_unretained: objc_copyProtocolList hands back a buffer the runtime has already retained the
       way it documents, and under ARC a plain `Protocol **` cannot be initialised from the
       `Protocol *__unsafe_unretained *` it returns without saying so. */
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

/* One member of one class, asked of each side through the runtime: the host's own class by its bare name,
   the port's by the prefixed one its renamed copy answers to. The sign in the selector says which half of the
   class to ask, because a +[X new] row is a class method and every other row here is an instance method. */
static void probe_member(const char *owner, const char *selector)
{
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "%s%s", PORT_PREFIX, owner);
    Class host = NSClassFromString([NSString stringWithUTF8String:owner]);
    Class port = objc_getClass(prefixed);
    int classMethod = selector[0] == '+';
    /* a property's accessor is spelled without a sign, and one character of it must not be eaten */
    const char *name = (selector[0] == '+' || selector[0] == '-') ? selector + 1 : selector;
    SEL asked = sel_registerName(name);
    printf("RESPONDS\t%c[%s %s]\thost=%s\tport=%s\n", classMethod ? '+' : '-', owner, name,
           (host && (classMethod ? class_getClassMethod(host, asked) : class_getInstanceMethod(host, asked))) ? "yes" : "no",
           (port && (classMethod ? class_getClassMethod(port, asked) : class_getInstanceMethod(port, asked))) ? "yes" : "no");
}

/* What one object answers for one call, as one string: the value for a getter, the exception's name AND its
   reason for a call that refuses. The reason is part of the answer - Apple's reasons name the selector, and
   the port's are the same strings, which is the whole of what this phase compares for the three refusals. */
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

@interface CharonControlsProbeDelegate : NSObject <AVCaptureSessionControlsDelegate>
@end

@implementation CharonControlsProbeDelegate
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

/* Every call whose value both sides can be asked, printed as one row with both columns, so the join is a
   comparison of two columns of one run rather than of two runs that could have drifted. */
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
    /* -controls is an array, so what is compared is its count and the class of it: two empty arrays are
       equal, an array with a control in it is not, and nil is neither. */
    id hostControls = read_object(host, @selector(controls));
    id portControls = read_object(port, @selector(controls));
    /* [x class] as a string: printf's %s does not send -description, it reads the pointer. */
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
    /* The property whose value no macOS caller may ask for: the port's side is read against the header's
       documented default (NO), then set and read back, and the host's side is never asked. */
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
        /* The port's own two objects, through the names their renamed copies answer to. They are controls of
           this run and not rows: a port whose renamed class is not in this binary has examined nothing. */
        Class portControl = objc_getClass(PORT_PREFIX "AVCaptureControl");
        Class portSession = objc_getClass(PORT_PREFIX "AVCaptureSession");
        printf("CONTROL\tcharon_host_AVCaptureControl\t%s\n", portControl ? "HAS" : "ABSENT");
        printf("CONTROL\tcharon_host_AVCaptureSession\t%s\n", portSession ? "HAS" : "ABSENT");
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
        /* The four methods are NOT read out of the protocol object here. protocol_copyMethodDescriptionList
           plus sel_getName crashes on this release - measured, on Apple's own NSObject protocol first, where
           the first required method takes the process down with SIGSEGV, because a protocol's method list
           holds selector references the runtime has not registered - so run.sh reads the four out of this
           binary's own Objective-C metadata with the repository's own reader instead
           (tools/corpus/objc-inventory.lua), which is what the registry check reads as well. What is asked
           of the runtime here is that the protocol object EXISTS and that a class can conform to it. */
        printf("CONTROL\tAVCaptureSessionControlsDelegate conformed\t%s\n",
               [[CharonControlsProbeDelegate new] conformsToProtocol:
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
                /* A method of a PROTOCOL belongs to no class, so there is no class here to ask: what is checked
                   instead is that this binary's own metadata declares it, and run.sh reads that out of the
                   image with tools/corpus/objc-inventory.lua. Printed rather than dropped, so a row the
                   registry names and this run never looks at is visible. */
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