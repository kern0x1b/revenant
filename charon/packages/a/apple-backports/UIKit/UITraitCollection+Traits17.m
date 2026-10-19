#import "CharonTraits17.h"
#import "CharonTraitStyle.h"
#import <objc/runtime.h>


#pragma clang diagnostic ignored "-Wdeprecated-declarations"




static const CharonTraitDefinition *charon_definition_for(Class trait, CharonTraitValue kind);

static NSString *charon_kind_name(CharonTraitValue kind)
{
    switch (kind) {
    case CharonTraitValueCGFloat:
        return @"CGFloat";
    case CharonTraitValueObject:
        return @"Object";
    default:
        return @"NSInteger";
    }
}

static const CharonTraitDefinition *charon_definition_for(Class trait, CharonTraitValue kind)
{
    if (!trait)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Trait class '(null)' does not implement the required defaultValue class property"];
    const CharonTraitDefinition *definition = charon_trait_definition(trait);
    if (!definition)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Trait class '%@' does not implement the required defaultValue class property",
                           NSStringFromClass(trait)];
    if (definition->kind != kind)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Data type (%@) for trait with name '%@' does not match expected data type (%@)",
                           charon_kind_name(definition->kind), charon_trait_public_name(definition), charon_kind_name(kind)];
    return definition;
}

static UITraitCollection *charon_trait_copy(UITraitCollection *collection)
{
    UITraitCollection *result = [UITraitCollection traitCollectionWithTraitsFromCollections:@[collection]];
    charon_set_trait_force_touch(result, collection.forceTouchCapability);
    return result;
}



UITraitCollection *charon_trait_collection_with(UITraitCollection *collection, const CharonTraitDefinition *definition, id value)
{
    switch (definition->home) {
    case CharonTraitHomeIvar: {
        UITraitCollection *result = nil;
        if (definition->trait == (Class)[UITraitUserInterfaceIdiom class])
            result = [UITraitCollection traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)[value integerValue]];
        else if (definition->trait == (Class)[UITraitDisplayScale class])
            result = [UITraitCollection traitCollectionWithDisplayScale:(CGFloat)[value doubleValue]];
        else if (definition->trait == (Class)[UITraitHorizontalSizeClass class])
            result = [UITraitCollection traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)[value integerValue]];
        else
            result = [UITraitCollection traitCollectionWithVerticalSizeClass:(UIUserInterfaceSizeClass)[value integerValue]];
        return [UITraitCollection traitCollectionWithTraitsFromCollections:@[result, collection]];
    }
    case CharonTraitHomeStyle: {
        UITraitCollection *result = charon_trait_copy(collection);
        charon_set_trait_style(result, (UIUserInterfaceStyle)[value integerValue]);
        return result;
    }
    case CharonTraitHomeForceTouch: {
        UITraitCollection *result = charon_trait_copy(collection);
        charon_set_trait_force_touch(result, (UIForceTouchCapability)[value integerValue]);
        return result;
    }
    default: {
        UITraitCollection *result = charon_trait_copy(collection);
        charon_set_trait_extra_object(result, definition->name, value);
        return result;
    }
    }
}

@implementation CharonTraitMutations

- (instancetype)initWithCollection:(UITraitCollection *)collection
{
    if ((self = [super init]))
        _collection = collection ? collection : [[UITraitCollection alloc] init];
    return self;
}

- (UITraitCollection *)charon_collection
{
    return _collection;
}

- (const CharonTraitDefinition *)charon_definition:(Class)trait kind:(CharonTraitValue)kind
{
    return charon_definition_for(trait, kind);
}

- (void)charon_set:(const CharonTraitDefinition *)definition value:(id)value
{
    _collection = charon_trait_collection_with(_collection, definition, value);
}

- (void)setCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait
{
    [self charon_set:[self charon_definition:trait kind:CharonTraitValueCGFloat] value:@(value)];
}

- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait
{
    const CharonTraitDefinition *definition = [self charon_definition:trait kind:CharonTraitValueCGFloat];
    id value = charon_trait_value(_collection, definition);
    return value ? (CGFloat)[value doubleValue] : (CGFloat)[definition->defaultValue doubleValue];
}

- (void)setNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait
{
    [self charon_set:[self charon_definition:trait kind:CharonTraitValueNSInteger] value:@(value)];
}

- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait
{
    const CharonTraitDefinition *definition = [self charon_definition:trait kind:CharonTraitValueNSInteger];
    id value = charon_trait_value(_collection, definition);
    return value ? [value integerValue] : [definition->defaultValue integerValue];
}

- (void)setObject:(id<NSObject>)object forTrait:(UIObjectTrait)trait
{
    [self charon_set:[self charon_definition:trait kind:CharonTraitValueObject] value:object];
}

- (id)objectForTrait:(UIObjectTrait)trait
{
    const CharonTraitDefinition *definition = [self charon_definition:trait kind:CharonTraitValueObject];
    id value = charon_trait_value(_collection, definition);
    return value ? value : definition->defaultValue;
}

#define CHARON_TRAIT_PROPERTY(TraitClass, Type, Getter, Setter)                                                                          \
    - (Type)Getter                                                                                                                     \
    {                                                                                                                                   \
        return (Type)[self valueForTraitClass:TraitClass];                                                                              \
    }                                                                                                                                   \
    - (void)Setter:(Type)value                                                                                                          \
    {                                                                                                                                   \
        [self setValueForTraitClass:TraitClass value:value];                                                                             \
    }

- (NSInteger)valueForTraitClass:(Class)trait
{
    return [self valueForNSIntegerTrait:trait];
}

- (void)setValueForTraitClass:(Class)trait value:(NSInteger)value
{
    [self setNSIntegerValue:value forTrait:trait];
}

- (CGFloat)valueForCGFloatTraitClass:(Class)trait
{
    return [self valueForCGFloatTrait:trait];
}

- (void)setCGFloatValueForTraitClass:(Class)trait value:(CGFloat)value
{
    [self setCGFloatValue:value forTrait:trait];
}

- (id)valueForObjectTraitClass:(Class)trait
{
    return [self objectForTrait:trait];
}

- (void)setObjectValueForTraitClass:(Class)trait value:(id)value
{
    [self setObject:value forTrait:trait];
}

CHARON_TRAIT_PROPERTY([UITraitUserInterfaceIdiom class], UIUserInterfaceIdiom, userInterfaceIdiom, setUserInterfaceIdiom)
CHARON_TRAIT_PROPERTY([UITraitUserInterfaceStyle class], UIUserInterfaceStyle, userInterfaceStyle, setUserInterfaceStyle)
CHARON_TRAIT_PROPERTY([UITraitLayoutDirection class], UITraitEnvironmentLayoutDirection, layoutDirection, setLayoutDirection)
CHARON_TRAIT_PROPERTY([UITraitHorizontalSizeClass class], UIUserInterfaceSizeClass, horizontalSizeClass, setHorizontalSizeClass)
CHARON_TRAIT_PROPERTY([UITraitVerticalSizeClass class], UIUserInterfaceSizeClass, verticalSizeClass, setVerticalSizeClass)
CHARON_TRAIT_PROPERTY([UITraitForceTouchCapability class], UIForceTouchCapability, forceTouchCapability, setForceTouchCapability)
CHARON_TRAIT_PROPERTY([UITraitDisplayGamut class], UIDisplayGamut, displayGamut, setDisplayGamut)
CHARON_TRAIT_PROPERTY([UITraitAccessibilityContrast class], UIAccessibilityContrast, accessibilityContrast, setAccessibilityContrast)
CHARON_TRAIT_PROPERTY([UITraitUserInterfaceLevel class], UIUserInterfaceLevel, userInterfaceLevel, setUserInterfaceLevel)
CHARON_TRAIT_PROPERTY([UITraitLegibilityWeight class], UILegibilityWeight, legibilityWeight, setLegibilityWeight)
CHARON_TRAIT_PROPERTY([UITraitActiveAppearance class], UIUserInterfaceActiveAppearance, activeAppearance, setActiveAppearance)
CHARON_TRAIT_PROPERTY([UITraitToolbarItemPresentationSize class], UINSToolbarItemPresentationSize, toolbarItemPresentationSize,
                      setToolbarItemPresentationSize)
