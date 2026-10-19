#ifndef REVENANT_TRAITS17_H
#define REVENANT_TRAITS17_H

#import <UIKit/UIKit.h>
#import "../RevenantSayOnce.h"

#if !__has_include(<UIKit/UITrait.h>)

@protocol UIMutableTraits;

#pragma clang diagnostic ignored "-Wobjc-protocol-qualifiers"

typedef NS_ENUM(NSInteger, UIImageDynamicRange) {
    UIImageDynamicRangeUnspecified = -1,
    UIImageDynamicRangeStandard = 0,
    UIImageDynamicRangeConstrainedHigh = 1,
    UIImageDynamicRangeHigh = 2
};

typedef NS_ENUM(NSInteger, UISceneCaptureState) {
    UISceneCaptureStateUnspecified = -1,
    UISceneCaptureStateInactive = 0,
    UISceneCaptureStateActive = 1
};

typedef NS_ENUM(NSInteger, UIHDRHeadroomUsageLimit) {
    UIHDRHeadroomUsageLimitUnspecified = -1,
    UIHDRHeadroomUsageLimitActive = 0,
    UIHDRHeadroomUsageLimitInactive = 1
};

typedef NS_ENUM(NSInteger, UIListEnvironment) {
    UIListEnvironmentUnspecified = 0,
    UIListEnvironmentNone = 1,
    UIListEnvironmentPlain = 2,
    UIListEnvironmentGrouped = 3,
    UIListEnvironmentInsetGrouped = 4,
    UIListEnvironmentSidebar = 5,
    UIListEnvironmentSidebarPlain = 6
};

typedef NS_ENUM(NSInteger, UITabAccessoryEnvironment) {
    UITabAccessoryEnvironmentUnspecified = 0,
    UITabAccessoryEnvironmentNone = 1,
    UITabAccessoryEnvironmentRegular = 2,
    UITabAccessoryEnvironmentInline = 3
};

typedef NS_ENUM(NSInteger, UISplitViewControllerLayoutEnvironment) {
    UISplitViewControllerLayoutEnvironmentNone = 0,
    UISplitViewControllerLayoutEnvironmentExpanded = 1,
    UISplitViewControllerLayoutEnvironmentCollapsed = 2
};

@protocol UITraitDefinition <NSObject>
@optional
@property (nonatomic, class, readonly) NSString *identifier;
@property (nonatomic, class, readonly) NSString *name;
@property (nonatomic, class, readonly) BOOL affectsColorAppearance;
@end
typedef Class<UITraitDefinition> UITrait;

@protocol UICGFloatTraitDefinition <UITraitDefinition>
@property (nonatomic, class, readonly) CGFloat defaultValue;
@end
typedef Class<UICGFloatTraitDefinition> UICGFloatTrait;

@protocol UINSIntegerTraitDefinition <UITraitDefinition>
@property (nonatomic, class, readonly) NSInteger defaultValue;
@end
typedef Class<UINSIntegerTraitDefinition> UINSIntegerTrait;

@protocol UIObjectTraitDefinition <UITraitDefinition>
@property (nonatomic, class, readonly, nullable) __kindof id<NSObject> defaultValue;
@end
typedef Class<UIObjectTraitDefinition> UIObjectTrait;

@interface UITraitUserInterfaceIdiom : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitUserInterfaceStyle : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitLayoutDirection : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitDisplayScale : NSObject <UICGFloatTraitDefinition>
@end
@interface UITraitHorizontalSizeClass : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitVerticalSizeClass : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitForceTouchCapability : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitPreferredContentSizeCategory : NSObject <UIObjectTraitDefinition>
@end
@interface UITraitDisplayGamut : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitAccessibilityContrast : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitUserInterfaceLevel : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitLegibilityWeight : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitActiveAppearance : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitToolbarItemPresentationSize : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitImageDynamicRange : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitTypesettingLanguage : NSObject <UIObjectTraitDefinition>
@end
@interface UITraitSceneCaptureState : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitHDRHeadroomUsageLimit : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitResolvesNaturalAlignmentWithBaseWritingDirection : NSObject <UIObjectTraitDefinition>
@end
@interface UITraitListEnvironment : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitTabAccessoryEnvironment : NSObject <UINSIntegerTraitDefinition>
@end
@interface UITraitSplitViewControllerLayoutEnvironment : NSObject <UINSIntegerTraitDefinition>
@end

typedef void (^UITraitMutations)(id<UIMutableTraits> mutableTraits);

