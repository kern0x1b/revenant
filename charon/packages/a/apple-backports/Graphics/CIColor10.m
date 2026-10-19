#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

static CGColorRef CharonCIColorInSpace(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, CGColorSpaceRef space)
{
    if (!space)
        space = CGColorSpaceCreateDeviceRGB();
    return CGColorCreate(space, (CGFloat[]){red, green, blue, alpha});
}

@implementation CIColor (CharonColorSpace)

+ (instancetype)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self colorWithCGColor:CharonCIColorInSpace(red, green, blue, 1, colorSpace)];
}

+ (instancetype)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
                   colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self colorWithCGColor:CharonCIColorInSpace(red, green, blue, alpha, colorSpace)];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self initWithCGColor:CharonCIColorInSpace(red, green, blue, 1, colorSpace)];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
                  colorSpace:(CGColorSpaceRef)colorSpace
{
    return [self initWithCGColor:CharonCIColorInSpace(red, green, blue, alpha, colorSpace)];
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
    return [self initWithRed:red green:green blue:blue alpha:1];
}

@end

@implementation CIColor (CharonNamedColors)

#define CharonNamedColor(name, r, g, b, a)                                                                                \
    + (CIColor *)name                                                                                                     \
    {                                                                                                                     \
        static CIColor *color;                                                                                            \
        if (!color)                                                                                                       \
            color = [CIColor colorWithRed:r green:g blue:b alpha:a colorSpace:CGColorSpaceCreateDeviceRGB()];                 \
        return color;                                                                                                     \
    }

CharonNamedColor(blackColor, 0, 0, 0, 1)
CharonNamedColor(whiteColor, 1, 1, 1, 1)
CharonNamedColor(grayColor, 0.5, 0.5, 0.5, 1)
CharonNamedColor(redColor, 1, 0, 0, 1)
CharonNamedColor(greenColor, 0, 1, 0, 1)
CharonNamedColor(blueColor, 0, 0, 1, 1)
CharonNamedColor(cyanColor, 0, 1, 1, 1)
CharonNamedColor(magentaColor, 1, 0, 1, 1)
CharonNamedColor(yellowColor, 1, 1, 0, 1)
CharonNamedColor(clearColor, 0, 0, 0, 0)

@end
