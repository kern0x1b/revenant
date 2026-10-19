#import "CharonTraitStyle.h"
#import <objc/runtime.h>

static char charon_trait_style_key;

UIUserInterfaceStyle charon_trait_style(UITraitCollection *collection)
{
    NSNumber *held = objc_getAssociatedObject(collection, &charon_trait_style_key);
    return held ? (UIUserInterfaceStyle)held.integerValue : UIUserInterfaceStyleUnspecified;
}

void charon_set_trait_style(UITraitCollection *collection, UIUserInterfaceStyle style)
{
    if (!collection)
        return;
    objc_setAssociatedObject(collection, &charon_trait_style_key, style == UIUserInterfaceStyleUnspecified ? nil : @(style),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UITraitCollection (CharonUserInterfaceStyle)

+ (UITraitCollection *)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)userInterfaceStyle
{
    UITraitCollection *collection = [self traitCollectionWithTraitsFromCollections:@[]];
    charon_set_trait_style(collection, userInterfaceStyle);
    return collection;
}

- (UIUserInterfaceStyle)userInterfaceStyle
{
    return charon_trait_style(self);
}

@end
