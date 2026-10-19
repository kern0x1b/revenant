/* capabilities.m - the capture-device capability members the port carries, the port against the host, in ONE
 * binary, in one process.
 *
 * The host HAS this API (iOS 17 and macOS 14 added the reaction surface, this macOS is 27) and this Mac has a
 * camera (measured: "MacBook Pro Camera", AVCaptureDeviceTypeBuiltInWideAngleCamera, seven formats), so every
 * row below is something the host answers. What the two sides do NOT necessarily agree on is the capability
 * itself: this camera has reaction effects and background replacement, the devices of this port's bands
 * (an iPhone 4S, an iPad 2) have neither, and the hardware is the reason in both directions. So this run does
 * two things and does not mix them:
 *
 *   RESPONDS  does each side answer the accessor the registry row names, read out of the port's own header so
 *             a row whose getter=isMultichannelAudioModeSupported would be asked under that name? Both sides
 *             must answer: the claim is that the port carries what Apple's own class carries.
 *   ANSWER    what each side answers, printed side by side. run.sh compares each against
 *             expectations.tsv, which carries BOTH columns and, where they differ, the reason. A row whose two
 *             columns differ is not a failure by itself - the hardware differs - and a row whose column
 *             disagrees with the table is.
 *
 * The two CLASS properties are read out of the APPLICATION's Info.plist, so they are checked four times over,
 * with four plists the harness writes itself and an expectation it computes from the plist it just wrote:
 * tests/backports/host/avf-capabilities/run.sh, the "four Info.plists" phase.
 *
 * Controls, so a run that examined nothing cannot pass:
 *   AVCaptureNoSuchClass              a planted name                -> ABSENT on both sides
 *   AVCaptureDevice (host)            the host's own camera         -> present
 *   charon_host_AVCaptureDevice       the port's renamed copy       -> present
 *   charon_host_AVCaptureDeviceFormat the port's renamed copy       -> present
 *   AVCaptureDeviceFormat (host)      the host's active format      -> present
 */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
// The port's own read of the SDK this binary was linked against, so the label below is a MEASUREMENT of this
// binary and not a claim about it: run.sh links this source twice, once with a 26-or-later SDK field and once
// with a pre-26 one, and the two runs have to answer differently for the 26.0 deferred-start defaults.
#import "../CharonProgramSDK.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PORT_PREFIX "charon_host_"

/* What each side answers, as one string. The port's side is asked of the port's own renamed class, the
   stand-in this build declares; the host's of Apple's own camera, which is a real one. */
