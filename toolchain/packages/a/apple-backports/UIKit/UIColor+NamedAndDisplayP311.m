#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation UIColor (CharonDisplayP311)

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
    *outR = CharonDelinearise( 1.2249401f * lr - 0.2249401f * lg + 0.0000000f * lb);
    *outG = CharonDelinearise(-0.0420570f * lr + 1.0420570f * lg + 0.0000000f * lb);
    *outB = CharonDelinearise(-0.0196376f * lr - 0.0786360f * lg + 1.0982736f * lb);
}

+ (UIColor *)colorWithDisplayP3Red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    CGFloat r = 0, g = 0, b = 0;
    CharonDisplayP3ToSRGB(red, green, blue, &r, &g, &b);
    return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
}

- (UIColor *)initWithDisplayP3Red:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha
{
    CGFloat r = 0, g = 0, b = 0;
    CharonDisplayP3ToSRGB(red, green, blue, &r, &g, &b);
    return [self initWithRed:r green:g blue:b alpha:alpha];
}

+ (UIColor *)colorNamed:(NSString *)name
{
    if (![name isKindOfClass:[NSString class]] || !name.length)
        return nil;
    return [self colorNamed:name inBundle:[NSBundle mainBundle] compatibleWithTraitCollection:nil];
}

+ (UIColor *)colorNamed:(NSString *)name
               inBundle:(NSBundle *)bundle
compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    if (![name isKindOfClass:[NSString class]] || !name.length || !bundle)
        return nil;
    UIImage *image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:traitCollection];
    if (!image)
        return nil;
    CGImageRef cgImage = image.CGImage;
    if (!cgImage)
        return nil;
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    if (!data)
        return nil;
    const UInt8 *bytes = CFDataGetBytePtr(data);
    size_t length = CFDataGetLength(data);
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
