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

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        revenant_expect_string("the transient event type is the one Core Haptics uses", CHHapticEventTypeHapticTransient,
                               revenant_apple_event_type_transient());
        revenant_expect_string("the continuous event type is the one Core Haptics uses", CHHapticEventTypeHapticContinuous,
                               revenant_apple_event_type_continuous());
        revenant_expect_string("the intensity parameter is the one Core Haptics uses", CHHapticEventParameterIDHapticIntensity,
                               revenant_apple_parameter_intensity());
        revenant_expect_string("the sharpness parameter is the one Core Haptics uses", CHHapticEventParameterIDHapticSharpness,
                               revenant_apple_parameter_sharpness());
        revenant_expect_string("the intensity control is the one Core Haptics uses", CHHapticDynamicParameterIDHapticIntensityControl,
                               revenant_apple_dynamic_intensity());
        revenant_expect_string("the sharpness control is the one Core Haptics uses", CHHapticDynamicParameterIDHapticSharpnessControl,
                               revenant_apple_dynamic_sharpness());

        CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:0.7f];
        revenant_check(fabs(intensity.value - 0.7f) < 0.00001f, "the event parameter keeps its value",
                       [NSString stringWithFormat:@"%f", intensity.value]);
        CHHapticEventParameter *sharpness = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.3f];
        sharpness.value = 0.4f;
        revenant_check(fabs(sharpness.value - 0.4f) < 0.00001f, "the event parameter keeps the value it is given",
                       [NSString stringWithFormat:@"%f", sharpness.value]);

        CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                              parameters:@[intensity, sharpness]
                                                            relativeTime:0.25
                                                                duration:2.0];
        revenant_expect_string("the event keeps its type", event.type, revenant_apple_event_type_continuous());
        revenant_check(event.eventParameters.count == 2, "the event keeps its parameters",
                       [NSString stringWithFormat:@"%lu", (unsigned long)event.eventParameters.count]);
        revenant_check(fabs(event.relativeTime - 0.25) < 0.00001 && fabs(event.duration - 2.0) < 0.00001,
                       "the event keeps its timing", [NSString stringWithFormat:@"%.5f %.5f", event.relativeTime, event.duration]);
        event.relativeTime = 0.5;
        event.duration = 1.5;
        revenant_check(fabs(event.relativeTime - 0.5) < 0.00001 && fabs(event.duration - 1.5) < 0.00001,
                       "the event keeps the timing it is given", [NSString stringWithFormat:@"%.5f %.5f", event.relativeTime, event.duration]);

        const RevenantOracleEvent cases[] = {
            {0.0, 2.0, 1.0f, 0},
            {0.25, 2.0, 0.7f, 0},
            {1.5, 0.0, 1.0f, 1},
            {-1.0, 2.0, 1.0f, 0},
            {0.0, 0.0, 1.0f, 0},
            {20.0, 0.0, 1.0f, 0},
        };
        const int counts[] = {1, 1, 1, 1, 1, 1};
        for (int index = 0; index < 6; index++) {
            NSError *error = nil;
            CHHapticPattern *pattern = revenant_pattern(&cases[index], counts[index], &error);
            NSTimeInterval apple = revenant_apple_pattern_duration(&cases[index], counts[index]);
            char label[96];
            snprintf(label, sizeof(label), "the pattern duration of case %d is the one Core Haptics computes", index);
            revenant_check(pattern != nil && error == nil && fabs(pattern.duration - apple) < 0.00001,
                           label, [NSString stringWithFormat:@"%.5f against %.5f", pattern ? pattern.duration : -1.0, apple]);
        }

        RevenantOracleEvent pair[2] = {{0.0, 10.0, 1.0f, 0}, {20.0, 0.0, 1.0f, 0}};
        NSError *error = nil;
        CHHapticPattern *pattern = revenant_pattern(pair, 2, &error);
        NSTimeInterval apple = revenant_apple_pattern_duration(pair, 2);
        revenant_check(pattern != nil && fabs(pattern.duration - apple) < 0.00001,
                       "the pattern duration is the latest event the one Core Haptics computes",
                       [NSString stringWithFormat:@"%.5f against %.5f", pattern ? pattern.duration : -1.0, apple]);

        error = nil;
        pattern = revenant_pattern(pair, 2, &error);
        NSDictionary *exported = [pattern exportDictionaryAndReturnError:NULL];
        NSDictionary *appleExported = revenant_apple_pattern_dictionary(pair, 2);
        revenant_check([exported isEqualToDictionary:appleExported], "the exported pattern is the one Core Haptics exports",
                       [NSString stringWithFormat:@"%@ against %@", exported, appleExported]);

        error = nil;
        CHHapticEvent *negative = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                                parameters:@[intensity]
                                                              relativeTime:-1.0
                                                                  duration:2.0];
        CHHapticPattern *accepted = [[CHHapticPattern alloc] initWithEvents:@[negative] parameters:@[] error:&error];
        revenant_check(accepted != nil && error == nil, "a pattern with a negative event time is accepted, as Core Haptics accepts it",
                       error ? error.description : @"no error");
    }
    return revenant_finish();
}
