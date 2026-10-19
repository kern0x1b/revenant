#import <UIKit/UIKit.h>
#import "CharonTraits17.h"

#if !__has_include(<UIKit/UITrait.h>)

@interface UITraitCollection (CharonTraitConstructors17)
+ (UITraitCollection *)traitCollectionWithImageDynamicRange:(UIImageDynamicRange)imageDynamicRange;
+ (UITraitCollection *)traitCollectionWithSceneCaptureState:(UISceneCaptureState)sceneCaptureState;
+ (UITraitCollection *)traitCollectionWithTypesettingLanguage:(NSString *)typesettingLanguage;
@end

#endif

@implementation UITraitCollection (CharonTraitConstructors17)

+ (UITraitCollection *)traitCollectionWithImageDynamicRange:(UIImageDynamicRange)imageDynamicRange
{
    return [self traitCollectionWithNSIntegerValue:imageDynamicRange forTrait:[UITraitImageDynamicRange class]];
}

+ (UITraitCollection *)traitCollectionWithSceneCaptureState:(UISceneCaptureState)sceneCaptureState
{
    return [self traitCollectionWithNSIntegerValue:sceneCaptureState forTrait:[UITraitSceneCaptureState class]];
}

+ (UITraitCollection *)traitCollectionWithTypesettingLanguage:(NSString *)typesettingLanguage
{
    return [self traitCollectionWithObject:typesettingLanguage forTrait:[UITraitTypesettingLanguage class]];
}

@end
