#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

typedef struct {
    NSTimeInterval time;
    double component[16];
} RevenantMDLSample;

@interface MDLAnimatedValue ()
@property (nonatomic) NSUInteger revenant_componentCount;
@property (nonatomic) RevenantMDLSample *revenant_samples;
@property (nonatomic) NSUInteger revenant_sampleCount;
@property (nonatomic) NSUInteger revenant_sampleCapacity;
@property (nonatomic) BOOL revenant_doublePrecision;
@end

@implementation MDLAnimatedValue

- (instancetype)init
{
    if ((self = [super init])) {
        self.revenant_sampleCapacity = 4;
        self.revenant_samples = calloc(self.revenant_sampleCapacity, sizeof(RevenantMDLSample));
        self.interpolation = MDLAnimatedValueInterpolationLinear;
    }
    return self;
}

- (void)dealloc
{
    free(self.revenant_samples);
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLAnimatedValue *copy = [[[self class] allocWithZone:zone] init];
    copy.revenant_componentCount = self.revenant_componentCount;
    copy.revenant_doublePrecision = self.revenant_doublePrecision;
    copy.interpolation = self.interpolation;
    [copy revenant_setSamples:self.revenant_samples count:self.revenant_sampleCount];
    return copy;
}

- (void)revenant_setSamples:(RevenantMDLSample *)samples count:(NSUInteger)count
{
    free(self.revenant_samples);
    self.revenant_sampleCapacity = count ? count : 1;
    self.revenant_samples = calloc(self.revenant_sampleCapacity, sizeof(RevenantMDLSample));
    if (samples && count)
        memcpy(self.revenant_samples, samples, count * sizeof(RevenantMDLSample));
    self.revenant_sampleCount = count;
}

- (void)revenant_locate:(NSTimeInterval)time atIndex:(NSUInteger *)index fraction:(double *)fraction
{
    NSUInteger count = self.revenant_sampleCount;
    if (count == 0) {
        *index = 0;
        *fraction = 0;
        return;
    }
    if (time <= self.revenant_samples[0].time) {
        *index = 0;
        *fraction = 0;
        return;
    }
    if (time >= self.revenant_samples[count - 1].time) {
        *index = count - 1;
        *fraction = 0;
        return;
    }
    NSUInteger low = 0, high = count - 1;
    while (high - low > 1) {
        NSUInteger middle = (low + high) / 2;
        if (self.revenant_samples[middle].time <= time)
            low = middle;
        else
            high = middle;
    }
    *index = low;
    NSTimeInterval span = self.revenant_samples[high].time - self.revenant_samples[low].time;
    *fraction = span > 0 ? (time - self.revenant_samples[low].time) / span : 0;
}

- (void)revenant_setComponents:(const double *)value atTime:(NSTimeInterval)time
{
    NSUInteger components = self.revenant_componentCount;
    if (!components) {
        components = 1;
        self.revenant_componentCount = 1;
    }
    NSUInteger index;
    double fraction;
    [self revenant_locate:time atIndex:&index fraction:&fraction];
    if (self.revenant_sampleCount && self.revenant_samples[index].time == time) {
        for (NSUInteger k = 0; k < components; k++)
            self.revenant_samples[index].component[k] = value[k];
        return;
    }
    if (self.revenant_sampleCount == self.revenant_sampleCapacity) {
        self.revenant_sampleCapacity *= 2;
        self.revenant_samples = realloc(self.revenant_samples, self.revenant_sampleCapacity * sizeof(RevenantMDLSample));
    }
    NSUInteger at = self.revenant_sampleCount;
    for (NSUInteger k = 0; k < self.revenant_sampleCount; k++)
        if (self.revenant_samples[k].time > time) {
            at = k;
            break;
        }
    for (NSUInteger k = self.revenant_sampleCount; k > at; k--)
        self.revenant_samples[k] = self.revenant_samples[k - 1];
    self.revenant_samples[at].time = time;
    for (NSUInteger k = 0; k < components; k++)
        self.revenant_samples[at].component[k] = value[k];
    self.revenant_sampleCount++;
}