@protocol UIMutableTraits <NSObject>
- (void)setCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait;
- (void)setNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait;
- (void)setObject:(nullable id<NSObject>)object forTrait:(UIObjectTrait)trait;
- (nullable __kindof id<NSObject>)objectForTrait:(UIObjectTrait)trait;
@property (nonatomic) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic) UIUserInterfaceStyle userInterfaceStyle;
@property (nonatomic) UITraitEnvironmentLayoutDirection layoutDirection;
@property (nonatomic) CGFloat displayScale;
@property (nonatomic) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic) UIUserInterfaceSizeClass verticalSizeClass;
@property (nonatomic) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, copy) UIContentSizeCategory preferredContentSizeCategory;
@property (nonatomic) UIDisplayGamut displayGamut;
@property (nonatomic) UIAccessibilityContrast accessibilityContrast;
@property (nonatomic) UIUserInterfaceLevel userInterfaceLevel;
@property (nonatomic) UILegibilityWeight legibilityWeight;
@property (nonatomic) UIUserInterfaceActiveAppearance activeAppearance;
@property (nonatomic) UINSToolbarItemPresentationSize toolbarItemPresentationSize;
@property (nonatomic) UIImageDynamicRange imageDynamicRange;
@property (nonatomic) UISceneCaptureState sceneCaptureState;
@property (nonatomic, copy) NSString *typesettingLanguage;
@property (nonatomic) UIListEnvironment listEnvironment;
@property (nonatomic) UITabAccessoryEnvironment tabAccessoryEnvironment;
@property (nonatomic) UISplitViewControllerLayoutEnvironment splitViewControllerLayoutEnvironment;
@property (nonatomic) BOOL resolvesNaturalAlignmentWithBaseWritingDirection;
@end

@protocol UITraitOverrides <UIMutableTraits>
- (BOOL)containsTrait:(UITrait)trait;
- (void)removeTrait:(UITrait)trait;
@end

@protocol UITraitChangeRegistration <NSObject, NSCopying>
@end

typedef void (^UITraitChangeHandler)(__kindof id<UITraitEnvironment> traitEnvironment, UITraitCollection *previousCollection);

@protocol UITraitChangeObservable <NSObject>
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withHandler:(UITraitChangeHandler)handler;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withTarget:(id)target action:(SEL)action;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withAction:(SEL)action;
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration;
@end

@interface UITraitCollection (RevenantTraits)
+ (UITraitCollection *)traitCollectionWithTraits:(UITraitMutations NS_NOESCAPE)mutations;
- (UITraitCollection *)traitCollectionByModifyingTraits:(UITraitMutations NS_NOESCAPE)mutations;
+ (UITraitCollection *)traitCollectionWithCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (UITraitCollection *)traitCollectionByReplacingCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait;
+ (UITraitCollection *)traitCollectionWithNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (UITraitCollection *)traitCollectionByReplacingNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait;
+ (UITraitCollection *)traitCollectionWithObject:(nullable id<NSObject>)object forTrait:(UIObjectTrait)trait;
- (UITraitCollection *)traitCollectionByReplacingObject:(nullable id<NSObject>)object forTrait:(UIObjectTrait)trait;
- (nullable __kindof id<NSObject>)objectForTrait:(UIObjectTrait)trait;
- (NSSet<UITrait> *)changedTraitsFromTraitCollection:(nullable UITraitCollection *)traitCollection;
@property (nonatomic, readonly, class) NSArray<UITrait> *systemTraitsAffectingColorAppearance;
@property (nonatomic, readonly, class) NSArray<UITrait> *systemTraitsAffectingImageLookup;
@end

#else

@protocol UIMutableTraits;
@protocol UITraitOverrides;
@protocol UITraitChangeRegistration;
@protocol UITraitChangeObservable;

@interface UITraitCollection (RevenantTraits)
+ (UITraitCollection *)traitCollectionWithTraits:(UITraitMutations NS_NOESCAPE)mutations;
- (UITraitCollection *)traitCollectionByModifyingTraits:(UITraitMutations NS_NOESCAPE)mutations;
+ (UITraitCollection *)traitCollectionWithCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (UITraitCollection *)traitCollectionByReplacingCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait;
+ (UITraitCollection *)traitCollectionWithNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (UITraitCollection *)traitCollectionByReplacingNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait;
+ (UITraitCollection *)traitCollectionWithObject:(nullable id<NSObject>)object forTrait:(UIObjectTrait)trait;
- (UITraitCollection *)traitCollectionByReplacingObject:(nullable id<NSObject>)object forTrait:(UIObjectTrait)trait;
- (nullable __kindof id<NSObject>)objectForTrait:(UIObjectTrait)trait;
- (NSSet<UITrait> *)changedTraitsFromTraitCollection:(nullable UITraitCollection *)traitCollection;
@property (nonatomic, readonly, class) NSArray<UITrait> *systemTraitsAffectingColorAppearance;
@property (nonatomic, readonly, class) NSArray<UITrait> *systemTraitsAffectingImageLookup;
@end

