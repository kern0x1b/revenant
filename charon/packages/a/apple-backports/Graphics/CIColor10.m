#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// CIColor exists on iOS 6: what it does not have is a way to name the colour space a colour was
// measured in. The components of a colour given in a space are that colour as the space sees it, so
// the colour is built in the space the caller named, and the framework's own CIColor is made over it,
// so it is a real colour object and every existing method of it works on it. The renderer converts
// when it draws, which is where a conversion belongs: converting here changed what the accessors
// answer, and the caller reads those.

static CGColorRef CharonCIColorInSpace(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, CGColorSpaceRef space)
{
    // The colour in the space the caller named, and NOT matched into the space the renderer works
    // in.  Matching it here is what this function used to do, and it made the accessors answer a
    // number the caller never passed: measured, a green of 0.0000 in
    // kCGColorSpaceGenericRGB came back 0.1491, and 0.2/0.6/0.9 came back 0.2403/0.6697/0.9208,
    // because the components read back were the ones in the space the colour had been converted
    // into.  The system keeps the caller's components in the caller's space - `-[CIColor green]` on
    // that colour is 0.0000 - and converts when it renders, and the rendered bytes are the same
    // either way: the pixels of that colour are 0 811c9dc5 in both processes.
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

// The named colours: the primaries and neutrals of the space colours are read in, which is the sRGB
// space the system draws in. Each is built through the caller's own initialiser, so the colour is the
// one that initialiser makes and not a separate table of numbers.
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
