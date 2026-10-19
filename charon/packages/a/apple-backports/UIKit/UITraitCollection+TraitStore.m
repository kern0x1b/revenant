// UITraitCollection+TraitStore.m - the table the twenty-two traits of iOS 17, 18 and 26 are read out of, and
// the three readers a trait collection's own description asks it for.
//
// The three readers are here, apart from UITraitCollection+Traits17.m, because they are used by two files of two
// different releases: UITraitCollection+Appearance13.m, which is carried from 5.0, prints a collection's traits
// and asks the table what a name means, and UITraitCollection+Traits17.m, which is carried from 6.0, is where
// the table itself is filled in. An object is carried from one release on, and a 5.0 object may not name a 6.0
// symbol - the 4.3 gate refused the appearance file for exactly that - so the readers the 5.0 file needs are in an
// object that is carried from 5.0, which is what its three registry entries say.
//
// Nothing here changed behaviour: the table, its registrar, the by-class lookup and the three readers are the
// same code in a different file, and the traits17 differential is the check on that.

#import <UIKit/UIKit.h>
#import "CharonTraits17.h"
#import "CharonTraitStyle.h"

static const CharonTraitDefinition *charon_definitions[CHARON_TRAIT_COUNT];
static BOOL charon_definitions_filled[CHARON_TRAIT_COUNT];


void charon_register_trait_definition(int index, const CharonTraitDefinition *definition)
{
    if (index < 0 || index >= CHARON_TRAIT_COUNT)
        [NSException raise:NSInternalInconsistencyException format:@"trait index %d is out of the table", index];
    if (charon_definitions_filled[index] && charon_definitions[index] != definition)
        [NSException raise:NSInternalInconsistencyException format:@"two traits claim index %d", index];
    charon_definitions[index] = definition;
    charon_definitions_filled[index] = YES;
}

const CharonTraitDefinition *charon_trait_definition(Class trait)
{
    if (!trait)
        return NULL;
    for (int i = 0; i < CHARON_TRAIT_COUNT; i++) {
        if (charon_definitions[i] && charon_definitions[i]->trait == trait)
            return charon_definitions[i];
    }
    return NULL;
}

const CharonTraitDefinition *charon_trait_definition_for_name(NSString *name)
{
    for (int i = 0; i < CHARON_TRAIT_COUNT; i++) {
        if (charon_definitions[i] && [charon_definitions[i]->name isEqualToString:name])
            return charon_definitions[i];
    }
    return NULL;
}

BOOL charon_trait_is_default(UITraitCollection *collection, const CharonTraitDefinition *definition)
{
    switch (definition->home) {
    case CharonTraitHomeIvar:
        if (definition->trait == (Class)[UITraitUserInterfaceIdiom class])
            return collection.userInterfaceIdiom == UIUserInterfaceIdiomUnspecified;
        if (definition->trait == (Class)[UITraitDisplayScale class])
            return collection.displayScale == 0;
        if (definition->trait == (Class)[UITraitHorizontalSizeClass class])
            return collection.horizontalSizeClass == UIUserInterfaceSizeClassUnspecified;
        return collection.verticalSizeClass == UIUserInterfaceSizeClassUnspecified;
    case CharonTraitHomeStyle:
        return charon_trait_style(collection) == UIUserInterfaceStyleUnspecified;
    case CharonTraitHomeForceTouch:
        return collection.forceTouchCapability == UIForceTouchCapabilityUnknown;
    default:
        return charon_trait_extra_object(collection, definition->name) == nil;
    }
}

id charon_trait_value(UITraitCollection *collection, const CharonTraitDefinition *definition)
{
    if (charon_trait_is_default(collection, definition))
        return nil;
    switch (definition->home) {
    case CharonTraitHomeIvar:
        if (definition->trait == (Class)[UITraitUserInterfaceIdiom class])
            return @((NSInteger)collection.userInterfaceIdiom);
        if (definition->trait == (Class)[UITraitDisplayScale class])
            return @((double)collection.displayScale);
        if (definition->trait == (Class)[UITraitHorizontalSizeClass class])
            return @((NSInteger)collection.horizontalSizeClass);
        return @((NSInteger)collection.verticalSizeClass);
    case CharonTraitHomeStyle:
        return @((NSInteger)charon_trait_style(collection));
    case CharonTraitHomeForceTouch:
        return @((NSInteger)collection.forceTouchCapability);
    default:
        return charon_trait_extra_object(collection, definition->name);
    }
}

NSArray *charon_trait_classes(void)
{
    static NSArray *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *found = [NSMutableArray arrayWithCapacity:CHARON_TRAIT_COUNT];
        for (int i = 0; i < CHARON_TRAIT_COUNT; i++) {
            if (charon_definitions[i])
                [found addObject:(id)charon_definitions[i]->trait];
        }
        classes = found;
    });
    return classes;
}

// The reader a 5.0 object asks the table through. known answers whether the port has a definition for the name
// at all, which is what tells a caller with an extras dictionary of its own that this trait is not one of that
// dictionary's. isDefault answers whether the value is the trait class's own default, which the host prints as
// nothing. Measured before and after this file moved out of UITraitCollection+Traits17.m, and the lookup answers
// the same thing either way: a definition for every name the description uses, with its own home - so the
// header's note that the older traits have no class of their own is stale, and this reader is the one thing
// that has to know it.
NSString *charon_read_trait_value(UITraitCollection *collection, NSString *name, BOOL *known, BOOL *isDefault)
{
    if (known)
        *known = NO;
    if (isDefault)
        *isDefault = NO;
    const CharonTraitDefinition *definition = charon_trait_definition_for_name(name);
    if (!definition)
        return nil;
    if (known)
        *known = YES;
    if (charon_trait_is_default(collection, definition)) {
        if (isDefault)
            *isDefault = YES;
        return nil;
    }
    return charon_trait_value_text(definition, charon_trait_value(collection, definition));
}