static void answer_of(id object, SEL selector, char *out, size_t room)
{
    @autoreleasepool {
        @try {
            if (selector == @selector(availableReactionTypes)) {
                /* The eight types sorted and comma-joined: -description of an NSSet wraps over several lines,
                   which is not one field of a tab-separated row. */
                id set = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                NSArray *sorted = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];
                snprintf(out, room, "%lu type(s): %s", (unsigned long)[sorted count],
                         [sorted componentsJoinedByString:@","].UTF8String);
            } else if (selector == @selector(reactionEffectsInProgress)) {
                id array = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%lu running", (unsigned long)[array count]);
            } else if (selector == @selector(supportedVideoZoomRangesForDepthDataDelivery)) {
                id array = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%lu range(s)", (unsigned long)[array count]);
            } else if (selector == @selector(videoFrameRateRangeForReactionEffectsInProgress) ||
                       selector == @selector(videoFrameRateRangeForBackgroundReplacement) ||
                       selector == @selector(videoFrameRateRangeForCinematicVideo) ||
                       selector == @selector(systemRecommendedExposureBiasRange) ||
                       selector == @selector(systemRecommendedVideoZoomRange)) {
                id range = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%s", range ? "a range" : "nil");
            } else if (selector == @selector(focusRectOfInterest) ||
                       selector == @selector(exposureRectOfInterest)) {
                /* CGRectNull is one value of CGRect and prints as three infinities, so it is asked of
                 * CGRectIsNull first: the header's own name for it is what a reader can compare with. */
                CGRect rect = ((CGRect (*)(id, SEL))objc_msgSend)(object, selector);
                if (CGRectIsNull(rect))
                    snprintf(out, room, "CGRectNull");
                else
                    snprintf(out, room, "%g %g %g %g", rect.origin.x, rect.origin.y, rect.size.width,
                             rect.size.height);
            } else if (selector == @selector(minFocusRectOfInterestSize) ||
                       selector == @selector(minExposureRectOfInterestSize)) {
                CGSize size = ((CGSize (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%g %g", size.width, size.height);
            } else if (selector == @selector(spatialCaptureDiscomfortReasons)) {
                /* The two reasons and the eight reaction types alike: a set rendered as one field. */
                id set = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                NSArray *sorted = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];
                snprintf(out, room, "%lu reason(s): %s", (unsigned long)[sorted count],
                         [sorted componentsJoinedByString:@","].UTF8String);
            } else if (selector == @selector(isCameraLensSmudgeDetectionSupported)) {
                /* This one row is asked with its exception NAME and not its reason, and the reason is why:
                 * sent to this host's own camera, -[AVCaptureDeviceFormat isCameraLensSmudgeDetectionSupported]
                 * raises NSInvalidArgumentException for all seven of its formats ("-[__NSCFType mediaType]:
                 * unrecognized selector sent to instance 0x...", inside Apple's own -figCaptureSourceVideoFormat),
                 * and that reason carries an object's ADDRESS, which is a different string on every run and so
                 * cannot be a table's expectation. The name is the part that is a value. */
                int raised = 0;
                @try {
                    snprintf(out, room, "%d", (int)((BOOL (*)(id, SEL))objc_msgSend)(object, selector));
                } @catch (NSException *exception) {
                    raised = 1;
                    snprintf(out, room, "RAISED %s", exception.name.UTF8String);
                }
                (void)raised;
            } else if (selector == @selector(dynamicAspectRatio)) {
                id ratio = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%s", ratio ? [ratio UTF8String] : "nil");
            } else if (selector == @selector(dynamicDimensions)) {
                CMVideoDimensions size = ((CMVideoDimensions (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%dx%d", size.width, size.height);
            } else if (selector == @selector(supportedDynamicAspectRatios)) {
                id list = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                NSArray *sorted = [[list allObjects] sortedArrayUsingSelector:@selector(compare:)];
                snprintf(out, room, "%lu ratio(s): %s", (unsigned long)[sorted count],
                         [sorted componentsJoinedByString:@","].UTF8String);
            } else if (selector == @selector(minSupportedLockedVideoFrameDuration) ||
                       selector == @selector(minSupportedExternalSyncFrameDuration) ||
                       selector == @selector(activeLockedVideoFrameDuration) ||
                       selector == @selector(activeExternalSyncVideoFrameDuration) ||
                       selector == @selector(cameraLensSmudgeDetectionInterval)) {
                /* A CMTime is a struct returned in registers, so it cannot be read through a pointer cast the
                 * way an object can; and its invalid value is the header's own answer for five of this
                 * family's rows, so it is spelled out rather than printed as zeroes. */
                CMTime time = ((CMTime (*)(id, SEL))objc_msgSend)(object, selector);
                if (CMTIME_IS_INVALID(time))
                    snprintf(out, room, "kCMTimeInvalid");
                else
                    snprintf(out, room, "%lld/%lld", (long long)time.value, (long long)time.timescale);
            } else if (selector == @selector(externalSyncDevice)) {
                id device = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%s", device ? "a device" : "nil");
            } else if (selector == @selector(cinematicVideoCaptureSceneMonitoringStatuses)) {
                id set = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                NSArray *sorted = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];
                snprintf(out, room, "%lu status(es): %s", (unsigned long)[sorted count],
                         [sorted componentsJoinedByString:@","].UTF8String);
            } else if (selector == @selector(displayVideoZoomFactorMultiplier) ||
                       selector == @selector(videoMinZoomFactorForCinematicVideo) ||
                       selector == @selector(videoMaxZoomFactorForCinematicVideo)) {
                /* The only CGFloat of the two slices, so it cannot be read through a BOOL cast. */
                snprintf(out, room, "%g", ((double (*)(id, SEL))objc_msgSend)(object, selector));
            } else if (selector == @selector(multichannelAudioMode)) {
                /* The enum is spelled out as well as numbered: the numbers are the header's own
                   (AVCaptureInput.h:365-367) and a reader can check them without this file. */
                long mode = (long)((NSInteger (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%ld %s", mode, mode == 0 ? "None" : mode == 1 ? "Stereo" :
                         mode == 2 ? "FirstOrderAmbisonics" : "(not one of the three)");
            } else if (selector == @selector(deferredStartDelegate) ||
                       selector == @selector(deferredStartDelegateCallbackQueue)) {
                id held = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%s", held ? "set" : "nil");
            } else if (selector == @selector(systemPreferredCamera) || selector == @selector(userPreferredCamera)) {
                id camera = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                snprintf(out, room, "%s", camera ? "a camera" : "nil");
            } else {
                snprintf(out, room, "%d", (int)((BOOL (*)(id, SEL))objc_msgSend)(object, selector));
            }
        } @catch (NSException *exception) {
            snprintf(out, room, "%s: %s", exception.name.UTF8String,
                     exception.reason ? exception.reason.UTF8String : "(no reason)");
        }
    }
}

/* A refusal: what the call raises, which is part of its answer, and both sides' answer in one row so it can be
 * compared the way every other row here is. Printing one side's exception name with nothing beside it was a
 * row nobody could check, which is what this was for four runs. */
static void raise_of(id hostObject, id portObject, SEL selector, id argument, const char *label)
{
    char hostAnswer[512], portAnswer[512];
    for (int side = 0; side < 2; side++) {
        id object = side ? portObject : hostObject;
        char *out = side ? portAnswer : hostAnswer;
        @autoreleasepool {
            @try {
                ((void (*)(id, SEL, id))objc_msgSend)(object, selector, argument);
                snprintf(out, 512, "returned");
            } @catch (NSException *exception) {
                snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                         exception.reason ? exception.reason.UTF8String : "(no reason)");
            }
        }
    }
    printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", label, hostAnswer, portAnswer);
}

static void class_answer_of(Class cls, SEL selector, char *out, size_t room)
{
    @autoreleasepool {
        @try {
            if (selector == @selector(systemPreferredCamera) || selector == @selector(userPreferredCamera)) {
                id camera = ((id (*)(Class, SEL))objc_msgSend)(cls, selector);
                /* named, not just "a camera": which camera answers is the whole content of these two rows. */
                snprintf(out, room, "%s", camera ? [(NSString *)[camera valueForKey:@"uniqueID"] UTF8String] : "nil");
            } else {
                snprintf(out, room, "%d", (int)((BOOL (*)(Class, SEL))objc_msgSend)(cls, selector));
            }
        } @catch (NSException *exception) {
            snprintf(out, room, "%s: %s", exception.name.UTF8String,
                     exception.reason ? exception.reason.UTF8String : "(no reason)");
        }
    }
}

static void print_class_answer(Class host, Class port, const char *label, SEL selector)
{
    char hostAnswer[512], portAnswer[512];
    class_answer_of(host, selector, hostAnswer, sizeof hostAnswer);
    class_answer_of(port, selector, portAnswer, sizeof portAnswer);
    printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", label, hostAnswer, portAnswer);
}

/* THE PREFERRED-CAMERA PAIR, and the five rules of the header that shape it
   (AVCaptureDevice.h:661-663 for the user's choice, :674 for the system's):
     persists "across app launches and reboots"; a "short history", so a camera that is not connected now still
     reports "the next best choice"; "always returns a device that is present"; nil only "if no camera is
     available"; and "Setting the property to nil has no effect".
   None of the four is a constant, so each is asked as its own step below with its own expectation, computed in
   run.sh from the step it belongs to.

   The PORT's device list is the stand-in's, not Apple's: the copy run.sh compiles renames the class name in the
   port's SOURCES as well, so the `[AVCaptureDevice devicesWithMediaType:]` and
   `[AVCaptureDevice defaultDeviceWithMediaType:]` inside the port's code reach the stand-in class and this run
   decides which cameras are present by handing it a list. The HOST's column is asked of Apple's own camera and
   carries the process's camera authorization beside it, because a nil from a process that was never granted
   access is the answer for that process and not Apple's answer for the row. */

/* Which cameras the port's class is to see. The seam belongs to this build: it is declared in the harness's own
   prologue, never in the port's sources, so nothing the library carries depends on it. */
static void set_present(Class portDevice, NSArray *devices)
{
    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(charon_host_setPresentDevices:), devices);
}

static id make_device(Class portDevice, NSString *identifier, NSString *name, long position)
{
    id device = [portDevice new];
    ((void (*)(id, SEL, id))objc_msgSend)(device, @selector(setUniqueID:), identifier);
    ((void (*)(id, SEL, id))objc_msgSend)(device, @selector(setLocalizedName:), name);
    ((void (*)(id, SEL, long))objc_msgSend)(device, @selector(setPosition:), position);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(device, @selector(setConnected:), YES);
    return device;
}

/* The two cameras of a device of this port's bands, on each side (facts/AVFoundation/
   AVCaptureDeviceDiscovery.md, "What the hardware has", measured on an iPhone 4S and an iPad 2). */
static id prefcam_back, prefcam_front;

static void prefcam_setup(Class portDevice)
{
    /* AVCaptureDevicePositionUnspecified 0, Back 1, Front 2 - the release's own numbering (AVFoundation.h). */
    prefcam_back = make_device(portDevice, @"back-camera", @"Back Camera", 1);
    prefcam_front = make_device(portDevice, @"front-camera", @"Front Camera", 2);
    set_present(portDevice, @[prefcam_back, prefcam_front]);
}

/* What the application's own defaults hold for the history, in one string, so a run that persisted nothing
   reads "0 entries []" and not an empty string: the comparison in run.sh is a string comparison. */
static NSString *stored_history(void)
{
    id history = [[NSUserDefaults standardUserDefaults]
        objectForKey:@"CharonCaptureUserPreferredCameraHistory"];
    NSArray *entries = [history isKindOfClass:[NSArray class]] ? history : [NSArray array];
    return [NSString stringWithFormat:@"%lu entr%s [%@]", (unsigned long)entries.count,
                                      entries.count == 1 ? "y" : "ies",
                                      entries.count ? [entries componentsJoinedByString:@","] : @""];
}

static void prefcam_step(Class portDevice, const char *label)
{
    char user[512], system[512], stored[512];
    class_answer_of(portDevice, @selector(userPreferredCamera), user, sizeof user);
    class_answer_of(portDevice, @selector(systemPreferredCamera), system, sizeof system);
    /* What the application's own defaults hold, so a run that persisted nothing shows an empty history and a
       second launch over the same bundle can be compared against the first one's. */
    snprintf(stored, sizeof stored, "%s", stored_history().UTF8String);
    printf("PREFCAM\t%s\tuser=[%s]\tsystem=[%s]\tdefaults=[%s]\n", label, user, system, stored);
}

/* ACROSS LAUNCHES. argv[2] = "persist" makes this a launch of the persistence pair instead: "set" chooses the
   front camera and leaves it, "read" chooses nothing and only reports what this process finds. The header's
   promise is "across app launches and reboots" (AVCaptureDevice.h:661), which one process's own memory cannot
   answer, so run.sh runs two of these over one bundle and a third over a bundle of its own. */
static void persist_phase(Class portDevice, const char *mode)
{
    if (!strcmp(mode, "set")) {
        /* A launch that MAKES the choice starts by forgetting any earlier one, so the pair does not inherit a
           domain an earlier run of this harness left behind: the count printed below is this launch's own. */
        [[NSUserDefaults standardUserDefaults]
            removeObjectForKey:@"CharonCaptureUserPreferredCameraHistory"];
        ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), prefcam_front);
    }
    char user[512], system[512];
    class_answer_of(portDevice, @selector(userPreferredCamera), user, sizeof user);
    class_answer_of(portDevice, @selector(systemPreferredCamera), system, sizeof system);
    id history = [[NSUserDefaults standardUserDefaults]
        objectForKey:@"CharonCaptureUserPreferredCameraHistory"];
    NSArray *entries = [history isKindOfClass:[NSArray class]] ? history : [NSArray array];
    printf("PERSIST\t%s\t%s\tsystem=[%s]\t%lu entr%s in this bundle's own defaults\n",
           strcmp(mode, "set") ? "second-launch" : "first-launch", user, system, (unsigned long)entries.count,
           entries.count == 1 ? "y" : "ies");
}

/* THE 18.0 SLICE'S TWO PHASES, both over the same two objects as the table above.
 *
 * SUPPORT asks -[AVCaptureDeviceInput isMultichannelAudioModeSupported:] with each of the three values of the
 * enum, on both sides. It is asked three times and not once because the header's own subject is the value:
 * the header's rule is that the multichannelAudioMode property takes a given mode only when this method answers YES for that mode (AVCaptureInput.h:381), so one answer cannot stand for the rule.
 *
 * SETTER sends each of the three readwrite members of the slice and records what happened, then asks the getter
 * again. A refusal is part of an answer here - two of these three setters refuse on this release and Apple's own
 * do as well - so what the row carries is either the raised exception with its reason, exactly as the caller
 * reads it, or the value the getter answers after the set was accepted. The probe sends through objc_msgSend
 * with a correctly typed argument: an NSNumber where the setter takes NSInteger puts a pointer in the integer
 * register, and a probe that does that reports a refusal Apple's own class does not raise (measured, and the
 * reading withdrawn - see the facts page). */
static void support_phase(id hostInput, id portInput)
{
    for (NSInteger mode = 0; mode < 3; mode++) {
        char hostAnswer[128], portAnswer[128];
        snprintf(hostAnswer, sizeof hostAnswer, "%d",
                 (int)((BOOL (*)(id, SEL, NSInteger))objc_msgSend)(hostInput,
                                                                 @selector(isMultichannelAudioModeSupported:), mode));
        snprintf(portAnswer, sizeof portAnswer, "%d",
                 (int)((BOOL (*)(id, SEL, NSInteger))objc_msgSend)(portInput,
                                                                 @selector(isMultichannelAudioModeSupported:), mode));
        printf("ANSWER	-[AVCaptureDeviceInput isMultichannelAudioModeSupported:] mode %ld\thost=[%s]\tport=[%s]\n",
               (long)mode, hostAnswer, portAnswer);
    }
}

/* One setter, asked with one value, and what the getter answered afterwards. The two kinds of answer are
 * spelled here once so every case reads the same: the value the getter answers after an accepted set, or the
 * exception with the reason the caller reads. NONE of the three getters here returns an object - two are BOOL
 * and one is the enum - so the getter is asked through the type it returns rather than through an id cast, which
 * would read a BOOL as a pointer and send -UTF8String to it. */
typedef enum { CharonGetterBool, CharonGetterEnum } CharonGetterKind;

static void setter_case(id hostObject, id portObject, SEL setter, SEL getter, CharonGetterKind kind,
                        NSInteger argument, const char *label)
{
    char hostAnswer[512], portAnswer[512];
    for (int side = 0; side < 2; side++) {
        id object = side ? portObject : hostObject;
        char *out = side ? portAnswer : hostAnswer;
        @autoreleasepool {
            @try {
                /* The value goes in as an NSInteger for every one of these, the BOOL setters included: a
                 * BOOL parameter is read out of the low byte of the same register, which is what clang does
                 * when a caller writes `setX:someBool`. Sending a literal 1 for the BOOL cases instead made
                 * the "false" case send YES - the case passed, on both sides, for a value it never sent. */
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(object, setter, argument);
                char readback[64];
                if (kind == CharonGetterBool)
                    snprintf(readback, sizeof readback, "%d",
                             (int)((BOOL (*)(id, SEL))objc_msgSend)(object, getter));
                else
                    snprintf(readback, sizeof readback, "%ld",
                             (long)((NSInteger (*)(id, SEL))objc_msgSend)(object, getter));
                snprintf(out, 512, "returned, the getter answers %s", readback);
            } @catch (NSException *exception) {
                snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                         exception.reason ? exception.reason.UTF8String : "(no reason)");
            }
        }
    }
    printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", label, hostAnswer, portAnswer);
}

