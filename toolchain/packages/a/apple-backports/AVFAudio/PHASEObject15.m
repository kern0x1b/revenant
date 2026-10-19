#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

static const simd_float4x4 CharonIdentityTransform = {{
    {1.0f, 0.0f, 0.0f, 0.0f},
    {0.0f, 1.0f, 0.0f, 0.0f},
    {0.0f, 0.0f, 1.0f, 0.0f},
    {0.0f, 0.0f, 0.0f, 1.0f},
}};

@implementation PHASEObject {
    __weak PHASEObject *_charon_parent;
    __weak PHASEEngine *_charon_engine;
    NSMutableArray<PHASEObject *> *_charon_children;
    simd_float4x4 _charon_transform;
    simd_float4x4 _charon_worldTransform;
    simd_float4x4 _charon_localTransform;
}

- (instancetype)initWithEngine:(PHASEEngine *)engine
{
    if ((self = [super init])) {
        _charon_engine = engine;
        _charon_children = [NSMutableArray array];
        _charon_transform = CharonIdentityTransform;
        _charon_localTransform = CharonIdentityTransform;
        _charon_worldTransform = CharonIdentityTransform;
    }
    return self;
}

- (PHASEObject *)parent
{
    return _charon_parent;
}

- (NSArray<PHASEObject *> *)children
{
    return [_charon_children copy];
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
    [self charon_setParent:child];
    [_charon_children addObject:child];
    [child charon_recomputeWorldTransform];
    return YES;
}

- (void)removeChild:(PHASEObject *)child
{
    if (child == nil || ![_charon_children containsObject:child]) {
        return;
    }
    [child charon_setParent:nil];
    [_charon_children removeObject:child];
    [child charon_recomputeWorldTransform];
}

- (void)removeChildren
{
    for (PHASEObject *child in [_charon_children copy]) {
        [child charon_setParent:nil];
        [child charon_recomputeWorldTransform];
    }
    [_charon_children removeAllObjects];
}

- (simd_float4x4)transform
{
    return _charon_transform;
}

- (void)setTransform:(simd_float4x4)transform
{
    _charon_transform = transform;
    [self charon_recomputeWorldTransform];
}

- (simd_float4x4)worldTransform
{
    return _charon_worldTransform;
}

- (void)setWorldTransform:(simd_float4x4)worldTransform
{
    _charon_worldTransform = worldTransform;
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

- (void)charon_setParent:(PHASEObject *)parent
{
    _charon_parent = parent;
}

- (void)charon_recomputeWorldTransform
{
    simd_float4x4 accumulated = _charon_transform;
    for (PHASEObject *ancestor = _charon_parent; ancestor != nil; ancestor = ancestor.parent) {
        accumulated = simd_mul(ancestor.transform, accumulated);
    }
    _charon_worldTransform = accumulated;
}


- (id)copyWithZone:(NSZone *)zone
{
    PHASEObject *copy = [[[self class] allocWithZone:zone] initWithEngine:_charon_engine];
    copy->_charon_transform = _charon_transform;
    [copy charon_recomputeWorldTransform];
    return copy;
}

@end
