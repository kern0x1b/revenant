#include "RevenantSwitchGeometry.h"
#include <math.h>

const CGSize RevenantSwitchSize = {51, 31};
const CGFloat RevenantSwitchAlignmentRight = 2;
const CGFloat RevenantSwitchOffComponents[4] = {120.0 / 255, 120.0 / 255, 128.0 / 255, 0.16};
const CGFloat RevenantSwitchOnComponents[4] = {52.0 / 255, 199.0 / 255, 89.0 / 255, 1};
const CGFloat RevenantSwitchDisabledAlpha = 0.5;
const RevenantSwitchSpring RevenantSwitchKnobSpring = {1, 438.649, 31.416, 0.488};
const RevenantSwitchSpring RevenantSwitchWellOnSpring = {1, 85.377, 18.480, 0.9995};
const RevenantSwitchSpring RevenantSwitchWellOffSpring = {1, 246.740, 31.416, 0.5879};

static const CGFloat RevenantSwitchInset = 2;
static const CGFloat RevenantSwitchKnobImageSide = 43;
static const CGFloat RevenantSwitchKnobImageCenterY = 18.5;
static const CGFloat RevenantSwitchKnobPressedGrowth = 7;
static const CGFloat RevenantSwitchKnobShadowOffset = 2.5;
static const CGFloat RevenantSwitchKnobShadowBlur = 5.75;
static const CGFloat RevenantSwitchKnobShadowAlpha = 0.12;
static const CGFloat RevenantSwitchWellLength = 10;
static const CGFloat RevenantSwitchPanHysteresis = 10;

static CGFloat RevenantSwitchKnobDiameter(void)
{
    return RevenantSwitchSize.height - 2 * RevenantSwitchInset;
}

static CGFloat RevenantSwitchKnobImagePadding(void)
{
    return (RevenantSwitchKnobImageSide - RevenantSwitchKnobDiameter()) / 2;
}

CGRect RevenantSwitchKnobBounds(bool pressed)
{
    CGFloat width = RevenantSwitchKnobImageSide + (pressed ? RevenantSwitchKnobPressedGrowth : 0);
    return CGRectMake(0, 0, width, RevenantSwitchKnobImageSide);
}

CGPoint RevenantSwitchKnobPosition(bool on, bool pressed)
{
    CGFloat half = (RevenantSwitchKnobDiameter() + (pressed ? RevenantSwitchKnobPressedGrowth : 0)) / 2;
    CGFloat x = on ? RevenantSwitchSize.width - RevenantSwitchInset - half : RevenantSwitchInset + half;
    CGFloat y = RevenantSwitchSize.height / 2 + RevenantSwitchKnobImageSide / 2 - RevenantSwitchKnobImageCenterY;
    return CGPointMake(x, y);
}

CGRect RevenantSwitchKnobContentsCenter(void)
{
    CGFloat middle = floor(RevenantSwitchKnobImageSide / 2);
    return CGRectMake(middle / RevenantSwitchKnobImageSide, 0, 1 / RevenantSwitchKnobImageSide, 1);
}

CGRect RevenantSwitchWellFrame(bool on)
{
    CGFloat length = RevenantSwitchWellLength * RevenantSwitchSize.width;
    CGFloat x = on ? 0 : RevenantSwitchSize.width - length;
    return CGRectMake(x, 0, length, RevenantSwitchSize.height);
}

CGFloat RevenantSwitchWellAlpha(CGFloat x)
{
    CGFloat width = RevenantSwitchSize.width;
    CGFloat length = RevenantSwitchWellLength * width;
    if (x <= width)
        return 1;
    if (x >= length - width)
        return 0;
    return 1 - (x - width) / (length - 2 * width);
}

static CGContextRef RevenantSwitchContextCreate(size_t width, size_t height)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    return context;
}

CGRect RevenantSwitchKnobTrackRect(bool on)
{
    CGPoint position = RevenantSwitchKnobPosition(on, false);
    CGFloat half = RevenantSwitchKnobImageSide / 2;
    return CGRectMake(half - position.x, half - position.y, RevenantSwitchSize.width, RevenantSwitchSize.height);
}

