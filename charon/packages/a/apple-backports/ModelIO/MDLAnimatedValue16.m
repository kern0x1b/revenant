#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"


typedef struct {
    NSTimeInterval time;
    double component[16];
} CharonMDLSample;

@interface MDLAnimatedQuaternion ()
- (void)charon_setComponents:(const double *)value atTime:(NSTimeInterval)time;
- (void)charon_getComponents:(double *)value atTime:(NSTimeInterval)time;
@property (nonatomic) NSUInteger charon_componentCount;
@property (nonatomic) BOOL charon_doublePrecision;
@end

@interface MDLAnimatedValue ()
@property (nonatomic) NSUInteger charon_componentCount;
@property (nonatomic) CharonMDLSample *charon_samples;
@property (nonatomic) NSUInteger charon_sampleCount;
@property (nonatomic) NSUInteger charon_sampleCapacity;
@property (nonatomic) BOOL charon_doublePrecision;
@end

@implementation MDLAnimatedQuaternion

- (instancetype)init
{
    if ((self = [super init]))
        self.charon_componentCount = 4;
    return self;
}

- (void)setFloatQuaternion:(simd_quatf)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.vector.x, value.vector.y, value.vector.z, value.vector.w};
    [self charon_setComponents:components atTime:time];
}

- (void)setDoubleQuaternion:(simd_quatd)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.vector.x, value.vector.y, value.vector.z, value.vector.w};
    self.charon_doublePrecision = YES;
    [self charon_setComponents:components atTime:time];
}

- (simd_quatf)floatQuaternionAtTime:(NSTimeInterval)time
{
    double components[4];
    [self charon_getComponents:components atTime:time];
    return simd_quaternion((float)components[0], (float)components[1], (float)components[2], (float)components[3]);
}

- (simd_quatd)doubleQuaternionAtTime:(NSTimeInterval)time
{
    double components[4];
    [self charon_getComponents:components atTime:time];
    return simd_quaternion(components[0], components[1], components[2], components[3]);
}

@end
