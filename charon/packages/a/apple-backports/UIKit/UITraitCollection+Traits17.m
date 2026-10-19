// The traits of iOS 17 on a trait collection, and the store they live in.
//
// A trait collection already holds a value per trait: five in its own ivars, the style and the force touch
// capability beside them, and the rest in one dictionary of extras keyed by the trait's name. The traits of 17
// add no store of their own: each of the twenty-two says where its value already lives, and forTrait: and
// valueForCGFloatTrait: and the rest read and write that one place, so a collection built by
// +traitCollectionWithUserInterfaceStyle: and one built by +traitCollectionWithNSIntegerValue:forTrait: with
// UITraitUserInterfaceStyle are the same collection and compare equal. What the host's own UIKit answers was
// measured first (facts/UIKit/UITrait17.md, M2 to M4).

#import "CharonTraits17.h"
#import "CharonTraitStyle.h"
#import <objc/runtime.h>


#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The table the three files that carry the twenty-two trait classes register into, one file per release because
// an object carries the API of exactly one. It lives here, in the file of the release the table's own lookup
// functions belong to, and the registration is what the other two files call.




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

// UIKitCore 26.2 refuses a trait class the caller reached through the wrong protocol, and a class that is not a
// trait at all, in NSInternalInconsistencyException with these words (M4). The port refuses them the same way: an
// application that mistypes a trait would otherwise store a value nothing can read back.
//
// The two traits whose default the system does not know - the typesetting language and the natural alignment
// flag - are not among them. A host whose trait metadata has already raised once answers "does not implement the
// required defaultValue class property" for them too, and that answer is a sign that the store is in a state it
// does not come back from, not a rule: asked first, in a process where nothing has raised, the system takes
// both. So the port takes them too, and the two facts record what was seen in which order (M8).
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

// A collection the traits of are immutable, so -copyWithZone: answers the same object; a copy to mutate is made
// here instead, from the class method that carries the five ivar-backed traits and the style and then the two
// that keep theirs beside: the extras dictionary, which the merge of one collection copies, and the force touch
// capability, which the merge does not and which is put back by its own route.
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
        // The five traits UITraitCollection.h declares readonly have no setter an outside file can reach, so a
        // collection carrying the new value is made through the collection's own constructors: the one for the
        // trait, with the base collection's traits merged over it. The base's traits are kept and the new value
        // wins, which is the order M2 measured for traitCollectionByModifyingTraits:.
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

// The two traits whose default the system does not know are set here and not through the object's forTrait:,
// which is the only route the host takes for them as well (M8). The set and the read are the same as for any
// other trait; what differs is only that nothing is asked of the trait's default first.

- (id)objectForTrait:(UIObjectTrait)trait
{
    const CharonTraitDefinition *definition = [self charon_definition:trait kind:CharonTraitValueObject];
    id value = charon_trait_value(_collection, definition);
    return value ? value : definition->defaultValue;
}

// The twenty-one properties UIMutableTraits declares, one pair per trait, each the same trait class the generic
// accessors above take. They are written out rather than built at run time because they are what a mutations
// block reads and writes, and a block must not send a message the runtime has to look up by name for a
// collection of traits it holds: the two paths are the same table, so a value set through a property and one set
// through setNSIntegerValue:forTrait: are the same value in the same collection.
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

// The eight accessors of iOS 17, 18 and 26 that this port had no answer for. Each reads the one value its trait
// keeps, and a collection that sets none of the trait answers the trait class's own default, which is what M2
// measured for all of them. The last is the one that differs: a collection that sets nothing answers true for
// resolvesNaturalAlignmentWithBaseWritingDirection, where the trait class's defaultValue is nil. The host answers
// true and the port does too, because true is the answer a collection on this release has to give - the base
// writing direction of a view here is the one the user's language gives, which is the other of the two the
// header names, so natural alignment resolves the way this release always resolved it.
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
    // M2: the traits whose value in the receiver differs from the other collection's, and for a nil argument
    // every trait the receiver sets. A trait neither sets is not a change, so a collection compared with itself
    // changes nothing and one compared with an empty collection changes only what it holds.
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

// The traits that decide how a dynamic colour and a dynamic image resolve, in the order the host lists them (M1).
// The host's lists also hold four traits no SDK header declares - UITraitVibrancy,
// UITraitUserInterfaceRenderingMode, UITraitSelectionIsKey and UITraitArtworkSubtype - which this port does not
// carry, so they are not named here and an application that reads the list sees the ones it can name.
+ (NSArray<UITrait> *)systemTraitsAffectingColorAppearance
{
    // The six the host names, in its order, and not the seven: UITraitListEnvironment is a trait class the host
    // carries and does not list here, and the port's list is the host's (M1).
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
