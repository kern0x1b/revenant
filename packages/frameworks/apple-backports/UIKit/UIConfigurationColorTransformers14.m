#import <UIKit/UIKit.h>

static UIColor *RevenantGrayscaleColor(UIColor *color)
{
    CGColorRef base = color.CGColor;
    if (!base)
        return color;
    static CGColorSpaceRef space;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        space = CGColorSpaceCreateDeviceGray();
    });
    CGColorRef gray = space ? CGColorCreateCopyByMatchingToColorSpace(space, kCGRenderingIntentDefault,
                                                                       base, NULL) : NULL;
    if (!gray)
        return color;
    UIColor *converted = [UIColor colorWithCGColor:gray];
    CGColorRelease(gray);
    return converted;
}

const UIConfigurationColorTransformer UIConfigurationColorTransformerGrayscale = ^UIColor *(UIColor *color) {
    return RevenantGrayscaleColor(color);
};

const UIConfigurationColorTransformer UIConfigurationColorTransformerPreferredTint = ^UIColor *(UIColor *color) {
    return color;
};

const UIConfigurationColorTransformer UIConfigurationColorTransformerMonochromeTint = ^UIColor *(UIColor *color) {
    (void)color;
    return [UIColor colorWithWhite:1.0 alpha:140.0 / 255.0];
};
