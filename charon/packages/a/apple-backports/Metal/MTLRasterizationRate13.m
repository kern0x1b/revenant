#import "CharonMetal.h"
#import "CharonMetalProtocols.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
// The header marks -init API_UNAVAILABLE and -initWithSampleCount: the DESIGNATED initializer, so the
// port has to override -init to give a fresh layer its two sample arrays and cannot say so in an
// interface the SDK already owns. That is two initializer warnings by construction, so they are
// silenced HERE and named, the way MTLHeap10.m silences its own.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// THE RASTERIZATION-RATE FAMILY, the part of it that is a plain data holder.
//
// A rasterization-rate MAP says how densely a render target is sampled: how many layers it has, and
// per layer a grid of sample rates. So the whole of it is numbers and two small containers, and none
// of it asks a device anything. THAT IS THE CASE FOR CARRYING IT, and it is why this unit needs no
// device: a caller building a map writes a layer count, a screen size and some sample rates, and
// reads the same numbers back.
//
// THE THREE CLASSES ARE MUTUALLY DEPENDENT and land together: the descriptor OWNS the layer array,
// and a layer descriptor OWNS the two sample arrays, so a map without them and a layer without its
// samples are not the family. MTLRasterizationRateMap - the object a device makes out of a map - is
// NOT here; it is a reader over device-made state and belongs with the device work.
//
// NO DEVICE IS CREATED anywhere in this file or its case: a descriptor asks a device nothing, which
// facts/Metal/DeviceOnThisMachine.md measures.

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
// The port's own: the header gives this class two indexed members and no count, and the map's
// readonly layerCount is DERIVED from the array, so the array needs a way to say how many it holds.
- (NSUInteger)count;
@end

@interface MTLRasterizationRateMapDescriptor ()
{
    MTLRasterizationRateLayerArray *_layers;
    MTLSize _screenSize;
}
@end

// THE SAMPLE ARRAY holds NSNumber, exactly as the header says, and grows to the index written so a
// read past the end is nil rather than a trap - which is NSArray's own behaviour and what the case
// compares against Apple's.
@implementation MTLRasterizationRateSampleArray

// THE SAME -init THIS CLASS NEEDED AND DID NOT HAVE. Its NSMutableArray ivar was never created, and
// -setObject:atIndexedSubscript: grows the storage in a while loop: a message to nil does not advance
// the count, so the loop never ends. Writing one sample into a fresh array hung, and the layer array
// above hung the same way for the same reason. Both containers now create their own storage, and
// neither has a member that can grow without it.
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

// The header makes -init API_UNAVAILABLE and -initWithSampleCount:horizontal:vertical: the
// designated initializer, so the port does the same: a layer is made with its sample count, and the
// two sample arrays exist from the start. A fresh one reads the enumeration's own zero for both
// counts, which is what the case compares against Apple's own fresh object.
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

// THE STORAGE IS CREATED HERE, and it had to be: this class had no -init of its own, so its
// NSMutableArray ivar was never created and -setLayer:atIndex: on a map sent addObject: and
// replaceObjectAtIndex: to nil. That does not crash and it does not loop - it leaves the map
// with no layers and no count, which is the quiet nothing a test that only reads a count
// would sail past. The map already made one, so the array was the half that never existed.
- (instancetype)init
{
    if ((self = [super init])) { _layers = [[NSMutableArray alloc] init]; }
    return self;
}

// THE COUNT IS THE LEADING CONTIGUOUS RUN OF WRITTEN LAYERS, and that is Apple's own answer,
// measured rather than guessed. Writing a layer at index 2 on an empty map makes layerAtIndex:2
// return it while layerCount stays 0; the count reaches 2 only once 0 and 1 are written too; and
// writing at index 5 after one layer leaves the count at 1 with index 5 still readable. A count that
// were merely the array's length would have said 3 and 6, and this was the divergence the review
// asked me to measure and copy.
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

// The header makes -init API_UNAVAILABLE and the class carries a layer array from the start, so a
// fresh map already HAS one - and that is the thing the case checks, because Apple's own fresh
// descriptor answers a non-nil -layers too.
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

// THE LAYER COUNT IS DERIVED, not stored twice: the header declares it readonly and a count that can
// disagree with the array holding the layers is a bug waiting to happen. The array is the truth.
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