#endif

typedef NS_ENUM(NSInteger, RevenantTraitValue) {
    RevenantTraitValueCGFloat = 0,
    RevenantTraitValueNSInteger = 1,
    RevenantTraitValueObject = 2
};

typedef NS_ENUM(NSInteger, RevenantTraitHome) {
    RevenantTraitHomeExtras = 0,
    RevenantTraitHomeIvar = 1,
    RevenantTraitHomeStyle = 2,
    RevenantTraitHomeForceTouch = 3
};

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

typedef struct {
    __unsafe_unretained Class trait;
    __unsafe_unretained NSString *name;
    RevenantTraitValue kind;
    RevenantTraitHome home;
    __unsafe_unretained id defaultValue;
    BOOL affectsColorAppearance;
} RevenantTraitDefinition;

typedef NSString *(*RevenantTraitValueReader)(UITraitCollection *collection, NSString *name, BOOL *known,
                                            BOOL *isDefault);
void revenant_add_trait_value_reader(RevenantTraitValueReader reader);

NSString *revenant_read_trait_value(UITraitCollection *collection, NSString *name, BOOL *known, BOOL *isDefault);

#define REVENANT_TRAIT_COUNT 22

void revenant_register_trait_definition(int index, const RevenantTraitDefinition *definition);

const RevenantTraitDefinition *revenant_trait_definition(Class trait);

NSArray *revenant_trait_classes(void);

const RevenantTraitDefinition *revenant_trait_definition_for_name(NSString *name);

static inline NSString *revenant_trait_public_name(const RevenantTraitDefinition *definition)
{
    NSString *identifier = NSStringFromClass(definition->trait);
    NSRange prefix = [identifier rangeOfString:@"UITrait"];
    if (prefix.location == NSNotFound)
        return identifier;
    return [identifier substringFromIndex:NSMaxRange(prefix)];
}

static inline NSString *revenant_identifier_of(Class trait)
{
    return NSStringFromClass(trait);
}

static inline NSString *revenant_trait_name_of(Class trait)
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    return definition ? revenant_trait_public_name(definition) : NSStringFromClass(trait);
}

static inline BOOL revenant_appearance_of(Class trait)
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    return definition ? definition->affectsColorAppearance : NO;
}

static inline NSInteger revenant_integer_default_of(Class trait)
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    if (!definition || !definition->defaultValue)
        return -1;
    return [definition->defaultValue integerValue];
}

static inline CGFloat revenant_cgfloat_default_of(Class trait)
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    return definition && definition->defaultValue ? (CGFloat)[definition->defaultValue doubleValue] : 0;
}

static inline id revenant_object_default_of(Class trait)
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    return definition ? definition->defaultValue : nil;
}

BOOL revenant_trait_is_default(UITraitCollection *collection, const RevenantTraitDefinition *definition);

id revenant_trait_value(UITraitCollection *collection, const RevenantTraitDefinition *definition);

NSString *revenant_trait_value_text(const RevenantTraitDefinition *definition, id value);

UITraitCollection *revenant_trait_collection_with(UITraitCollection *collection, const RevenantTraitDefinition *definition, id value);

id revenant_trait_extra_object(UITraitCollection *collection, NSString *name);
void revenant_set_trait_extra_object(UITraitCollection *collection, NSString *name, id value);

void revenant_set_trait_force_touch(UITraitCollection *collection, UIForceTouchCapability capability);

@interface UITraitCollection (RevenantTraitStorage)
- (void)revenant_setUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom;
- (void)revenant_setDisplayScale:(CGFloat)scale;
- (void)revenant_setHorizontalSizeClass:(UIUserInterfaceSizeClass)sizeClass;
- (void)revenant_setVerticalSizeClass:(UIUserInterfaceSizeClass)sizeClass;
@end

@interface RevenantTraitMutations : NSObject <UIMutableTraits> {
    UITraitCollection *_collection;
}
- (instancetype)initWithCollection:(UITraitCollection *)collection;
- (UITraitCollection *)revenant_collection;
- (void)setCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait;
- (void)setNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait;
- (void)setObject:(nullable id<NSObject>)object forTrait:(UIObjectTrait)trait;
- (nullable __kindof id<NSObject>)objectForTrait:(UIObjectTrait)trait;
@end

static inline void revenant_traits_say_once(NSString *key, NSString *text)
{
    revenant_say_once_for(key, text);
}

#endif
