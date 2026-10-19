#import <UIKit/UIKit.h>
#import "RevenantTraits17.h"
#import "RevenantTraitStyle.h"

static const RevenantTraitDefinition *revenant_definitions[REVENANT_TRAIT_COUNT];
static BOOL revenant_definitions_filled[REVENANT_TRAIT_COUNT];


void revenant_register_trait_definition(int index, const RevenantTraitDefinition *definition)
{
    if (index < 0 || index >= REVENANT_TRAIT_COUNT)
        [NSException raise:NSInternalInconsistencyException format:@"trait index %d is out of the table", index];
    if (revenant_definitions_filled[index] && revenant_definitions[index] != definition)
        [NSException raise:NSInternalInconsistencyException format:@"two traits claim index %d", index];
    revenant_definitions[index] = definition;
    revenant_definitions_filled[index] = YES;
}

const RevenantTraitDefinition *revenant_trait_definition(Class trait)
{
    if (!trait)
        return NULL;
    for (int i = 0; i < REVENANT_TRAIT_COUNT; i++) {
        if (revenant_definitions[i] && revenant_definitions[i]->trait == trait)
            return revenant_definitions[i];
    }
    return NULL;
}

const RevenantTraitDefinition *revenant_trait_definition_for_name(NSString *name)
{
    for (int i = 0; i < REVENANT_TRAIT_COUNT; i++) {
        if (revenant_definitions[i] && [revenant_definitions[i]->name isEqualToString:name])
            return revenant_definitions[i];
    }
    return NULL;
}

BOOL revenant_trait_is_default(UITraitCollection *collection, const RevenantTraitDefinition *definition)
{
    switch (definition->home) {
    case RevenantTraitHomeIvar:
        if (definition->trait == (Class)[UITraitUserInterfaceIdiom class])
            return collection.userInterfaceIdiom == UIUserInterfaceIdiomUnspecified;
        if (definition->trait == (Class)[UITraitDisplayScale class])
            return collection.displayScale == 0;
        if (definition->trait == (Class)[UITraitHorizontalSizeClass class])
            return collection.horizontalSizeClass == UIUserInterfaceSizeClassUnspecified;
        return collection.verticalSizeClass == UIUserInterfaceSizeClassUnspecified;
    case RevenantTraitHomeStyle:
        return revenant_trait_style(collection) == UIUserInterfaceStyleUnspecified;
    case RevenantTraitHomeForceTouch:
        return collection.forceTouchCapability == UIForceTouchCapabilityUnknown;
    default:
        return revenant_trait_extra_object(collection, definition->name) == nil;
    }
}

id revenant_trait_value(UITraitCollection *collection, const RevenantTraitDefinition *definition)
{
    if (revenant_trait_is_default(collection, definition))
        return nil;
    switch (definition->home) {
    case RevenantTraitHomeIvar:
        if (definition->trait == (Class)[UITraitUserInterfaceIdiom class])
            return @((NSInteger)collection.userInterfaceIdiom);
        if (definition->trait == (Class)[UITraitDisplayScale class])
            return @((double)collection.displayScale);
        if (definition->trait == (Class)[UITraitHorizontalSizeClass class])
            return @((NSInteger)collection.horizontalSizeClass);
        return @((NSInteger)collection.verticalSizeClass);
    case RevenantTraitHomeStyle:
        return @((NSInteger)revenant_trait_style(collection));
    case RevenantTraitHomeForceTouch:
        return @((NSInteger)collection.forceTouchCapability);
    default:
        return revenant_trait_extra_object(collection, definition->name);
    }
}

NSArray *revenant_trait_classes(void)
{
    static NSArray *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *found = [NSMutableArray arrayWithCapacity:REVENANT_TRAIT_COUNT];
        for (int i = 0; i < REVENANT_TRAIT_COUNT; i++) {
            if (revenant_definitions[i])
                [found addObject:(id)revenant_definitions[i]->trait];
        }
        classes = found;
    });
    return classes;
}

NSString *revenant_read_trait_value(UITraitCollection *collection, NSString *name, BOOL *known, BOOL *isDefault)
{
    if (known)
        *known = NO;
    if (isDefault)
        *isDefault = NO;
    const RevenantTraitDefinition *definition = revenant_trait_definition_for_name(name);
    if (!definition)
        return nil;
    if (known)
        *known = YES;
    if (revenant_trait_is_default(collection, definition)) {
        if (isDefault)
            *isDefault = YES;
        return nil;
    }
    return revenant_trait_value_text(definition, revenant_trait_value(collection, definition));
}