static void setter_phase(id hostCamera, id portCamera, id hostInput, id portInput)
{
    setter_case(hostCamera, portCamera, @selector(setAutoVideoFrameRateEnabled:),
                @selector(isAutoVideoFrameRateEnabled), CharonGetterBool, 1,
                "AVCaptureDevice.setAutoVideoFrameRateEnabled: true");
    setter_case(hostCamera, portCamera, @selector(setAutoVideoFrameRateEnabled:),
                @selector(isAutoVideoFrameRateEnabled), CharonGetterBool, 0,
                "AVCaptureDevice.setAutoVideoFrameRateEnabled: false");
    setter_case(hostInput, portInput, @selector(setMultichannelAudioMode:), @selector(multichannelAudioMode),
                CharonGetterEnum, 0, "AVCaptureDeviceInput.setMultichannelAudioMode: None");
    setter_case(hostInput, portInput, @selector(setMultichannelAudioMode:), @selector(multichannelAudioMode),
                CharonGetterEnum, 1, "AVCaptureDeviceInput.setMultichannelAudioMode: Stereo");
    setter_case(hostInput, portInput, @selector(setMultichannelAudioMode:), @selector(multichannelAudioMode),
                CharonGetterEnum, 2, "AVCaptureDeviceInput.setMultichannelAudioMode: FirstOrderAmbisonics");
    setter_case(hostInput, portInput, @selector(setWindNoiseRemovalEnabled:), @selector(isWindNoiseRemovalEnabled),
                CharonGetterBool, 1, "AVCaptureDeviceInput.setWindNoiseRemovalEnabled: true");
    setter_case(hostInput, portInput, @selector(setWindNoiseRemovalEnabled:), @selector(isWindNoiseRemovalEnabled),
                CharonGetterBool, 0, "AVCaptureDeviceInput.setWindNoiseRemovalEnabled: false");
}

