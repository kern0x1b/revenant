#import "RevenantCoreHaptics.h"

CHHapticEventType BACKPORT_IMPL(CHHapticEventTypeHapticTransient) = @"HapticTransient";
CHHapticEventType BACKPORT_IMPL(CHHapticEventTypeHapticContinuous) = @"HapticContinuous";
CHHapticEventParameterID BACKPORT_IMPL(CHHapticEventParameterIDHapticIntensity) = @"HapticIntensity";
CHHapticEventParameterID BACKPORT_IMPL(CHHapticEventParameterIDHapticSharpness) = @"HapticSharpness";
CHHapticDynamicParameterID BACKPORT_IMPL(CHHapticDynamicParameterIDHapticIntensityControl) = @"HapticIntensityControl";
CHHapticDynamicParameterID BACKPORT_IMPL(CHHapticDynamicParameterIDHapticSharpnessControl) = @"HapticSharpnessControl";

NSError *revenant_corehaptics_error(CHHapticErrorCode code)
{
    return [NSError errorWithDomain:CoreHapticsErrorDomain code:code userInfo:nil];
}