CHARON_TRAIT_PROPERTY([UITraitImageDynamicRange class], UIImageDynamicRange, imageDynamicRange, setImageDynamicRange)
CHARON_TRAIT_PROPERTY([UITraitSceneCaptureState class], UISceneCaptureState, sceneCaptureState, setSceneCaptureState)
CHARON_TRAIT_PROPERTY([UITraitListEnvironment class], UIListEnvironment, listEnvironment, setListEnvironment)
CHARON_TRAIT_PROPERTY([UITraitTabAccessoryEnvironment class], UITabAccessoryEnvironment, tabAccessoryEnvironment, setTabAccessoryEnvironment)
CHARON_TRAIT_PROPERTY([UITraitSplitViewControllerLayoutEnvironment class], UISplitViewControllerLayoutEnvironment,
                      splitViewControllerLayoutEnvironment, setSplitViewControllerLayoutEnvironment)

- (CGFloat)displayScale
{
    return [self valueForCGFloatTraitClass:[UITraitDisplayScale class]];
}

- (void)setDisplayScale:(CGFloat)displayScale
{
    [self setCGFloatValueForTraitClass:[UITraitDisplayScale class] value:displayScale];
}

- (UIContentSizeCategory)preferredContentSizeCategory
{
    return [self valueForObjectTraitClass:[UITraitPreferredContentSizeCategory class]];
}

- (void)setPreferredContentSizeCategory:(UIContentSizeCategory)preferredContentSizeCategory
{
    [self setObjectValueForTraitClass:[UITraitPreferredContentSizeCategory class] value:preferredContentSizeCategory];
}

- (NSString *)typesettingLanguage
{
    return [self valueForObjectTraitClass:[UITraitTypesettingLanguage class]];
}

- (void)setTypesettingLanguage:(NSString *)typesettingLanguage
{
    [self setObjectValueForTraitClass:[UITraitTypesettingLanguage class] value:typesettingLanguage];
}

- (BOOL)resolvesNaturalAlignmentWithBaseWritingDirection
{
    return [[self valueForObjectTraitClass:[UITraitResolvesNaturalAlignmentWithBaseWritingDirection class]] boolValue];
}

- (void)setResolvesNaturalAlignmentWithBaseWritingDirection:(BOOL)resolves
{
    [self setObjectValueForTraitClass:[UITraitResolvesNaturalAlignmentWithBaseWritingDirection class] value:@(resolves)];
}

@end

@implementation UITraitCollection (CharonTraits)

+ (UITraitCollection *)traitCollectionWithTraits:(UITraitMutations NS_NOESCAPE)mutations
{
    CharonTraitMutations *mutable = [[CharonTraitMutations alloc] initWithCollection:nil];
    if (mutations)
        mutations(mutable);
    return [mutable charon_collection];
}

- (UITraitCollection *)traitCollectionByModifyingTraits:(UITraitMutations NS_NOESCAPE)mutations
{
    CharonTraitMutations *mutable = [[CharonTraitMutations alloc] initWithCollection:self];
    if (mutations)
        mutations(mutable);
    return [mutable charon_collection];
}

+ (UITraitCollection *)traitCollectionWithCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait
{
    return charon_trait_collection_with([[self alloc] init], charon_definition_for(trait, CharonTraitValueCGFloat), @(value));
}

- (UITraitCollection *)traitCollectionByReplacingCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait
{
    return charon_trait_collection_with(self, charon_definition_for(trait, CharonTraitValueCGFloat), @(value));
}

- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait
{
    const CharonTraitDefinition *definition = charon_definition_for(trait, CharonTraitValueCGFloat);
    id value = charon_trait_value(self, definition);
    return value ? (CGFloat)[value doubleValue] : (CGFloat)[definition->defaultValue doubleValue];
}

+ (UITraitCollection *)traitCollectionWithNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait
{
    return charon_trait_collection_with([[self alloc] init], charon_definition_for(trait, CharonTraitValueNSInteger), @(value));
}

- (UITraitCollection *)traitCollectionByReplacingNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait
{
    return charon_trait_collection_with(self, charon_definition_for(trait, CharonTraitValueNSInteger), @(value));
}

- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait
{
    const CharonTraitDefinition *definition = charon_definition_for(trait, CharonTraitValueNSInteger);
    id value = charon_trait_value(self, definition);
    return value ? [value integerValue] : [definition->defaultValue integerValue];
}

