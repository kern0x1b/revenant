#import <CoreHaptics/CoreHaptics.h>
#import <Foundation/Foundation.h>
#import "corehaptics_oracle.h"

static CHHapticPattern *revenant_apple_pattern(const RevenantOracleEvent *events, int count)
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
    return [[CHHapticPattern alloc] initWithEvents:listing parameters:@[] error:NULL];
}

NSTimeInterval revenant_apple_pattern_duration(const RevenantOracleEvent *events, int count)
{
    CHHapticPattern *pattern = revenant_apple_pattern(events, count);
    return pattern ? pattern.duration : -1.0;
}

NSDictionary *revenant_apple_pattern_dictionary(const RevenantOracleEvent *events, int count)
{
    CHHapticPattern *pattern = revenant_apple_pattern(events, count);
    return [pattern exportDictionaryAndReturnError:NULL];
}

NSString *revenant_apple_event_type_transient(void)
{
    return CHHapticEventTypeHapticTransient;
}

NSString *revenant_apple_event_type_continuous(void)
{
    return CHHapticEventTypeHapticContinuous;
}

NSString *revenant_apple_parameter_intensity(void)
{
    return CHHapticEventParameterIDHapticIntensity;
}

NSString *revenant_apple_parameter_sharpness(void)
{
    return CHHapticEventParameterIDHapticSharpness;
}

NSString *revenant_apple_dynamic_intensity(void)
{
    return CHHapticDynamicParameterIDHapticIntensityControl;
}

NSString *revenant_apple_dynamic_sharpness(void)
{
    return CHHapticDynamicParameterIDHapticSharpnessControl;
}
