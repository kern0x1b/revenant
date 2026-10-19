#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

static CGColorRef RevenantCIColorInSpace(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, CGColorSpaceRef space)
{
    if (!space)
        space = CGColorSpaceCreateDeviceRGB();
    return CGColorCreate(space, (CGFloat[]){red, green, blue, alpha});
}

@implementation CIColor (RevenantColorSpace)

+ (instancetype)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self colorWithCGColor:RevenantCIColorInSpace(red, green, blue, 1, colorSpace)];
}

+ (instancetype)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
                   colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self colorWithCGColor:RevenantCIColorInSpace(red, green, blue, alpha, colorSpace)];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self initWithCGColor:RevenantCIColorInSpace(red, green, blue, 1, colorSpace)];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
                  colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self initWithCGColor:RevenantCIColorInSpace(red, green, blue, alpha, colorSpace)];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
    return [self initWithRed:red green:green blue:blue alpha:1];
}

@end

@implementation CIColor (RevenantNamedColors)

#define RevenantNamedColor(name, r, g, b, a)                                                                                \
    + (CIColor *)name                                                                                                     \
    {                                                                                                                     \
        static CIColor *color;                                                                                            \
        if (!color)                                                                                                       \
            color = [CIColor colorWithRed:r green:g blue:b alpha:a colorSpace:CGColorSpaceCreateDeviceRGB()];                 \
        return color;                                                                                                     \
    }

RevenantNamedColor(blackColor, 0, 0, 0, 1)
RevenantNamedColor(whiteColor, 1, 1, 1, 1)
RevenantNamedColor(grayColor, 0.5, 0.5, 0.5, 1)
RevenantNamedColor(redColor, 1, 0, 0, 1)
RevenantNamedColor(greenColor, 0, 1, 0, 1)
RevenantNamedColor(blueColor, 0, 0, 1, 1)
RevenantNamedColor(cyanColor, 0, 1, 1, 1)
RevenantNamedColor(magentaColor, 1, 0, 1, 1)
RevenantNamedColor(yellowColor, 1, 1, 0, 1)
RevenantNamedColor(clearColor, 0, 0, 0, 0)

@end
