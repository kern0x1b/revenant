#import "RevenantTraits17.h"
#import "RevenantTraitStyle.h"
#import <objc/runtime.h>


#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static char revenant_trait_overrides_key;
static char revenant_trait_registrations_key;

static NSMutableArray *revenant_registrations_of(id observable, BOOL make)
{
    NSMutableArray *registrations = objc_getAssociatedObject(observable, &revenant_trait_registrations_key);
    if (!registrations && make) {
        registrations = [NSMutableArray array];
        objc_setAssociatedObject(observable, &revenant_trait_registrations_key, registrations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return registrations;
}

@interface RevenantRegistration : NSObject <UITraitChangeRegistration>
@property (nonatomic, copy) NSArray *traits;
@property (nonatomic, copy) void (^handler)(id, UITraitCollection *);
@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;
@end

@implementation RevenantRegistration

@synthesize traits = _traits;
@synthesize handler = _handler;
@synthesize target = _target;
@synthesize action = _action;

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)revenant_call:(id<UITraitEnvironment>)environment previous:(UITraitCollection *)previous
{
    if (_handler) {
        _handler(environment, previous);
        return;
    }
    if (!_target || !_action)
        return;
    NSMethodSignature *signature = [_target methodSignatureForSelector:_action];
    if (!signature)
        return;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:_target];
    [invocation setSelector:_action];
    NSUInteger arguments = signature.numberOfArguments - 2;
    if (arguments > 0) {
        id first = environment;
        [invocation setArgument:&first atIndex:2];
    }
    if (arguments > 1) {
        UITraitCollection *before = previous;
        [invocation setArgument:&before atIndex:3];
    }
    [invocation retainArguments];
    [invocation invoke];
}

@end

@interface RevenantOverrides : RevenantTraitMutations <UITraitOverrides>
@end

@implementation RevenantOverrides

void revenant_deliver_trait_registrations(NSArray *environments, NSArray *previous);

+ (void)load
{
    revenant_add_trait_change_observer(revenant_deliver_trait_registrations);
}

- (BOOL)containsTrait:(UITrait)trait
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    return definition ? revenant_trait_value([self revenant_collection], definition) != nil : NO;
}

- (const RevenantTraitDefinition *)revenant_overridden_definition:(Class)trait kind:(RevenantTraitValue)kind
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    if (!definition || definition->kind != kind)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Trait class '%@' does not implement the required defaultValue class property", NSStringFromClass(trait)];
    if (![self containsTrait:trait])
        [NSException raise:NSInternalInconsistencyException
                    format:@"Can't return value for trait %@ that has no override", revenant_trait_public_name(definition)];
    return definition;
}

- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait
{
    return [super valueForCGFloatTrait:(UICGFloatTrait)[self revenant_overridden_definition:trait kind:RevenantTraitValueCGFloat]];
}

- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait
{
    return [super valueForNSIntegerTrait:(UINSIntegerTrait)[self revenant_overridden_definition:trait kind:RevenantTraitValueNSInteger]];
}

- (id)objectForTrait:(UIObjectTrait)trait
{
    return [super objectForTrait:(UIObjectTrait)[self revenant_overridden_definition:trait kind:RevenantTraitValueObject]];
}

- (void)removeTrait:(UITrait)trait
{
    const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
    if (!definition)
        return;
    UITraitCollection *collection = [self revenant_collection];
    switch (definition->home) {
    case RevenantTraitHomeIvar:
        if (definition->trait == (Class)[UITraitUserInterfaceIdiom class])
            [collection revenant_setUserInterfaceIdiom:UIUserInterfaceIdiomUnspecified];
        else if (definition->trait == (Class)[UITraitDisplayScale class])
            [collection revenant_setDisplayScale:0];
        else if (definition->trait == (Class)[UITraitHorizontalSizeClass class])
            [collection revenant_setHorizontalSizeClass:UIUserInterfaceSizeClassUnspecified];
        else
            [collection revenant_setVerticalSizeClass:UIUserInterfaceSizeClassUnspecified];
        break;
    case RevenantTraitHomeStyle:
        revenant_set_trait_style(collection, UIUserInterfaceStyleUnspecified);
        break;
    case RevenantTraitHomeForceTouch:
        revenant_set_trait_force_touch(collection, UIForceTouchCapabilityUnavailable);
        break;
    default:
        revenant_set_trait_extra_object(collection, definition->name, nil);
        break;
    }
}

- (NSSet *)revenant_overriddenTraits
{
    NSMutableSet *overridden = [NSMutableSet set];
    for (Class trait in revenant_trait_classes()) {
        if ([self containsTrait:trait])
            [overridden addObject:trait];
    }
    return overridden;
}

