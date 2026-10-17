#import <CoreGraphics/CoreGraphics.h>

// The colour conversion black point option, named by iOS 10.0.1. The release names it kCGColorTransformBlackPointCompensation,
// and the constant's own name is the one an application writes (facts/CoreGraphics/ColourKeys.md).
const CFStringRef kCGColorConversionBlackPointCompensation = CFSTR("kCGColorTransformBlackPointCompensation");
