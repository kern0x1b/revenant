// traitOverrides, registerForTraitChanges: and updateTraitsIfNeeded - the three ways iOS 17 gives an object its
// own traits, the two private classes the host answers with, and the delivery that calls a registration back.
//
// What the host's own UIKit answers was measured first (facts/UIKit/UITrait17.md, M5 and M6). The host answers
// with two classes it does not declare in any header, _UITraitOverrides and _UITraitRegistration, and this
// file answers with two of its own, CharonOverrides and CharonRegistration.
//
// The names are different on purpose. A class a library defines under a name nobody owns is that library's own
// type, it is not Apple's API, and it therefore carries no release - which is what every other private helper in
// this library is called, from CharonHomeViewController to CharonTraitMutations. A class defined under Apple's
// private name is the other thing entirely: it looks like Apple's API, nothing says which iOS release it
// arrived in. A 6.1.3 gate run against a tree where this file did define those two names said, of
// that tree and not of this one:
//
//   neither the SDK, the registry nor a held release's own cache says which iOS release _UITraitOverrides
//   _UITraitRegistration arrived in, and UITraitOverrides17.m defines it, so no band can hold it
//
// The clause about this file defining them is the gate's, about that tree; this file no longer does.
//
// The one thing the different names cost is the class name inside a printed description, which is the only
// difference between the string the host prints and the string this file prints. The rest of that string is
// behaviour, so the differential compares the two with the leading class name left out, and says so where it
// does. The overrides object is per owner - a view, a view controller, a presentation controller and a scene
// each have their own, and two views never share one, which M5 measured.
//
// A registration is not a token: it is called when the traits it names change in the environment it was made on,
// which is why UITraitCollection.m's own delivery asks this file for the call. The port's traits change when the
// release reports a new status bar orientation and when an application sets a trait, so those are the two paths
// a handler fires on; nothing else on this release moves a trait.

#import "CharonTraits17.h"
#import "CharonTraitStyle.h"
#import <objc/runtime.h>


#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static char charon_trait_overrides_key;
static char charon_trait_registrations_key;

// The registrations of one observable, made on first ask and kept beside it.
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
    // A registration is what unregisterForTraitChanges: takes back, and a copy of one is the same registration
    // held once more, so unregistering either unregisters the one: two calls asking for the same traits are two
    // registrations, and a copy is not a second of them.
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
    // withTarget:action: takes a method of zero, one or two arguments, and the count of the method's own decides
    // what the call is given: the environment whose traits are changing, and then the collection it had before,
    // as the header of UITraitChangeObservable documents and the host does.
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

// The overrides of one owner: a trait collection to begin from, and the trait values put over it. The host's
// description is two forms, "no overrides" and the list of what is set, and this prints both.
@interface CharonOverrides : CharonTraitMutations <UITraitOverrides>
@end

@implementation CharonOverrides

// The delivery this file registers below, defined at the foot of it. It is a C function, not a category method,
// so +load may name it whatever the categories' +load ordering is.
void charon_deliver_trait_registrations(NSArray *environments, NSArray *previous);

// The delivery of a trait change is UITraitCollection.m's, and that object is carried from 5.0 while this file is
// carried from 6.0, so the registration of iOS 17 is not called there by name: this file registers it as a
// listener of the delivery instead, and a release that carries no 6.0 band has no listener and delivers to
// nobody. +load on this class - a class this file defines, not one a category adds - is what runs the
// registration, and it calls a C function, which is why the categories' +load ordering does not reach it.
+ (void)load
{
    charon_add_trait_change_observer(charon_deliver_trait_registrations);
}

- (BOOL)containsTrait:(UITrait)trait
{
    const CharonTraitDefinition *definition = charon_trait_definition(trait);
    return definition ? charon_trait_value([self charon_collection], definition) != nil : NO;
}

// A trait overrides object answers a trait it does not override with the exception the host's answers with, and
// not with the trait's default: the object is asked what it was told, and it was told nothing. The mutations
// object a mutations block is given is the same class and does answer the default, because a block that reads a
// trait it has not set is reading the environment's, and that is what the host's mutations do (M5).
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
    // Removing an override puts the trait back to what the environment itself says, which is the trait's
    // default: the dictionary entry goes, and the five traits the collection holds in its own storage and the
    // style and the force touch capability are set to the values they start at.
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

// The traits of this overrides object that the environment does not already say are the ones the object changes,
// which is what decides whether a registration fires.
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
        // The style keeps its value beside the collection and the collection's own description already knows how
        // to print it, so the overrides object prints it the same way rather than through the name lists.
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
    // Quiet twice over, as M6 measured: unregistering the same registration again asks nothing and changes
    // nothing, and neither does unregistering one that is not this observable's.
    [charon_registrations_of(observable, NO) removeObject:registration];
}

void charon_deliver_trait_registrations(NSArray *environments, NSArray *previous)
{
    // Called by UITraitCollection.m's own delivery once the change is made, with the environments it told and
    // the collection each had before. A registration fires for the traits it named when one of them differs
    // between the two, and an environment that changed nothing fires nothing.
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

// The four classes that adopt UITraitChangeObservable in UIKitCore 17, and the one owner of traitOverrides that
// is a controller rather than a view. A category on NSObject carries the four registration methods, because
// UITraitChangeObservable is a protocol the SDK's own UITrait.h declares and the build SDK does not, and every
// one of the four must answer them.
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
    // The registrar itself, as the three methods above it: the target is self, which is what
    // -registerForTraitChanges:withTarget:action: with self says, and a send to self here is a send no
    // host differential can place - the port's own method on a class the system owns.
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
    // An application calls this after it changes an override, where the host re-resolves the environment. Here
    // the environment is the screen's traits, which nothing has moved, so the call is the whole of it: a view's
    // traitCollection is the screen's and stays the screen's.
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