/* THE 26.0 RECTANGLES OF INTEREST, and the substrate they are applied through.
 *
 * A rectangle of interest is applied through the release's own point of interest (AVCaptureDevice.h:1171), so
 * the stand-in device carries the release's members and this phase asks the PORT's code about them: the support
 * flag is the stand-in's (flipped by main() so both branches of the port's rule are asked), the lock is the
 * stand-in's, and the rectangle itself is the port's.
 *
 * The six properties are asked by the member table above, which reads them from the registry and the port's
 * own header; what is left here is what the table cannot ask: the two default-rectangle methods (each with
 * two points, because the header's subject is the point) and the two setters (unlocked and locked).
 * The host's column is Apple's own class, and its refusals carry Apple's own text - and the port's answers are
 * the same branch of the same rule, because a rectangle of interest is weighed as an area and this release
 * cannot weigh one, so the port says the device does not support it (the coordinator's ruling, 2026-10-03).
 */
static void rect_case(id hostObject, id portObject, SEL getter, const char *label)
{
    char hostAnswer[128], portAnswer[128];
    for (int side = 0; side < 2; side++) {
        id object = side ? portObject : hostObject;
        char *out = side ? portAnswer : hostAnswer;
        CGRect rect = ((CGRect (*)(id, SEL))objc_msgSend)(object, getter);
        if (CGRectIsNull(rect))
            snprintf(out, 128, "CGRectNull");
        else
            snprintf(out, 128, "%g %g %g %g", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    }
    printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", label, hostAnswer, portAnswer);
}

/* One rectangle write, and what the point of interest and the rectangle answer afterwards. The point is printed
 * as well as the rectangle because the header's own effect is that the point becomes the centre. */
static void rect_write(id hostObject, id portObject, SEL setter, SEL rectGetter, SEL pointGetter,
                      CGRect rect, const char *label)
{
    char hostAnswer[512], portAnswer[512];
    for (int side = 0; side < 2; side++) {
        id object = side ? portObject : hostObject;
        char *out = side ? portAnswer : hostAnswer;
        @autoreleasepool {
            @try {
                ((void (*)(id, SEL, CGRect))objc_msgSend)(object, setter, rect);
                CGRect after = ((CGRect (*)(id, SEL))objc_msgSend)(object, rectGetter);
                CGPoint point = ((CGPoint (*)(id, SEL))objc_msgSend)(object, pointGetter);
                snprintf(out, 512, "returned, the rectangle answers %g %g %g %g and the point [%g %g]",
                         after.origin.x, after.origin.y, after.size.width, after.size.height, point.x, point.y);
            } @catch (NSException *exception) {
                snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                         exception.reason ? exception.reason.UTF8String : "(no reason)");
            }
        }
    }
    printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", label, hostAnswer, portAnswer);
}

/* Which of the port's own objects a row is asked of, so the NOHOST branch above can ask the port's side
 * without repeating the choice the loop below makes. */
static int onInputOwner(const char *owner)
{
    return !strcmp(owner, "AVCaptureDeviceInput");
}

/* THE 26.0 CINEMATIC VIDEO PHASE: the one readwrite member of the family, asked twice, and the three focus
 * methods, whose answer on this host is a refusal with Apple's own reason. Each is asked of both sides and
 * compared through expectations.tsv like every other row. */
