#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVFDescriptorConstruction.h"

#include <stdio.h>

static int plants;
static int plantRow;
static int rowIndex;

#define NO_ORACLE @"no-oracle-forwarding-object"
#define NOT_ON_THIS_HOST @"scenario-not-applicable-on-this-host"

static void row(const char *key, NSString *v)
{
    rowIndex++;
    if (plants == 1) {
        v = [NSString stringWithFormat:@"WRONG-ALL-%d", rowIndex];
    } else if (plants == 2 && rowIndex == plantRow) {
        v = @"WRONG-ONE";
    }
    setvbuf(stdout, NULL, _IOLBF, 0);
    NSString *text = @"(nil)";
    @try {
        text = v ? [v description] : @"(nil)";
    } @catch (NSException *e) {
        text = NO_ORACLE;
    }
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "];
    printf("%-76s = %s\n", key, [text UTF8String] ?: "(unprintable)");
    fflush(stdout);
}

static Class lookup(const char *name)
{
    NSString *asked = [NSString stringWithUTF8String:name];
#ifdef REVENANT_PORT_BUILD
    asked = [@"revenant_host_" stringByAppendingString:asked];
#endif
    return NSClassFromString(asked);
}

static id instance(const char *name)
{
    Class c = lookup(name);
    if (!c) {
        return nil;
    }
    @try {
        return [[c alloc] init];
    } @catch (NSException *e) {
        return nil;
    }
}

static BOOL classMethodAnswers(Class c, SEL sel)
{
    if (!c) {
        return NO;
    }
    return [c respondsToSelector:sel];
}

static BOOL answersSelector(id made, SEL sel)
{
    if (!made) {
        return NO;
    }
    @try {
        return [made respondsToSelector:sel];
    } @catch (NSException *e) {
        return NO;
    }
}

static NSString *answersValue(id made, SEL sel, BOOL classDeclares)
{
    if (answersSelector(made, sel)) {
        return @"yes";
    }
    if (classDeclares) {
        return NO_ORACLE;
    }
    return @"no";
}

static void structure(const char *name, const char *const *members, unsigned count)
{
    Class c = lookup(name);
    NSString *label = [NSString stringWithUTF8String:name];
    row([[label stringByAppendingString:@" PRESENT"] UTF8String], c ? @"yes" : @"NO");
    NSString *superName = c ? [NSString stringWithUTF8String:class_getName(class_getSuperclass(c))] : @"(no class)";
    row([[label stringByAppendingString:@" SUPERCLASS"] UTF8String],
        [superName stringByReplacingOccurrencesOfString:@"revenant_host_" withString:@""]);
    id made = instance(name);
    row([[label stringByAppendingString:@" ALLOC-INIT"] UTF8String], made ? @"yes" : @"no");
    for (unsigned i = 0; i < count; i++) {
        SEL sel = sel_registerName(members[i]);
        row([[NSString stringWithFormat:@"%@ RESPONDS %s", label, members[i]] UTF8String],
            answersValue(made, sel, c ? class_respondsToSelector(c, sel) : NO));
    }
}


static void band13Media(void)
{
    static const char *const movieTrackMembers[] = {
        "asset", "naturalSize", "preferredTransform", "hasMediaCharacteristic:",
    };
    static const char *const compositionTrackMembers[] = {
        "formatDescriptionReplacements", "segmentForTrackTime:",
    };
    static const char *const mutableCompositionTrackMembers[] = {
        "enabled", "formatDescriptionReplacements", "naturalSize", "preferredTransform",
    };
    static const char *const movieMembers[] = {
        "naturalSize", "preferredTransform", "canContainMovieFragments",
    };
    static const char *const mutableMovieMembers[] = {
        "naturalSize", "preferredTransform", "canContainMovieFragments",
    };
    static const char *const fragmentedMembers[] = {
        "naturalSize", "preferredTransform", "movieFragmentIndex",
    };
    static const char *const replacementMembers[] = {
        "currentFormatDescription", "replacingFormatDescriptions",
    };
    static const char *const noMemberClasses[] = {
        "AVMediaDataStorage", "AVFragmentedMovieMinder", "AVMovie", "AVMutableMovie",
    };

    structure("AVMovieTrack", movieTrackMembers, 4);
    structure("AVMutableMovieTrack", movieTrackMembers, 4);
    structure("AVCompositionTrack", compositionTrackMembers, 2);
    structure("AVMutableCompositionTrack", mutableCompositionTrackMembers, 4);
    structure("AVFragmentedMovie", fragmentedMembers, 3);
    structure("AVFragmentedMovieTrack", fragmentedMembers, 3);
    structure("AVCompositionTrackFormatDescriptionReplacement", replacementMembers, 2);
    structure("AVMediaDataStorage", noMemberClasses, 0);
    structure("AVFragmentedMovieMinder", noMemberClasses, 0);
    structure("AVMovie", movieMembers, 3);
    structure("AVMutableMovie", mutableMovieMembers, 3);

    {
        Class c = lookup("AVMutableCompositionTrack");
        id made = instance("AVMutableCompositionTrack");
        SEL replace = sel_registerName("replaceFormatDescription:withFormatDescription:");
        row("AVMutableCompositionTrack METHOD replaceFormatDescription:withFormatDescription:",
            answersSelector(made, replace) ? @"responds" : @"does not respond");
    }
}

