#import "CharonTraits17.h"

CHARON_TRAIT(18, UITraitHDRHeadroomUsageLimit, @"HDRHeadroomUsageLimit", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), NO)
CHARON_TRAIT(19, UITraitResolvesNaturalAlignmentWithBaseWritingDirection, @"ResolvesNaturalAlignmentWithBaseWritingDirection",
             CharonTraitValueObject, CharonTraitHomeExtras, nil, NO)
CHARON_TRAIT(20, UITraitTabAccessoryEnvironment, @"TabAccessoryEnvironment", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(0), NO)
CHARON_TRAIT(21, UITraitSplitViewControllerLayoutEnvironment, @"SplitViewControllerLayoutEnvironment", CharonTraitValueNSInteger,
             CharonTraitHomeExtras, @(0), NO)

@interface CharonTraitClasses26 : NSObject
@end

@implementation CharonTraitClasses26

+ (void)load
{
    charon_define_UITraitHDRHeadroomUsageLimit();
    charon_define_UITraitResolvesNaturalAlignmentWithBaseWritingDirection();
    charon_define_UITraitTabAccessoryEnvironment();
    charon_define_UITraitSplitViewControllerLayoutEnvironment();
}

@end

@implementation UITraitHDRHeadroomUsageLimit

+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }

@end

@implementation UITraitResolvesNaturalAlignmentWithBaseWritingDirection

+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (id)defaultValue { return charon_object_default_of(self); }

@end

@implementation UITraitTabAccessoryEnvironment

+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }

@end

@implementation UITraitSplitViewControllerLayoutEnvironment

+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }

@end