static void RevenantSwitchClipToCapsule(CGContextRef context, CGRect rect)
{
    CGFloat radius = CGRectGetHeight(rect) / 2;
    CGFloat middle = CGRectGetMidY(rect);
    CGContextBeginPath(context);
    CGContextAddArc(context, CGRectGetMinX(rect) + radius, middle, radius, M_PI / 2, 3 * M_PI / 2, 0);
    CGContextAddArc(context, CGRectGetMaxX(rect) - radius, middle, radius, 3 * M_PI / 2, M_PI / 2, 0);
    CGContextClosePath(context);
    CGContextClip(context);
}

CGImageRef RevenantSwitchKnobImageCreate(CGColorRef fill, CGFloat scale, bool on)
{
    size_t side = (size_t)ceil(RevenantSwitchKnobImageSide * scale);
    CGContextRef context = RevenantSwitchContextCreate(side, side);
    if (!context)
        return NULL;
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, 0, RevenantSwitchKnobImageSide);
    CGContextScaleCTM(context, 1, -1);
    CGFloat diameter = RevenantSwitchKnobDiameter();
    CGRect knob = CGRectMake(RevenantSwitchKnobImagePadding(), RevenantSwitchKnobImageCenterY - diameter / 2, diameter, diameter);
    RevenantSwitchClipToCapsule(context, RevenantSwitchKnobTrackRect(on));
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    const CGFloat black[4] = {0, 0, 0, RevenantSwitchKnobShadowAlpha};
    CGColorRef shadow = CGColorCreate(space, black);
    CGColorSpaceRelease(space);
    CGContextSetShadowWithColor(context, CGSizeMake(0, -RevenantSwitchKnobShadowOffset * scale), RevenantSwitchKnobShadowBlur * scale, shadow);
    CGColorRelease(shadow);
    CGContextSetFillColorWithColor(context, fill);
    CGContextFillEllipseInRect(context, knob);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

CGImageRef RevenantSwitchWellImageCreate(CGColorRef color, CGFloat scale)
{
    CGFloat length = RevenantSwitchWellLength * RevenantSwitchSize.width;
    size_t width = (size_t)ceil(length * scale);
    CGContextRef context = RevenantSwitchContextCreate(width, 1);
    if (!context)
        return NULL;
    CGFloat alpha = CGColorGetAlpha(color);
    for (size_t column = 0; column < width; column++) {
        CGColorRef shade = CGColorCreateCopyWithAlpha(color, alpha * RevenantSwitchWellAlpha((column + 0.5) / scale));
        CGContextSetFillColorWithColor(context, shade);
        CGColorRelease(shade);
        CGContextFillRect(context, CGRectMake(column, 0, 1, 1));
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

void RevenantSwitchTrackingBegin(RevenantSwitchTracking *tracking, bool on, CGFloat x)
{
    tracking->on = on;
    tracking->displayedOn = on;
    tracking->panning = false;
    tracking->touchX = x;
    tracking->anchorX = x;
}

bool RevenantSwitchTrackingMove(RevenantSwitchTracking *tracking, CGFloat x)
{
    if (!tracking->panning) {
        if (fabs(x - tracking->touchX) <= RevenantSwitchPanHysteresis)
            return false;
        tracking->panning = true;
    }
    CGFloat translation = x - tracking->anchorX;
    CGFloat flip = RevenantSwitchSize.width / 2;
    bool flipped = tracking->displayedOn ? translation <= -flip : translation >= flip;
    if (!flipped)
        return false;
    tracking->displayedOn = !tracking->displayedOn;
    tracking->anchorX = x;
    return true;
}

bool RevenantSwitchTrackingEnd(RevenantSwitchTracking *tracking, bool inside)
{
    if (tracking->panning)
        return tracking->displayedOn;
    return inside ? !tracking->on : tracking->on;
}
