#import "RevenantTraits17.h"
#import "RevenantTraitStyle.h"
#import <objc/runtime.h>


#pragma clang diagnostic ignored "-Wdeprecated-declarations"




static const RevenantTraitDefinition *revenant_definition_for(Class trait, RevenantTraitValue kind);

static NSString *revenant_kind_name(RevenantTraitValue kind)
{
    switch (kind) {
    case RevenantTraitValueCGFloat:
        return @"CGFloat";
    case RevenantTraitValueObject:
        return @"Object";
    default:
        return @"NSInteger";
    }
}

static const RevenantTraitDefinition *revenant_definition_for(Class trait, RevenantTraitValue kind)
{
    if (!trait)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Trait class '(null)' does not implement the required defaultValue class property"];
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    if (!definition)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Trait class '%@' does not implement the required defaultValue class property",
                           NSStringFromClass(trait)];
    if (definition->kind != kind)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Data type (%@) for trait with name '%@' does not match expected data type (%@)",
                           revenant_kind_name(definition->kind), revenant_trait_public_name(definition), revenant_kind_name(kind)];
    return definition;
}

static UITraitCollection *revenant_trait_copy(UITraitCollection *collection)
{
    UITraitCollection *result = [UITraitCollection traitCollectionWithTraitsFromCollections:@[collection]];
    revenant_set_trait_force_touch(result, collection.forceTouchCapability);
    return result;
}



