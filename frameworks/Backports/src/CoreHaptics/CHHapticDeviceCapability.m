#import "RevenantCoreHapticsPrivate.h"

@implementation RevenantHapticParameterAttributes
{
    float _minValue;
    float _maxValue;
    float _defaultValue;
}

@synthesize minValue = _minValue;
@synthesize maxValue = _maxValue;
@synthesize defaultValue = _defaultValue;

- (instancetype)initWithMinimum:(float)minimum maximum:(float)maximum initial:(float)initial
{
    self = [super init];
    if (self) {
        _minValue = minimum;
        _maxValue = maximum;
        _defaultValue = initial;
    }
    return self;
}

@end

@implementation RevenantHapticDeviceCapability

- (BOOL)supportsHaptics
{
    return RevenantVibratorIsAvailable();
}

- (BOOL)supportsAudio
{
    return NO;
}

- (id<CHHapticParameterAttributes>)attributesForEventParameter:(CHHapticEventParameterID)parameter
                                                     eventType:(CHHapticEventType)type
                                                         error:(NSError **)outError
{
    if ([parameter isEqualToString:CHHapticEventParameterIDHapticIntensity]) {
        if (outError)
            *outError = nil;
        return [[RevenantHapticParameterAttributes alloc] initWithMinimum:0.0f maximum:1.0f initial:1.0f];
    }
    if ([parameter isEqualToString:CHHapticEventParameterIDHapticSharpness]) {
        if (outError)
            *outError = nil;
        return [[RevenantHapticParameterAttributes alloc] initWithMinimum:0.0f maximum:1.0f initial:0.5f];
    }
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidParameterType);
    return nil;
}

- (id<CHHapticParameterAttributes>)attributesForDynamicParameter:(CHHapticDynamicParameterID)parameter
                                                           error:(NSError **)outError
{
    if ([parameter isEqualToString:CHHapticDynamicParameterIDHapticIntensityControl]) {
        if (outError)
            *outError = nil;
        return [[RevenantHapticParameterAttributes alloc] initWithMinimum:0.0f maximum:1.0f initial:1.0f];
    }
    if ([parameter isEqualToString:CHHapticDynamicParameterIDHapticSharpnessControl]) {
        if (outError)
            *outError = nil;
        return [[RevenantHapticParameterAttributes alloc] initWithMinimum:-1.0f maximum:1.0f initial:0.0f];
    }
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidParameterType);
    return nil;
}

@end
