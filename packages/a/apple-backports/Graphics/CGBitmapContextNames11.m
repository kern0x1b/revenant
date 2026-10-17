#import <CoreGraphics/CoreGraphics.h>

// The bitmap context bit depth hint. The SDK's CGBitmapContext.h gives it API_AVAILABLE(ios(11.0)), but release-split finds
// no held cache (11.0 to 18.0) that names it, so its release is the SDK's claim and not a measurement
// (facts/CoreGraphics/ColourKeys.md).
const CFStringRef kCGAdaptiveMaximumBitDepth = CFSTR("kCGAdaptiveMaximumBitDepth");
