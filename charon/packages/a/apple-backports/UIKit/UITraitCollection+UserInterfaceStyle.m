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
    // Unspecified is the value a collection that says nothing for the style answers, so setting it takes the
    // value away rather than storing it: a caller that passes it means the collection has no style of its own,
    // which is what -removeTrait: on a trait overrides object needs and what the older constructors that pass a
    // caller's Unspecified have always meant.
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
