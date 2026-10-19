#import "RevenantAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

static const simd_float4x4 RevenantIdentityTransform = {{
    {1.0f, 0.0f, 0.0f, 0.0f},
    {0.0f, 1.0f, 0.0f, 0.0f},
    {0.0f, 0.0f, 1.0f, 0.0f},
    {0.0f, 0.0f, 0.0f, 1.0f},
}};

@implementation PHASEObject {
    __weak PHASEObject *_revenant_parent;
    __weak PHASEEngine *_revenant_engine;
    NSMutableArray<PHASEObject *> *_revenant_children;
    simd_float4x4 _revenant_transform;
    simd_float4x4 _revenant_worldTransform;
    simd_float4x4 _revenant_localTransform;
}

- (instancetype)initWithEngine:(PHASEEngine *)engine
{
    if ((self = [super init])) {
        _revenant_engine = engine;
        _revenant_children = [NSMutableArray array];
        _revenant_transform = RevenantIdentityTransform;
        _revenant_localTransform = RevenantIdentityTransform;
        _revenant_worldTransform = RevenantIdentityTransform;
    }
    return self;
}

- (PHASEObject *)parent
{
    return _revenant_parent;
}

- (NSArray<PHASEObject *> *)children
{
    return [_revenant_children copy];
}

- (BOOL)addChild:(PHASEObject *)child error:(NSError **)outError
{
    if (child == nil) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return NO;
    }
    if (child.parent != nil) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue
                                        userInfo:@{NSLocalizedDescriptionKey: @"the object already has a parent"}];
        }
        return NO;
    }
    [self revenant_setParent:child];
    [_revenant_children addObject:child];
    [child revenant_recomputeWorldTransform];
    return YES;
}

- (void)removeChild:(PHASEObject *)child
{
    if (child == nil || ![_revenant_children containsObject:child]) {
        return;
    }
    [child revenant_setParent:nil];
    [_revenant_children removeObject:child];
    [child revenant_recomputeWorldTransform];
}

- (void)removeChildren
{
    for (PHASEObject *child in [_revenant_children copy]) {
        [child revenant_setParent:nil];
        [child revenant_recomputeWorldTransform];
    }
    [_revenant_children removeAllObjects];
}

- (simd_float4x4)transform
{
    return _revenant_transform;
}

- (void)setTransform:(simd_float4x4)transform
{
    _revenant_transform = transform;
    [self revenant_recomputeWorldTransform];
}

- (simd_float4x4)worldTransform
{
    return _revenant_worldTransform;
}

- (void)setWorldTransform:(simd_float4x4)worldTransform
{
    _revenant_worldTransform = worldTransform;
}

+ (simd_float3)right
{
    return simd_make_float3(1.0f, 0.0f, 0.0f);
}

+ (simd_float3)up
{
    return simd_make_float3(0.0f, 1.0f, 0.0f);
}

+ (simd_float3)forward
{
    return simd_make_float3(0.0f, 0.0f, -1.0f);
}

- (void)revenant_setParent:(PHASEObject *)parent
{
    _revenant_parent = parent;
}

- (void)revenant_recomputeWorldTransform
{
    simd_float4x4 accumulated = _revenant_transform;
    for (PHASEObject *ancestor = _revenant_parent; ancestor != nil; ancestor = ancestor.parent) {
        accumulated = simd_mul(ancestor.transform, accumulated);
    }
    _revenant_worldTransform = accumulated;
}


- (id)copyWithZone:(NSZone *)zone
{
    PHASEObject *copy = [[[self class] allocWithZone:zone] initWithEngine:_revenant_engine];
    copy->_revenant_transform = _revenant_transform;
    [copy revenant_recomputeWorldTransform];
    return copy;
}

@end
