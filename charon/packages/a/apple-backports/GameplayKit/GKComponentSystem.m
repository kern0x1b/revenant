// GKComponentSystem.m -- the entity-component system's three classes. GameplayKit.framework carries
// no code at all before iOS 9 (GK_BASE_AVAILABILITY is NS_CLASS_AVAILABLE(10_11, 9_0) and the 6.1.3
// armv7 cache exports no GameplayKit class), so this is this port's own; what the host does was
// measured by tests/backports/host/gameplaykit-core/measure.m:
//
//   An entity holds one component per component class, keyed by that class: adding a second
//   component of a class the entity already has replaces the first, -componentForClass: is nil for
//   a class it does not have, and -components is in no defined order (adding C1 then C2 to one
//   entity gives C2, C1, and adding C2 then C1 to another gives C2, C1 as well, which is a
//   dictionary's order and not an insertion order), measured.
//   -addComponent: sets the component's entity and tells it -didAddToEntity, -removeComponentForClass:
//   tells it -willRemoveFromEntity, and -updateWithDeltaTime: goes to every component in the order
//   -components gives, measured. Adding a component that replaces another tells the new one
//   -didAddToEntity and the replaced one nothing, measured.
//   A component system holds the components of one class in the order they were added, enumerates
//   them, forwards -updateWithDeltaTime: to each, and -addComponentWithEntity: takes only the
//   entity's component of the system's own class, so an entity holding a component of another class
//   adds nothing, measured. -classForGenericArgumentAtIndex: answers the system's component class
//   for every index, measured.
//
// -[GKEntity components] is one place the port answers in a defined order where the host's is a
// dictionary's: the entity keeps the order the caller added its components in beside the class it
// holds each one under. The header promises no order either way, and an application can rely on the
// one it can reproduce; facts/GameplayKit/EntityComponent.md says so where a reader finds it.
//
// Every property the SDK declares here is weak or readonly, and each is answered from an ivar this
// file keeps with a getter of the class's own, so clang never auto-synthesizes one and there is
// nothing for -Wobjc-missing-property-synthesis to say: the archived version silenced that warning
// with a pragma, and the pragma is gone with the thing it hid.

#import "CharonGK.h"

@implementation GKComponent {
    __weak GKEntity *_owner;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (GKEntity *)entity
{
    return _owner;
}

- (void)charon_attachToEntity:(GKEntity *)entity
{
    _owner = entity;
}

// The three hooks are what a subclass fills in, so the base class answers each with nothing, which
// is the whole of what it is for.
- (void)updateWithDeltaTime:(NSTimeInterval)seconds
{
}

- (void)didAddToEntity
{
}

- (void)willRemoveFromEntity
{
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] init];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end

@implementation GKEntity {
    // One component per class, and the order they were added in beside it.
    NSMutableDictionary<NSString *, GKComponent *> *_byClass;
    NSMutableArray<GKComponent *> *_ordered;
}

+ (instancetype)entity
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _byClass = [NSMutableDictionary dictionary];
        _ordered = [NSMutableArray array];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        NSArray<NSString *> *names = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                                          forKey:CharonGKEntityComponentsKey];
        for (NSString *name in names) {
            // A component is archived by its own coder, in an archive of its own: the entity writes
            // down which class each component is and, under that class's own key, the bytes the
            // component's -encodeWithCoder: produced. Reading it back is a decode of those bytes,
            // so a component that carries state of its own is carried with it and one that does not
            // comes back as the class it was.
            Class componentClass = NSClassFromString(name);
            if (![componentClass isSubclassOfClass:[GKComponent class]]) {
                continue;
            }
            NSData *bytes = [coder decodeObjectOfClass:[NSData class]
                                                forKey:[NSString stringWithFormat:@"%@.%@", CharonGKEntityComponentsKey, name]];
            GKComponent *component = nil;
            if ([bytes length] > 0) {
                component = [NSKeyedUnarchiver unarchiveObjectWithData:bytes];
            }
            if (![component isKindOfClass:[GKComponent class]]) {
                component = [[componentClass alloc] init];
            }
            [self addComponent:component];
        }
    }
    return self;
}

