#import <ModelIO/ModelIO.h>
#import "RevenantMDLTransformMath.h"
#import <simd/simd.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

typedef struct {
    __unsafe_unretained NSString *name;
    BOOL inverse;
} RevenantMDLOpRecord;

@protocol RevenantMDLTransformOpRecord <NSObject>
- (RevenantMDLOpRecord *)revenant_record;
- (MDLAnimatedValue *)revenant_value;
- (void)revenant_setAnimatedValue:(MDLAnimatedValue *)value;
- (void)revenant_takeOverFrom:(id<MDLTransformOp>)op;
@end

@interface MDLTransformRotateXOp () <RevenantMDLTransformOpRecord>
@end
@interface MDLTransformRotateYOp () <RevenantMDLTransformOpRecord>
@end
@interface MDLTransformRotateZOp () <RevenantMDLTransformOpRecord>
@end
@interface MDLTransformRotateOp () <RevenantMDLTransformOpRecord>
- (MDLTransformOpRotationOrder)revenant_order;
- (void)revenant_setOrder:(MDLTransformOpRotationOrder)order;
@end
@interface MDLTransformTranslateOp () <RevenantMDLTransformOpRecord>
@end
@interface MDLTransformScaleOp () <RevenantMDLTransformOpRecord>
@end
@interface MDLTransformMatrixOp () <RevenantMDLTransformOpRecord>
@end
@interface MDLTransformOrientOp () <RevenantMDLTransformOpRecord>
@end

@implementation MDLTransformOrientOp {
    RevenantMDLOpRecord _record;
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

- (RevenantMDLOpRecord *)revenant_record
{
    return &_record;
}

- (MDLAnimatedValue *)revenant_value
{
    return _value;
}

- (void)revenant_setAnimatedValue:(MDLAnimatedValue *)value
{
    if (_value != value) {
        _value = (id)value;
    }
}

- (void)revenant_takeOverFrom:(id<MDLTransformOp>)op
{
    [self revenant_setAnimatedValue:[(MDLAnimatedValue *)(MDLAnimatedValue *)[(id)op animatedValue] copy]];
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
    return RevenantMDLQuaternionMatrix(rotation);
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    return RevenantMDLFloat4x4([self double4x4AtTime:time]);
}

- (MDLAnimatedQuaternion *)animatedValue
{
    return _value;
}

@end
