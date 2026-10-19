// The four trait classes of iOS 26, in a file of their own because an object carries the API of exactly one
// release and these arrived in 26.0 while the other eighteen did not. What a trait class is, and what every one
// of them says about itself, is in UITrait17.m and in facts/UIKit/UITrait17.md, M1; the table the definitions go
// into, and the lookups over it, are in UITraitCollection+Traits17.m.
//
// Three of the four are traits this release has no hardware and no system for, and they say so by their
// unspecified value: a scene is never being recorded, so the capture state is unspecified; a device with no
// headroom reporting and no HDR screen has no headroom limit to use; and no view here is in a tab accessory. The
// fourth says whether natural alignment resolves from the base writing direction, which on this release it does
// not, because the writing direction of a view is the one the user's language gives.

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
