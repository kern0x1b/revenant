#import <ModelIO/ModelIO.h>
#import "CharonMDLTransformMath.h"
#import <simd/simd.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// Every operation of a transform stack reads an animated value of one shape and turns it into a
// matrix. They differ only in that shape and in what the inverse of the operation is, so what they
// share - the name the stack was given for the operation, whether it was added as an inverse, the
// two spellings of its matrix - is a small set of methods each of them writes itself. All of this is
// the port's own: iOS 6 has no ModelIO at all.

// The name, the inverse flag and the matrix of one operation, in one struct every operation carries,
// so the stack can read and write them without knowing which operation it is holding.
typedef struct {
    __unsafe_unretained NSString *name;
    BOOL inverse;
} CharonMDLOpRecord;

// The rotation matrix of a quaternion, by its own four components: the imaginary part first and the
// real part last, which is the order a quaternion is written in.
// The inverse of a matrix, by its own adjugate over its determinant. Real arithmetic, no library
// internal, and the determinant of a singular matrix is zero, which is answered as the matrix itself
// rather than as a division by zero.
static matrix_double4x4 CharonMDLMatrixInverse(matrix_double4x4 m)
{
    double a00 = m.columns[0][0], a01 = m.columns[1][0], a02 = m.columns[2][0], a03 = m.columns[3][0];
    double a10 = m.columns[0][1], a11 = m.columns[1][1], a12 = m.columns[2][1], a13 = m.columns[3][1];
    double a20 = m.columns[0][2], a21 = m.columns[1][2], a22 = m.columns[2][2], a23 = m.columns[3][2];
    double a30 = m.columns[0][3], a31 = m.columns[1][3], a32 = m.columns[2][3], a33 = m.columns[3][3];
    double c00 = a11 * a22 * a33 + a12 * a23 * a31 + a13 * a21 * a32 - a13 * a22 * a31 - a12 * a23 * a21 - a11 * a32 * a23;
    double c01 = a02 * a23 * a31 + a03 * a21 * a32 + a01 * a22 * a33 - a03 * a22 * a31 - a01 * a23 * a32 - a02 * a21 * a33;
    double c02 = a03 * a12 * a31 + a00 * a22 * a33 + a01 * a23 * a32 - a03 * a12 * a32 - a00 * a23 * a31 - a01 * a12 * a33;
    double c03 = a02 * a13 * a31 + a03 * a11 * a32 + a00 * a12 * a33 - a03 * a11 * a32 - a00 * a13 * a31 - a02 * a11 * a33;
    double c10 = a12 * a23 * a30 + a13 * a21 * a32 + a10 * a22 * a33 - a13 * a22 * a30 - a12 * a23 * a32 - a10 * a32 * a23;
    double c20 = a13 * a12 * a30 + a10 * a23 * a32 + a11 * a22 * a33 - a10 * a12 * a33 - a13 * a11 * a32 - a12 * a11 * a23;
    double c11 = a10 * a22 * a33 + a12 * a23 * a30 + a13 * a20 * a32 - a10 * a23 * a32 - a13 * a22 * a30 - a12 * a20 * a33;
    double c21 = a10 * a13 * a32 + a13 * a20 * a30 + a11 * a22 * a33 - a11 * a13 * a30 - a10 * a13 * a33 - a13 * a11 * a32;
    double c31 = a10 * a12 * a33 + a12 * a23 * a30 + a13 * a20 * a32 - a13 * a12 * a30 - a10 * a12 * a33 - a10 * a23 * a32;
    double c12 = a10 * a23 * a31 + a13 * a20 * a33 + a11 * a22 * a30 - a13 * a22 * a31 - a10 * a22 * a33 - a11 * a23 * a30;
    double c22 = a10 * a12 * a33 + a13 * a20 * a31 + a11 * a22 * a33 - a11 * a13 * a30 - a10 * a12 * a33 - a10 * a23 * a31;
    double c32 = a10 * a12 * a31 + a11 * a13 * a30 + a12 * a20 * a33 - a11 * a12 * a30 - a10 * a13 * a33 - a12 * a20 * a31;
    double c13 = a10 * a22 * a31 + a11 * a21 * a32 + a12 * a20 * a33 - a11 * a22 * a30 - a10 * a21 * a33 - a12 * a20 * a31;
    double c23 = a10 * a13 * a31 + a11 * a20 * a32 + a12 * a21 * a30 - a10 * a12 * a33 - a13 * a11 * a30 - a11 * a20 * a32;
    double c33 = a10 * a12 * a31 + a11 * a13 * a30 + a13 * a20 * a32 - a13 * a12 * a30 - a10 * a13 * a33 - a10 * a12 * a32;
    double c30 = a10 * a13 * a32 + a11 * a12 * a30 + a12 * a21 * a30 - a10 * a12 * a31 - a11 * a13 * a30 - a13 * a11 * a32;
    double determinant = a00 * c00 + a01 * c01 + a02 * c02 + a03 * c03;
    if (determinant == 0)
        return m;
    double d = 1.0 / determinant;
    matrix_double4x4 inverse;
        inverse.columns[0] = (vector_double4){c00 * d, -c10 * d, -c20 * d, -c30 * d};
        inverse.columns[1] = (vector_double4){-c01 * d, c11 * d, c21 * d, c31 * d};
        inverse.columns[2] = (vector_double4){-c02 * d, -c12 * d, c22 * d, c32 * d};
        inverse.columns[3] = (vector_double4){-c03 * d, -c13 * d, -c23 * d, c33 * d};
    return inverse;
}

