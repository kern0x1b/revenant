#import <ModelIO/ModelIO.h>
#import <simd/simd.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// One sample of an animated value: a time and the components of the value at it. Every concrete
// class keeps its samples in this one shape, so the base's keyTimes, its interpolation between two
// samples and its lookup are written once and each class only converts to and from its own type.

typedef struct {
    NSTimeInterval time;
    double component[16];
} CharonMDLSample;

@interface MDLAnimatedValue ()
@property (nonatomic) NSUInteger charon_componentCount;
@property (nonatomic) CharonMDLSample *charon_samples;
@property (nonatomic) NSUInteger charon_sampleCount;
@property (nonatomic) NSUInteger charon_sampleCapacity;
@property (nonatomic) BOOL charon_doublePrecision;
@end

@implementation MDLAnimatedValue

- (instancetype)init
{
    if ((self = [super init])) {
        self.charon_sampleCapacity = 4;
        self.charon_samples = calloc(self.charon_sampleCapacity, sizeof(CharonMDLSample));
        self.interpolation = MDLAnimatedValueInterpolationLinear;
    }
    return self;
}

- (void)dealloc
{
    free(self.charon_samples);
}

- (id)copyWithZone:(NSZone *)zone
{
    MDLAnimatedValue *copy = [[[self class] allocWithZone:zone] init];
    copy.charon_componentCount = self.charon_componentCount;
    copy.charon_doublePrecision = self.charon_doublePrecision;
    copy.interpolation = self.interpolation;
    [copy charon_setSamples:self.charon_samples count:self.charon_sampleCount];
    return copy;
}

// A private setter, so the copy above and the setters of the concrete classes share one append.
- (void)charon_setSamples:(CharonMDLSample *)samples count:(NSUInteger)count
{
    free(self.charon_samples);
    self.charon_sampleCapacity = count ? count : 1;
    self.charon_samples = calloc(self.charon_sampleCapacity, sizeof(CharonMDLSample));
    if (samples && count)
        memcpy(self.charon_samples, samples, count * sizeof(CharonMDLSample));
    self.charon_sampleCount = count;
}

// The index of the sample at or before the time, and how far the time lies between it and the next
// one. A time before the first sample or after the last one is the first or the last sample, which
// is what the host's animated values hold past their own range.
- (void)charon_locate:(NSTimeInterval)time atIndex:(NSUInteger *)index fraction:(double *)fraction
{
    NSUInteger count = self.charon_sampleCount;
    if (count == 0) {
        *index = 0;
        *fraction = 0;
        return;
    }
    if (time <= self.charon_samples[0].time) {
        *index = 0;
        *fraction = 0;
        return;
    }
    if (time >= self.charon_samples[count - 1].time) {
        *index = count - 1;
        *fraction = 0;
        return;
    }
    NSUInteger low = 0, high = count - 1;
    while (high - low > 1) {
        NSUInteger middle = (low + high) / 2;
        if (self.charon_samples[middle].time <= time)
            low = middle;
        else
            high = middle;
    }
    *index = low;
    NSTimeInterval span = self.charon_samples[high].time - self.charon_samples[low].time;
    *fraction = span > 0 ? (time - self.charon_samples[low].time) / span : 0;
}

