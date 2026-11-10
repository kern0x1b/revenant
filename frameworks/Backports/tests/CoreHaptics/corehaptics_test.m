#import <Foundation/Foundation.h>
#include "check.h"
#import "RevenantCoreHaptics.h"
#import "corehaptics_oracle.h"
#include <math.h>

static CHHapticPattern *revenant_pattern(const RevenantOracleEvent *events, int count, NSError **error)
{
    NSMutableArray<CHHapticEvent *> *listing = [NSMutableArray array];
    for (int index = 0; index < count; index++) {
        CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity
                                                                                          value:events[index].intensity];
        NSArray<CHHapticEventParameter *> *parameters = intensity ? @[intensity] : @[];
        if (events[index].transient) {
            [listing addObject:[[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
                                                              parameters:parameters
                                                            relativeTime:events[index].relative]];
        } else {
            [listing addObject:[[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                              parameters:parameters
                                                            relativeTime:events[index].relative
                                                                duration:events[index].duration]];
        }
    }
    return [[CHHapticPattern alloc] initWithEvents:listing parameters:@[] error:error];
}

static void revenant_expect_equal(const char *name, NSString *value, NSString *expected)
{
    revenant_check(([value isEqualToString:expected] != revenant_negative), name,
                   [NSString stringWithFormat:@"%@ is not %@", value, expected]);
}

extern NSString * __revenant_fb_CHHapticEventTypeHapticTransient;
extern NSString * __revenant_fb_CHHapticEventTypeHapticContinuous;
extern NSString * __revenant_fb_CHHapticEventParameterIDHapticIntensity;
extern NSString * __revenant_fb_CHHapticEventParameterIDHapticSharpness;
extern NSString * __revenant_fb_CHHapticDynamicParameterIDHapticIntensityControl;
extern NSString * __revenant_fb_CHHapticDynamicParameterIDHapticSharpnessControl;

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        revenant_expect_equal("the transient event type the backport defines is the one Core Haptics uses", __revenant_fb_CHHapticEventTypeHapticTransient,
                               revenant_apple_event_type_transient());
        revenant_expect_equal("the continuous event type the backport defines is the one Core Haptics uses", __revenant_fb_CHHapticEventTypeHapticContinuous,
                               revenant_apple_event_type_continuous());
        revenant_expect_equal("the intensity parameter the backport defines is the one Core Haptics uses", __revenant_fb_CHHapticEventParameterIDHapticIntensity,
                               revenant_apple_parameter_intensity());
        revenant_expect_equal("the sharpness parameter the backport defines is the one Core Haptics uses", __revenant_fb_CHHapticEventParameterIDHapticSharpness,
                               revenant_apple_parameter_sharpness());
        revenant_expect_equal("the intensity control the backport defines is the one Core Haptics uses", __revenant_fb_CHHapticDynamicParameterIDHapticIntensityControl,
                               revenant_apple_dynamic_intensity());
        revenant_expect_equal("the sharpness control the backport defines is the one Core Haptics uses", __revenant_fb_CHHapticDynamicParameterIDHapticSharpnessControl,
                               revenant_apple_dynamic_sharpness());

        CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:0.7f];
        revenant_check((fabs(intensity.value - 0.7f) < 0.00001f) != revenant_negative, "the event parameter keeps its value",
                       [NSString stringWithFormat:@"%f", intensity.value]);
        CHHapticEventParameter *sharpness = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.3f];
        sharpness.value = 0.4f;
        revenant_check((fabs(sharpness.value - 0.4f) < 0.00001f) != revenant_negative, "the event parameter keeps the value it is given",
                       [NSString stringWithFormat:@"%f", sharpness.value]);

        CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                              parameters:@[intensity, sharpness]
                                                            relativeTime:0.25
                                                                duration:2.0];
        revenant_expect_equal("the event keeps its type", event.type, revenant_apple_event_type_continuous());
        revenant_check((event.eventParameters.count == 2) != revenant_negative, "the event keeps its parameters",
                       [NSString stringWithFormat:@"%lu", (unsigned long)event.eventParameters.count]);
        revenant_check((fabs(event.relativeTime - 0.25) < 0.00001 && fabs(event.duration - 2.0) < 0.00001) != revenant_negative,
                       "the event keeps its timing", [NSString stringWithFormat:@"%.5f %.5f", event.relativeTime, event.duration]);
        event.relativeTime = 0.5;
        event.duration = 1.5;
        revenant_check((fabs(event.relativeTime - 0.5) < 0.00001 && fabs(event.duration - 1.5) < 0.00001) != revenant_negative,
                       "the event keeps the timing it is given", [NSString stringWithFormat:@"%.5f %.5f", event.relativeTime, event.duration]);

        const RevenantOracleEvent cases[] = {
            {0.0, 2.0, 1.0f, 0},
            {0.25, 2.0, 0.7f, 0},
            {1.5, 0.0, 1.0f, 1},
            {-1.0, 2.0, 1.0f, 0},
            {0.0, 0.0, 1.0f, 0},
            {20.0, 0.0, 1.0f, 0},
        };
        for (int index = 0; index < 6; index++) {
            NSError *error = nil;
            CHHapticPattern *pattern = revenant_pattern(&cases[index], 1, &error);
            NSTimeInterval apple = revenant_apple_pattern_duration(&cases[index], 1);
            char label[96];
            snprintf(label, sizeof(label), "the pattern duration of case %d is the one Core Haptics computes", index);
            revenant_check((pattern != nil && error == nil && fabs(pattern.duration - apple) < 0.00001) != revenant_negative,
                           label, [NSString stringWithFormat:@"%.5f against %.5f", pattern ? pattern.duration : -1.0, apple]);
        }

        RevenantOracleEvent pair[2] = {{0.0, 10.0, 1.0f, 0}, {20.0, 0.0, 1.0f, 0}};
        NSError *error = nil;
        CHHapticPattern *pattern = revenant_pattern(pair, 2, &error);
        NSTimeInterval apple = revenant_apple_pattern_duration(pair, 2);
        revenant_check((pattern != nil && fabs(pattern.duration - apple) < 0.00001) != revenant_negative,
                       "the pattern duration is the latest event the one Core Haptics computes",
                       [NSString stringWithFormat:@"%.5f against %.5f", pattern ? pattern.duration : -1.0, apple]);

        pattern = revenant_pattern(pair, 2, &error);
        NSDictionary *exported = [pattern exportDictionaryAndReturnError:NULL];
        NSDictionary *appleExported = revenant_apple_pattern_dictionary(pair, 2);
        revenant_check(([exported isEqualToDictionary:appleExported]) != revenant_negative, "the exported pattern is the one Core Haptics exports",
                       [NSString stringWithFormat:@"%@ against %@", exported, appleExported]);

        error = nil;
        CHHapticEvent *negative = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                                parameters:@[intensity]
                                                              relativeTime:-1.0
                                                                  duration:2.0];
        CHHapticPattern *accepted = [[CHHapticPattern alloc] initWithEvents:@[negative] parameters:@[] error:&error];
        revenant_check((accepted != nil && error == nil) != revenant_negative, "a pattern with a negative event time is accepted, as Core Haptics accepts it",
                       error ? error.description : @"no error");

        NSDictionary *dictionaryEvent = @{CHHapticPatternKeyEvent: @{CHHapticPatternKeyEventType: @"HapticContinuous",
                                                                  CHHapticPatternKeyEventDuration: @10,
                                                                  CHHapticPatternKeyTime: @0,
                                                                  CHHapticPatternKeyEventParameters: @[@{CHHapticPatternKeyParameterID: @"HapticIntensity",
                                                                                                          CHHapticPatternKeyParameterValue: @1}]}};
        NSArray *dictionaries = @[
            @{CHHapticPatternKeyPattern: @[dictionaryEvent]},
            @{CHHapticPatternKeyVersion: @1, CHHapticPatternKeyPattern: @[dictionaryEvent]},
            @{CHHapticPatternKeyVersion: @2, CHHapticPatternKeyPattern: @[dictionaryEvent]},
            @{},
            @{CHHapticPatternKeyVersion: @1},
            @{CHHapticPatternKeyPattern: @[dictionaryEvent], CHHapticPatternKeyVersion: @1},
            @{CHHapticPatternKeyPattern: @[@{CHHapticPatternKeyEvent: @{CHHapticPatternKeyEventType: @"HapticContinuous",
                                                                         CHHapticPatternKeyEventDuration: @10}}]},
            @{CHHapticPatternKeyPattern: @[@{CHHapticPatternKeyEvent: @{CHHapticPatternKeyEventDuration: @10,
                                                                         CHHapticPatternKeyTime: @0}}]},
            @{CHHapticPatternKeyPattern: @[@{CHHapticPatternKeyEvent: @{CHHapticPatternKeyEventType: @"HapticContinuous",
                                                                         CHHapticPatternKeyEventDuration: @10,
                                                                         CHHapticPatternKeyTime: @0,
                                                                         CHHapticPatternKeyEventParameters: @[@{CHHapticPatternKeyParameterID: @"HapticIntensity"}]}}]},
            @{CHHapticPatternKeyPattern: @[@{CHHapticPatternKeyParameter: @{CHHapticPatternKeyParameterID: @"HapticIntensityControl",
                                                                         CHHapticPatternKeyParameterValue: @0.5,
                                                                         CHHapticPatternKeyTime: @3}}]},
            @{CHHapticPatternKeyPattern: @[@{CHHapticPatternKeyParameter: @{CHHapticPatternKeyParameterID: @"HapticIntensityControl",
                                                                         CHHapticPatternKeyParameterValue: @0.5}}]},
        ];
        for (unsigned index = 0; index < dictionaries.count; index++) {
            NSDictionary *dictionary = dictionaries[index];
            NSError *parseError = nil;
            CHHapticPattern *parsed = [[CHHapticPattern alloc] initWithDictionary:dictionary error:&parseError];
            NSTimeInterval appleDuration = -1.0;
            NSString *appleDomain = nil;
            NSInteger appleCode = 0;
            BOOL appleAccepted = revenant_apple_parse_dictionary(dictionary, &appleDuration, &appleDomain, &appleCode);
            BOOL same = (parsed != nil) == appleAccepted;
            same = same && (parsed == nil || fabs(parsed.duration - appleDuration) < 0.00001);
            same = same && (parseError == nil) == (appleDomain == nil);
            same = same && (!parseError || ([parseError.domain isEqualToString:appleDomain] && parseError.code == appleCode));
            char label[96];
            snprintf(label, sizeof(label), "the pattern of dictionary %u is the one CoreHaptics reads", index);
            revenant_check((same) != revenant_negative, label,
                           [NSString stringWithFormat:@"%@ against %@", parseError ? parseError.description : @"accepted", appleDomain ? appleDomain : @"accepted"]);
        }
    }
    return revenant_finish();
}