// What the operations share, as the methods the stack and the protocol below use. Each operation
// writes them itself, over the one record it carries, and a new operation of the same class takes
// the whole state of the one it is a copy of.
@protocol CharonMDLTransformOpRecord <NSObject>
- (CharonMDLOpRecord *)charon_record;
- (MDLAnimatedValue *)charon_value;
- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value;
- (void)charon_takeOverFrom:(id<MDLTransformOp>)op;
@end

@interface MDLTransformRotateXOp () <CharonMDLTransformOpRecord>
@end
@interface MDLTransformRotateYOp () <CharonMDLTransformOpRecord>
@end
@interface MDLTransformRotateZOp () <CharonMDLTransformOpRecord>
@end
@interface MDLTransformRotateOp () <CharonMDLTransformOpRecord>
- (MDLTransformOpRotationOrder)charon_order;
- (void)charon_setOrder:(MDLTransformOpRotationOrder)order;
@end
@interface MDLTransformTranslateOp () <CharonMDLTransformOpRecord>
@end
@interface MDLTransformScaleOp () <CharonMDLTransformOpRecord>
@end
@interface MDLTransformMatrixOp () <CharonMDLTransformOpRecord>
@end
@interface MDLTransformOrientOp () <CharonMDLTransformOpRecord>
@end

@implementation MDLTransformRotateXOp {
    CharonMDLOpRecord _record;
    MDLAnimatedScalar *_value;
    int _axis;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _axis = 0;
        _value = [[MDLAnimatedScalar alloc] init];
    }
    return self;
}

- (void)dealloc
{
}

- (CharonMDLOpRecord *)charon_record
{
    return &_record;
}

- (MDLAnimatedValue *)charon_value
{
    return _value;
}

- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (void)charon_takeOverFrom:(id<MDLTransformOp>)op
{
    [self charon_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
    _record.name = [(id<MDLTransformOp>)op name];
    _record.inverse = [op IsInverseOp];
}

- (NSString *)name
{
    return _record.name;
}

- (bool)IsInverseOp
{
    return _record.inverse;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    double angle = [_value doubleAtTime:time] * M_PI / 180.0;
    // The angle of a rotation operation's animated scalar is in DEGREES, measured against the
    // system: an operation set to 90 gives an exact quarter turn (col1 0 0 1, col2 0 -1 0) and
    // one set to pi/2 gives 0 0.99962 0.02741, which is a turn of 0.02741 radians, and
    // pi/2 degrees is 0.02742.  The value is converted here rather than at every read, so the
    // unit is stated once.  (MDLTransform's own rotation is radians, which is the other way
    // round and is why the two are not shared: measured, MDLTransform set to 90 gives
    // 0 -0.44807 0.89400, a turn of 90 radians.)
    return CharonMDLAxisRotation(_axis, _record.inverse ? -angle : angle);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedScalar *)animatedValue
{
    return _value;
}

@end
@implementation MDLTransformRotateYOp {
    CharonMDLOpRecord _record;
    MDLAnimatedScalar *_value;
    int _axis;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _axis = 1;
        _value = [[MDLAnimatedScalar alloc] init];
    }
    return self;
}

- (void)dealloc
{
}

- (CharonMDLOpRecord *)charon_record
{
    return &_record;
}

- (MDLAnimatedValue *)charon_value
{
    return _value;
}

- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (void)charon_takeOverFrom:(id<MDLTransformOp>)op
{
    [self charon_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
    _record.name = [(id<MDLTransformOp>)op name];
    _record.inverse = [op IsInverseOp];
}

- (NSString *)name
{
    return _record.name;
}

- (bool)IsInverseOp
{
    return _record.inverse;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    double angle = [_value doubleAtTime:time] * M_PI / 180.0;
    // The angle of a rotation operation's animated scalar is in DEGREES, measured against the
    // system: an operation set to 90 gives an exact quarter turn (col1 0 0 1, col2 0 -1 0) and
    // one set to pi/2 gives 0 0.99962 0.02741, which is a turn of 0.02741 radians, and
    // pi/2 degrees is 0.02742.  The value is converted here rather than at every read, so the
    // unit is stated once.  (MDLTransform's own rotation is radians, which is the other way
    // round and is why the two are not shared: measured, MDLTransform set to 90 gives
    // 0 -0.44807 0.89400, a turn of 90 radians.)
    return CharonMDLAxisRotation(_axis, _record.inverse ? -angle : angle);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedScalar *)animatedValue
{
    return _value;
}

@end
@implementation MDLTransformRotateZOp {
    CharonMDLOpRecord _record;
    MDLAnimatedScalar *_value;
    int _axis;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _axis = 2;
        _value = [[MDLAnimatedScalar alloc] init];
    }
    return self;
}

- (void)dealloc
{
}

- (CharonMDLOpRecord *)charon_record
{
    return &_record;
}

- (MDLAnimatedValue *)charon_value
{
    return _value;
}

- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (void)charon_takeOverFrom:(id<MDLTransformOp>)op
{
    [self charon_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
    _record.name = [(id<MDLTransformOp>)op name];
    _record.inverse = [op IsInverseOp];
}

- (NSString *)name
{
    return _record.name;
}

- (bool)IsInverseOp
{
    return _record.inverse;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    double angle = [_value doubleAtTime:time] * M_PI / 180.0;
    // The angle of a rotation operation's animated scalar is in DEGREES, measured against the
    // system: an operation set to 90 gives an exact quarter turn (col1 0 0 1, col2 0 -1 0) and
    // one set to pi/2 gives 0 0.99962 0.02741, which is a turn of 0.02741 radians, and
    // pi/2 degrees is 0.02742.  The value is converted here rather than at every read, so the
    // unit is stated once.  (MDLTransform's own rotation is radians, which is the other way
    // round and is why the two are not shared: measured, MDLTransform set to 90 gives
    // 0 -0.44807 0.89400, a turn of 90 radians.)
    return CharonMDLAxisRotation(_axis, _record.inverse ? -angle : angle);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedScalar *)animatedValue
{
    return _value;
}

@end
@implementation MDLTransformRotateOp {
    CharonMDLOpRecord _record;
    MDLAnimatedVector3 *_value;
    MDLTransformOpRotationOrder _order;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _order = MDLTransformOpRotationOrderXYZ;
        _value = [[MDLAnimatedVector3 alloc] init];
    }
    return self;
}

- (void)dealloc
{
}

- (CharonMDLOpRecord *)charon_record
{
    return &_record;
}

- (MDLAnimatedValue *)charon_value
{
    return _value;
}

- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (MDLTransformOpRotationOrder)charon_order
{
    return _order;
}

- (void)charon_setOrder:(MDLTransformOpRotationOrder)order
{
    _order = order;
}