- (void)charon_setComponents:(const double *)value atTime:(NSTimeInterval)time
{
    NSUInteger components = self.charon_componentCount;
    if (!components) {
        // The base class itself holds no value of a shape of its own; a sample of it is one component.
        components = 1;
        self.charon_componentCount = 1;
    }
    NSUInteger index;
    double fraction;
    [self charon_locate:time atIndex:&index fraction:&fraction];
    // A sample already at this time is this value, not a second one beside it.
    if (self.charon_sampleCount && self.charon_samples[index].time == time) {
        for (NSUInteger k = 0; k < components; k++)
            self.charon_samples[index].component[k] = value[k];
        return;
    }
    if (self.charon_sampleCount == self.charon_sampleCapacity) {
        self.charon_sampleCapacity *= 2;
        self.charon_samples = realloc(self.charon_samples, self.charon_sampleCapacity * sizeof(CharonMDLSample));
    }
    NSUInteger at = self.charon_sampleCount;
    for (NSUInteger k = 0; k < self.charon_sampleCount; k++)
        if (self.charon_samples[k].time > time) {
            at = k;
            break;
        }
    for (NSUInteger k = self.charon_sampleCount; k > at; k--)
        self.charon_samples[k] = self.charon_samples[k - 1];
    self.charon_samples[at].time = time;
    for (NSUInteger k = 0; k < components; k++)
        self.charon_samples[at].component[k] = value[k];
    self.charon_sampleCount++;
}

- (void)charon_getComponents:(double *)value atTime:(NSTimeInterval)time
{
    NSUInteger components = self.charon_componentCount;
    for (NSUInteger k = 0; k < components; k++)
        value[k] = 0;
    if (!self.charon_sampleCount)
        return;
    NSUInteger index;
    double fraction;
    [self charon_locate:time atIndex:&index fraction:&fraction];
    if (!fraction || self.interpolation == MDLAnimatedValueInterpolationConstant) {
        for (NSUInteger k = 0; k < components; k++)
            value[k] = self.charon_samples[index].component[k];
        return;
    }
    for (NSUInteger k = 0; k < components; k++)
        value[k] = self.charon_samples[index].component[k] * (1 - fraction) + self.charon_samples[index + 1].component[k] * fraction;
}

- (BOOL)isAnimated
{
    return self.charon_sampleCount > 1;
}

- (MDLDataPrecision)precision
{
    return self.charon_doublePrecision ? MDLDataPrecisionDouble : MDLDataPrecisionFloat;
}

- (NSUInteger)timeSampleCount
{
    return self.charon_sampleCount;
}

- (NSArray<NSNumber *> *)keyTimes
{
    NSMutableArray<NSNumber *> *times = [NSMutableArray arrayWithCapacity:self.charon_sampleCount];
    for (NSUInteger k = 0; k < self.charon_sampleCount; k++)
        [times addObject:@(self.charon_samples[k].time)];
    return times;
}

- (NSTimeInterval)minimumTime
{
    return self.charon_sampleCount ? self.charon_samples[0].time : 0;
}

- (NSTimeInterval)maximumTime
{
    return self.charon_sampleCount ? self.charon_samples[self.charon_sampleCount - 1].time : 0;
}

- (void)clear
{
    self.charon_sampleCount = 0;
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
        self.charon_componentCount = 1;
    return self;
}

- (void)setFloat:(float)value atTime:(NSTimeInterval)time
{
    double components[1] = {value};
    [self charon_setComponents:components atTime:time];
}

- (void)setDouble:(double)value atTime:(NSTimeInterval)time
{
    double components[1] = {value};
    self.charon_doublePrecision = YES;
    [self charon_setComponents:components atTime:time];
}

- (float)floatAtTime:(NSTimeInterval)time
{
    double components[1];
    [self charon_getComponents:components atTime:time];
    return (float)components[0];
}

- (double)doubleAtTime:(NSTimeInterval)time
{
    double components[1];
    [self charon_getComponents:components atTime:time];
    return components[0];
}

@end
@implementation MDLAnimatedVector2

- (instancetype)init
{
    if ((self = [super init]))
        self.charon_componentCount = 2;
    return self;
}

- (void)setFloat2:(vector_float2)value atTime:(NSTimeInterval)time
{
    double components[2] = {value.x, value.y};
    [self charon_setComponents:components atTime:time];
}

- (void)setDouble2:(vector_double2)value atTime:(NSTimeInterval)time
{
    double components[2] = {value.x, value.y};
    self.charon_doublePrecision = YES;
    [self charon_setComponents:components atTime:time];
}