static void cinematic_phase(id hostCamera, id portCamera, id hostInput, id portInput)
{
    for (int value = 0; value < 2; value++) {
        char hostAnswer[512], portAnswer[512];
        for (int side = 0; side < 2; side++) {
            id object = side ? portInput : hostInput;
            char *out = side ? portAnswer : hostAnswer;
            @autoreleasepool {
                @try {
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(object,
                                                          @selector(setCinematicVideoCaptureEnabled:), value);
                    snprintf(out, 512, "returned, the getter answers %d",
                             (int)((BOOL (*)(id, SEL))objc_msgSend)(object,
                                                                     @selector(isCinematicVideoCaptureEnabled)));
                } @catch (NSException *exception) {
                    snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                             exception.reason ? exception.reason.UTF8String : "(no reason)");
                }
            }
        }
        printf("ANSWER\tAVCaptureDeviceInput.setCinematicVideoCaptureEnabled: %s\thost=[%s]\tport=[%s]\n",
               value ? "true" : "false", hostAnswer, portAnswer);
    }
    /* The three focus methods, each with the arguments its own header names. */
    struct { const char *label; SEL selector; NSInteger first; NSInteger second; } cases[] = {
        {"-[AVCaptureDevice setCinematicVideoFixedFocusAtPoint:focusMode:] 0.5 0.5 Strong",
         @selector(setCinematicVideoFixedFocusAtPoint:focusMode:), 0, 1},
        {"-[AVCaptureDevice setCinematicVideoTrackingFocusAtPoint:focusMode:] 0.5 0.5 Weak",
         @selector(setCinematicVideoTrackingFocusAtPoint:focusMode:), 0, 2},
        {"-[AVCaptureDevice setCinematicVideoTrackingFocusWithDetectedObjectID:focusMode:] 7 Strong",
         @selector(setCinematicVideoTrackingFocusWithDetectedObjectID:focusMode:), 7, 1},
    };
    for (unsigned i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        char hostAnswer[512], portAnswer[512];
        for (int side = 0; side < 2; side++) {
            id object = side ? portCamera : hostCamera;
            char *out = side ? portAnswer : hostAnswer;
            @autoreleasepool {
                @try {
                    if (cases[i].first == 0 && cases[i].second == 1)
                        ((void (*)(id, SEL, CGPoint, NSInteger))objc_msgSend)(object, cases[i].selector,
                                                                             CGPointMake(0.5, 0.5),
                                                                             cases[i].second);
                    else if (cases[i].first == 0)
                        ((void (*)(id, SEL, CGPoint, NSInteger))objc_msgSend)(object, cases[i].selector,
                                                                             CGPointMake(0.5, 0.5),
                                                                             cases[i].second);
                    else
                        ((void (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(object, cases[i].selector,
                                                                               cases[i].first,
                                                                               cases[i].second);
                    snprintf(out, 512, "returned");
                } @catch (NSException *exception) {
                    snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                             exception.reason ? exception.reason.UTF8String : "(no reason)");
                }
            }
        }
        printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", cases[i].label, hostAnswer, portAnswer);
    }
}

static void rect_phase(id hostCamera, id portCamera, Class portStandinClass)
{
    /* The stand-in's support flag stays where main() set it (YES), because the 26.0 Cinematic Video input flag
     * reads it through the format; the rectangle family does not read it at all any more, because the port
     * answers NO for a device this release cannot weigh an area on, which is the ruling this run now checks.
     * Both sides are asked the same way, and where they differ the answer says why. */
    ((void (*)(Class, SEL, BOOL))objc_msgSend)(portStandinClass,
                                               @selector(charon_host_setPointsOfInterestSupported:), YES);
    rect_case(hostCamera, portCamera, @selector(focusRectOfInterest), "AVCaptureDevice.focusRectOfInterest unset");
    rect_case(hostCamera, portCamera, @selector(exposureRectOfInterest),
              "AVCaptureDevice.exposureRectOfInterest unset");
    /* The two default-rectangle methods, each with two points. Two cases and not one loop with a formatted
     * name: printf has no %@, and a %@ in a format string makes it take the NEXT argument as the object -
     * here the double 0.5, whose bit pattern strlen() then walked, which took the probe down (measured, the
     * address it faulted on was 0x3fe0000000000000, which is 0.5). */
    for (int mode = 0; mode < 2; mode++) {
        for (int step = 0; step < 2; step++) {
            CGPoint point = step ? CGPointMake(0.75, 0.75) : CGPointMake(0.5, 0.5);
            char hostAnswer[128], portAnswer[128];
            SEL getter = mode ? @selector(defaultRectForExposurePointOfInterest:)
                              : @selector(defaultRectForFocusPointOfInterest:);
            for (int side = 0; side < 2; side++) {
                id object = side ? portCamera : hostCamera;
                char *out = side ? portAnswer : hostAnswer;
                CGRect rect = ((CGRect (*)(id, SEL, CGPoint))objc_msgSend)(object, getter, point);
                if (CGRectIsNull(rect))
                    snprintf(out, 128, "CGRectNull");
                else
                    snprintf(out, 128, "%g %g %g %g", rect.origin.x, rect.origin.y, rect.size.width,
                             rect.size.height);
            }
            if (mode)
                printf("ANSWER\t-[AVCaptureDevice defaultRectForExposurePointOfInterest:] %g %g\thost=[%s]"
                       "\tport=[%s]\n", point.x, point.y, hostAnswer, portAnswer);
            else
                printf("ANSWER\t-[AVCaptureDevice defaultRectForFocusPointOfInterest:] %g %g\thost=[%s]"
                       "\tport=[%s]\n", point.x, point.y, hostAnswer, portAnswer);
        }
    }
    /* The three refusals in the order Apple's own raises them, then the accepted write. */
    rect_write(hostCamera, portCamera, @selector(setFocusRectOfInterest:), @selector(focusRectOfInterest),
               @selector(focusPointOfInterest), CGRectMake(0, 0, 0.25, 0.25),
               "AVCaptureDevice.setFocusRectOfInterest: a quarter by a quarter, unlocked");
    /* The lock, on both sides: the host's own class asks it before it does anything else (measured: an
     * unlocked write raises NSGenericException even where the device does not support the rectangle), and the
     * stand-in's substrate refuses its own point without it too. */
    ((void (*)(id, SEL))objc_msgSend)(portCamera, @selector(lockForConfiguration));
    /* The host's own lock is the release's public -lockForConfiguration:, which takes the NSError out
     * parameter; the stand-in's is the harness's own -lockForConfiguration, which the stand-in's substrate
     * setters ask (there is no 6.1.3 release in this process to ask). */
    ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(hostCamera, @selector(lockForConfiguration:), NULL);
    rect_write(hostCamera, portCamera, @selector(setFocusRectOfInterest:), @selector(focusRectOfInterest),
               @selector(focusPointOfInterest), CGRectMake(0, 0, 0.25, 0.25),
               "AVCaptureDevice.setFocusRectOfInterest: a quarter by a quarter, locked");
    rect_write(hostCamera, portCamera, @selector(setExposureRectOfInterest:), @selector(exposureRectOfInterest),
               @selector(exposurePointOfInterest), CGRectMake(0.25, 0.25, 0.5, 0.5),
               "AVCaptureDevice.setExposureRectOfInterest: half by half, locked");
}

/* THE 26.0 EXTERNAL-SYNC AND LOCKED-FRAME-DURATION PHASE: the two methods, which are the family's only
 * writes. followExternalSyncDevice:videoFrameDuration:delegate: refuses on this release with Apple's own
 * reason, measured; unfollowExternalSyncDevice returns, because nothing is followed. The locked-duration
 * setter is asked too, since it is the one write whose behaviour DIFFERS between the two sides and the
 * difference belongs in a row of its own. */
static void sync_phase(id hostInput, id portInput)
{
    char hostAnswer[512], portAnswer[512];
    for (int side = 0; side < 2; side++) {
        id object = side ? portInput : hostInput;
        char *out = side ? portAnswer : hostAnswer;
        @autoreleasepool {
            @try {
                ((void (*)(id, SEL, id, CMTime, id))objc_msgSend)(object,
                                                                  @selector(followExternalSyncDevice:videoFrameDuration:delegate:),
                                                                  nil, CMTimeMake(1, 30), nil);
                snprintf(out, 512, "returned");
            } @catch (NSException *exception) {
                snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                         exception.reason ? exception.reason.UTF8String : "(no reason)");
            }
        }
    }
    printf("ANSWER\t-[AVCaptureDeviceInput followExternalSyncDevice:videoFrameDuration:delegate:] nil 1/30 nil"
           "\thost=[%s]\tport=[%s]\n", hostAnswer, portAnswer);
    for (int side = 0; side < 2; side++) {
        id object = side ? portInput : hostInput;
        char *out = side ? portAnswer : hostAnswer;
        @autoreleasepool {
            @try {
                ((void (*)(id, SEL))objc_msgSend)(object, @selector(unfollowExternalSyncDevice));
                snprintf(out, 512, "returned");
            } @catch (NSException *exception) {
                snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                         exception.reason ? exception.reason.UTF8String : "(no reason)");
            }
        }
    }
    printf("ANSWER\t-[AVCaptureDeviceInput unfollowExternalSyncDevice]\thost=[%s]\tport=[%s]\n", hostAnswer,
           portAnswer);
    /* The locked-duration setter, which is where the two sides differ: the host's own class ACCEPTS a valid
     * value on a device that cannot lock (measured) and the port refuses, by the header's rule. */
    for (int side = 0; side < 2; side++) {
        id object = side ? portInput : hostInput;
        char *out = side ? portAnswer : hostAnswer;
        @autoreleasepool {
            @try {
                ((void (*)(id, SEL, CMTime))objc_msgSend)(object, @selector(setActiveLockedVideoFrameDuration:),
                                                          CMTimeMake(1, 30));
                CMTime after = ((CMTime (*)(id, SEL))objc_msgSend)(object,
                                                                    @selector(activeLockedVideoFrameDuration));
                snprintf(out, 512, "returned, the getter answers %s",
                         CMTIME_IS_INVALID(after) ? "kCMTimeInvalid" : "a valid time");
            } @catch (NSException *exception) {
                snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                         exception.reason ? exception.reason.UTF8String : "(no reason)");
            }
        }
    }
    printf("ANSWER\tAVCaptureDeviceInput.setActiveLockedVideoFrameDuration: 1/30\thost=[%s]\tport=[%s]\n",
           hostAnswer, portAnswer);
}

/* THE 26.0 DYNAMIC-ASPECT-RATIO, SMUDGE-DETECTION AND APERTURE PHASE: the two device setters and the input's
 * aperture, each asked of both sides. All three refuse on this release, two of them with Apple's own measured
 * reason, and the aperture setter's refusal is the header's rule read through the format's minimum - which is
 * what the plant `smudge` moves. */
