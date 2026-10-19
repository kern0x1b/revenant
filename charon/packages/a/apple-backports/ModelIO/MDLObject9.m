#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@interface MDLObjectContainer ()
@property (nonatomic, assign) MDLObject *charon_owner;
@end

static void CharonMDLBounds(MDLAxisAlignedBoundingBox *box, vector_float3 point)
{
    float low[3], high[3], p[3];
    low[0] = box->minBounds.x, low[1] = box->minBounds.y, low[2] = box->minBounds.z;
    high[0] = box->maxBounds.x, high[1] = box->maxBounds.y, high[2] = box->maxBounds.z;
    p[0] = point.x, p[1] = point.y, p[2] = point.z;
    box->minBounds = (vector_float3){low[0] < p[0] ? low[0] : p[0], low[1] < p[1] ? low[1] : p[1],
                                    low[2] < p[2] ? low[2] : p[2]};
    box->maxBounds = (vector_float3){high[0] > p[0] ? high[0] : p[0], high[1] > p[1] ? high[1] : p[1],
                                    high[2] > p[2] ? high[2] : p[2]};
}

@implementation MDLObject {
    NSMutableArray<id<MDLComponent>> *_components;
    __unsafe_unretained MDLObject *_parent;
    MDLObject *_instance;
    id<MDLObjectContainerComponent> _children;
    id<MDLTransformComponent> _transform;
    BOOL _hidden;
}

@synthesize name = _name;

- (instancetype)init
{
    if ((self = [super init])) {
        _components = [[NSMutableArray alloc] init];
        _name = @"";
    }
    return self;
}

- (void)dealloc
{
}

- (NSArray<id<MDLComponent>> *)components
{
    return [_components copy];
}

- (void)setComponent:(id<MDLComponent>)component forProtocol:(Protocol *)protocol
{
    for (NSUInteger k = 0; k < _components.count; k++)
        if ([_components[k] conformsToProtocol:protocol]) {
            [_components removeObjectAtIndex:k];
            break;
        }
    if (component)
        [_components addObject:component];
}

- (id<MDLComponent>)componentConformingToProtocol:(Protocol *)protocol
{
    for (id<MDLComponent> component in _components)
        if ([component conformsToProtocol:protocol])
            return component;
    return nil;
}

- (id<MDLComponent>)objectForKeyedSubscript:(Protocol *)key
{
    return [self componentConformingToProtocol:key];
}

- (void)setObject:(id<MDLComponent>)obj forKeyedSubscript:(Protocol *)key
{
    [self setComponent:obj forProtocol:key];
}

- (MDLObject *)parent
{
    return _parent;
}

- (void)setParent:(MDLObject *)parent
{
    _parent = parent;
}

- (MDLObject *)instance
{
    return _instance;
}

- (void)setInstance:(MDLObject *)instance
{
    if (_instance != instance) {
        _instance = instance;
    }
}

- (id<MDLTransformComponent>)transform
{
    return _transform;
}

- (void)setTransform:(id<MDLTransformComponent>)transform
{
    if (_transform != transform) {
        _transform = transform;
    }
}

- (id<MDLObjectContainerComponent>)children
{
    if (!_children) {
        MDLObjectContainer *container = [[MDLObjectContainer alloc] init];
        container.charon_owner = self;
        _children = container;
    }
    return _children;
}

- (void)setChildren:(id<MDLObjectContainerComponent>)children
{
    if (_children != children) {
        _children = children;
    }
    if ([children isKindOfClass:[MDLObjectContainer class]])
        [(MDLObjectContainer *)children setCharon_owner:self];
    for (MDLObject *child in [_children objects])
        if (child.parent != self)
            [child setParent:self];
}

- (BOOL)hidden
{
    return _hidden;
}

- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
}

- (void)addChild:(MDLObject *)child
{
    if (!child)
        return;
    [[self children] addObject:child];
    [child setParent:self];
}

- (NSString *)path
{
    if (!_parent)
        return [NSString stringWithFormat:@"/%@", self.name];
    return [_parent.path stringByAppendingFormat:@"/%@", self.name];
}

- (MDLObject *)objectAtPath:(NSString *)path
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *part in [path componentsSeparatedByString:@"/"])
        if (part.length)
            [parts addObject:part];
    if (!parts.count)
        return self;
    MDLObject *at = self;
    for (NSUInteger k = 0; k < parts.count; k++) {
        MDLObject *next = nil;
        for (MDLObject *child in at.children.objects)
            if ([child.name isEqualToString:parts[k]]) {
                next = child;
                break;
            }
        if (!next)
            return nil;
        at = next;
    }
    return at;
}

- (void)enumerateChildObjectsOfClass:(Class)objectClass
                                root:(MDLObject *)root
                          usingBlock:(void (^)(MDLObject *, BOOL *))block
                         stopPointer:(BOOL *)stopPointer
{
    for (MDLObject *child in root.children.objects) {
        if (stopPointer && *stopPointer)
            return;
        if (!objectClass || [child isKindOfClass:objectClass])
            block(child, stopPointer);
        if (stopPointer && *stopPointer)
            return;
        [self enumerateChildObjectsOfClass:objectClass root:child usingBlock:block stopPointer:stopPointer];
    }
}

- (MDLAxisAlignedBoundingBox)boundingBoxAtTime:(NSTimeInterval)time
{
    MDLAxisAlignedBoundingBox result = {{-INFINITY, -INFINITY, -INFINITY}, {INFINITY, INFINITY, INFINITY}};
    for (MDLObject *child in self.children.objects) {
        if (child.hidden)
            continue;
        matrix_float4x4 global = [MDLTransform globalTransformWithObject:child atTime:time];
        MDLAxisAlignedBoundingBox box = [child boundingBoxAtTime:time];
        if (box.minBounds[0] > box.maxBounds[0])
            continue;
        for (int corner = 0; corner < 8; corner++) {
            vector_float3 point = {(corner & 1) ? box.maxBounds.x : box.minBounds.x, (corner & 2) ? box.maxBounds.y : box.minBounds.y,
                                   (corner & 4) ? box.maxBounds.z : box.minBounds.z};
            vector_float4 transformed = simd_mul(global, (vector_float4){point.x, point.y, point.z, 1});
            CharonMDLBounds(&result, transformed.xyz);
        }
    }
    if (result.minBounds[0] > result.maxBounds[0]) {
        result.minBounds = (vector_float3){0, 0, 0};
        result.maxBounds = (vector_float3){-1, -1, -1};
    }
    return result;
}

@end

@implementation MDLObjectContainer {
    NSMutableArray<MDLObject *> *_objects;
}

- (instancetype)init
{
    if ((self = [super init]))
        _objects = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
}

- (void)addObject:(MDLObject *)object
{
    if (!object || [_objects containsObject:object])
        return;
    [_objects addObject:object];
    if (self.charon_owner && object.parent != self.charon_owner)
        [object setParent:self.charon_owner];
}

- (void)removeObject:(MDLObject *)object
{
    if ([_objects containsObject:object]) {
        [_objects removeObject:object];
        if (object.parent == self.charon_owner)
            [object setParent:nil];
    }
}

- (MDLObject *)objectAtIndexedSubscript:(NSUInteger)index
{
    return index < _objects.count ? _objects[index] : nil;
}

- (NSUInteger)count
{
    return _objects.count;
}

- (NSArray<MDLObject *> *)objects
{
    return [_objects copy];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)length
{
    return [_objects countByEnumeratingWithState:state objects:buffer count:length];
}

@end
