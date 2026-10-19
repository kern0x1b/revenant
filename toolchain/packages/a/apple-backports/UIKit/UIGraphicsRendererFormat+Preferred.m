#import <float.h>
#import "RevenantGraphicsRenderer.h"

@implementation UIGraphicsRendererFormat (RevenantPreferred)

+ (instancetype)preferredFormat
{
    return [[self alloc] init];
}

@end

@implementation UIGraphicsImageRendererFormat (RevenantPreferred)

+ (instancetype)preferredFormat
{
    return [self defaultFormat];
}

+ (instancetype)formatForTraitCollection:(UITraitCollection *)traitCollection
{
    if (!traitCollection) {
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: traitCollection"];
        return nil;
    }
    UIGraphicsImageRendererFormat *format = [self preferredFormat];
    CGFloat scale = traitCollection.displayScale;
    if (!(fabs(scale) < DBL_EPSILON))
        format.scale = scale;
    UIDisplayGamut gamut = [traitCollection respondsToSelector:@selector(displayGamut)] ? traitCollection.displayGamut : UIDisplayGamutUnspecified;
    if (gamut != UIDisplayGamutUnspecified)
        format.prefersExtendedRange = gamut != UIDisplayGamutSRGB;
    return format;
}

@end
