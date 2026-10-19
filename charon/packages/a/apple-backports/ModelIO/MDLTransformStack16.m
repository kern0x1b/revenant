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

@implementation MDLTransformOrientOp {
    CharonMDLOpRecord _record;
    MDLAnimatedQuaternion *_value;
}

- (instancetype)init
{
    if ((self = [super init]))
        _value = [[MDLAnimatedQuaternion alloc] init];
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
    simd_quatd rotation = [_value doubleQuaternionAtTime:time];
    return CharonMDLQuaternionMatrix(rotation);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return CharonMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedQuaternion *)animatedValue
{
    return _value;
}

@end
