#import "RevenantMetal.h"
#import "RevenantMetalProtocols.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface MTLRasterizationRateSampleArray ()
{
    NSMutableArray *_samples;
}
@end

@interface MTLRasterizationRateLayerDescriptor ()
{
    MTLRasterizationRateSampleArray *_horizontal;
    MTLRasterizationRateSampleArray *_vertical;
    MTLSize _sampleCount;
    MTLSize _maxSampleCount;
    float *_horizontalSampleStorage;
    float *_verticalSampleStorage;
}
@end

@interface MTLRasterizationRateLayerArray ()
{
    NSMutableArray *_layers;
}
- (NSUInteger)count;
@end

@interface MTLRasterizationRateMapDescriptor ()
{
    MTLRasterizationRateLayerArray *_layers;
    MTLSize _screenSize;
}
@end

@implementation MTLRasterizationRateSampleArray

- (instancetype)init
{
    if ((self = [super init])) { _samples = [[NSMutableArray alloc] init]; }
    return self;
}

- (NSNumber *)objectAtIndexedSubscript:(NSUInteger)index
{
    return index < [_samples count] ? [_samples objectAtIndex:index] : nil;
}

- (void)setObject:(NSNumber *)value atIndexedSubscript:(NSUInteger)index
{
    while ([_samples count] <= index) { [_samples addObject:[NSNull null]]; }
    if (value == nil) {
        [_samples replaceObjectAtIndex:index withObject:[NSNull null]];
    } else {
        [_samples replaceObjectAtIndex:index withObject:(id)value];
    }
}

@end

@implementation MTLRasterizationRateLayerDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        _horizontal = [[MTLRasterizationRateSampleArray alloc] init];
        _vertical = [[MTLRasterizationRateSampleArray alloc] init];
        _sampleCount = MTLSizeMake(0, 0, 0);
        _maxSampleCount = MTLSizeMake(0, 0, 0);
    }
    return self;
}

- (instancetype)initWithSampleCount:(MTLSize)sampleCount
{
    if ((self = [self init])) {
        _sampleCount = sampleCount;
    }
    return self;
}

@synthesize sampleCount = _sampleCount;
@synthesize maxSampleCount = _maxSampleCount;
@synthesize horizontal = _horizontal;
@synthesize vertical = _vertical;
@synthesize horizontalSampleStorage = _horizontalSampleStorage;
@synthesize verticalSampleStorage = _verticalSampleStorage;

@end

@implementation MTLRasterizationRateLayerArray

- (instancetype)init
{
    if ((self = [super init])) { _layers = [[NSMutableArray alloc] init]; }
    return self;
}

- (NSUInteger)count
{
    NSUInteger run = 0;
    for (id v in _layers) {
        if (v == [NSNull null]) { break; }
        run++;
    }
    return run;
}

- (MTLRasterizationRateLayerDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    if (index >= [_layers count]) { return nil; }
    id v = [_layers objectAtIndex:index];
    return v == [NSNull null] ? nil : v;
}

- (void)setObject:(MTLRasterizationRateLayerDescriptor *)layer atIndexedSubscript:(NSUInteger)index
{
    while ([_layers count] <= index) { [_layers addObject:[NSNull null]]; }
    [_layers replaceObjectAtIndex:index withObject:(layer ? (id)layer : (id)[NSNull null])];
}

@end

@implementation MTLRasterizationRateMapDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        _layers = [[MTLRasterizationRateLayerArray alloc] init];
        _screenSize = MTLSizeMake(0, 0, 0);
    }
    return self;
}

@synthesize layers = _layers;
@synthesize screenSize = _screenSize;

- (NSUInteger)layerCount
{
    return [_layers count];
}

- (MTLRasterizationRateLayerDescriptor *)layerAtIndex:(NSUInteger)layerIndex
{
    return [_layers objectAtIndexedSubscript:layerIndex];
}

- (void)setLayer:(MTLRasterizationRateLayerDescriptor *)layer atIndex:(NSUInteger)layerIndex
{
    [_layers setObject:layer atIndexedSubscript:layerIndex];
}

@end
