#import <UIKit/UIKit.h>
#import "CharonTraits17.h"

#if !__has_include(<UIKit/UITrait.h>)

@interface UITraitCollection (CharonTraitConstructors18)
+ (UITraitCollection *)traitCollectionWithListEnvironment:(UIListEnvironment)listEnvironment;
@end

#endif

@implementation UITraitCollection (CharonTraitConstructors18)

+ (UITraitCollection *)traitCollectionWithListEnvironment:(UIListEnvironment)listEnvironment
{
    return [self traitCollectionWithNSIntegerValue:(NSInteger)listEnvironment forTrait:[UITraitListEnvironment class]];
}

@end