UITraitCollection *revenant_trait_collection_with(UITraitCollection *collection, const RevenantTraitDefinition *definition, id value)
{
    switch (definition->home) {
    case RevenantTraitHomeIvar: {
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
    case RevenantTraitHomeStyle: {
        UITraitCollection *result = revenant_trait_copy(collection);
        revenant_set_trait_style(result, (UIUserInterfaceStyle)[value integerValue]);
        return result;
    }
    case RevenantTraitHomeForceTouch: {
        UITraitCollection *result = revenant_trait_copy(collection);
        revenant_set_trait_force_touch(result, (UIForceTouchCapability)[value integerValue]);
        return result;
    }
    default: {
        UITraitCollection *result = revenant_trait_copy(collection);
        revenant_set_trait_extra_object(result, definition->name, value);
        return result;
    }
    }
}

@implementation RevenantTraitMutations

- (instancetype)initWithCollection:(UITraitCollection *)collection
{
    if ((self = [super init]))
        _collection = collection ? collection : [[UITraitCollection alloc] init];
    return self;
}

- (UITraitCollection *)revenant_collection
{
    return _collection;
}

- (const RevenantTraitDefinition *)revenant_definition:(Class)trait kind:(RevenantTraitValue)kind
{
    return revenant_definition_for(trait, kind);
}

- (void)revenant_set:(const RevenantTraitDefinition *)definition value:(id)value
{
    _collection = revenant_trait_collection_with(_collection, definition, value);
}

- (void)setCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait
{
    [self revenant_set:[self revenant_definition:trait kind:RevenantTraitValueCGFloat] value:@(value)];
}

- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait
{
    const RevenantTraitDefinition *definition = [self revenant_definition:trait kind:RevenantTraitValueCGFloat];
    id value = revenant_trait_value(_collection, definition);
    return value ? (CGFloat)[value doubleValue] : (CGFloat)[definition->defaultValue doubleValue];
}

- (void)setNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait
{
    [self revenant_set:[self revenant_definition:trait kind:RevenantTraitValueNSInteger] value:@(value)];
}

- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait
{
    const RevenantTraitDefinition *definition = [self revenant_definition:trait kind:RevenantTraitValueNSInteger];
    id value = revenant_trait_value(_collection, definition);
    return value ? [value integerValue] : [definition->defaultValue integerValue];
}

- (void)setObject:(id<NSObject>)object forTrait:(UIObjectTrait)trait
{
    [self revenant_set:[self revenant_definition:trait kind:RevenantTraitValueObject] value:object];
}

- (id)objectForTrait:(UIObjectTrait)trait
{
    const RevenantTraitDefinition *definition = [self revenant_definition:trait kind:RevenantTraitValueObject];
    id value = revenant_trait_value(_collection, definition);
    return value ? value : definition->defaultValue;
}

#define REVENANT_TRAIT_PROPERTY(TraitClass, Type, Getter, Setter)                                                                          \
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

REVENANT_TRAIT_PROPERTY([UITraitUserInterfaceIdiom class], UIUserInterfaceIdiom, userInterfaceIdiom, setUserInterfaceIdiom)
REVENANT_TRAIT_PROPERTY([UITraitUserInterfaceStyle class], UIUserInterfaceStyle, userInterfaceStyle, setUserInterfaceStyle)
REVENANT_TRAIT_PROPERTY([UITraitLayoutDirection class], UITraitEnvironmentLayoutDirection, layoutDirection, setLayoutDirection)
REVENANT_TRAIT_PROPERTY([UITraitHorizontalSizeClass class], UIUserInterfaceSizeClass, horizontalSizeClass, setHorizontalSizeClass)
REVENANT_TRAIT_PROPERTY([UITraitVerticalSizeClass class], UIUserInterfaceSizeClass, verticalSizeClass, setVerticalSizeClass)
REVENANT_TRAIT_PROPERTY([UITraitForceTouchCapability class], UIForceTouchCapability, forceTouchCapability, setForceTouchCapability)
REVENANT_TRAIT_PROPERTY([UITraitDisplayGamut class], UIDisplayGamut, displayGamut, setDisplayGamut)
REVENANT_TRAIT_PROPERTY([UITraitAccessibilityContrast class], UIAccessibilityContrast, accessibilityContrast, setAccessibilityContrast)
REVENANT_TRAIT_PROPERTY([UITraitUserInterfaceLevel class], UIUserInterfaceLevel, userInterfaceLevel, setUserInterfaceLevel)
REVENANT_TRAIT_PROPERTY([UITraitLegibilityWeight class], UILegibilityWeight, legibilityWeight, setLegibilityWeight)
REVENANT_TRAIT_PROPERTY([UITraitActiveAppearance class], UIUserInterfaceActiveAppearance, activeAppearance, setActiveAppearance)
REVENANT_TRAIT_PROPERTY([UITraitToolbarItemPresentationSize class], UINSToolbarItemPresentationSize, toolbarItemPresentationSize,
                      setToolbarItemPresentationSize)
REVENANT_TRAIT_PROPERTY([UITraitImageDynamicRange class], UIImageDynamicRange, imageDynamicRange, setImageDynamicRange)
REVENANT_TRAIT_PROPERTY([UITraitSceneCaptureState class], UISceneCaptureState, sceneCaptureState, setSceneCaptureState)
REVENANT_TRAIT_PROPERTY([UITraitListEnvironment class], UIListEnvironment, listEnvironment, setListEnvironment)
REVENANT_TRAIT_PROPERTY([UITraitTabAccessoryEnvironment class], UITabAccessoryEnvironment, tabAccessoryEnvironment, setTabAccessoryEnvironment)
REVENANT_TRAIT_PROPERTY([UITraitSplitViewControllerLayoutEnvironment class], UISplitViewControllerLayoutEnvironment,
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

@implementation UITraitCollection (RevenantTraits)

+ (UITraitCollection *)traitCollectionWithTraits:(UITraitMutations NS_NOESCAPE)mutations
{
    RevenantTraitMutations *mutable = [[RevenantTraitMutations alloc] initWithCollection:nil];
    if (mutations)
        mutations(mutable);
    return [mutable revenant_collection];
}

- (UITraitCollection *)traitCollectionByModifyingTraits:(UITraitMutations NS_NOESCAPE)mutations
{
    RevenantTraitMutations *mutable = [[RevenantTraitMutations alloc] initWithCollection:self];
    if (mutations)
        mutations(mutable);
    return [mutable revenant_collection];
}

+ (UITraitCollection *)traitCollectionWithCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait
{
    return revenant_trait_collection_with([[self alloc] init], revenant_definition_for(trait, RevenantTraitValueCGFloat), @(value));
}

- (UITraitCollection *)traitCollectionByReplacingCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait
{
    return revenant_trait_collection_with(self, revenant_definition_for(trait, RevenantTraitValueCGFloat), @(value));
}

- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait
{
    const RevenantTraitDefinition *definition = revenant_definition_for(trait, RevenantTraitValueCGFloat);
    id value = revenant_trait_value(self, definition);
    return value ? (CGFloat)[value doubleValue] : (CGFloat)[definition->defaultValue doubleValue];
}

+ (UITraitCollection *)traitCollectionWithNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait
{
    return revenant_trait_collection_with([[self alloc] init], revenant_definition_for(trait, RevenantTraitValueNSInteger), @(value));
}

- (UITraitCollection *)traitCollectionByReplacingNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait
{
    return revenant_trait_collection_with(self, revenant_definition_for(trait, RevenantTraitValueNSInteger), @(value));
}

- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait
{
    const RevenantTraitDefinition *definition = revenant_definition_for(trait, RevenantTraitValueNSInteger);
    id value = revenant_trait_value(self, definition);
    return value ? [value integerValue] : [definition->defaultValue integerValue];
}

+ (UITraitCollection *)traitCollectionWithObject:(id<NSObject>)object forTrait:(UIObjectTrait)trait
{
    return revenant_trait_collection_with([[self alloc] init], revenant_definition_for(trait, RevenantTraitValueObject), object);
}

- (UITraitCollection *)traitCollectionByReplacingObject:(id<NSObject>)object forTrait:(UIObjectTrait)trait
{
    return revenant_trait_collection_with(self, revenant_definition_for(trait, RevenantTraitValueObject), object);
}

- (id)objectForTrait:(UIObjectTrait)trait
{
    const RevenantTraitDefinition *definition = revenant_definition_for(trait, RevenantTraitValueObject);
    id value = revenant_trait_value(self, definition);
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
    const RevenantTraitDefinition *definition = revenant_trait_definition([UITraitResolvesNaturalAlignmentWithBaseWritingDirection class]);
    id value = revenant_trait_value(self, definition);
    return value ? [value boolValue] : YES;
}

- (NSSet<UITrait> *)changedTraitsFromTraitCollection:(UITraitCollection *)traitCollection
{
    NSMutableSet *changed = [NSMutableSet set];
    for (Class trait in revenant_trait_classes()) {
        const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
        id mine = revenant_trait_value(self, definition);
        id theirs = traitCollection ? revenant_trait_value(traitCollection, definition) : nil;
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
