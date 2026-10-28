#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

REVENANT_CASE(trait_style_default)
{
    UITraitCollection *unset = [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
    UITraitCollection *light = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight];
    UITraitCollection *dark = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];

    revenant_expect_true(@"an unset trait collection reads its user interface style as light",
                         (unset.userInterfaceStyle == UIUserInterfaceStyleLight) != (BOOL)negative,
                         [NSString stringWithFormat:@"%ld", (long)unset.userInterfaceStyle]);
    revenant_expect_true(@"an unset trait collection is not equal to one that sets light",
                         ([unset isEqual:light] == NO) != (BOOL)negative, @"");
    revenant_expect_true(@"merging two unset trait collections leaves the style unset",
                         ([[UITraitCollection traitCollectionWithTraitsFromCollections:@[unset, unset]] isEqual:unset]) != (BOOL)negative, @"");
    revenant_expect_true(@"merging an unset collection with a dark one takes the dark style",
                         ([UITraitCollection traitCollectionWithTraitsFromCollections:@[unset, dark]].userInterfaceStyle == UIUserInterfaceStyleDark) != (BOOL)negative, @"");
}