static void dynamic_phase(id hostCamera, id portCamera, id hostInput, id portInput)
{
    struct { const char *label; SEL selector; int kind; } cases[] = {
        {"-[AVCaptureDevice setDynamicAspectRatio:completionHandler:] 16x9",
         @selector(setDynamicAspectRatio:completionHandler:), 0},
        {"-[AVCaptureDevice setCameraLensSmudgeDetectionEnabled:detectionInterval:] true 1s",
         @selector(setCameraLensSmudgeDetectionEnabled:detectionInterval:), 0},
        {"AVCaptureDeviceInput.setSimulatedAperture: 2", @selector(setSimulatedAperture:), 1},
    };
    for (unsigned i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        char hostAnswer[512], portAnswer[512];
        for (int side = 0; side < 2; side++) {
            id camera = side ? portCamera : hostCamera;
            id input = side ? portInput : hostInput;
            char *out = side ? portAnswer : hostAnswer;
            @autoreleasepool {
                @try {
                    switch (i) {
                    case 0:
                        ((void (*)(id, SEL, id, id))objc_msgSend)(camera, cases[i].selector, @"16x9", (id)0);
                        break;
                    case 1:
                        ((void (*)(id, SEL, BOOL, CMTime))objc_msgSend)(camera, cases[i].selector, YES,
                                                                         CMTimeMake(1, 1));
                        break;
                    default:
                        ((void (*)(id, SEL, float))objc_msgSend)(input, cases[i].selector, 2.0f);
                        break;
                    }
                    snprintf(out, 512, "returned");
                } @catch (NSException *exception) {
                    snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                             exception.reason ? exception.reason.UTF8String : "(no reason)");
                }
            }
        }
        printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", cases[i].label, hostAnswer, portAnswer);
    }
}

/* A delegate for the deferred-start setter. Any object will do: the port's setter refuses before it looks at
 * it, and Apple's does too on this host (measured), so the case below is about the refusal and not about what
 * would be stored. The class conforms to the protocol so the host's own setter would accept it if the feature
 * were supported, which is what makes the case a fair one. */
@interface AvfProbeDelegate : NSObject <AVCaptureSessionDeferredStartDelegate>
@end
@implementation AvfProbeDelegate
- (void)sessionWillRunDeferredStart:(AVCaptureSession *)session { }
- (void)sessionDidRunDeferredStart:(AVCaptureSession *)session { }
@end

/* THE 26.0 DEFERRED START PHASE: the two session methods and the three setters, each asked of both sides.
 * Every one of them refuses on this release and two of the five refuse with Apple's own reason character for
 * character; the output's and the layer's flag are the two rows where the host and the port differ, and both
 * columns are in the table. */
static void deferred_phase(id hostSession, id portSession, id hostOutput, id portOutput, id hostLayer,
                            id portLayer)
{
    AvfProbeDelegate *delegate = [[AvfProbeDelegate alloc] init];
    dispatch_queue_t queue = dispatch_queue_create("org.charon.probe.avf-deferred", DISPATCH_QUEUE_SERIAL);
    struct { const char *label; id hostObject; id portObject; SEL selector; int kind; } cases[] = {
        {"-[AVCaptureSession setDeferredStartDelegate:deferredStartDelegateCallbackQueue:] with a delegate and a queue",
         hostSession, portSession, @selector(setDeferredStartDelegate:deferredStartDelegateCallbackQueue:), 0},
        {"-[AVCaptureSession setDeferredStartDelegate:deferredStartDelegateCallbackQueue:] with a delegate and NULL",
         hostSession, portSession, @selector(setDeferredStartDelegate:deferredStartDelegateCallbackQueue:), 2},
        {"-[AVCaptureSession runDeferredStartWhenNeeded]", hostSession, portSession,
         @selector(runDeferredStartWhenNeeded), 1},
        {"AVCaptureSession.setAutomaticallyRunsDeferredStart: false", hostSession, portSession,
         @selector(setAutomaticallyRunsDeferredStart:), 3},
        {"AVCaptureOutput.setDeferredStartEnabled: true", hostOutput, portOutput,
         @selector(setDeferredStartEnabled:), 4},
        {"AVCaptureVideoPreviewLayer.setDeferredStartEnabled: true", hostLayer, portLayer,
         @selector(setDeferredStartEnabled:), 4},
    };
    for (unsigned i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        char hostAnswer[512], portAnswer[512];
        for (int side = 0; side < 2; side++) {
            id object = side ? cases[i].portObject : cases[i].hostObject;
            char *out = side ? portAnswer : hostAnswer;
            @autoreleasepool {
                @try {
                    switch (cases[i].kind) {
                    case 0:
                        ((void (*)(id, SEL, id, id))objc_msgSend)(object, cases[i].selector, delegate, (id)queue);
                        break;
                    case 2:
                        ((void (*)(id, SEL, id, id))objc_msgSend)(object, cases[i].selector, delegate, (id)0);
                        break;
                    case 1:
                        ((void (*)(id, SEL))objc_msgSend)(object, cases[i].selector);
                        break;
                    case 3:
                        ((void (*)(id, SEL, BOOL))objc_msgSend)(object, cases[i].selector, 0);
                        break;
                    default:
                        ((void (*)(id, SEL, BOOL))objc_msgSend)(object, cases[i].selector, 1);
                        break;
                    }
                    snprintf(out, 512, "returned");
                } @catch (NSException *exception) {
                    snprintf(out, 512, "raised %s: %s", exception.name.UTF8String,
                             exception.reason ? exception.reason.UTF8String : "(no reason)");
                }
            }
        }
        printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", cases[i].label, hostAnswer, portAnswer);
    }
    /* What the session holds after all of that: nothing, on either side, because nothing could be set. */
    char hostAnswer[128], portAnswer[128];
    for (int side = 0; side < 2; side++) {
        id object = side ? portSession : hostSession;
        char *out = side ? portAnswer : hostAnswer;
        id held = ((id (*)(id, SEL))objc_msgSend)(object, @selector(deferredStartDelegate));
        id heldQueue = ((id (*)(id, SEL))objc_msgSend)(object, @selector(deferredStartDelegateCallbackQueue));
        snprintf(out, 128, "delegate=%s queue=%s", held ? "set" : "nil", heldQueue ? "set" : "nil");
    }
    printf("ANSWER\tAVCaptureSession.deferredStartDelegate after every refused set\thost=[%s]\tport=[%s]\n",
           hostAnswer, portAnswer);
}

