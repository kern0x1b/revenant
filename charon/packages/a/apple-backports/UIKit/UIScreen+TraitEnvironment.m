#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITraitCollection (CharonTraitEnvironment)
+ (UITraitCollection *)charon_traitCollectionForScreen:(UIScreen *)screen;
@end

@interface UIScreen (CharonTraitEnvironment) <UITraitEnvironment>
@end

@implementation UIScreen (CharonTraitEnvironment)

- (UITraitCollection *)traitCollection
{
    return [UITraitCollection charon_traitCollectionForScreen:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
}

@end
