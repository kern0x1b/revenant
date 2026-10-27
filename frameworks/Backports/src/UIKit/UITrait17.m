#import "RevenantTraits17.h"
#import "RevenantTraitStyle.h"

#define REVENANT_TRAIT(Index, ClassName, StoredName, ValueKind, Home, Default, Appearance)                                                 \
    static RevenantTraitDefinition revenant_held_##ClassName;                                                                               \
    static void revenant_define_##ClassName(void)                                                                                        \
    {                                                                                                                                   \
        revenant_held_##ClassName.trait = [ClassName class];                                                                             \
        revenant_held_##ClassName.name = StoredName;                                                                                     \
        revenant_held_##ClassName.kind = ValueKind;                                                                                      \
        revenant_held_##ClassName.home = Home;                                                                                           \
        revenant_held_##ClassName.defaultValue = Default;                                                                                \
        revenant_held_##ClassName.affectsColorAppearance = Appearance;                                                                   \
        revenant_register_trait_definition(Index, &revenant_held_##ClassName);                                                             \
    }

REVENANT_TRAIT(0, UITraitUserInterfaceIdiom, @"UserInterfaceIdiom", RevenantTraitValueNSInteger, RevenantTraitHomeIvar, @(-1), YES)
REVENANT_TRAIT(1, UITraitUserInterfaceStyle, @"UserInterfaceStyle", RevenantTraitValueNSInteger, RevenantTraitHomeStyle, @(UIUserInterfaceStyleLight), YES)
REVENANT_TRAIT(2, UITraitLayoutDirection, @"UserInterfaceLayoutDirection", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), NO)
REVENANT_TRAIT(3, UITraitDisplayScale, @"DisplayScale", RevenantTraitValueCGFloat, RevenantTraitHomeIvar, @(0), NO)
REVENANT_TRAIT(4, UITraitHorizontalSizeClass, @"HorizontalSizeClass", RevenantTraitValueNSInteger, RevenantTraitHomeIvar, @(0), NO)
REVENANT_TRAIT(5, UITraitVerticalSizeClass, @"VerticalSizeClass", RevenantTraitValueNSInteger, RevenantTraitHomeIvar, @(0), NO)
REVENANT_TRAIT(6, UITraitForceTouchCapability, @"ForceTouchCapability", RevenantTraitValueNSInteger, RevenantTraitHomeForceTouch, @(0), NO)
REVENANT_TRAIT(7, UITraitPreferredContentSizeCategory, @"PreferredContentSizeCategory", RevenantTraitValueObject, RevenantTraitHomeExtras,
             UIContentSizeCategoryUnspecified, NO)
REVENANT_TRAIT(8, UITraitDisplayGamut, @"DisplayGamut", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), YES)
REVENANT_TRAIT(9, UITraitAccessibilityContrast, @"AccessibilityContrast", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), YES)
REVENANT_TRAIT(10, UITraitUserInterfaceLevel, @"UserInterfaceLevel", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), YES)
REVENANT_TRAIT(11, UITraitLegibilityWeight, @"LegibilityWeight", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), NO)
REVENANT_TRAIT(12, UITraitActiveAppearance, @"ActiveAppearance", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), YES)
REVENANT_TRAIT(13, UITraitToolbarItemPresentationSize, @"ToolbarItemPresentationSize", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), NO)
REVENANT_TRAIT(14, UITraitImageDynamicRange, @"ImageDynamicRange", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), NO)
REVENANT_TRAIT(15, UITraitTypesettingLanguage, @"TypesettingLanguage", RevenantTraitValueObject, RevenantTraitHomeExtras, nil, NO)
REVENANT_TRAIT(16, UITraitSceneCaptureState, @"SceneCaptureState", RevenantTraitValueNSInteger, RevenantTraitHomeExtras, @(-1), NO)

@interface RevenantTraitDefinitions17 : NSObject
@end

@implementation RevenantTraitDefinitions17

+ (void)load
{
    revenant_define_UITraitUserInterfaceIdiom();
    revenant_define_UITraitUserInterfaceStyle();
    revenant_define_UITraitLayoutDirection();
    revenant_define_UITraitDisplayScale();
    revenant_define_UITraitHorizontalSizeClass();
    revenant_define_UITraitVerticalSizeClass();
    revenant_define_UITraitForceTouchCapability();
    revenant_define_UITraitPreferredContentSizeCategory();
    revenant_define_UITraitDisplayGamut();
    revenant_define_UITraitAccessibilityContrast();
    revenant_define_UITraitUserInterfaceLevel();
    revenant_define_UITraitLegibilityWeight();
    revenant_define_UITraitActiveAppearance();
    revenant_define_UITraitToolbarItemPresentationSize();
    revenant_define_UITraitImageDynamicRange();
    revenant_define_UITraitTypesettingLanguage();
    revenant_define_UITraitSceneCaptureState();

    revenant_register_trait_kind((RevenantTraitKind){@"ImageDynamicRange", 0, 2, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"SceneCaptureState", 0, 2, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"HDRHeadroomUsageLimit", 0, 2, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"ListEnvironment", 0, 2, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"TabAccessoryEnvironment", 0, 2, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"SplitViewControllerLayoutEnvironment", 0, 2, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"ToolbarItemPresentationSize", 0, 2, @"Regular,Small,,Large", nil});
    revenant_register_trait_kind((RevenantTraitKind){@"ForceTouchCapability", 0, 2, @"Unknown,Unavailable,Available", nil});
    revenant_register_trait_kind((RevenantTraitKind){@"TypesettingLanguage", 0, 3, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"ResolvesNaturalAlignmentWithBaseWritingDirection", 0, 3, nil, nil});
    revenant_register_trait_kind((RevenantTraitKind){@"PreferredContentSizeCategory", 0, 2,
                                                   @"XS,S,M,L,XL,XXL,XXXL,AccessibilityM,AccessibilityL,AccessibilityXL,"
                                                   @"AccessibilityXXL,AccessibilityXXXL", nil});
    revenant_add_trait_value_reader(revenant_read_trait_value);
}


@end

@implementation UITraitUserInterfaceIdiom
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitUserInterfaceStyle
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitLayoutDirection
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitDisplayScale
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (CGFloat)defaultValue { return revenant_cgfloat_default_of(self); }
@end

@implementation UITraitHorizontalSizeClass
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitVerticalSizeClass
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitForceTouchCapability
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitPreferredContentSizeCategory
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (id)defaultValue { return revenant_object_default_of(self); }
@end

@implementation UITraitDisplayGamut
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitAccessibilityContrast
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitUserInterfaceLevel
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitLegibilityWeight
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitActiveAppearance
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitToolbarItemPresentationSize
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitImageDynamicRange
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end

@implementation UITraitTypesettingLanguage
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (id)defaultValue { return revenant_object_default_of(self); }
@end

@implementation UITraitSceneCaptureState
+ (NSString *)identifier { return revenant_identifier_of(self); }
+ (NSString *)name { return revenant_trait_name_of(self); }
+ (BOOL)affectsColorAppearance { return revenant_appearance_of(self); }
+ (NSInteger)defaultValue { return revenant_integer_default_of(self); }
@end