static void prefcam_phase(Class hostDevice, Class portDevice, const char *mode)
{
    /* The host's own answer, with the authorization printed beside it - the measurement the coordinator asked
       for after a run read the host's nil as Apple's answer for the row. */
    long auth = (long)[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    const char *authName = auth == 0 ? "notDetermined" : auth == 1 ? "restricted" : auth == 2 ? "denied" : "authorized";
    char hostSystem[512];
    class_answer_of(hostDevice, @selector(systemPreferredCamera), hostSystem, sizeof hostSystem);
    char hostUser[512];
    class_answer_of(hostDevice, @selector(userPreferredCamera), hostUser, sizeof hostUser);
    printf("PREFCAM\thost\tauth=%ld (%s)\tuser=[%s]\tsystem=[%s]\tdefault=[%s]\n", auth, authName, hostUser,
           hostSystem,
           [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] ? "a camera" : "nil");

/* Nothing was ever chosen: the measured host answer for a property that has not been set is nil, with a
       camera present. */
    prefcam_step(portDevice, "before-any-set");

    if (mode) {
        /* One launch of the persistence pair: nothing else, and no step that would clear the history. */
        persist_phase(portDevice, mode);
        return;
    }

    /* The choice, then the getter, and a second choice, so the history holds two entries. */
    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), prefcam_front);
    prefcam_step(portDevice, "after-front-is-chosen");
    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), prefcam_back);
    prefcam_step(portDevice, "after-back-is-chosen");

    /* "Setting the property to nil has no effect" (:663): a nil adds nothing, so the choice survives it. */
    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), nil);
    prefcam_step(portDevice, "after-nil-is-set");

    /* the header says that a user's most recent preferred camera, once disconnected, is still reported, and that the
       next best one is reported in its place (:662): the back is the most recent and it goes, so the front - the entry before it - answers. */
    set_present(portDevice, @[prefcam_front]);
    prefcam_step(portDevice, "most-recent-gone-next-best-answers");

    /* No camera at all: nil is the header's own answer for both properties (:663, :674). */
    set_present(portDevice, @[]);
    prefcam_step(portDevice, "no-camera-at-all");

    /* Only the front was ever chosen and it is gone: the history is exhausted, and the release's own best
       camera is the next best choice one step further - the back, which is what +defaultDeviceWithMediaType:
       answers over the list this run handed the stand-in. */
    set_present(portDevice, @[prefcam_back, prefcam_front]);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CharonCaptureUserPreferredCameraHistory"];
    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), prefcam_front);
    set_present(portDevice, @[prefcam_back]);
    prefcam_step(portDevice, "history-exhausted");

    /* And a launch that chooses nothing: the measured host answer for a property that has not been set is nil,
       while the system's answer is the release's own best camera. */
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CharonCaptureUserPreferredCameraHistory"];
    set_present(portDevice, @[prefcam_back, prefcam_front]);
    prefcam_step(portDevice, "nothing-ever-chosen");
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
        Class hostDevice = NSClassFromString(@"AVCaptureDevice");
        Class hostFormat = NSClassFromString(@"AVCaptureDeviceFormat");
        Class portDevice = objc_getClass(PORT_PREFIX "AVCaptureDevice");
        Class portFormat = objc_getClass(PORT_PREFIX "AVCaptureDeviceFormat");
        Class portInputClass = objc_getClass(PORT_PREFIX "AVCaptureDeviceInput");
        Class portSessionClass = objc_getClass(PORT_PREFIX "AVCaptureSession");
        Class portOutputClass = objc_getClass(PORT_PREFIX "AVCaptureOutput");
        Class portLayerClass = objc_getClass(PORT_PREFIX "AVCaptureVideoPreviewLayer");
        AVCaptureDevice *camera = hostDevice ? [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] : nil;
        AVCaptureDeviceFormat *format = camera ? [camera activeFormat] : nil;
        // The load command packs the version as (major << 16) | (minor << 8) | patch, so 16.4 is 0x00100400:
        // printing the low half whole would say "16.1024", which is neither of the two numbers a reader wants.
        printf("CONTROL\tlinked-sdk\t%u.%u\n", (unsigned)(charon_program_sdk_on_platform(0) >> 16),
               (unsigned)((charon_program_sdk_on_platform(0) >> 8) & 0xff));
        printf("CONTROL\tAVCaptureNoSuchClass\t%s\n",
               NSClassFromString(@"AVCaptureNoSuchClass") ? "HAS" : "ABSENT");
        printf("CONTROL\tAVCaptureDevice\t%s\tcamera=%s\n", hostDevice ? "HAS" : "ABSENT",
               camera ? "one" : "NONE");
        printf("CONTROL\tAVCaptureDeviceFormat\t%s\tactive format=%s\n", hostFormat ? "HAS" : "ABSENT",
               format ? "one" : "NONE");
        printf("CONTROL\tcharon_host_AVCaptureDevice\t%s\n", portDevice ? "HAS" : "ABSENT");
        printf("CONTROL\tcharon_host_AVCaptureDeviceFormat\t%s\n", portFormat ? "HAS" : "ABSENT");
        printf("CONTROL\tcharon_host_AVCaptureDeviceInput\t%s\n", portInputClass ? "HAS" : "ABSENT");
        printf("CONTROL\tcharon_host_AVCaptureSession\t%s\n", portSessionClass ? "HAS" : "ABSENT");
        printf("CONTROL\tcharon_host_AVCaptureOutput\t%s\n", portOutputClass ? "HAS" : "ABSENT");
        printf("CONTROL\tcharon_host_AVCaptureVideoPreviewLayer\t%s\n", portLayerClass ? "HAS" : "ABSENT");
        /* The microphone and its input, for the 18.0 slice's three AVCaptureDeviceInput rows. Both columns
         * need one: without the host's own input every one of those rows would be read off the port alone,
         * which is the comparison this run does not make. */
        AVCaptureDevice *microphone = hostDevice ? [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]
                                                 : nil;
        NSError *inputError = nil;
        AVCaptureDeviceInput *hostInput =
            microphone ? [AVCaptureDeviceInput deviceInputWithDevice:microphone error:&inputError] : nil;
        printf("CONTROL\tAVCaptureDeviceInput\t%s\tmicrophone=%s input=%s\n",
               NSClassFromString(@"AVCaptureDeviceInput") ? "HAS" : "ABSENT",
               microphone ? "one" : "NONE",
               hostInput ? "one" : (inputError ? inputError.description.UTF8String : "NONE"));
        if (hostDevice == nil || camera == nil || format == nil || portDevice == nil || portFormat == nil ||
            portInputClass == nil || hostInput == nil || portSessionClass == nil || portOutputClass == nil ||
            portLayerClass == nil) {
            fprintf(stderr, "FAIL: a side of this run is missing, so every row below would be read off "
                            "nothing\n");
            return 1;
        }
        printf("CAMERA\t%s\t%lu format(s)\n", [camera.localizedName UTF8String],
               (unsigned long)camera.formats.count);
        /* The port's own objects: a stand-in class each, so the port's answers are asked of the port's code
           and not of Apple's, which is what the rename is for. */
        id portCamera = [portDevice new];
        id portFormatObject = [portFormat new];
        /* -setAutoVideoFrameRateEnabled: asks the release's own -activeFormat and then this port's format
         * category, so the stand-in device is given the same format object the format rows are asked of. */
        ((void (*)(id, SEL, id))objc_msgSend)(portCamera, @selector(setActiveFormat:), portFormatObject);
        /* The preferred-camera pair reads a device list, so the stand-in is given one before anything is asked:
           two cameras, on each side. And the history is cleared here rather than in the phase that writes it,
           because the member loop below asks +userPreferredCamera too and must not see a previous run's choice. */
        id portInput = [portInputClass new];
        /* The deferred-start family's three owners, on both sides, and BOTH sets are made HERE because the
         * member table below asks their rows and has to ask them of these objects and not of the camera. */
        AVCaptureSession *hostSession = [[AVCaptureSession alloc] init];
        AVCaptureVideoDataOutput *hostOutput = [[AVCaptureVideoDataOutput alloc] init];
        AVCaptureVideoPreviewLayer *hostLayer = [AVCaptureVideoPreviewLayer layerWithSession:hostSession];
        id portSession = [portSessionClass new];
        id portOutput = [portOutputClass new];
        id portLayer = [portLayerClass new];
        /* and the device the 26.0 Cinematic Video support flag reads the active format of, which is the
         * release's own member of the release's own input */
        ((void (*)(Class, SEL, id))objc_msgSend)(portInputClass, @selector(charon_host_setDevice:), portCamera);
        /* The stand-in's substrate for the 26.0 rectangles of interest, set before anything is asked of it: the
         * member table reads the support row through it, and the rect phase sets the flag again for its own
         * steps. The static's initial value is not what a run may rely on. */
        ((void (*)(Class, SEL, BOOL))objc_msgSend)(portDevice,
                                                   @selector(charon_host_setPointsOfInterestSupported:), YES);
        prefcam_setup(portDevice);
        /* Not in a launch of the persistence pair: clearing the key there would erase what the launch before
           this one left, which is the only thing that launch is there to leave. */
        if (argc <= 2)
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CharonCaptureUserPreferredCameraHistory"];

        FILE *list = fopen(argv[1], "r");
        if (list == NULL) {
            fprintf(stderr, "FAIL: the list did not open, so nothing was examined\n");
            return 1;
        }
        char line[512];
        unsigned members = 0, answers = 0;
        while (fgets(line, sizeof line, list) != NULL) {
            char *save = NULL;
            char *api = strtok_r(line, "\t\n", &save);
            char *owner = strtok_r(NULL, "\t\n", &save);
            char *selector = strtok_r(NULL, "\t\n", &save);
            char *kind = strtok_r(NULL, "\t\n", &save);
            if (api == NULL || owner == NULL || selector == NULL) {
                continue;
            }
            /* Whether this is a class member comes from the list's own KIND column and not from the sign in
               the selector: a class PROPERTY is written with no sign at all, and a probe that reads the sign
               asks every class property of its class's instance side and finds nothing on either. */
            int classMember = kind != NULL && !strcmp(kind, "class");
            const char *name = (selector[0] == '+' || selector[0] == '-') ? selector + 1 : selector;
            SEL asked = sel_registerName(name);
            Class hostOwner = NSClassFromString([NSString stringWithUTF8String:owner]);
            char prefixed[512];
            snprintf(prefixed, sizeof prefixed, "%s%s", PORT_PREFIX, owner);
            Class portOwner = objc_getClass(prefixed);
            Method hostMethod = classMember ? class_getClassMethod(hostOwner, asked)
                                            : class_getInstanceMethod(hostOwner, asked);
            Method portMethod = classMember ? class_getClassMethod(portOwner, asked)
                                            : class_getInstanceMethod(portOwner, asked);
            printf("RESPONDS\t%c[%s %s]\thost=%s\tport=%s\n", classMember ? '+' : '-', owner, name,
                   hostMethod ? "yes" : "no", portMethod ? "yes" : "no");
            members++;

            /* A row the HOST'S OWN FRAMEWORK does not carry at all. Measured for one row of the 26.0 Cinematic
             * Video family: this macOS's AVCaptureDevice has no -cinematicVideoCaptureSceneMonitoringStatuses,
             * so there is no host column to compare and reading one would be reading nothing. Such a row is
             * named by a NOHOST line, its host cell is empty, and run.sh requires expectations.tsv to say so -
             * a host that later gains the selector then fails the run with a message that asks for a
             * re-measurement, which is what should happen. The port's own answer is asked either way. */
            if (!hostMethod && !classMember) {
                printf("NOHOST\t%s\n", api);
                char portAnswer[512];
                answer_of(onInputOwner(owner) ? (id)portInput
                                              : !strcmp(owner, "AVCaptureDeviceFormat") ? (id)portFormatObject
                                              : !strcmp(owner, "AVCaptureSession") ? (id)portSession
                                              : !strcmp(owner, "AVCaptureOutput") ? (id)portOutput
                                              : !strcmp(owner, "AVCaptureVideoPreviewLayer") ? (id)portLayer
                                                                                     : (id)portCamera,
                          asked, portAnswer, sizeof portAnswer);
                printf("ANSWER\t%s\thost=[]\tport=[%s]\n", api, portAnswer);
                continue;
            }

            char hostAnswer[512], portAnswer[512];
            if (!strcmp(kind, "class")) {
                class_answer_of(hostOwner, asked, hostAnswer, sizeof hostAnswer);
                class_answer_of(portOwner, asked, portAnswer, sizeof portAnswer);
            } else {
                /* The FORMAT rows are asked of the active format and the port's own stand-in format, the
                   INPUT rows of the host's own microphone input and the port's stand-in input, and the rest
                   of the device rows of the camera and the port's stand-in device. */
                int onFormat = !strcmp(owner, "AVCaptureDeviceFormat");
                int onInput = !strcmp(owner, "AVCaptureDeviceInput");
                int onSession = !strcmp(owner, "AVCaptureSession");
                int onOutput = !strcmp(owner, "AVCaptureOutput");
                int onLayer = !strcmp(owner, "AVCaptureVideoPreviewLayer");
                answer_of(onFormat ? (id)format : onInput ? (id)hostInput : onSession ? (id)hostSession
                          : onOutput ? (id)hostOutput : onLayer ? (id)hostLayer : (id)camera,
                          asked, hostAnswer, sizeof hostAnswer);
                answer_of(onFormat ? (id)portFormatObject : onInput ? (id)portInput : onSession ? (id)portSession
                          : onOutput ? (id)portOutput : onLayer ? (id)portLayer : (id)portCamera,
                          asked, portAnswer, sizeof portAnswer);
            }
            printf("ANSWER\t%s\thost=[%s]\tport=[%s]\n", api, hostAnswer, portAnswer);
            answers++;
        }
        fclose(list);

        /* The 18.0 slice's own phases: which modes this input supports, and what each of the three setters
         * does. Both are asked of both sides and compared by run.sh through expectations.tsv. */
        support_phase(hostInput, portInput);
        setter_phase(camera, portCamera, hostInput, portInput);

        /* The 26.0 rectangles of interest, over the stand-in that carries the release's substrate. */
        rect_phase(camera, portCamera, portDevice);

        /* The 26.0 Cinematic Video family's own writes. */
        cinematic_phase(camera, portCamera, hostInput, portInput);

        /* The 26.0 external-sync family's two methods, and the locked-duration setter. */
        sync_phase(hostInput, portInput);

        /* The 26.0 dynamic family's three setters. */
        dynamic_phase(camera, portCamera, hostInput, portInput);

        /* The 26.0 deferred-start family's two methods and three setters, over stand-ins for the session, the
         * output and the preview layer. */
        deferred_phase(hostSession, portSession, hostOutput, portOutput, hostLayer, portLayer);

        /* The members whose answer is a refusal rather than a value, asked of both sides. */
        raise_of(camera, portCamera, @selector(performEffectForReaction:), @"ReactionHeart",
                 "AVCaptureDevice.performEffectForReaction:");

        /* The class properties, which the four Info.plists phase reads. Printed here too, so a run with no
           plist phase at all still shows them. */
        print_class_answer(hostDevice, portDevice, "AVCaptureDevice.reactionEffectsEnabled",
                           @selector(reactionEffectsEnabled));
        print_class_answer(hostDevice, portDevice, "AVCaptureDevice.reactionEffectGesturesEnabled",
                           @selector(reactionEffectGesturesEnabled));
        print_class_answer(hostDevice, portDevice, "AVCaptureDevice.systemPreferredCamera",
                           @selector(systemPreferredCamera));
        print_class_answer(hostDevice, portDevice, "AVCaptureDevice.userPreferredCamera",
                           @selector(userPreferredCamera));
        prefcam_phase(hostDevice, portDevice, argc > 2 ? argv[2] : NULL);

        printf("members probed: %u  answers emitted: %u\n", members, answers);
    }
    return 0;
}
