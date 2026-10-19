#import <CoreGraphics/CoreGraphics.h>

// The release's own colour conversion, which CoreGraphics exports without a header from 3.1.3 on
// and which CGColorCreateCopyByMatchingToColorSpace wraps from 9.0: the same answers on the host,
// component for component, for grey, RGB, CMYK, sRGB and Display P3 targets.
typedef struct CGColorTransform *CGColorTransformRef;
CGColorTransformRef CGColorTransformCreate(CGColorSpaceRef space, CFDictionaryRef options);
CGColorRef CGColorTransformConvertColor(CGColorTransformRef transform, CGColorRef color, CGColorRenderingIntent intent);
void CGColorTransformRelease(CGColorTransformRef transform);

CGColorRef CGColorCreateCopyByMatchingToColorSpace(CGColorSpaceRef space, CGColorRenderingIntent intent, CGColorRef color, CFDictionaryRef options)
{
    if (!space || !color || CGColorSpaceGetModel(space) == kCGColorSpaceModelPattern
        || CGColorSpaceGetModel(CGColorGetColorSpace(color)) == kCGColorSpaceModelPattern)
        return NULL;
    // A colour already in a calibrated target space comes back itself; one in a device space is
    // converted even to the same device space, as the host does.
    CGColorSpaceRef source = CGColorGetColorSpace(color);
    if (CFEqual(source, space)) {
        CGColorSpaceRef devices[] = {CGColorSpaceCreateDeviceGray(), CGColorSpaceCreateDeviceRGB(), CGColorSpaceCreateDeviceCMYK()};
        bool device = false;
        for (size_t i = 0; i < sizeof devices / sizeof *devices; i++) {
            device = device || CFEqual(devices[i], space);
            CGColorSpaceRelease(devices[i]);
        }
        if (!device)
            return CGColorRetain(color);
    }
    CGColorTransformRef transform = CGColorTransformCreate(space, options);
    if (!transform)
        return NULL;
    CGColorRef matched = CGColorTransformConvertColor(transform, color, intent);
    CGColorTransformRelease(transform);
    return matched;
}