- (void)revenant_getComponents:(double *)value atTime:(NSTimeInterval)time
{
    NSUInteger components = self.revenant_componentCount;
    for (NSUInteger k = 0; k < components; k++)
        value[k] = 0;
    if (!self.revenant_sampleCount)
        return;
    NSUInteger index;
    double fraction;
    [self revenant_locate:time atIndex:&index fraction:&fraction];
    if (!fraction || self.interpolation == MDLAnimatedValueInterpolationConstant) {
        for (NSUInteger k = 0; k < components; k++)
            value[k] = self.revenant_samples[index].component[k];
        return;
    }
    for (NSUInteger k = 0; k < components; k++)
        value[k] = self.revenant_samples[index].component[k] * (1 - fraction) + self.revenant_samples[index + 1].component[k] * fraction;
}

- (BOOL)isAnimated
{
    return self.revenant_sampleCount > 1;
}

- (MDLDataPrecision)precision
{
    return self.revenant_doublePrecision ? MDLDataPrecisionDouble : MDLDataPrecisionFloat;
}

- (NSUInteger)timeSampleCount
{
    return self.revenant_sampleCount;
}

- (NSArray<NSNumber *> *)keyTimes
{
    NSMutableArray<NSNumber *> *times = [NSMutableArray arrayWithCapacity:self.revenant_sampleCount];
    for (NSUInteger k = 0; k < self.revenant_sampleCount; k++)
        [times addObject:@(self.revenant_samples[k].time)];
    return times;
}

- (NSTimeInterval)minimumTime
{
    return self.revenant_sampleCount ? self.revenant_samples[0].time : 0;
}

- (NSTimeInterval)maximumTime
{
    return self.revenant_sampleCount ? self.revenant_samples[self.revenant_sampleCount - 1].time : 0;
}

- (void)clear
{
    self.revenant_sampleCount = 0;
}

@end
@implementation MDLAnimatedScalarArray {
    NSUInteger _elementCount;
}

@synthesize elementCount = _elementCount;

- (instancetype)initWithElementCount:(NSUInteger)arrayElementCount
{
    if ((self = [super init]))
        _elementCount = arrayElementCount;
    return self;
}

@end
@implementation MDLAnimatedVector3Array {
    NSUInteger _elementCount;
}

@synthesize elementCount = _elementCount;

- (instancetype)initWithElementCount:(NSUInteger)arrayElementCount
{
    if ((self = [super init]))
        _elementCount = arrayElementCount;
    return self;
}

@end
@implementation MDLAnimatedQuaternionArray {
    NSUInteger _elementCount;
}

@synthesize elementCount = _elementCount;

- (instancetype)initWithElementCount:(NSUInteger)arrayElementCount
{
    if ((self = [super init]))
        _elementCount = arrayElementCount;
    return self;
}

@end
@implementation MDLAnimatedScalar

- (instancetype)init
{
    if ((self = [super init]))
        self.revenant_componentCount = 1;
    return self;
}

- (void)setFloat:(float)value atTime:(NSTimeInterval)time
{
    double components[1] = {value};
    [self revenant_setComponents:components atTime:time];
}

- (void)setDouble:(double)value atTime:(NSTimeInterval)time
{
    double components[1] = {value};
    self.revenant_doublePrecision = YES;
    [self revenant_setComponents:components atTime:time];
}

- (float)floatAtTime:(NSTimeInterval)time
{
    double components[1];
    [self revenant_getComponents:components atTime:time];
    return (float)components[0];
}

- (double)doubleAtTime:(NSTimeInterval)time
{
    double components[1];
    [self revenant_getComponents:components atTime:time];
    return components[0];
}

@end
@implementation MDLAnimatedVector2

- (instancetype)init
{
    if ((self = [super init]))
        self.revenant_componentCount = 2;
    return self;
}

