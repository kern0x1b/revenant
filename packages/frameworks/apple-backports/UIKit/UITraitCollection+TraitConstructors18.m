#import <UIKit/UIKit.h>
#import "RevenantTraits17.h"

#if !__has_include(<UIKit/UITrait.h>)

@interface UITraitCollection (RevenantTraitConstructors18)
+ (UITraitCollection *)traitCollectionWithListEnvironment:(UIListEnvironment)listEnvironment;
@end

#endif

@implementation UITraitCollection (RevenantTraitConstructors18)

+ (UITraitCollection *)traitCollectionWithListEnvironment:(UIListEnvironment)listEnvironment
{
    return [self traitCollectionWithNSIntegerValue:(NSInteger)listEnvironment forTrait:[UITraitListEnvironment class]];
}

@end
