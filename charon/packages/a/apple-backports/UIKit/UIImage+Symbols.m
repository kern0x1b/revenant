#import "CharonSymbols.h"
#import <objc/runtime.h>
#import "CharonImageBaseline.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char charon_symbol_configuration_key;
static char charon_symbol_name_key;

static UITraitCollection *charon_screen_traits(void)
{
    return [UIScreen instancesRespondToSelector:@selector(traitCollection)] ? [UIScreen mainScreen].traitCollection : nil;
}

static UIImageSymbolConfiguration *charon_environment_configuration(UITraitCollection *extra)
{
    UITraitCollection *traits = charon_screen_traits();
    if (extra)
        traits = traits ? [UITraitCollection traitCollectionWithTraitsFromCollections:@[traits, extra]] : extra;
    return [[UIImageSymbolConfiguration unspecifiedConfiguration] configurationWithTraitCollection:traits];
}

static UIImage *charon_symbol_image(NSString *name, UIImageSymbolConfiguration *configuration)
{
    if (!charon_symbol_known(name)) {
        if ([name isKindOfClass:[NSString class]] && name.length)
            charon_menus_say_once(@"symbol", [NSString stringWithFormat:@"UIImage: no drawing for the symbol \"%@\": +systemImageNamed: answers nil for it and for every other name that has none.", name]);
        return nil;
    }
    double pointSize = [configuration charon_symbolPointSize];
    NSInteger weight = [configuration charon_symbolWeight], scale = [configuration charon_symbolScale];
    CGFloat displayScale = configuration.traitCollection.displayScale;
    if (displayScale <= 0)
        displayScale = [UIScreen mainScreen].scale;
    CGSize size;
    UIEdgeInsets insets;
    CGFloat baseline;
    UIImage *drawn = charon_symbol_bitmap(name, pointSize, weight, scale, displayScale);
    if (!drawn || !charon_symbol_metrics(name, pointSize, weight, scale, &size, &insets, &baseline))
        return nil;
    UIImage *image = [drawn imageWithAlignmentRectInsets:insets];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    objc_setAssociatedObject(image, &charon_symbol_name_key, name, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(image, &charon_symbol_configuration_key, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_set_image_baseline(image, @(baseline));
    return image;
}

static UIImage *charon_image_with_configuration(UIImage *image, UIImageSymbolConfiguration *configuration)
{
    UIImage *copy = nil;
    if (image.images.count)
        copy = [UIImage animatedImageWithImages:image.images duration:image.duration];
    else if (image.CGImage)
        copy = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
    else if (image.CIImage)
        copy = [UIImage imageWithCIImage:image.CIImage scale:image.scale orientation:image.imageOrientation];
    if (!copy)
        copy = [[UIImage alloc] init];
    UIEdgeInsets capInsets = image.capInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero))
        copy = [copy resizableImageWithCapInsets:capInsets resizingMode:image.resizingMode];
    UIEdgeInsets alignmentInsets = image.alignmentRectInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(alignmentInsets, UIEdgeInsetsZero))
        copy = [copy imageWithAlignmentRectInsets:alignmentInsets];
    if (image.renderingMode != UIImageRenderingModeAutomatic)
        copy = [copy imageWithRenderingMode:image.renderingMode];
    if (configuration)
        objc_setAssociatedObject(copy, &charon_symbol_configuration_key, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return copy;
}

@implementation UIImage (CharonSymbols)

+ (UIImage *)systemImageNamed:(NSString *)name
{
    return charon_symbol_image(name, charon_environment_configuration(nil));
}

+ (UIImage *)systemImageNamed:(NSString *)name compatibleWithTraitCollection:(UITraitCollection *)traitCollection
{
    return charon_symbol_image(name, charon_environment_configuration(traitCollection));
}

+ (UIImage *)systemImageNamed:(NSString *)name withConfiguration:(UIImageConfiguration *)configuration
{
    UIImageSymbolConfiguration *effective = [charon_environment_configuration(nil) configurationByApplyingConfiguration:configuration];
    return charon_symbol_image(name, effective);
}

- (BOOL)isSymbolImage
{
    return objc_getAssociatedObject(self, &charon_symbol_name_key) != nil;
}

- (UIImageSymbolConfiguration *)symbolConfiguration
{
    return objc_getAssociatedObject(self, &charon_symbol_configuration_key);
}

- (UIImage *)imageByApplyingSymbolConfiguration:(UIImageSymbolConfiguration *)configuration
{
    UIImageSymbolConfiguration *current = self.symbolConfiguration;
    if (!configuration)
        return current ? self : charon_image_with_configuration(self, nil);
    if (!current)
        current = charon_environment_configuration(nil);
    UIImageSymbolConfiguration *merged = [current configurationByApplyingConfiguration:configuration];
    NSString *name = objc_getAssociatedObject(self, &charon_symbol_name_key);
    if (name)
        return charon_symbol_image(name, merged) ?: self;
    return charon_image_with_configuration(self, merged);
}

@end