- (vector_float2)float2AtTime:(NSTimeInterval)time
{
    double components[2];
    [self charon_getComponents:components atTime:time];
    return (vector_float2){(float)components[0], (float)components[1]};
}

- (vector_double2)double2AtTime:(NSTimeInterval)time
{
    double components[2];
    [self charon_getComponents:components atTime:time];
    return (vector_double2){components[0], components[1]};
}

@end
@implementation MDLAnimatedVector3

- (instancetype)init
{
    if ((self = [super init]))
        self.charon_componentCount = 3;
    return self;
}

- (void)setFloat3:(vector_float3)value atTime:(NSTimeInterval)time
{
    double components[3] = {value.x, value.y, value.z};
    [self charon_setComponents:components atTime:time];
}

- (void)setDouble3:(vector_double3)value atTime:(NSTimeInterval)time
{
    double components[3] = {value.x, value.y, value.z};
    self.charon_doublePrecision = YES;
    [self charon_setComponents:components atTime:time];
}

- (vector_float3)float3AtTime:(NSTimeInterval)time
{
    double components[3];
    [self charon_getComponents:components atTime:time];
    return (vector_float3){(float)components[0], (float)components[1], (float)components[2]};
}

- (vector_double3)double3AtTime:(NSTimeInterval)time
{
    double components[3];
    [self charon_getComponents:components atTime:time];
    return (vector_double3){components[0], components[1], components[2]};
}

@end
@implementation MDLAnimatedVector4

- (instancetype)init
{
    if ((self = [super init]))
        self.charon_componentCount = 4;
    return self;
}

- (void)setFloat4:(vector_float4)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.x, value.y, value.z, value.w};
    [self charon_setComponents:components atTime:time];
}

- (void)setDouble4:(vector_double4)value atTime:(NSTimeInterval)time
{
    double components[4] = {value.x, value.y, value.z, value.w};
    self.charon_doublePrecision = YES;
    [self charon_setComponents:components atTime:time];
}

- (vector_float4)float4AtTime:(NSTimeInterval)time
{
    double components[4];
    [self charon_getComponents:components atTime:time];
    return (vector_float4){(float)components[0], (float)components[1], (float)components[2], (float)components[3]};
}

- (vector_double4)double4AtTime:(NSTimeInterval)time
{
    double components[4];
    [self charon_getComponents:components atTime:time];
    return (vector_double4){components[0], components[1], components[2], components[3]};
}

@end
@implementation MDLAnimatedMatrix4x4

- (instancetype)init
{
    if ((self = [super init]))
        self.charon_componentCount = 16;
    return self;
}

- (void)setFloat4x4:(matrix_float4x4)value atTime:(NSTimeInterval)time
{
    double components[16];
    for (size_t k = 0; k < 16; k++)
        components[k] = value.columns[k / 4][k % 4];
    [self charon_setComponents:components atTime:time];
}

- (void)setDouble4x4:(matrix_double4x4)value atTime:(NSTimeInterval)time
{
    double components[16];
    for (size_t k = 0; k < 16; k++)
        components[k] = value.columns[k / 4][k % 4];
    self.charon_doublePrecision = YES;
    [self charon_setComponents:components atTime:time];
}

- (matrix_float4x4)float4x4AtTime:(NSTimeInterval)time
{
    double components[16];
    [self charon_getComponents:components atTime:time];
    matrix_float4x4 value;
    for (size_t k = 0; k < 16; k++)
        value.columns[k / 4][k % 4] = (float)components[k];
    return value;
}

- (matrix_double4x4)double4x4AtTime:(NSTimeInterval)time
{
    double components[16];
    [self charon_getComponents:components atTime:time];
    matrix_double4x4 value;
    for (size_t k = 0; k < 16; k++)
        value.columns[k / 4][k % 4] = components[k];
    return value;
}

@end