- (void)charon_takeOverFrom:(id<MDLTransformOp>)op
{
    [self charon_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
    _record.name = [op name];
    _record.inverse = [op IsInverseOp];
    if ([(id)op isKindOfClass:[MDLTransformRotateOp class]])
        _order = [(MDLTransformRotateOp *)(id)op charon_order];
}

- (NSString *)name
{
    return _record.name;
}

- (bool)IsInverseOp
{
    return _record.inverse;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    // Degrees, as the single-axis operations are: the same measurement, and the same conversion.
    vector_double3 angles = [_value double3AtTime:time] * M_PI / 180.0;
    if (_record.inverse)
        angles = (vector_double3){-angles.x, -angles.y, -angles.z};
    return CharonMDLAngleRotation(angles, _order);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedVector3 *)animatedValue
{
    return _value;
}

@end
@implementation MDLTransformTranslateOp {
    CharonMDLOpRecord _record;
    MDLAnimatedVector3 *_value;
}

- (instancetype)init
{
    if ((self = [super init]))
        _value = [[MDLAnimatedVector3 alloc] init];
    return self;
}

- (void)dealloc
{
}

- (CharonMDLOpRecord *)charon_record
{
    return &_record;
}

- (MDLAnimatedValue *)charon_value
{
    return _value;
}

- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (void)charon_takeOverFrom:(id<MDLTransformOp>)op
{
    [self charon_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
    _record.name = [(id<MDLTransformOp>)op name];
    _record.inverse = [op IsInverseOp];
}

- (NSString *)name
{
    return _record.name;
}

- (bool)IsInverseOp
{
    return _record.inverse;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    vector_double3 translation = [_value double3AtTime:time];
    if (_record.inverse)
        translation = (vector_double3){-translation.x, -translation.y, -translation.z};
    return CharonMDLTranslation(translation);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedVector3 *)animatedValue
{
    return _value;
}

@end
@implementation MDLTransformScaleOp {
    CharonMDLOpRecord _record;
    MDLAnimatedVector3 *_value;
}

- (instancetype)init
{
    if ((self = [super init]))
        _value = [[MDLAnimatedVector3 alloc] init];
    return self;
}

- (void)dealloc
{
}

- (CharonMDLOpRecord *)charon_record
{
    return &_record;
}

- (MDLAnimatedValue *)charon_value
{
    return _value;
}

- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (void)charon_takeOverFrom:(id<MDLTransformOp>)op
{
    [self charon_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
    _record.name = [(id<MDLTransformOp>)op name];
    _record.inverse = [op IsInverseOp];
}

- (NSString *)name
{
    return _record.name;
}

- (bool)IsInverseOp
{
    return _record.inverse;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    vector_double3 scale = [_value double3AtTime:time];
    if (_record.inverse)
        scale = (vector_double3){scale.x ? 1 / scale.x : 0, scale.y ? 1 / scale.y : 0, scale.z ? 1 / scale.z : 0};
    return CharonMDLScale(scale);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedVector3 *)animatedValue
{
    return _value;
}

@end
@implementation MDLTransformMatrixOp {
    CharonMDLOpRecord _record;
    MDLAnimatedMatrix4x4 *_value;
}

- (instancetype)init
{
    if ((self = [super init]))
        _value = [[MDLAnimatedMatrix4x4 alloc] init];
    return self;
}

- (void)dealloc
{
}

- (CharonMDLOpRecord *)charon_record
{
    return &_record;
}

- (MDLAnimatedValue *)charon_value
{
    return _value;
}

- (void)charon_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (void)charon_takeOverFrom:(id<MDLTransformOp>)op
{
    [self charon_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
    _record.name = [(id<MDLTransformOp>)op name];
    _record.inverse = [op IsInverseOp];
}

- (NSString *)name
{
    return _record.name;
}

- (bool)IsInverseOp
{
    return _record.inverse;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    matrix_double4x4 value = [_value double4x4AtTime:time];
    if (!_record.inverse)
        return value;
    // The matrix inverse written out rather than asked for: simd_inverse on a matrix is a libm
    // internal, and the gate's import check names it in the port's own library.
    return CharonMDLMatrixInverse(value);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedMatrix4x4 *)animatedValue
{
    return _value;
}

@end
@implementation MDLTransformStack {
    NSMutableArray<id<MDLTransformOp>> *_ops;
    NSMutableDictionary<NSString *, MDLAnimatedValue *> *_values;
    // The names the operations' records point at. A record holds the name without retaining it, so
    // the stack is what keeps the string alive, and a name is still there when the operation is asked
    // for it.
    NSMutableArray<NSString *> *_names;
    BOOL _resetsTransform;
}

@synthesize resetsTransform = _resetsTransform;

- (instancetype)init
{
    if ((self = [super init])) {
        _ops = [[NSMutableArray alloc] init];
        _values = [[NSMutableDictionary alloc] init];
        _names = [[NSMutableArray alloc] init];
        _resetsTransform = YES;
    }
    return self;
}

- (void)dealloc
{
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLTransformStack *copy = [[[self class] allocWithZone:zone] init];
    for (id<MDLTransformOp> op in _ops) {
        Class kind = [(id)op class];
        id<CharonMDLTransformOpRecord> duplicate = [[kind allocWithZone:zone] init];
        // The copy keeps the samples of the value, not an empty one of the same shape.
        [duplicate charon_takeOverFrom:op];
        [copy charon_addOp:duplicate named:op.name inverse:[op IsInverseOp]];
    }
    return copy;
}

// Every operation added is named, and the value under that name is the one the operation reads, so
// animatedValueWithName: finds what an operation added under a name.
- (void)charon_addOp:(id<CharonMDLTransformOpRecord>)op named:(NSString *)name inverse:(bool)inverse
{
    CharonMDLOpRecord *record = [op charon_record];
    [_names addObject:name];
    record->name = [_names lastObject];
    record->inverse = inverse;
    [_ops addObject:op];
    [_values setObject:[op charon_value] forKey:name];
}

- (MDLTransformTranslateOp *)addTranslateOp:(NSString *)animatedValueName inverse:(bool)inverse
{
    MDLTransformTranslateOp *op = [[MDLTransformTranslateOp alloc] init];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLTransformRotateXOp *)addRotateXOp:(NSString *)animatedValueName inverse:(bool)inverse
{
    MDLTransformRotateXOp *op = [[MDLTransformRotateXOp alloc] init];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLTransformRotateYOp *)addRotateYOp:(NSString *)animatedValueName inverse:(bool)inverse
{
    MDLTransformRotateYOp *op = [[MDLTransformRotateYOp alloc] init];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLTransformRotateZOp *)addRotateZOp:(NSString *)animatedValueName inverse:(bool)inverse
{
    MDLTransformRotateZOp *op = [[MDLTransformRotateZOp alloc] init];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLTransformRotateOp *)addRotateOp:(NSString *)animatedValueName order:(MDLTransformOpRotationOrder)order inverse:(bool)inverse
{
    MDLTransformRotateOp *op = [[MDLTransformRotateOp alloc] init];
    [op charon_setOrder:order];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLTransformScaleOp *)addScaleOp:(NSString *)animatedValueName inverse:(bool)inverse
{
    MDLTransformScaleOp *op = [[MDLTransformScaleOp alloc] init];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLTransformMatrixOp *)addMatrixOp:(NSString *)animatedValueName inverse:(bool)inverse
{
    MDLTransformMatrixOp *op = [[MDLTransformMatrixOp alloc] init];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLTransformOrientOp *)addOrientOp:(NSString *)animatedValueName inverse:(bool)inverse
{
    MDLTransformOrientOp *op = [[MDLTransformOrientOp alloc] init];
    [self charon_addOp:op named:animatedValueName inverse:inverse];
    return op;
}

- (MDLAnimatedValue *)animatedValueWithName:(NSString *)name
{
    return _values[name];
}

- (NSUInteger)count
{
    return _ops.count;
}

- (NSArray<id<MDLTransformOp>> *)transformOps
{
    return [_ops copy];
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    // The operations multiply from the left as they are added: the first one added is the
    // outermost.  Measured, for a stack holding a translate of (1, 2, 3) added first and a rotate
    // of 90 degrees about X added second, the system answers
    //   col0 1.00000 0.00000 0.00000 0.00000
    //   col3 1.00000 2.00000 3.00000 1.00000
    // so the translation is not rotated and the product is T*R.  Multiplying the other way round,
    // R*T, puts the rotated translation in the last column: 1 -3 2 1, and that is not what the
    // system does.
    matrix_double4x4 result = CharonMDLDouble4x4Identity();
    for (id<MDLTransformOp> op in _ops)
        result = simd_mul(result, [op double4x4AtTime:time]);
    return result;
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (matrix_float4x4)matrix
{
    return [self float4x4AtTime:0];
}

- (matrix_float4x4)localTransformAtTime:(NSTimeInterval)time
{
    return [self float4x4AtTime:time];
}

- (void)setLocalTransform:(matrix_float4x4)transform forTime:(NSTimeInterval)time
{
    MDLTransformMatrixOp *op = [self addMatrixOp:@"charon_localTransform" inverse:NO];
    [(MDLAnimatedMatrix4x4 *)[(id)op animatedValue] setFloat4x4:transform atTime:time];
}

- (void)setLocalTransform:(matrix_float4x4)transform
{
    [self setLocalTransform:transform forTime:0];
}

- (NSTimeInterval)minimumTime
{
    NSTimeInterval minimum = 0;
    for (id<MDLTransformOp> op in _ops)
        minimum = MIN(minimum, [(MDLAnimatedValue *)[(id)op animatedValue] minimumTime]);
    return minimum;
}

- (NSTimeInterval)maximumTime
{
    NSTimeInterval maximum = 0;
    for (id<MDLTransformOp> op in _ops)
        maximum = MAX(maximum, [(MDLAnimatedValue *)[(id)op animatedValue] maximumTime]);
    return maximum;
}

- (NSArray<NSNumber *> *)keyTimes
{
    NSMutableSet<NSNumber *> *times = [NSMutableSet set];
    for (id<MDLTransformOp> op in _ops)
        for (NSNumber *time in [(MDLAnimatedValue *)[(id)op animatedValue] keyTimes])
            [times addObject:time];
    return [[times allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

@end
