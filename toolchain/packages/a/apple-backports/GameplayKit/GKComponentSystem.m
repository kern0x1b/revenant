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

- (Class)classForGenericArgumentAtIndex:(NSUInteger)index
{
    return _componentClass;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained *)buffer count:(NSUInteger)length
{
    return [_components countByEnumeratingWithState:state objects:buffer count:length];
}

@end