- (NSString *)description
{
    NSMutableArray *parts = [NSMutableArray array];
    for (Class trait in [self revenant_overriddenTraits]) {
        const RevenantTraitDefinition *definition = revenant_trait_definition(trait);
        id value = revenant_trait_value([self revenant_collection], definition);
        NSString *text = definition->home == RevenantTraitHomeStyle
                             ? (value ? (revenant_trait_style([self revenant_collection]) == UIUserInterfaceStyleDark ? @"Dark" : @"Light") : nil)
                             : revenant_trait_value_text(definition, value);
        if (text)
            [parts addObject:[NSString stringWithFormat:@"%@ = %@", revenant_trait_public_name(definition), text]];
    }
    if (!parts.count)
        return [NSString stringWithFormat:@"<%@: %p; no overrides>", [self class], self];
    return [NSString stringWithFormat:@"<%@: %p; overrides = { %@ }>", [self class], self,
                                      [parts componentsJoinedByString:@", "]];
}

@end

static id<UITraitOverrides> revenant_overrides_for(id owner)
{
    id<UITraitOverrides> overrides = objc_getAssociatedObject(owner, &revenant_trait_overrides_key);
    if (!overrides) {
        overrides = [[RevenantOverrides alloc] initWithCollection:nil];
        objc_setAssociatedObject(owner, &revenant_trait_overrides_key, overrides, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return overrides;
}

static id<UITraitChangeRegistration> revenant_register(id observable, NSArray *traits, RevenantRegistration *(^make)(void))
{
    if (![traits count])
        [NSException raise:NSInternalInconsistencyException format:@"Must pass one or more traits to register for"];
    RevenantRegistration *registration = make();
    registration.traits = traits;
    [revenant_registrations_of(observable, YES) addObject:registration];
    return registration;
}

static void revenant_unregister(id observable, id<UITraitChangeRegistration> registration)
{
    if (!registration)
        [NSException raise:NSInternalInconsistencyException format:@"Must pass a non-nil registration to unregister"];
    [revenant_registrations_of(observable, NO) removeObject:registration];
}

void revenant_deliver_trait_registrations(NSArray *environments, NSArray *previous)
{
    NSUInteger index = 0;
    for (id<UITraitEnvironment> environment in environments) {
        UITraitCollection *before = index < [previous count] ? [previous objectAtIndex:index] : nil;
        index++;
        NSArray *registrations = revenant_registrations_of(environment, NO);
        if (![registrations count])
            continue;
        NSSet<UITrait> *changed = [environment.traitCollection changedTraitsFromTraitCollection:before];
        if (![changed count])
            continue;
        for (RevenantRegistration *registration in [registrations copy]) {
            for (Class trait in registration.traits) {
                if (![changed containsObject:trait])
                    continue;
                [registration revenant_call:environment previous:before];
                break;
            }
        }
    }
}

@interface NSObject (RevenantTraitChange) <UITraitChangeObservable>
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withHandler:(UITraitChangeHandler)handler;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withTarget:(id)target action:(SEL)action;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withAction:(SEL)action;
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration;
@end

@implementation NSObject (RevenantTraitChange)

- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withHandler:(UITraitChangeHandler)handler
{
    return revenant_register(self, traits, ^RevenantRegistration * {
        RevenantRegistration *registration = [[RevenantRegistration alloc] init];
        registration.handler = handler;
        return registration;
    });
}

- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withTarget:(id)target action:(SEL)action
{
    return revenant_register(self, traits, ^RevenantRegistration * {
        RevenantRegistration *registration = [[RevenantRegistration alloc] init];
        registration.target = target;
        registration.action = action;
        return registration;
    });
}

- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withAction:(SEL)action
{
    return revenant_register(self, traits, ^RevenantRegistration * {
        RevenantRegistration *registration = [[RevenantRegistration alloc] init];
        registration.target = self;
        registration.action = action;
        return registration;
    });
}

- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration
{
    revenant_unregister(self, registration);
}

@end

@implementation UIView (RevenantTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return revenant_overrides_for(self);
}

- (void)updateTraitsIfNeeded
{
}

@end

@implementation UIViewController (RevenantTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return revenant_overrides_for(self);
}

- (void)updateTraitsIfNeeded
{
}

@end

@implementation UIPresentationController (RevenantTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return revenant_overrides_for(self);
}

@end

@implementation UIWindowScene (RevenantTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return revenant_overrides_for(self);
}

- (void)updateTraitsIfNeeded
{
}

@end