int main(void)
{
    @autoreleasepool {
        const char *plant = getenv("AVFDESCPROBE");
        plants = plant && strcmp(plant, "plant-one") == 0 ? 2
              : (plant && strcmp(plant, "plant-all") == 0 ? 1 : 0);
        const char *which = getenv("AVFDESCPROW");
        plantRow = which ? atoi(which) : 1;

        {
            static const char *members[] = {"preferredLanguages", "preferredMediaCharacteristics",
                                            "principalMediaCharacteristics",
                                            "initWithPrincipalMediaCharacteristics:preferredLanguages:preferredMediaCharacteristics:"};
            structure("AVPlayerMediaSelectionCriteria", members, 4);
            id criteria = instance("AVPlayerMediaSelectionCriteria");
            SEL principal = NSSelectorFromString(@"initWithPrincipalMediaCharacteristics:preferredLanguages:preferredMediaCharacteristics:");
            row("12.0-INITIALIZER responds (instance)",
                answersSelector(criteria, principal) ? @"yes" : @"no");
            if (answersSelector(criteria, principal)) {
                id made = ((id (*)(id, SEL, id, id, id))objc_msgSend)(criteria, principal,
                                                                          (@[@"public.video"]),
                                                                          (@[@"en"]),
                                                                          (@[@"public.audio"]));
                SEL out = NSSelectorFromString(@"principalMediaCharacteristics");
                id value = answersSelector(made, out)
                    ? ((id (*)(id, SEL))objc_msgSend)(made, out) : nil;
                row("~VALUES 12.0 initializer answers principalMediaCharacteristics", value);
                SEL languages = NSSelectorFromString(@"preferredLanguages");
                row("~VALUES 12.0 initializer kept the preferred languages",
                    answersSelector(made, languages) ? ((id (*)(id, SEL))objc_msgSend)(made, languages) : nil);
            } else {
                row("~VALUES 12.0 initializer answers principalMediaCharacteristics", @"(not answered)");
                row("~VALUES 12.0 initializer CALL on this build", NO_ORACLE);
            }
            Class criteriaClass = lookup("AVPlayerMediaSelectionCriteria");
            SEL factory = NSSelectorFromString(@"preferredMediaSelectionCriteriaWithPreferredLanguages:preferredMediaCharacteristics:");
            Class hostCriteria = NSClassFromString(@"AVPlayerMediaSelectionCriteria");
            BOOL hostCanBuild = hostCriteria && classMethodAnswers(hostCriteria, factory);
            if (criteriaClass && classMethodAnswers(criteriaClass, factory)) {
                id made = ((id (*)(id, SEL, id, id))objc_msgSend)(criteriaClass, factory,
                                                                    (@[@"en"]), (@[@"public.audio"]));
                for (unsigned i = 0; i < 2; i++) {
                    SEL out = sel_registerName(i == 0 ? "preferredLanguages" : "preferredMediaCharacteristics");
                    row([[NSString stringWithFormat:@"~VALUES criteria %s after the factory",
                          sel_getName(out)] UTF8String],
                        answersSelector(made, out)
                            ? ((id (*)(id, SEL))objc_msgSend)(made, out) : nil);
                }
            } else if (!hostCanBuild) {
                row("~VALUES criteria preferredLanguages after the factory", NOT_ON_THIS_HOST);
                row("~VALUES criteria preferredMediaCharacteristics after the factory", NOT_ON_THIS_HOST);
            } else {
                row("~VALUES criteria preferredLanguages after the factory", @"(the port has no such factory)");
                row("~VALUES criteria preferredMediaCharacteristics after the factory", @"(the port has no such factory)");
            }
        }

        {
            static const char *members[] = {"exposureTargetBias",
                                            "autoExposureSettingsWithExposureTargetBias:"};
            structure("AVCaptureBracketedStillImageSettings", members, 0);
            structure("AVCaptureAutoExposureBracketedStillImageSettings", members, 2);
            static const char *manual[] = {"ISO", "exposureDuration",
                                           "manualExposureSettingsWithExposureDuration:ISO:"};
            structure("AVCaptureManualExposureBracketedStillImageSettings", manual, 3);

            Class autoClass = lookup("AVCaptureAutoExposureBracketedStillImageSettings");
            SEL autoFactory = NSSelectorFromString(@"autoExposureSettingsWithExposureTargetBias:");
            if (autoClass && classMethodAnswers(autoClass, autoFactory)) {
                id made = ((id (*)(id, SEL, float))objc_msgSend)(autoClass, autoFactory, 1.5f);
                SEL bias = NSSelectorFromString(@"exposureTargetBias");
                row("~VALUES auto-exposure bias after the factory",
                    answersSelector(made, bias)
                        ? [NSString stringWithFormat:@"%g", (double)((float (*)(id, SEL))objc_msgSend)(made, bias)]
                        : NO_ORACLE);
            } else {
                row("~VALUES auto-exposure bias after the factory", NO_ORACLE);
            }
            Class manualClass = lookup("AVCaptureManualExposureBracketedStillImageSettings");
            SEL manualFactory = NSSelectorFromString(@"manualExposureSettingsWithExposureDuration:ISO:");
            if (manualClass && classMethodAnswers(manualClass, manualFactory)) {
                id made = ((id (*)(id, SEL, CMTime, float))objc_msgSend)(manualClass, manualFactory,
                                                                          kCMTimeZero, 400.0f);
                SEL iso = NSSelectorFromString(@"ISO");
                row("~VALUES manual-exposure ISO after the factory",
                    answersSelector(made, iso)
                        ? [NSString stringWithFormat:@"%g", (double)((float (*)(id, SEL))objc_msgSend)(made, iso)]
                        : NO_ORACLE);
                SEL duration = NSSelectorFromString(@"exposureDuration");
                if (answersSelector(made, duration)) {
                    CMTime t = ((CMTime (*)(id, SEL))objc_msgSend)(made, duration);
                    row("~VALUES manual-exposure duration after the factory",
                        [NSString stringWithFormat:@"%lld/%lld", (long long)t.value, (long long)t.timescale]);
                } else {
                    row("~VALUES manual-exposure duration after the factory", NO_ORACLE);
                }
            } else {
                row("~VALUES manual-exposure ISO after the factory", NO_ORACLE);
                row("~VALUES manual-exposure duration after the factory", NO_ORACLE);
            }
        }

        {
            static const char *members[] = {"contentInformationRequest", "finishLoading",
                                            "loadingRequest", "asset"};
            structure("AVAssetResourceRenewalRequest", members, 4);
        }

        {
            static const char *members[] = {"asset", "mediaSelectionGroups", "selectedMediaOptions",
                                            "selectedMediaOptionInMediaSelectionGroup:"};
            structure("AVMediaSelection", members, 4);
            static const char *mutableMembers[] = {"selectMediaOption:inMediaSelectionGroup:"};
            structure("AVMutableMediaSelection", mutableMembers, 1);
            id made = [[lookup("AVMediaSelection") alloc] init];
            for (unsigned i = 0; i < 2; i++) {
                SEL out = sel_registerName(i == 0 ? "selectedMediaOptions" : "mediaSelectionGroups");
                row([[NSString stringWithFormat:@"~VALUES selection %s after -init",
                      sel_getName(out)] UTF8String],
                    answersSelector(made, out)
                        ? [NSString stringWithFormat:@"%lu",
                           (unsigned long)[((id (*)(id, SEL))objc_msgSend)(made, out) count]]
                        : NO_ORACLE);
            }
        }
        band13Media();
        printf("rows: %d plants: %d\n", rowIndex, plants);
    }
    return 0;
}
