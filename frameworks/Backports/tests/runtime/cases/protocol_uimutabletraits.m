#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

REVENANT_CASE(protocol_uimutabletraits)
{
    NSArray *names = @[@"userInterfaceIdiom", @"userInterfaceStyle", @"layoutDirection", @"horizontalSizeClass",
                       @"verticalSizeClass", @"forceTouchCapability", @"displayGamut", @"accessibilityContrast",
                       @"userInterfaceLevel", @"legibilityWeight", @"activeAppearance", @"toolbarItemPresentationSize",
                       @"imageDynamicRange", @"sceneCaptureState", @"listEnvironment", @"tabAccessoryEnvironment",
                       @"splitViewControllerLayoutEnvironment"];
    __block BOOL conforms = NO;
    __block NSString *missing = nil;
    __block UIUserInterfaceIdiom idiom = UIUserInterfaceIdiomUnspecified;
    UITraitCollection *collection = [UITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
        conforms = [traits conformsToProtocol:@protocol(UIMutableTraits)];
        for (NSString *name in names) {
            NSString *setter = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
            if (![traits respondsToSelector:NSSelectorFromString(name)] || ![traits respondsToSelector:NSSelectorFromString(setter)]) {
                missing = name;
                return;
            }
        }
        traits.userInterfaceIdiom = UIUserInterfaceIdiomPad;
        idiom = traits.userInterfaceIdiom;
    }];
    revenant_expect_true(@"the object a trait mutations block receives conforms to UIMutableTraits",
                         conforms != (BOOL)negative, @"");
    revenant_expect_true(@"the trait mutations object responds to all 17 UIMutableTraits getters and setters",
                         (missing == nil) != (BOOL)negative, missing ?: @"");
    revenant_expect_true(@"a value set through the mutations object reaches the collection it builds",
                         (idiom == UIUserInterfaceIdiomPad && collection.userInterfaceIdiom == UIUserInterfaceIdiomPad) != (BOOL)negative,
                         [NSString stringWithFormat:@"%ld", (long)idiom]);
}
