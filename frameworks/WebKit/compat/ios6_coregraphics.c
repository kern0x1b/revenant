#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdint.h>

void CGPathAddUnevenCornersRoundedRect(CGMutablePathRef path, const CGAffineTransform *transform, CGRect rect, const CGSize corners[4])
{
    if (!path)
        return;
    if (!corners) {
        CGPathAddRect(path, transform, rect);
        return;
    }

    CGFloat left = CGRectGetMinX(rect), right = CGRectGetMaxX(rect);
    CGFloat top = CGRectGetMinY(rect), bottom = CGRectGetMaxY(rect);
    CGFloat halfWidth = CGRectGetWidth(rect) / 2, halfHeight = CGRectGetHeight(rect) / 2;

    CGFloat topLeft = fmin(corners[0].width, halfWidth), topLeftY = fmin(corners[0].height, halfHeight);
    CGFloat topRight = fmin(corners[1].width, halfWidth), topRightY = fmin(corners[1].height, halfHeight);
    CGFloat bottomRight = fmin(corners[2].width, halfWidth), bottomRightY = fmin(corners[2].height, halfHeight);
    CGFloat bottomLeft = fmin(corners[3].width, halfWidth), bottomLeftY = fmin(corners[3].height, halfHeight);

    CGPathMoveToPoint(path, transform, left + topLeft, top);
    CGPathAddLineToPoint(path, transform, right - topRight, top);
    CGPathAddCurveToPoint(path, transform, right, top, right, top, right, top + topRightY);
    CGPathAddLineToPoint(path, transform, right, bottom - bottomRightY);
    CGPathAddCurveToPoint(path, transform, right, bottom, right, bottom, right - bottomRight, bottom);
    CGPathAddLineToPoint(path, transform, left + bottomLeft, bottom);
    CGPathAddCurveToPoint(path, transform, left, bottom, left, bottom, left, bottom - bottomLeftY);
    CGPathAddLineToPoint(path, transform, left, top + topLeftY);
    CGPathAddCurveToPoint(path, transform, left, top, left, top, left + topLeft, top);
    CGPathCloseSubpath(path);
}

void CGPathAddContinuousRoundedRect(CGMutablePathRef path, const CGAffineTransform *transform, CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight)
{
    CGSize corners[4];
    for (int i = 0; i < 4; i++)
        corners[i] = CGSizeMake(cornerWidth, cornerHeight);
    CGPathAddUnevenCornersRoundedRect(path, transform, rect, corners);
}

CGGradientRef CGGradientCreateWithColorComponentsAndOptions(CGColorSpaceRef space, const CGFloat *components, const CGFloat *locations, size_t count, CFDictionaryRef options)
{
    (void)options;
    return CGGradientCreateWithColorComponents(space, components, locations, count);
}

void CGContextDrawConicGradient(CGContextRef context, CGGradientRef gradient, CGPoint center, CGFloat angle)
{
    (void)center;
    (void)angle;
    if (!context || !gradient)
        return;

    uint8_t pixel[4] = { 0, 0, 0, 0 };
    CGColorSpaceRef sampleSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef sample = CGBitmapContextCreate(pixel, 1, 1, 8, 4, sampleSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(sampleSpace);
    if (!sample)
        return;

    CGContextDrawLinearGradient(sample, gradient, CGPointMake(4, 0), CGPointMake(5, 0),
        kCGGradientDrawsBeforeStartLocation);
    CGContextRelease(sample);

    if (!pixel[3])
        return;

    CGFloat alpha = pixel[3] / 255.0;
    CGContextSetRGBFillColor(context, pixel[0] / 255.0 / alpha, pixel[1] / 255.0 / alpha,
        pixel[2] / 255.0 / alpha, alpha);
    CGContextFillRect(context, CGContextGetClipBoundingBox(context));
}

CGColorRef CGColorCreateSRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    CGFloat components[4] = { red, green, blue, alpha };
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGColorRef color = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    return color;
}

CGColorSpaceRef CGContextGetColorSpace(CGContextRef context)
{
    (void)context;
    static CGColorSpaceRef deviceRGB;
    if (!deviceRGB)
        deviceRGB = CGColorSpaceCreateDeviceRGB();
    return deviceRGB;
}

CFStringRef CGColorSpaceGetName(CGColorSpaceRef space)
{
    (void)space;
    return NULL;
}

bool CGColorSpaceIsWideGamutRGB(CGColorSpaceRef space)
{
    (void)space;
    return false;
}

bool CGColorSpaceUsesExtendedRange(CGColorSpaceRef space)
{
    (void)space;
    return false;
}

extern CGImageRef CGIOSurfaceContextCreateImage(CGContextRef);

CGImageRef CGIOSurfaceContextCreateImageReference(CGContextRef context)
{
    return CGIOSurfaceContextCreateImage(context);
}