- (void)setFloat2:(vector_float2)value atTime:(NSTimeInterval)time
{
    double components[2] = {value.x, value.y};
    [self revenant_setComponents:components atTime:time];
}

- (void)setDouble2:(vector_double2)value atTime:(NSTimeInterval)time
{
    double components[2] = {value.x, value.y};
    self.revenant_doublePrecision = YES;
    [self revenant_setComponents:components atTime:time];
}

- (vector_float2)float2AtTime:(NSTimeInterval)time
{
    double components[2];
    [self revenant_getComponents:components atTime:time];
    return (vector_float2){(float)components[0], (float)components[1]};
}

- (vector_double2)double2AtTime:(NSTimeInterval)time
{
    double components[2];
    [self revenant_getComponents:components atTime:time];
    return (vector_double2){components[0], components[1]};
}

@end
@implementation MDLAnimatedVector3

- (instancetype)init
{
    if ((self = [super init]))
        self.revenant_componentCount = 3;
    return self;
}

- (void)setFloat3:(vector_float3)value atTime:(NSTimeInterval)time
{
    double components[3] = {value.x, value.y, value.z};
    [self revenant_setComponents:components atTime:time];
}

- (void)setDouble3:(vector_double3)value atTime:(NSTimeInterval)time
{
    double components[3] = {value.x, value.y, value.z};
    self.revenant_doublePrecision = YES;
    [self revenant_setComponents:components atTime:time];
}

- (vector_float3)float3AtTime:(NSTimeInterval)time
{
    double components[3];
    [self revenant_getComponents:components atTime:time];
    return (vector_float3){(float)components[0], (float)components[1], (float)components[2]};
}

- (vector_double3)double3AtTime:(NSTimeInterval)time
{
    double components[3];
    [self revenant_getComponents:components atTime:time];
    return (vector_double3){components[0], components[1], components[2]};
}

@end
@implementation MDLAnimatedVector4

- (instancetype)init
{
    if ((self = [super init]))
        self.revenant_componentCount = 4;
    return self;
}

- (void)setFloat4:(vector_float4)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.x, value.y, value.z, value.w};
    [self revenant_setComponents:components atTime:time];
}

- (void)setDouble4:(vector_double4)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.x, value.y, value.z, value.w};
    self.revenant_doublePrecision = YES;
    [self revenant_setComponents:components atTime:time];
}

- (vector_float4)float4AtTime:(NSTimeInterval)time
{
    double components[4];
    [self revenant_getComponents:components atTime:time];
    return (vector_float4){(float)components[0], (float)components[1], (float)components[2], (float)components[3]};
}

- (vector_double4)double4AtTime:(NSTimeInterval)time
{
    double components[4];
    [self revenant_getComponents:components atTime:time];
    return (vector_double4){components[0], components[1], components[2], components[3]};
}

@end
@implementation MDLAnimatedMatrix4x4

- (instancetype)init
{
    if ((self = [super init]))
        self.revenant_componentCount = 16;
    return self;
}

- (void)setFloat4x4:(matrix_float4x4)value atTime:(NSTimeInterval)time
{
    double components[16];
    for (size_t k = 0; k < 16; k++)
        components[k] = value.columns[k / 4][k % 4];
    [self revenant_setComponents:components atTime:time];
}

- (void)setDouble4x4:(matrix_double4x4)value atTime:(NSTimeInterval)time
{
    double components[16];
    for (size_t k = 0; k < 16; k++)
        components[k] = value.columns[k / 4][k % 4];
    self.revenant_doublePrecision = YES;
    [self revenant_setComponents:components atTime:time];
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    double components[16];
    [self revenant_getComponents:components atTime:time];
    matrix_float4x4 value;
    for (size_t k = 0; k < 16; k++)
        value.columns[k / 4][k % 4] = (float)components[k];
    return value;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    double components[16];
    [self revenant_getComponents:components atTime:time];
    matrix_double4x4 value;
    for (size_t k = 0; k < 16; k++)
        value.columns[k / 4][k % 4] = components[k];
    return value;
}

@end
