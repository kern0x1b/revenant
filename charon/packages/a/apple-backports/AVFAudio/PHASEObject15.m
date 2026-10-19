#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>
#import <simd/simd.h>

// PHASEObject: a 3D object in the engine, organised into a hierarchy with relative transforms.
//
// The header makes `initWithEngine:` the designated initializer and marks both `-init` and `+new`
// NS_UNAVAILABLE, so the object is always made against an engine and never bare. The transform is a
// simd_float4x4, and the header's note on both transforms asks for orthogonal basis vectors and a uniform
// scale (PHASEObject.h:92-95). The identity satisfies that, so an object starts at the
// identity rather than at whatever a zeroed allocation gave (a zero matrix is not a transform, and
// multiplying a position by one is how a hierarchy composes).
//
// PHASE arrived in iOS 15 and the port's releases are 6.1.3 and 4.3, so there is no PHASE.framework
// on either and this is the value and hierarchy the header describes, not a translation of a class
// that exists.

// The identity matrix, written out. The SDK's matrix_identity_float4x4 is a *function* in this SDK's
// simd header, and the 6.1.3 gate says so by name:
//
//   libAVFAudioBackports.dylib weakly imports 1 symbol the armv7 release it is checked against does
//   not export, each of which is NULL there and must be called only behind a check for it:
//   _matrix_identity_float4x4
//
// A weak import of a symbol the release lacks is a call through NULL, so the identity is a literal and
// the object depends on no symbol to stand at one.
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
    // The identity: orthonormal basis, unit scale, origin at zero. The header's own requirement for
    // both transforms, and the value a new object is at.
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

// The header (PHASEObject.h:38-45) makes adding a child that already has a parent an error. An object that is already
// somewhere else in the hierarchy cannot be added here without the hierarchy becoming a graph, so the
// call is refused with an error the caller can read rather than silently moving the object.
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

// The world transform is the object's own composed with every ancestor's, so a child's world
// transform moves when its parent's does. That is the whole of what a hierarchy of relative
// transforms is, and it is one matrix product rather than an approximation.
- (simd_float4x4)worldTransform
{
    return _charon_worldTransform;
}

- (void)setWorldTransform:(simd_float4x4)worldTransform
{
    _charon_worldTransform = worldTransform;
}

// The three directions PHASE treats as right, up and forward in local space. The header declares them
// as class properties, so they are the same for every object, and the conventional right-handed frame
// is what they name: right along +x, up along +y, forward along -z, which is the frame every
// graphics API uses and the one these are for.
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
