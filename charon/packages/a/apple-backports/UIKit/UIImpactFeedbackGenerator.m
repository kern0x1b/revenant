#import "CharonFeedbackGenerator.h"

@implementation UIImpactFeedbackGenerator {
@private
    float _intensity;
    int _milliseconds;
}

- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style
{
    if ((self = [super init])) {
        switch (style) {
            case UIImpactFeedbackStyleLight:  _intensity = 0.45f; _milliseconds = 40;  break;
            case UIImpactFeedbackStyleMedium: _intensity = 0.70f; _milliseconds = 65;  break;
            case UIImpactFeedbackStyleHeavy:  _intensity = 1.00f; _milliseconds = 100; break;
            default:                          _intensity = 0.0f;  _milliseconds = 0;   break;
        }
    }
    return self;
}

- (void)impactOccurred
{
    [self charon_impactScaledBy:1];
}

- (void)charon_impactScaledBy:(float)scale
{
    if (_milliseconds == 0 || scale <= 0)
        return;
    [self _charonPlayIntensity:_intensity * (scale > 1 ? 1 : scale) milliseconds:&_milliseconds count:1];
}

@end
