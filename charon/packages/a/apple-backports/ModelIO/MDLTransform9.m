#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A transform is a translation, a rotation, a shear and a scale applied in that order, which is the
// order MDLTransform's own accessors read a matrix back in. The rotation is a product of the three
// axis rotations in X, Y, Z order. The samples themselves are held as an MDLAnimatedMatrix4x4, so
// the times between them are interpolated the way every other animated value's are.

static matrix_float4x4 CharonMDLRotationMatrix(vector_float3 radians)
{
    float cx = cosf(radians.x), sx = sinf(radians.x);
    float cy = cosf(radians.y), sy = sinf(radians.y);
    float cz = cosf(radians.z), sz = sinf(radians.z);
    matrix_float4x4 x;
        x.columns[0] = (vector_float4){1, 0, 0, 0};
        x.columns[1] = (vector_float4){0, cx, sx, 0};
        x.columns[2] = (vector_float4){0, -sx, cx, 0};
        x.columns[3] = (vector_float4){0, 0, 0, 1};
    matrix_float4x4 y;
        y.columns[0] = (vector_float4){cy, 0, -sy, 0};
        y.columns[1] = (vector_float4){0, 1, 0, 0};
        y.columns[2] = (vector_float4){sy, 0, cy, 0};
        y.columns[3] = (vector_float4){0, 0, 0, 1};
    matrix_float4x4 z;
        z.columns[0] = (vector_float4){cz, sz, 0, 0};
        z.columns[1] = (vector_float4){-sz, cz, 0, 0};
        z.columns[2] = (vector_float4){0, 0, 1, 0};
        z.columns[3] = (vector_float4){0, 0, 0, 1};
    return simd_mul(x, simd_mul(y, z));
}


// The identity, written by assigning its columns.  A braced initialiser of a simd matrix does not
// build one: matrix_float4x4 is a struct of four vector_float4 columns, so {{1,0,0,0}, {0,1,0,0},
// {0,0,1,0}, {0,0,0,1}} initialises the first column with the first group and warns
// "excess elements in struct initializer" for the other three.  Measured, the four groups written
// that way give col0 1 1 1 1 and columns 1 to 3 all zero, and the port's MDLTransformStack product
// of a translate and a rotate came out with a zero bottom row where the system's is 0 0 0 1.
static matrix_float4x4 CharonMDLIdentityFloat4x4(void)
{
    matrix_float4x4 identity;
    identity.columns[0] = (vector_float4){1, 0, 0, 0};
    identity.columns[1] = (vector_float4){0, 1, 0, 0};
    identity.columns[2] = (vector_float4){0, 0, 1, 0};
    identity.columns[3] = (vector_float4){0, 0, 0, 1};
    return identity;
}

@implementation MDLTransform {
    MDLAnimatedMatrix4x4 *_samples;
    vector_float3 _translation, _rotation, _shear, _scale;
}

@synthesize matrix = _matrix;
@synthesize resetsTransform = _resetsTransform;
@synthesize translation = _translation;
@synthesize rotation = _rotation;
@synthesize shear = _shear;
@synthesize scale = _scale;

- (instancetype)initWithMatrix:(matrix_float4x4)matrix resetsTransform:(BOOL)resetsTransform
{
    if ((self = [super init])) {
        _samples = [[MDLAnimatedMatrix4x4 alloc] init];
        _resetsTransform = resetsTransform;
        // The four components a new transform has: nothing moved, nothing turned, and a scale of one.
        _translation = (vector_float3){0, 0, 0};
        _rotation = (vector_float3){0, 0, 0};
        _shear = (vector_float3){0, 0, 0};
        _scale = (vector_float3){1, 1, 1};
        [self setMatrix:matrix forTime:0];
    }
    return self;
}

- (void)dealloc
{
}

- (instancetype)init
{
    return [self initWithMatrix:CharonMDLIdentityFloat4x4() resetsTransform:YES];
}

- (instancetype)initWithIdentity
{
    return [self init];
}

- (instancetype)initWithMatrix:(matrix_float4x4)matrix
{
    return [self initWithMatrix:matrix resetsTransform:YES];
}

- (instancetype)initWithTransformComponent:(id<MDLTransformComponent>)component
{
    return [self initWithTransformComponent:component resetsTransform:NO];
}

- (instancetype)initWithTransformComponent:(id<MDLTransformComponent>)component resetsTransform:(BOOL)resetsTransform
{
    matrix_float4x4 matrix =
        [component respondsToSelector:@selector(matrix)] ? component.matrix : [component localTransformAtTime:0];
    return [self initWithMatrix:matrix resetsTransform:resetsTransform];
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLTransform *copy = [[[self class] allocWithZone:zone] initWithMatrix:self.matrix resetsTransform:self.resetsTransform];
    NSArray<NSNumber *> *times = _samples.keyTimes;
    for (NSUInteger k = 1; k < times.count; k++)
        [copy setMatrix:[_samples float4x4AtTime:times[k].doubleValue] forTime:times[k].doubleValue];
    return copy;
}

- (void)setIdentity
{
    [self setMatrix:CharonMDLIdentityFloat4x4() forTime:0];
}

// A sample at a time already held replaces that sample rather than standing beside it, and a time
// before the first or after the last sample falls on the first or the last, as every animated value
// of the port and of the host reads there.
- (void)setMatrix:(matrix_float4x4)matrix forTime:(NSTimeInterval)time
{
    [_samples setFloat4x4:matrix atTime:time];
    if (time <= 0)
        _matrix = matrix;
}