+ (UITraitCollection *)traitCollectionWithObject:(id<NSObject>)object forTrait:(UIObjectTrait)trait
{
    return charon_trait_collection_with([[self alloc] init], charon_definition_for(trait, CharonTraitValueObject), object);
}

- (UITraitCollection *)traitCollectionByReplacingObject:(id<NSObject>)object forTrait:(UIObjectTrait)trait
{
    return charon_trait_collection_with(self, charon_definition_for(trait, CharonTraitValueObject), object);
}

- (id)objectForTrait:(UIObjectTrait)trait
{
    const CharonTraitDefinition *definition = charon_definition_for(trait, CharonTraitValueObject);
    id value = charon_trait_value(self, definition);
    return value ? value : definition->defaultValue;
}

- (UINSToolbarItemPresentationSize)toolbarItemPresentationSize
{
    return (UINSToolbarItemPresentationSize)[self valueForNSIntegerTrait:[UITraitToolbarItemPresentationSize class]];
}

- (UIImageDynamicRange)imageDynamicRange
{
    return (UIImageDynamicRange)[self valueForNSIntegerTrait:[UITraitImageDynamicRange class]];
}

- (UISceneCaptureState)sceneCaptureState
{
    return (UISceneCaptureState)[self valueForNSIntegerTrait:[UITraitSceneCaptureState class]];
}

- (UIHDRHeadroomUsageLimit)hdrHeadroomUsageLimit
{
    return (UIHDRHeadroomUsageLimit)[self valueForNSIntegerTrait:[UITraitHDRHeadroomUsageLimit class]];
}

- (UIListEnvironment)listEnvironment
{
    return (UIListEnvironment)[self valueForNSIntegerTrait:[UITraitListEnvironment class]];
}

- (UITabAccessoryEnvironment)tabAccessoryEnvironment
{
    return (UITabAccessoryEnvironment)[self valueForNSIntegerTrait:[UITraitTabAccessoryEnvironment class]];
}

- (UISplitViewControllerLayoutEnvironment)splitViewControllerLayoutEnvironment
{
    return (UISplitViewControllerLayoutEnvironment)[self valueForNSIntegerTrait:[UITraitSplitViewControllerLayoutEnvironment class]];
}

- (NSString *)typesettingLanguage
{
    return [self objectForTrait:[UITraitTypesettingLanguage class]];
}

- (BOOL)resolvesNaturalAlignmentWithBaseWritingDirection
{
    const CharonTraitDefinition *definition = charon_trait_definition([UITraitResolvesNaturalAlignmentWithBaseWritingDirection class]);
    id value = charon_trait_value(self, definition);
    return value ? [value boolValue] : YES;
}

- (NSSet<UITrait> *)changedTraitsFromTraitCollection:(UITraitCollection *)traitCollection
{
    NSMutableSet *changed = [NSMutableSet set];
    for (Class trait in charon_trait_classes()) {
        const CharonTraitDefinition *definition = charon_trait_definition(trait);
        id mine = charon_trait_value(self, definition);
        id theirs = traitCollection ? charon_trait_value(traitCollection, definition) : nil;
        if (mine == nil && theirs == nil)
            continue;
        if (!mine || !theirs || ![mine isEqual:theirs])
            [changed addObject:trait];
    }
    return changed;
}

+ (NSArray<UITrait> *)systemTraitsAffectingColorAppearance
{
    return @[ (id)[UITraitUserInterfaceIdiom class], (id)[UITraitUserInterfaceStyle class], (id)[UITraitDisplayGamut class],
              (id)[UITraitAccessibilityContrast class], (id)[UITraitUserInterfaceLevel class], (id)[UITraitActiveAppearance class] ];
}

+ (NSArray<UITrait> *)systemTraitsAffectingImageLookup
{
    return @[ (id)[UITraitUserInterfaceIdiom class], (id)[UITraitUserInterfaceStyle class], (id)[UITraitLayoutDirection class],
              (id)[UITraitDisplayScale class], (id)[UITraitHorizontalSizeClass class], (id)[UITraitVerticalSizeClass class],
              (id)[UITraitPreferredContentSizeCategory class], (id)[UITraitDisplayGamut class],
              (id)[UITraitAccessibilityContrast class], (id)[UITraitLegibilityWeight class] ];
}

@end
