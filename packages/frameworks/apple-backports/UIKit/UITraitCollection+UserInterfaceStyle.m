#import "RevenantTraitStyle.h"
#import <objc/runtime.h>

static char revenant_trait_style_key;

UIUserInterfaceStyle revenant_trait_style(UITraitCollection *collection)
{
    NSNumber *held = objc_getAssociatedObject(collection, &revenant_trait_style_key);
    return held ? (UIUserInterfaceStyle)held.integerValue : UIUserInterfaceStyleUnspecified;
}

void revenant_set_trait_style(UITraitCollection *collection, UIUserInterfaceStyle style)
{
    if (!collection)
        return;
    objc_setAssociatedObject(collection, &revenant_trait_style_key, style == UIUserInterfaceStyleUnspecified ? nil : @(style),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UITraitCollection (RevenantUserInterfaceStyle)

+ (UITraitCollection *)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)userInterfaceStyle
{
    UITraitCollection *collection = [self traitCollectionWithTraitsFromCollections:@[]];
    revenant_set_trait_style(collection, userInterfaceStyle);
    return collection;
}

- (UIUserInterfaceStyle)userInterfaceStyle
{
    return revenant_trait_style(self);
}

@end
