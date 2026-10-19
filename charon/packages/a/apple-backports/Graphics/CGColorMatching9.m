#import <CoreGraphics/CoreGraphics.h>

typedef struct CGColorTransform *CGColorTransformRef;
CGColorTransformRef CGColorTransformCreate(CGColorSpaceRef space, CFDictionaryRef options);
CGColorRef CGColorTransformConvertColor(CGColorTransformRef transform, CGColorRef color, CGColorRenderingIntent intent);
void CGColorTransformRelease(CGColorTransformRef transform);

CGColorRef CGColorCreateCopyByMatchingToColorSpace(CGColorSpaceRef space, CGColorRenderingIntent intent, CGColorRef color, CFDictionaryRef options)
{
    if (!space || !color || CGColorSpaceGetModel(space) == kCGColorSpaceModelPattern
        || CGColorSpaceGetModel(CGColorGetColorSpace(color)) == kCGColorSpaceModelPattern)
        return NULL;
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
