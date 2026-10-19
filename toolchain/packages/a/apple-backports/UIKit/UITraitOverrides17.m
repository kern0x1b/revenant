#import "CharonTraits17.h"
#import "CharonTraitStyle.h"
#import <objc/runtime.h>


#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static char charon_trait_overrides_key;
static char charon_trait_registrations_key;

static NSMutableArray *charon_registrations_of(id observable, BOOL make)
{
    NSMutableArray *registrations = objc_getAssociatedObject(observable, &charon_trait_registrations_key);
    if (!registrations && make) {
        registrations = [NSMutableArray array];
        objc_setAssociatedObject(observable, &charon_trait_registrations_key, registrations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return registrations;
}

@interface CharonRegistration : NSObject <UITraitChangeRegistration>
@property (nonatomic, copy) NSArray *traits;
@property (nonatomic, copy) void (^handler)(id, UITraitCollection *);
@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;
@end

@implementation CharonRegistration

@synthesize traits = _traits;
@synthesize handler = _handler;
@synthesize target = _target;
@synthesize action = _action;

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)charon_call:(id<UITraitEnvironment>)environment previous:(UITraitCollection *)previous
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

@interface CharonOverrides : CharonTraitMutations <UITraitOverrides>
@end

@implementation CharonOverrides

void charon_deliver_trait_registrations(NSArray *environments, NSArray *previous);

+ (void)load
{
    charon_add_trait_change_observer(charon_deliver_trait_registrations);
}

- (BOOL)containsTrait:(UITrait)trait
{
    const CharonTraitDefinition *definition = charon_trait_definition(trait);
    return definition ? charon_trait_value([self charon_collection], definition) != nil : NO;
}

- (const CharonTraitDefinition *)charon_overridden_definition:(Class)trait kind:(CharonTraitValue)kind
{
    const CharonTraitDefinition *definition = charon_trait_definition(trait);
    if (!definition || definition->kind != kind)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Trait class '%@' does not implement the required defaultValue class property", NSStringFromClass(trait)];
    if (![self containsTrait:trait])
        [NSException raise:NSInternalInconsistencyException
                    format:@"Can't return value for trait %@ that has no override", charon_trait_public_name(definition)];
    return definition;
}

- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait
{
    return [super valueForCGFloatTrait:(UICGFloatTrait)[self charon_overridden_definition:trait kind:CharonTraitValueCGFloat]];
}

- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait
{
    return [super valueForNSIntegerTrait:(UINSIntegerTrait)[self charon_overridden_definition:trait kind:CharonTraitValueNSInteger]];
}

- (id)objectForTrait:(UIObjectTrait)trait
{
    return [super objectForTrait:(UIObjectTrait)[self charon_overridden_definition:trait kind:CharonTraitValueObject]];
}

- (void)removeTrait:(UITrait)trait
{
    const CharonTraitDefinition *definition = charon_trait_definition(trait);
    if (!definition)
        return;
    UITraitCollection *collection = [self charon_collection];
    switch (definition->home) {
    case CharonTraitHomeIvar:
        if (definition->trait == (Class)[UITraitUserInterfaceIdiom class])
            [collection charon_setUserInterfaceIdiom:UIUserInterfaceIdiomUnspecified];
        else if (definition->trait == (Class)[UITraitDisplayScale class])
            [collection charon_setDisplayScale:0];
        else if (definition->trait == (Class)[UITraitHorizontalSizeClass class])
            [collection charon_setHorizontalSizeClass:UIUserInterfaceSizeClassUnspecified];
        else
            [collection charon_setVerticalSizeClass:UIUserInterfaceSizeClassUnspecified];
        break;
    case CharonTraitHomeStyle:
        charon_set_trait_style(collection, UIUserInterfaceStyleUnspecified);
        break;
    case CharonTraitHomeForceTouch:
        charon_set_trait_force_touch(collection, UIForceTouchCapabilityUnavailable);
        break;
    default:
        charon_set_trait_extra_object(collection, definition->name, nil);
        break;
    }
}

- (NSSet *)charon_overriddenTraits
{
    NSMutableSet *overridden = [NSMutableSet set];
    for (Class trait in charon_trait_classes()) {
        if ([self containsTrait:trait])
            [overridden addObject:trait];
    }
    return overridden;
}

- (NSString *)description
{
    NSMutableArray *parts = [NSMutableArray array];
    for (Class trait in [self charon_overriddenTraits]) {
        const CharonTraitDefinition *definition = charon_trait_definition(trait);
        id value = charon_trait_value([self charon_collection], definition);
        NSString *text = definition->home == CharonTraitHomeStyle
                             ? (value ? (charon_trait_style([self charon_collection]) == UIUserInterfaceStyleDark ? @"Dark" : @"Light") : nil)
                             : charon_trait_value_text(definition, value);
        if (text)
            [parts addObject:[NSString stringWithFormat:@"%@ = %@", charon_trait_public_name(definition), text]];
    }
    if (!parts.count)
        return [NSString stringWithFormat:@"<%@: %p; no overrides>", [self class], self];
    return [NSString stringWithFormat:@"<%@: %p; overrides = { %@ }>", [self class], self,
                                      [parts componentsJoinedByString:@", "]];
}

@end

static id<UITraitOverrides> charon_overrides_for(id owner)
{
    id<UITraitOverrides> overrides = objc_getAssociatedObject(owner, &charon_trait_overrides_key);
    if (!overrides) {
        overrides = [[CharonOverrides alloc] initWithCollection:nil];
        objc_setAssociatedObject(owner, &charon_trait_overrides_key, overrides, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return overrides;
}

static id<UITraitChangeRegistration> charon_register(id observable, NSArray *traits, CharonRegistration *(^make)(void))
{
    if (![traits count])
        [NSException raise:NSInternalInconsistencyException format:@"Must pass one or more traits to register for"];
    CharonRegistration *registration = make();
    registration.traits = traits;
    [charon_registrations_of(observable, YES) addObject:registration];
    return registration;
}

static void charon_unregister(id observable, id<UITraitChangeRegistration> registration)
{
    if (!registration)
        [NSException raise:NSInternalInconsistencyException format:@"Must pass a non-nil registration to unregister"];
    [charon_registrations_of(observable, NO) removeObject:registration];
}

void charon_deliver_trait_registrations(NSArray *environments, NSArray *previous)
{
    NSUInteger index = 0;
    for (id<UITraitEnvironment> environment in environments) {
        UITraitCollection *before = index < [previous count] ? [previous objectAtIndex:index] : nil;
        index++;
        NSArray *registrations = charon_registrations_of(environment, NO);
        if (![registrations count])
            continue;
        NSSet<UITrait> *changed = [environment.traitCollection changedTraitsFromTraitCollection:before];
        if (![changed count])
            continue;
        for (CharonRegistration *registration in [registrations copy]) {
            for (Class trait in registration.traits) {
                if (![changed containsObject:trait])
                    continue;
                [registration charon_call:environment previous:before];
                break;
            }
        }
    }
}

@interface NSObject (CharonTraitChange) <UITraitChangeObservable>
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withHandler:(UITraitChangeHandler)handler;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withTarget:(id)target action:(SEL)action;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withAction:(SEL)action;
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration;
@end

@implementation NSObject (CharonTraitChange)

- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withHandler:(UITraitChangeHandler)handler
{
    return charon_register(self, traits, ^CharonRegistration * {
        CharonRegistration *registration = [[CharonRegistration alloc] init];
        registration.handler = handler;
        return registration;
    });
}

- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withTarget:(id)target action:(SEL)action
{
    return charon_register(self, traits, ^CharonRegistration * {
        CharonRegistration *registration = [[CharonRegistration alloc] init];
        registration.target = target;
        registration.action = action;
        return registration;
    });
}

- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withAction:(SEL)action
{
    return charon_register(self, traits, ^CharonRegistration * {
        CharonRegistration *registration = [[CharonRegistration alloc] init];
        registration.target = self;
        registration.action = action;
        return registration;
    });
}

- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration
{
    charon_unregister(self, registration);
}

@end

@implementation UIView (CharonTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return charon_overrides_for(self);
}

- (void)updateTraitsIfNeeded
{
}

@end

@implementation UIViewController (CharonTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return charon_overrides_for(self);
}

- (void)updateTraitsIfNeeded
{
}

@end

@implementation UIPresentationController (CharonTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return charon_overrides_for(self);
}

@end

@implementation UIWindowScene (CharonTraitOverrides)

- (id<UITraitOverrides>)traitOverrides
{
    return charon_overrides_for(self);
}

- (void)updateTraitsIfNeeded
{
}

@end
