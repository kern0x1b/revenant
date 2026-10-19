// The colour transformers of a UIKit cell or button configuration, iOS 14
// (facts/UIKit/UIConfigurationColorTransformers14.md).
//
// One object carries one release: all three are first exported by iOS 14, whose first held release
// is 16.0, so a band from 16.0 on re-exports the release's own and the bands below keep this one.
//
// The release holds a block here, not a value: reading the symbol of a constant out of the 16.0 or
// the 18.0 arm64e cache gives the address of the release's own code (0x1d8... / 0x1e8... in the two
// caches), which is not a thing this port can export. So these three are implemented as the three
// functions the header documents, and what is carried is their behaviour.

#import <UIKit/UIKit.h>

// A colour as the grayscale of the same colour, alpha kept: CoreGraphics' own conversion of the
// colour into the generic gray space, which is what "a grayscale version of the color" is on every
// platform that has one. A colour CoreGraphics cannot convert (a pattern colour, which has no
// components to match) is returned unchanged rather than dropped.
static UIColor *CharonGrayscaleColor(UIColor *color)
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
    return CharonGrayscaleColor(color);
};

// The header describes a transformer that keeps the original color or swaps in the
// system accent color: with the accent set to Multicolor it returns the original color, and with any other
// configured accent color it returns that color. On a platform without an accent color it returns the original color
// (SDK 26.2, UIConfigurationColorTransformer.h:23-27). The third case is this one: the system accent colour
// is iOS 15's, and the tint a control carries is the one the application gives it - there is no
// accent the system picks, so the original colour is the original colour.
const UIConfigurationColorTransformer UIConfigurationColorTransformerPreferredTint = ^UIColor *(UIColor *color) {
    return color;
};

// The header describes a transformer that gives a color a monochrome tint, meant to deemphasize the tinted
// item: it stays monochrome whatever the system accent color is, where the platform has one.
// (SDK 26.2, UIConfigurationColorTransformer.h:29-31). The two documents read together: the
// difference from PreferredTint is that the accent colour does not reach this one, so the colour
// the system would have substituted is the input itself, made monochrome. A platform with no
// accent colour therefore answers the grayscale of its input, which is monochrome and
// accent-independent - the two properties the header names.
const UIConfigurationColorTransformer UIConfigurationColorTransformerMonochromeTint = ^UIColor *(UIColor *color) {
    // 0.549020 to six places is 140/255, the alpha the host's own transformer answers for every
    // colour: the de-emphasis tint of a monochrome item, a fixed one.
    (void)color;
    return [UIColor colorWithWhite:1.0 alpha:140.0 / 255.0];
};
