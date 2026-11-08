#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

static CGColorSpaceRef revenant_device_rgb(void)
{
    static CGColorSpaceRef space;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        space = CGColorSpaceCreateDeviceRGB();
    });
    return space;
}

static CGColorRef revenant_cg_color(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, CGColorSpaceRef space)
{
    return CGColorCreate(space ?: revenant_device_rgb(), (CGFloat[]){red, green, blue, alpha});
}

static CIColor *revenant_ci_color(Class cls, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, CGColorSpaceRef space)
{
    CGColorRef color = revenant_cg_color(red, green, blue, alpha, space);
    CIColor *result = [cls colorWithCGColor:color];
    CGColorRelease(color);
    return result;
}

@implementation CIColor (RevenantColorSpace)

+ (instancetype)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue colorSpace:(CGColorSpaceRef)colorSpace
{
    return revenant_ci_color(self, red, green, blue, 1, colorSpace);
}

+ (instancetype)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
                   colorSpace:(CGColorSpaceRef)colorSpace
{
    return revenant_ci_color(self, red, green, blue, alpha, colorSpace);
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue colorSpace:(CGColorSpaceRef)colorSpace
{
    CGColorRef color = revenant_cg_color(red, green, blue, 1, colorSpace);
    self = [self initWithCGColor:color];
    CGColorRelease(color);
    return self;
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
                  colorSpace:(CGColorSpaceRef)colorSpace
{
    CGColorRef color = revenant_cg_color(red, green, blue, alpha, colorSpace);
    self = [self initWithCGColor:color];
    CGColorRelease(color);
    return self;
}

- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
    return [self initWithRed:red green:green blue:blue alpha:1];
}

@end

@implementation CIColor (RevenantNamedColors)

+ (CIColor *)blackColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 0, 0, 0, 1, NULL);
    });
    return color;
}

+ (CIColor *)whiteColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 1, 1, 1, 1, NULL);
    });
    return color;
}

+ (CIColor *)grayColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 0.5, 0.5, 0.5, 1, NULL);
    });
    return color;
}

+ (CIColor *)redColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 1, 0, 0, 1, NULL);
    });
    return color;
}

+ (CIColor *)greenColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 0, 1, 0, 1, NULL);
    });
    return color;
}

+ (CIColor *)blueColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 0, 0, 1, 1, NULL);
    });
    return color;
}

+ (CIColor *)cyanColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 0, 1, 1, 1, NULL);
    });
    return color;
}

+ (CIColor *)magentaColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 1, 0, 1, 1, NULL);
    });
    return color;
}

+ (CIColor *)yellowColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 1, 1, 0, 1, NULL);
    });
    return color;
}

+ (CIColor *)clearColor
{
    static CIColor *color;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        color = revenant_ci_color([CIColor class], 0, 0, 0, 0, NULL);
    });
    return color;
}

@end
