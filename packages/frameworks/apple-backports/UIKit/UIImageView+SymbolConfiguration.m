#import "RevenantSymbols.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char revenant_preferred_symbol_configuration_key;
static char revenant_original_symbol_image_key;

static UIImage *revenant_preferred_image(UIImageView *view, UIImage *image)
{
    UIImageSymbolConfiguration *preferred = objc_getAssociatedObject(view, &revenant_preferred_symbol_configuration_key);
    if (!preferred || !image.isSymbolImage) {
        objc_setAssociatedObject(view, &revenant_original_symbol_image_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return image;
    }
    objc_setAssociatedObject(view, &revenant_original_symbol_image_key, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return [image imageByApplyingSymbolConfiguration:[preferred configurationByApplyingConfiguration:image.symbolConfiguration]];
}

@implementation UIImageView (RevenantSymbolConfiguration)

+ (void)load
{
    if (objc_getClass("UIImageSymbolConfiguration") != [UIImageSymbolConfiguration class])
        return;
    Method method = class_getInstanceMethod(self, @selector(setImage:));
    IMP original = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^(UIImageView *view, UIImage *image) {
        ((void (*)(id, SEL, id))original)(view, @selector(setImage:), revenant_preferred_image(view, image));
    }));
}

- (UIImageSymbolConfiguration *)preferredSymbolConfiguration
{
    return objc_getAssociatedObject(self, &revenant_preferred_symbol_configuration_key);
}

- (void)setPreferredSymbolConfiguration:(UIImageSymbolConfiguration *)preferredSymbolConfiguration
{
    UIImageSymbolConfiguration *current = self.preferredSymbolConfiguration;
    if (preferredSymbolConfiguration == current || [preferredSymbolConfiguration isEqual:current])
        return;
    objc_setAssociatedObject(self, &revenant_preferred_symbol_configuration_key, preferredSymbolConfiguration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIImage *original = objc_getAssociatedObject(self, &revenant_original_symbol_image_key) ?: self.image;
    if (original.isSymbolImage)
        self.image = original;
}

@end
