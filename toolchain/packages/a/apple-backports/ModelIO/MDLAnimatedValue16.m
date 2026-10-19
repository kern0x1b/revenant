#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"


typedef struct {
    NSTimeInterval time;
    double component[16];
} RevenantMDLSample;

@interface MDLAnimatedQuaternion ()
- (void)revenant_setComponents:(const double *)value atTime:(NSTimeInterval)time;
- (void)revenant_getComponents:(double *)value atTime:(NSTimeInterval)time;
@property (nonatomic) NSUInteger revenant_componentCount;
@property (nonatomic) BOOL revenant_doublePrecision;
@end

@interface MDLAnimatedValue ()
@property (nonatomic) NSUInteger revenant_componentCount;
@property (nonatomic) RevenantMDLSample *revenant_samples;
@property (nonatomic) NSUInteger revenant_sampleCount;
@property (nonatomic) NSUInteger revenant_sampleCapacity;
@property (nonatomic) BOOL revenant_doublePrecision;
@end

@implementation MDLAnimatedQuaternion

- (instancetype)init
{
    if ((self = [super init]))
        self.revenant_componentCount = 4;
    return self;
}

- (void)setFloatQuaternion:(simd_quatf)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.vector.x, value.vector.y, value.vector.z, value.vector.w};
    [self revenant_setComponents:components atTime:time];
}

- (void)setDoubleQuaternion:(simd_quatd)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.vector.x, value.vector.y, value.vector.z, value.vector.w};
    self.revenant_doublePrecision = YES;
    [self revenant_setComponents:components atTime:time];
}

- (simd_quatf)floatQuaternionAtTime:(NSTimeInterval)time
{
    double components[4];
    [self revenant_getComponents:components atTime:time];
    return simd_quaternion((float)components[0], (float)components[1], (float)components[2], (float)components[3]);
}

- (simd_quatd)doubleQuaternionAtTime:(NSTimeInterval)time
{
    double components[4];
    [self revenant_getComponents:components atTime:time];
    return simd_quaternion(components[0], components[1], components[2], components[3]);
}

@end