- (matrix_float4x4)localTransformAtTime:(NSTimeInterval)time
{
    return [_samples float4x4AtTime:time];
}

- (void)setLocalTransform:(matrix_float4x4)transform forTime:(NSTimeInterval)time
{
    [self setMatrix:transform forTime:time];
}

- (void)setLocalTransform:(matrix_float4x4)transform
{
    [self setMatrix:transform forTime:0];
}

- (NSTimeInterval)minimumTime
{
    return _samples.minimumTime;
}

- (NSTimeInterval)maximumTime
{
    return _samples.maximumTime;
}

- (NSArray<NSNumber *> *)keyTimes
{
    return _samples.keyTimes;
}

// The accessors answer the four components the transform was given, not a reading of the matrix: a
// matrix set outright leaves them where they were, which is what the system answers and what a
// caller that sets a rotation and reads a scale is entitled to.
- (vector_float3)translationAtTime:(NSTimeInterval)time
{
    return _translation;
}

- (matrix_float4x4)rotationMatrixAtTime:(NSTimeInterval)time
{
    matrix_float4x4 matrix = [_samples float4x4AtTime:time];
    vector_float3 scale = {simd_length(matrix.columns[0]), simd_length(matrix.columns[1]), simd_length(matrix.columns[2])};
    matrix_float4x4 rotation;
    for (int c = 0; c < 3; c++) {
        float length = scale[c];
        rotation.columns[c] = length ? matrix.columns[c] / length : (vector_float4){0, 0, 0, 0};
    }
    rotation.columns[3] = (vector_float4){0, 0, 0, 1};
    return rotation;
}

- (vector_float3)rotationAtTime:(NSTimeInterval)time
{
    return _rotation;
}

- (vector_float3)scaleAtTime:(NSTimeInterval)time
{
    return _scale;
}

- (vector_float3)shearAtTime:(NSTimeInterval)time
{
    return _shear;
}

// One of the four components changed: the matrix at time zero is composed from the four again, so a
// caller that sets a translation and reads the matrix sees it move.
- (void)charon_recompose
{
    _matrix = [self matrixForTranslation:_translation rotation:_rotation shear:_shear scale:_scale];
    [_samples setFloat4x4:_matrix atTime:0];
}

- (void)setMatrix:(matrix_float4x4)matrix
{
    [self setMatrix:matrix forTime:0];
}

- (matrix_float4x4)matrixForTranslation:(vector_float3)translation
                               rotation:(vector_float3)rotation
                                  shear:(vector_float3)shear
                                  scale:(vector_float3)scale
{
    matrix_float4x4 result;
        result.columns[0] = (vector_float4){scale.x, scale.x * shear.x, 0, 0};
        result.columns[1] = (vector_float4){0, scale.y, scale.y * shear.y, 0};
        result.columns[2] = (vector_float4){0, 0, scale.z, 0};
        result.columns[3] = (vector_float4){0, 0, 0, 1};
    result = simd_mul(CharonMDLRotationMatrix(rotation), result);
    result.columns[3] = (vector_float4){translation.x, translation.y, translation.z, 1};
    return result;
}

- (void)setTranslation:(vector_float3)translation forTime:(NSTimeInterval)time
{
    _translation = translation;
    [self setMatrix:[self matrixForTranslation:translation rotation:[self rotationAtTime:time] shear:[self shearAtTime:time]
                                         scale:[self scaleAtTime:time]]
             forTime:time];
}

- (void)setRotation:(vector_float3)rotation forTime:(NSTimeInterval)time
{
    _rotation = rotation;
    [self setMatrix:[self matrixForTranslation:[self translationAtTime:time] rotation:rotation shear:[self shearAtTime:time]
                                         scale:[self scaleAtTime:time]]
             forTime:time];
}

- (void)setShear:(vector_float3)shear forTime:(NSTimeInterval)time
{
    _shear = shear;
    [self setMatrix:[self matrixForTranslation:[self translationAtTime:time] rotation:[self rotationAtTime:time] shear:shear
                                         scale:[self scaleAtTime:time]]
             forTime:time];
}

- (void)setScale:(vector_float3)scale forTime:(NSTimeInterval)time
{
    _scale = scale;
    [self setMatrix:[self matrixForTranslation:[self translationAtTime:time] rotation:[self rotationAtTime:time]
                                         shear:[self shearAtTime:time] scale:scale]
             forTime:time];
}

- (void)setTranslation:(vector_float3)translation
{
    [self setTranslation:translation forTime:0];
}

- (void)setRotation:(vector_float3)rotation
{
    [self setRotation:rotation forTime:0];
}

- (void)setShear:(vector_float3)shear
{
    [self setShear:shear forTime:0];
}

- (void)setScale:(vector_float3)scale
{
    [self setScale:scale forTime:0];
}

+ (matrix_float4x4)globalTransformWithObject:(MDLObject *)object atTime:(NSTimeInterval)time
{
    matrix_float4x4 global = CharonMDLIdentityFloat4x4();
    for (MDLObject *at = object; at; at = at.parent) {
        id<MDLTransformComponent> transform = at.transform;
        if (!transform)
            continue;
        // A transform that carries its own samples is asked for the time given; one that is a plain
        // matrix has the same matrix at every time.
        matrix_float4x4 local = [transform respondsToSelector:@selector(localTransformAtTime:)] ? [transform localTransformAtTime:time]
                                                                                              : transform.matrix;
        global = simd_mul(global, local);
    }
    return global;
}

@end
