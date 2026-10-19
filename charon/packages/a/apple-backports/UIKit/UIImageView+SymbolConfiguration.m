#import "CharonSymbols.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char charon_preferred_symbol_configuration_key;
static char charon_original_symbol_image_key;

// A symbol image on a view that has a preferred configuration is drawn again with the image's own configuration over it.
static UIImage *charon_preferred_image(UIImageView *view, UIImage *image)
{
    UIImageSymbolConfiguration *preferred = objc_getAssociatedObject(view, &charon_preferred_symbol_configuration_key);
    if (!preferred || !image.isSymbolImage) {
        objc_setAssociatedObject(view, &charon_original_symbol_image_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return image;
    }
    objc_setAssociatedObject(view, &charon_original_symbol_image_key, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return [image imageByApplyingSymbolConfiguration:[preferred configurationByApplyingConfiguration:image.symbolConfiguration]];
}

@implementation UIImageView (CharonSymbolConfiguration)

+ (void)load
{
    if (objc_getClass("UIImageSymbolConfiguration") != [UIImageSymbolConfiguration class])
        return;
    Method method = class_getInstanceMethod(self, @selector(setImage:));
    IMP original = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^(UIImageView *view, UIImage *image) {
        ((void (*)(id, SEL, id))original)(view, @selector(setImage:), charon_preferred_image(view, image));
    }));
}

- (UIImageSymbolConfiguration *)preferredSymbolConfiguration
{
    return objc_getAssociatedObject(self, &charon_preferred_symbol_configuration_key);
}

- (void)setPreferredSymbolConfiguration:(UIImageSymbolConfiguration *)preferredSymbolConfiguration
{
    UIImageSymbolConfiguration *current = self.preferredSymbolConfiguration;
    if (preferredSymbolConfiguration == current || [preferredSymbolConfiguration isEqual:current])
        return;
    objc_setAssociatedObject(self, &charon_preferred_symbol_configuration_key, preferredSymbolConfiguration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIImage *original = objc_getAssociatedObject(self, &charon_original_symbol_image_key) ?: self.image;
    if (original.isSymbolImage)
        self.image = original;
}

@end
