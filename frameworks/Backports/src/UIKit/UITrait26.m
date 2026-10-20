#import "RevenantTraits17.h"

REVENANT_TRAIT(18, UITraitHDRHeadroomUsageLimit, @"HDRHeadroomUsageLimit", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), NO)
REVENANT_TRAIT(19, UITraitResolvesNaturalAlignmentWithBaseWritingDirection, @"ResolvesNaturalAlignmentWithBaseWritingDirection",
             RevenantTraitValueObject, RevenantTraitHomeExtras, nil, NO)
REVENANT_TRAIT(20, UITraitTabAccessoryEnvironment, @"TabAccessoryEnvironment", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(0), NO)
REVENANT_TRAIT(21, UITraitSplitViewControllerLayoutEnvironment, @"SplitViewControllerLayoutEnvironment", RevenantTraitValueNSInteger,
             RevenantTraitHomeExtras, @(0), NO)

@interface RevenantTraitClasses26 : NSObject
@end

@implementation RevenantTraitClasses26

+ (void)load
{
    revenant_define_UITraitHDRHeadroomUsageLimit();
    revenant_define_UITraitResolvesNaturalAlignmentWithBaseWritingDirection();
    revenant_define_UITraitTabAccessoryEnvironment();
    revenant_define_UITraitSplitViewControllerLayoutEnvironment();
}

@end

@implementation UITraitHDRHeadroomUsageLimit

+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }

@end

@implementation UITraitResolvesNaturalAlignmentWithBaseWritingDirection

+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (id)defaultValue { return revenant_object_default_of(self); }

@end

@implementation UITraitTabAccessoryEnvironment

+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }

@end

@implementation UITraitSplitViewControllerLayoutEnvironment

+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }

@end
