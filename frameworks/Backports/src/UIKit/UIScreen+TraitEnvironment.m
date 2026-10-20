#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITraitCollection (RevenantTraitEnvironment)
+ (UITraitCollection *)revenant_traitCollectionForScreen:(UIScreen *)screen;
@end

@interface UIScreen (RevenantTraitEnvironment) <UITraitEnvironment>
@end

@implementation UIScreen (RevenantTraitEnvironment)

- (UITraitCollection *)traitCollection
{
    return [UITraitCollection revenant_traitCollectionForScreen:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
}

@end
