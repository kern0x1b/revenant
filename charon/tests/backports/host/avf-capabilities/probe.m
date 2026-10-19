#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../CharonProgramSDK.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PORT_PREFIX "charon_host_"

static void answer_of(id object, SEL selector, char *out, size_t room)
{
    @autoreleasepool {
        @try {
            if (selector == @selector(availableReactionTypes)) {
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
                id set = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                NSArray *sorted = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];
                snprintf(out, room, "%lu reason(s): %s", (unsigned long)[sorted count],
                         [sorted componentsJoinedByString:@","].UTF8String);
            } else if (selector == @selector(isCameraLensSmudgeDetectionSupported)) {
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
                snprintf(out, room, "%g", ((double (*)(id, SEL))objc_msgSend)(object, selector));
            } else if (selector == @selector(multichannelAudioMode)) {
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

static id prefcam_back, prefcam_front;

static void prefcam_setup(Class portDevice)
{
    prefcam_back = make_device(portDevice, @"back-camera", @"Back Camera", 1);
    prefcam_front = make_device(portDevice, @"front-camera", @"Front Camera", 2);
    set_present(portDevice, @[prefcam_back, prefcam_front]);
}

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
    snprintf(stored, sizeof stored, "%s", stored_history().UTF8String);
    printf("PREFCAM\t%s\tuser=[%s]\tsystem=[%s]\tdefaults=[%s]\n", label, user, system, stored);
}

static void persist_phase(Class portDevice, const char *mode)
{
    if (!strcmp(mode, "set")) {
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

static int onInputOwner(const char *owner)
{
    return !strcmp(owner, "AVCaptureDeviceInput");
}

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
    ((void (*)(Class, SEL, BOOL))objc_msgSend)(portStandinClass,
                                               @selector(charon_host_setPointsOfInterestSupported:), YES);
    rect_case(hostCamera, portCamera, @selector(focusRectOfInterest), "AVCaptureDevice.focusRectOfInterest unset");
    rect_case(hostCamera, portCamera, @selector(exposureRectOfInterest),
              "AVCaptureDevice.exposureRectOfInterest unset");
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
    rect_write(hostCamera, portCamera, @selector(setFocusRectOfInterest:), @selector(focusRectOfInterest),
               @selector(focusPointOfInterest), CGRectMake(0, 0, 0.25, 0.25),
               "AVCaptureDevice.setFocusRectOfInterest: a quarter by a quarter, unlocked");
    ((void (*)(id, SEL))objc_msgSend)(portCamera, @selector(lockForConfiguration));
    ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(hostCamera, @selector(lockForConfiguration:), NULL);
    rect_write(hostCamera, portCamera, @selector(setFocusRectOfInterest:), @selector(focusRectOfInterest),
               @selector(focusPointOfInterest), CGRectMake(0, 0, 0.25, 0.25),
               "AVCaptureDevice.setFocusRectOfInterest: a quarter by a quarter, locked");
    rect_write(hostCamera, portCamera, @selector(setExposureRectOfInterest:), @selector(exposureRectOfInterest),
               @selector(exposurePointOfInterest), CGRectMake(0.25, 0.25, 0.5, 0.5),
               "AVCaptureDevice.setExposureRectOfInterest: half by half, locked");
}

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

@interface AvfProbeDelegate : NSObject <AVCaptureSessionDeferredStartDelegate>
@end
@implementation AvfProbeDelegate
- (void)sessionWillRunDeferredStart:(AVCaptureSession *)session { }
- (void)sessionDidRunDeferredStart:(AVCaptureSession *)session { }
@end

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
    long auth = (long)[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    const char *authName = auth == 0 ? "notDetermined" : auth == 1 ? "restricted" : auth == 2 ? "denied" : "authorized";
    char hostSystem[512];
    class_answer_of(hostDevice, @selector(systemPreferredCamera), hostSystem, sizeof hostSystem);
    char hostUser[512];
    class_answer_of(hostDevice, @selector(userPreferredCamera), hostUser, sizeof hostUser);
    printf("PREFCAM\thost\tauth=%ld (%s)\tuser=[%s]\tsystem=[%s]\tdefault=[%s]\n", auth, authName, hostUser,
           hostSystem,
           [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] ? "a camera" : "nil");

    prefcam_step(portDevice, "before-any-set");

    if (mode) {
        persist_phase(portDevice, mode);
        return;
    }

    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), prefcam_front);
    prefcam_step(portDevice, "after-front-is-chosen");
    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), prefcam_back);
    prefcam_step(portDevice, "after-back-is-chosen");

    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), nil);
    prefcam_step(portDevice, "after-nil-is-set");

    set_present(portDevice, @[prefcam_front]);
    prefcam_step(portDevice, "most-recent-gone-next-best-answers");

    set_present(portDevice, @[]);
    prefcam_step(portDevice, "no-camera-at-all");

    set_present(portDevice, @[prefcam_back, prefcam_front]);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CharonCaptureUserPreferredCameraHistory"];
    ((void (*)(Class, SEL, id))objc_msgSend)(portDevice, @selector(setUserPreferredCamera:), prefcam_front);
    set_present(portDevice, @[prefcam_back]);
    prefcam_step(portDevice, "history-exhausted");

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
        id portCamera = [portDevice new];
        id portFormatObject = [portFormat new];
        ((void (*)(id, SEL, id))objc_msgSend)(portCamera, @selector(setActiveFormat:), portFormatObject);
        id portInput = [portInputClass new];
        AVCaptureSession *hostSession = [[AVCaptureSession alloc] init];
        AVCaptureVideoDataOutput *hostOutput = [[AVCaptureVideoDataOutput alloc] init];
        AVCaptureVideoPreviewLayer *hostLayer = [AVCaptureVideoPreviewLayer layerWithSession:hostSession];
        id portSession = [portSessionClass new];
        id portOutput = [portOutputClass new];
        id portLayer = [portLayerClass new];
        ((void (*)(Class, SEL, id))objc_msgSend)(portInputClass, @selector(charon_host_setDevice:), portCamera);
        ((void (*)(Class, SEL, BOOL))objc_msgSend)(portDevice,
                                                   @selector(charon_host_setPointsOfInterestSupported:), YES);
        prefcam_setup(portDevice);
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

        support_phase(hostInput, portInput);
        setter_phase(camera, portCamera, hostInput, portInput);

        rect_phase(camera, portCamera, portDevice);

        cinematic_phase(camera, portCamera, hostInput, portInput);

        sync_phase(hostInput, portInput);

        dynamic_phase(camera, portCamera, hostInput, portInput);

        deferred_phase(hostSession, portSession, hostOutput, portOutput, hostLayer, portLayer);

        raise_of(camera, portCamera, @selector(performEffectForReaction:), @"ReactionHeart",
                 "AVCaptureDevice.performEffectForReaction:");

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
