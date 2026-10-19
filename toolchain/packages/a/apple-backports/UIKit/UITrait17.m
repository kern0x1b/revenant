#import "CharonTraits17.h"
#import "CharonTraitStyle.h"

#define CHARON_TRAIT(Index, ClassName, StoredName, ValueKind, Home, Default, Appearance)                                                 \
    static CharonTraitDefinition charon_held_##ClassName;                                                                               \
    static void charon_define_##ClassName(void)                                                                                        \
    {                                                                                                                                   \
        charon_held_##ClassName.trait = [ClassName class];                                                                             \
        charon_held_##ClassName.name = StoredName;                                                                                     \
        charon_held_##ClassName.kind = ValueKind;                                                                                      \
        charon_held_##ClassName.home = Home;                                                                                           \
        charon_held_##ClassName.defaultValue = Default;                                                                                \
        charon_held_##ClassName.affectsColorAppearance = Appearance;                                                                   \
        charon_register_trait_definition(Index, &charon_held_##ClassName);                                                             \
    }

CHARON_TRAIT(0, UITraitUserInterfaceIdiom, @"UserInterfaceIdiom", CharonTraitValueNSInteger, CharonTraitHomeIvar, @(-1), YES)
CHARON_TRAIT(1, UITraitUserInterfaceStyle, @"UserInterfaceStyle", CharonTraitValueNSInteger, CharonTraitHomeStyle, @(0), YES)
CHARON_TRAIT(2, UITraitLayoutDirection, @"UserInterfaceLayoutDirection", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), NO)
CHARON_TRAIT(3, UITraitDisplayScale, @"DisplayScale", CharonTraitValueCGFloat, CharonTraitHomeIvar, @(0), NO)
CHARON_TRAIT(4, UITraitHorizontalSizeClass, @"HorizontalSizeClass", CharonTraitValueNSInteger, CharonTraitHomeIvar, @(0), NO)
CHARON_TRAIT(5, UITraitVerticalSizeClass, @"VerticalSizeClass", CharonTraitValueNSInteger, CharonTraitHomeIvar, @(0), NO)
CHARON_TRAIT(6, UITraitForceTouchCapability, @"ForceTouchCapability", CharonTraitValueNSInteger, CharonTraitHomeForceTouch, @(0), NO)
CHARON_TRAIT(7, UITraitPreferredContentSizeCategory, @"PreferredContentSizeCategory", CharonTraitValueObject, CharonTraitHomeExtras,
             UIContentSizeCategoryUnspecified, NO)
CHARON_TRAIT(8, UITraitDisplayGamut, @"DisplayGamut", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), YES)
CHARON_TRAIT(9, UITraitAccessibilityContrast, @"AccessibilityContrast", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), YES)
CHARON_TRAIT(10, UITraitUserInterfaceLevel, @"UserInterfaceLevel", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), YES)
CHARON_TRAIT(11, UITraitLegibilityWeight, @"LegibilityWeight", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), NO)
CHARON_TRAIT(12, UITraitActiveAppearance, @"ActiveAppearance", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), YES)
CHARON_TRAIT(13, UITraitToolbarItemPresentationSize, @"ToolbarItemPresentationSize", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), NO)
CHARON_TRAIT(14, UITraitImageDynamicRange, @"ImageDynamicRange", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), NO)
CHARON_TRAIT(15, UITraitTypesettingLanguage, @"TypesettingLanguage", CharonTraitValueObject, CharonTraitHomeExtras, nil, NO)
CHARON_TRAIT(16, UITraitSceneCaptureState, @"SceneCaptureState", CharonTraitValueNSInteger, CharonTraitHomeExtras, @(-1), NO)

@interface CharonTraitDefinitions17 : NSObject
@end

@implementation CharonTraitDefinitions17

+ (void)load
{
    charon_define_UITraitUserInterfaceIdiom();
    charon_define_UITraitUserInterfaceStyle();
    charon_define_UITraitLayoutDirection();
    charon_define_UITraitDisplayScale();
    charon_define_UITraitHorizontalSizeClass();
    charon_define_UITraitVerticalSizeClass();
    charon_define_UITraitForceTouchCapability();
    charon_define_UITraitPreferredContentSizeCategory();
    charon_define_UITraitDisplayGamut();
    charon_define_UITraitAccessibilityContrast();
    charon_define_UITraitUserInterfaceLevel();
    charon_define_UITraitLegibilityWeight();
    charon_define_UITraitActiveAppearance();
    charon_define_UITraitToolbarItemPresentationSize();
    charon_define_UITraitImageDynamicRange();
    charon_define_UITraitTypesettingLanguage();
    charon_define_UITraitSceneCaptureState();

    charon_register_trait_kind((CharonTraitKind){@"ImageDynamicRange", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"SceneCaptureState", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"HDRHeadroomUsageLimit", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"ListEnvironment", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"TabAccessoryEnvironment", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"SplitViewControllerLayoutEnvironment", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"ToolbarItemPresentationSize", 0, 2, @"Regular,Small,,Large", nil});
    charon_register_trait_kind((CharonTraitKind){@"ForceTouchCapability", 0, 2, @"Unknown,Unavailable,Available", nil});
    charon_register_trait_kind((CharonTraitKind){@"TypesettingLanguage", 0, 3, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"ResolvesNaturalAlignmentWithBaseWritingDirection", 0, 3, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"PreferredContentSizeCategory", 0, 2,
                                                   @"XS,S,M,L,XL,XXL,XXXL,AccessibilityM,AccessibilityL,AccessibilityXL,"
                                                   @"AccessibilityXXL,AccessibilityXXXL", nil});
    charon_add_trait_value_reader(charon_read_trait_value);
}


@end

@implementation UITraitUserInterfaceIdiom
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitUserInterfaceStyle
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitLayoutDirection
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitDisplayScale
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (CGFloat)defaultValue { return charon_cgfloat_default_of(self); }
@end

@implementation UITraitHorizontalSizeClass
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitVerticalSizeClass
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitForceTouchCapability
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitPreferredContentSizeCategory
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (id)defaultValue { return charon_object_default_of(self); }
@end

@implementation UITraitDisplayGamut
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitAccessibilityContrast
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitUserInterfaceLevel
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitLegibilityWeight
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitActiveAppearance
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitToolbarItemPresentationSize
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitImageDynamicRange
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end

@implementation UITraitTypesettingLanguage
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (id)defaultValue { return charon_object_default_of(self); }
@end

@implementation UITraitSceneCaptureState
+ (NSString *)identifier { return charon_identifier_of(self); }
+ (NSString *)name { return charon_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return charon_appearance_of(self); }
+ (NSInteger)defaultValue { return charon_integer_default_of(self); }
@end
