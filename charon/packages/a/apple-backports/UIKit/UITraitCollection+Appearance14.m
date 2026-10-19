#import "CharonTraitStyle.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static NSString *const CharonActiveAppearance = @"ActiveAppearance";

@interface CharonTraitKinds14 : NSObject
@end

@implementation CharonTraitKinds14

+ (void)load
{
    charon_register_trait_kind((CharonTraitKind){CharonActiveAppearance, 1, NO, @"Inactive", @"Active"});
}

@end

@implementation UITraitCollection (CharonAppearance14)

+ (UITraitCollection *)traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)userInterfaceActiveAppearance
{
    UITraitCollection *collection = [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
    charon_set_trait_extra(collection, CharonActiveAppearance, userInterfaceActiveAppearance);
    return collection;
}

- (UIUserInterfaceActiveAppearance)activeAppearance
{
    return (UIUserInterfaceActiveAppearance)charon_trait_extra(self, CharonActiveAppearance);
}

@end