// A component's own state is the entity it belongs to, which is a reference and is not archived, so
// the entity writes down which classes its components are and each component decodes itself. A
// component that carries state of its own overrides -encodeWithCoder: and -initWithCoder:.
//
// The nested archive is written and read with +archivedDataWithRootObject: and +unarchiveObjectWithData:
// and not with the pair that needs iOS 11: this object holds the API of one release and that release is
// 9.0, so a call the 9.0 SDK does not declare would put the object above its own band. That is the
// spelling Foundation/NSKeyedArchiver.h carries for the whole life of the class and the one
// HealthKit/HKObject.m uses for the same reason.
- (void)encodeWithCoder:(NSCoder *)coder
{
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:[_ordered count]];
    for (GKComponent *component in _ordered) {
        NSString *name = NSStringFromClass([component class]);
        [names addObject:name];
        NSData *bytes = [NSKeyedArchiver archivedDataWithRootObject:component];
        if ([bytes length]) {
            [coder encodeObject:bytes forKey:[NSString stringWithFormat:@"%@.%@", CharonGKEntityComponentsKey, name]];
        }
    }
    [coder encodeObject:names forKey:CharonGKEntityComponentsKey];
}

- (NSArray<GKComponent *> *)components
{
    return [_ordered copy];
}

- (void)addComponent:(GKComponent *)component
{
    if (!component) {
        return;
    }
    NSString *name = NSStringFromClass([component class]);
    GKComponent *replaced = _byClass[name];
    if (replaced == component) {
        return;
    }
    if (replaced) {
        [_ordered removeObject:replaced];
    }
    _byClass[name] = component;
    [_ordered addObject:component];
    [component charon_attachToEntity:self];
    [component didAddToEntity];
}

- (GKComponent *)componentForClass:(Class)componentClass
{
    if (!componentClass) {
        return nil;
    }
    return _byClass[NSStringFromClass(componentClass)];
}

- (void)removeComponentForClass:(Class)componentClass
{
    GKComponent *component = [self componentForClass:componentClass];
    if (!component) {
        return;
    }
    [_byClass removeObjectForKey:NSStringFromClass(componentClass)];
    [_ordered removeObject:component];
    [component willRemoveFromEntity];
    [component charon_attachToEntity:nil];
}

- (void)updateWithDeltaTime:(NSTimeInterval)seconds
{
    for (GKComponent *component in [_ordered copy]) {
        [component updateWithDeltaTime:seconds];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    GKEntity *copy = [[[self class] allocWithZone:zone] init];
    for (GKComponent *component in _ordered) {
        [copy addComponent:[component copy]];
    }
    return copy;
}

@end

@implementation GKComponentSystem {
    Class _componentClass;
    NSMutableArray *_components;
}

- (instancetype)initWithComponentClass:(Class)cls
{
    self = [super init];
    if (self) {
        _componentClass = cls;
        _components = [NSMutableArray array];
    }
    return self;
}

- (Class)componentClass
{
    return _componentClass;
}

- (NSArray *)components
{
    return [_components copy];
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
    return [_components objectAtIndex:idx];
}

// A component system takes only the components of its own class, and the header says what happens to
// the others: -addComponent: raises NSInvalidArgumentException, and it is the host's own message
// ("component class is not supported by this system") for a component of another class and for nil
// alike, measured. The archived version of this file dropped such a component silently, which is the
// silent fake the tree forbids: an application that added a component of the wrong class to its
// system saw no error and no component.
- (void)addComponent:(GKComponent *)component
{
    if (![component isKindOfClass:_componentClass]) {
        [NSException raise:NSInvalidArgumentException format:@"component class is not supported by this system"];
        return;
    }
    [_components addObject:component];
}

- (void)addComponentWithEntity:(GKEntity *)entity
{
    GKComponent *component = [entity componentForClass:_componentClass];
    if (component) {
        [_components addObject:component];
    }
}

- (void)removeComponent:(GKComponent *)component
{
    [_components removeObjectIdenticalTo:component];
}

- (void)removeComponentWithEntity:(GKEntity *)entity
{
    GKComponent *component = [entity componentForClass:_componentClass];
    if (component) {
        [_components removeObjectIdenticalTo:component];
    }
}

- (void)updateWithDeltaTime:(NSTimeInterval)seconds
{
    for (GKComponent *component in [_components copy]) {
        [component updateWithDeltaTime:seconds];
    }
}

// Every index answers the same class: the component class is the one generic argument a component
// system has, so there is nothing to vary by index.
- (Class)classForGenericArgumentAtIndex:(NSUInteger)index
{
    return _componentClass;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained *)buffer count:(NSUInteger)length
{
    return [_components countByEnumeratingWithState:state objects:buffer count:length];
}

@end