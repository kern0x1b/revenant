// The twenty-two trait classes of iOS 17, 18 and 26, and the table that says what each of them is.
// A trait class carries no state at all on any release: it is a token, and everything asked of it is asked of the
// class. What the host's own UIKit answers was measured before this was written (facts/UIKit/UITrait17.md, M1):
// +identifier is the class's own name, +name is that name without its UITrait prefix, +defaultValue is the value
// a collection that sets none of this trait has, and +affectsColorAppearance is YES for exactly the seven traits
// that decide how a dynamic colour and a dynamic image resolve. UITraitTypesettingLanguage is the one class the
// host gives no +affectsColorAppearance at all, and this keeps that: the property is @optional in the header and
// an application that asks a trait class for it must be ready for nil. The private +defaultValueRepresentsUnspecified
// and +_isPrivate the host also carries are not in any SDK header, so nothing here answers them.

#import "CharonTraits17.h"
#import "CharonTraitStyle.h"

// The table is the one place a trait's identity is written: the class, the name the port stores the value under,
// the kind of value, where that value lives, the default and whether the trait decides appearance. The name is
// the one the older trait collections already use, so one collection holds one value per trait whichever way it
// was set; UITraitLayoutDirection is the one whose stored name is longer than the class's +name, because the
// collection has always keyed that trait as UserInterfaceLayoutDirection and its description says so.

// A trait definition is written by a function, not by a static initializer, because a definition names its
// class with [Class class] and no initializer may send a message. The function fills the one static of its
// class and puts its address in the table; +load calls them in the order the headers declare the twenty-two.
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
// The one object trait with a default that is not nil: the port's own UIContentSizeCategoryUnspecified, which is
// the string UIKitCore 26.2 answers (M1).
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

    // The traits the older collections never had are named and described here, so a collection that holds one
    // prints it as the host prints it and codes it under the name the host's coder uses. The traits that
    // already had a description keep the one they have: charon_register_trait_kind refuses a second entry for a
    // name, so nothing carried changes.
    // The name lists are the ones the host prints, read value by value in M7: a trait whose enumeration the host
    // names, named; one it does not, with no list at all, so every value prints as its number. The toolbar item
    // presentation size is the one list with a hole in it, at 2, which is why a hole prints the number too.
    charon_register_trait_kind((CharonTraitKind){@"ImageDynamicRange", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"SceneCaptureState", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"HDRHeadroomUsageLimit", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"ListEnvironment", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"TabAccessoryEnvironment", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"SplitViewControllerLayoutEnvironment", 0, 2, nil, nil});
    charon_register_trait_kind((CharonTraitKind){@"ToolbarItemPresentationSize", 0, 2, @"Regular,Small,,Large", nil});
    charon_register_trait_kind((CharonTraitKind){@"ForceTouchCapability", 0, 2, @"Unknown,Unavailable,Available", nil});
    // The two object traits and the one BOOL trait have no pair of names to print, so code 3 prints what is
    // held: the typesetting language a collection carries, and whether it resolves natural alignment from the
    // base writing direction rather than from the user's language.
    charon_register_trait_kind((CharonTraitKind){@"TypesettingLanguage", 0, 3, nil, nil});
    // The content size category is a name in a list, and a collection that set one is described by the name the
    // list gives it, which is the one the older collections have always printed.
    charon_register_trait_kind((CharonTraitKind){@"ResolvesNaturalAlignmentWithBaseWritingDirection", 0, 3, nil, nil});
    // The content size category is a name in a list, and the port has always printed the short name the older
    // collections used; the entry is here so the rule that hides a trait at its own default reaches it, which
    // the port already does by never storing the unspecified category.
    charon_register_trait_kind((CharonTraitKind){@"PreferredContentSizeCategory", 0, 2,
                                                   @"XS,S,M,L,XL,XXL,XXXL,AccessibilityM,AccessibilityL,AccessibilityXL,"
                                                   @"AccessibilityXXL,AccessibilityXXXL", nil});
    // The description of a collection is carried from 5.0 and the trait table from 6.0, so the table is
    // reached through a reader this file registers rather than named there.
    charon_add_trait_value_reader(charon_read_trait_value);
}


@end

// One implementation for all twenty-two: the class property a caller names decides what the table holds for it.

// +name is the class's own name without its UITrait prefix on every one of the twenty-two, measured; it is not
// the name the port stores the value under, which for UITraitLayoutDirection is the longer
// UserInterfaceLayoutDirection the collection has always printed. The two are separate on purpose, and
// charon_trait_public_name in the header is the one place the rule is written.

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
