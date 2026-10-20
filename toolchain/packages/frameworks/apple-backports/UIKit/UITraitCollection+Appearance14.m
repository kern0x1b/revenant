#import "RevenantTraitStyle.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static NSString *const RevenantActiveAppearance = @"ActiveAppearance";

@interface RevenantTraitKinds14 : NSObject
@end

@implementation RevenantTraitKinds14

+ (void)load
{
    revenant_register_trait_kind((RevenantTraitKind){RevenantActiveAppearance, 1, NO, @"Inactive", @"Active"});
}

@end

@implementation UITraitCollection (RevenantAppearance14)

+ (UITraitCollection *)traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)userInterfaceActiveAppearance
{
    UITraitCollection *collection = [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
    revenant_set_trait_extra(collection, RevenantActiveAppearance, userInterfaceActiveAppearance);
    return collection;
}

- (UIUserInterfaceActiveAppearance)activeAppearance
{
    return (UIUserInterfaceActiveAppearance)revenant_trait_extra(self, RevenantActiveAppearance);
}

@end
