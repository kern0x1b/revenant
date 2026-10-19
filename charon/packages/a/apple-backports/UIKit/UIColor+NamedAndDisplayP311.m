#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

// A colour built from display-P3 components, and a colour looked up by name.
//
// The display-P3 conversion is the matrix Core Graphics itself documents, and it is checked against
// the host's own answer in tests/backports/host/uikitadditions: display-P3 (0.5, 0.25, 0.75, 0.8)
// comes back as sRGB (0.5378, 0.2321, 0.7770, 0.8), which is what these lines compute.
//
// A named colour is looked for in the bundle the caller names, and a name that is not in it has no
// colour: the host answers nil, and so does this.

@implementation UIColor (CharonDisplayP311)

// sRGB from display-P3, and back. The primaries differ and the transfer function does not, so the
// conversion is linearise, matrix, re-apply the transfer function -- the two steps a wide-gamut
// colour needs and an 8-bit-per-channel sRGB colour on this device cannot carry.
static CGFloat CharonLinearise(CGFloat component)
{
    return component <= 0.04045f ? component / 12.92f : powf((component + 0.055f) / 1.055f, 2.4f);
}

static CGFloat CharonDelinearise(CGFloat component)
{
    if (component <= 0.0031308f)
        return 12.92f * component;
    return 1.055f * powf(component, 1.0f / 2.4f) - 0.055f;
}

static void CharonDisplayP3ToSRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat *outR, CGFloat *outG, CGFloat *outB)
{
    CGFloat lr = CharonLinearise(r), lg = CharonLinearise(g), lb = CharonLinearise(b);
    // The sRGB primaries expressed in display-P3: the matrix of the two spaces against each other.
    // It is checked against the host's own answer rather than trusted, because a matrix typed from
    // memory is exactly the kind of thing that is nearly right.
    *outR = CharonDelinearise( 1.2249401f * lr - 0.2249401f * lg + 0.0000000f * lb);
    *outG = CharonDelinearise(-0.0420570f * lr + 1.0420570f * lg + 0.0000000f * lb);
    *outB = CharonDelinearise(-0.0196376f * lr - 0.0786360f * lg + 1.0982736f * lb);
}

// The colour a display-P3 triple means on this device's display, which is sRGB.
+ (UIColor *)colorWithDisplayP3Red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    CGFloat r = 0, g = 0, b = 0;
    CharonDisplayP3ToSRGB(red, green, blue, &r, &g, &b);
    return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
}

// The initialiser is the factory: a colour is immutable, so the receiver is replaced by the sRGB
// colour the components mean on this display, which is what the host answers for both spellings.
- (UIColor *)initWithDisplayP3Red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    CGFloat r = 0, g = 0, b = 0;
    CharonDisplayP3ToSRGB(red, green, blue, &r, &g, &b);
    return [self initWithRed:r green:g blue:b alpha:alpha];
}

// A colour by name, looked for in the main bundle.
+ (UIColor *)colorNamed:(NSString *)name
{
    if (![name isKindOfClass:[NSString class]] || !name.length)
        return nil;
    return [self colorNamed:name inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
}

// A colour by name, looked for in the bundle named and read for the traits named. The asset
// catalogue is where the name lives; the tree keeps the compiled one as loose files, so the lookup is
// through the bundle's own catalogue and there is nothing to invent when the name is not in it.
+ (UIColor *)colorNamed:(NSString *)name
               inBundle:(NSBundle *)bundle
compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    if (![name isKindOfClass:[NSString class]] || !name.length || !bundle)
        return nil;
    UIImage *image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:traitCollection];
    if (!image)
        return nil;
    // An asset catalogue's colour set is an image whose name is the colour's; its first pixel is the
    // colour itself, which is what a one-colour set holds.
    CGImageRef cgImage = image.CGImage;
    if (!cgImage)
        return nil;
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    if (!data)
        return nil;
    const UInt8 *bytes = CFDataGetBytePtr(data);
    size_t length = CFDataGetLength(data);
    // Any image that is not at least four bytes per pixel has no colour to read.
    if (length < 4) {
        CFRelease(data);
        return nil;
    }
    CGFloat alpha = bytes[3] / 255.0f;
    CGFloat r = bytes[0] / 255.0f, g = bytes[1] / 255.0f, b = bytes[2] / 255.0f;
    CFRelease(data);
    return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
}

@end
