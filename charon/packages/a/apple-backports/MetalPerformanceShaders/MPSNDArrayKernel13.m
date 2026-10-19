#import "CharonMPSNDArray.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation MPSNDArrayGradientState {
    NSUInteger _sourceCount;
    NSUInteger _sourceGradientIndex;
    CharonMPSNDArrayFilter *_filters;
    NSUInteger _sourceShapes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS * CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger _sourceDimensions[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger _axis;
    NSString *_recorded;
}


- (void)charon_mps_recordFor:(MPSNDArrayMultiaryBase *)kernel sources:(NSArray<MPSNDArray *> *)sources
{
    NSUInteger count = [sources count];
    if (count > CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        count = CHARON_MPS_NDARRAY_MAX_DIMENSIONS;
    if (count) {
        _filters = (CharonMPSNDArrayFilter *)realloc(_filters, count * sizeof(CharonMPSNDArrayFilter));
        memset(_sourceShapes, 0, sizeof(_sourceShapes));
        memset(_sourceDimensions, 0, sizeof(_sourceDimensions));
        for (NSUInteger i = 0; i < count; i++) {
            MPSNDArray *source = [sources objectAtIndex:i];
            _filters[i] = [kernel charon_mps_filterAtSourceIndex:i];
            _sourceDimensions[i] = source ? source.numberOfDimensions : 0;
            for (NSUInteger d = 0; d < _sourceDimensions[i] && d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++)
                _sourceShapes[i * CHARON_MPS_NDARRAY_MAX_DIMENSIONS + d] = [source lengthOfDimension:d];
        }
        _sourceCount = count;
    }
    _sourceGradientIndex = [kernel charon_mps_sourceGradientIndex];
    _axis = [kernel conformsToProtocol:@protocol(CharonMPSNDArrayAxisKernel)]
         ? (NSUInteger)[(id<CharonMPSNDArrayAxisKernel>)kernel axis] : 0;
    _recorded = [NSString stringWithFormat:@"%lu sources, gradient of source %lu",
                    (unsigned long)_sourceCount, (unsigned long)_sourceGradientIndex];
}

- (CharonMPSNDArrayFilter)charon_mps_filterOfSource:(NSUInteger)index
{
    if (!_filters || index >= _sourceCount)
        return CharonMPSNDArrayDefaultFilter();
    return _filters[index];
}

- (NSUInteger)charon_mps_dimensionsOfSource:(NSUInteger)index
{
    if (!_filters || index >= _sourceCount)
        return 0;
    return _sourceDimensions[index];
}

- (NSUInteger)charon_mps_axis { return _axis; }

- (NSUInteger)charon_mps_lengthOfSource:(NSUInteger)index dimension:(NSUInteger)dimension
{
    if (!_filters || index >= _sourceCount || dimension >= CHARON_MPS_NDARRAY_MAX_DIMENSIONS)
        return 1;
    return _sourceShapes[index * CHARON_MPS_NDARRAY_MAX_DIMENSIONS + dimension];
}

- (void)dealloc
{
    free(_filters);
}

@end

@implementation MPSNDArrayMultiaryBase {
    NSUInteger _sourceCount;
    CharonMPSNDArrayFilter *_filters;
    id<MPSNDArrayAllocator> _destinationArrayAllocator;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device sourceCount:(NSUInteger)count
{
    if ((self = [super initWithDevice:device])) {
        _sourceCount = count;
        if (count) {
            _filters = (CharonMPSNDArrayFilter *)malloc(count * sizeof(CharonMPSNDArrayFilter));
            for (NSUInteger i = 0; i < count; i++)
                _filters[i] = CharonMPSNDArrayDefaultFilter();
        }
        _destinationArrayAllocator = [MPSNDArray defaultAllocator];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    NSLog(@"MPSNDArrayMultiaryBase: -initWithDevice: names no source count; use -initWithDevice:sourceCount:, "
          @"which MPSNDArrayUnaryKernel's -initWithDevice: calls with one");
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super initWithCoder:aDecoder device:device])) {
        _sourceCount = (NSUInteger)[aDecoder decodeIntegerForKey:@"sourceCount"];
        if (_sourceCount) {
            _filters = (CharonMPSNDArrayFilter *)malloc(_sourceCount * sizeof(CharonMPSNDArrayFilter));
            for (NSUInteger i = 0; i < _sourceCount; i++) {
                _filters[i] = CharonMPSNDArrayDefaultFilter();
                for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++) {
                    NSString *key = [NSString stringWithFormat:@"offsets.%lu.%lu", (unsigned long)i, (unsigned long)d];
                    if ([aDecoder containsValueForKey:key])
                        _filters[i].offsets[d] = (NSInteger)[aDecoder decodeIntegerForKey:key];
                }
            }
        }
        _destinationArrayAllocator = [MPSNDArray defaultAllocator];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeInt64:(int64_t)_sourceCount forKey:@"sourceCount"];
    for (NSUInteger i = 0; _filters && i < _sourceCount; i++) {
        for (NSUInteger d = 0; d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++) {
            NSString *key = [NSString stringWithFormat:@"offsets.%lu.%lu", (unsigned long)i, (unsigned long)d];
            [aCoder encodeInt64:(int64_t)_filters[i].offsets[d] forKey:key];
        }
    }
}

- (id<MPSNDArrayAllocator>)destinationArrayAllocator
{
    return _destinationArrayAllocator;
}

- (void)setDestinationArrayAllocator:(id<MPSNDArrayAllocator>)destinationArrayAllocator
{
    _destinationArrayAllocator = destinationArrayAllocator;
}

- (CharonMPSNDArrayFilter)charon_mps_filterAtSourceIndex:(NSUInteger)sourceIndex
{
    if (!_filters || sourceIndex >= _sourceCount)
        return CharonMPSNDArrayDefaultFilter();
    return _filters[sourceIndex];
}

- (void)charon_mps_setFilter:(CharonMPSNDArrayFilter)filter atSourceIndex:(NSUInteger)sourceIndex
{
    if (!_filters || sourceIndex >= _sourceCount)
        return;
    _filters[sourceIndex] = filter;
}

- (NSUInteger)charon_mps_sourceCount { return _sourceCount; }

- (NSUInteger)charon_mps_sourceGradientIndex { return 0; }

- (MPSNDArrayOffsets)offsetsAtSourceIndex:(NSUInteger)sourceIndex
{
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:sourceIndex];
    MPSNDArrayOffsets offsets;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        offsets.dimensions[i] = filter.offsets[i];
    return offsets;
}

- (MPSImageEdgeMode)edgeModeAtSourceIndex:(NSUInteger)sourceIndex
{
    return [self charon_mps_filterAtSourceIndex:sourceIndex].edgeMode;
}

- (MPSNDArraySizes)kernelSizesForSourceIndex:(NSUInteger)sourceIndex
{
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:sourceIndex];
    MPSNDArraySizes sizes;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        sizes.dimensions[i] = filter.kernelSizes[i];
    return sizes;
}

- (MPSNDArrayOffsets)stridesForSourceIndex:(NSUInteger)sourceIndex
{
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:sourceIndex];
    MPSNDArrayOffsets strides;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        strides.dimensions[i] = filter.strides[i];
    return strides;
}

- (MPSNDArraySizes)dilationRatesForSourceIndex:(NSUInteger)sourceIndex
{
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:sourceIndex];
    MPSNDArraySizes rates;
    for (NSUInteger i = 0; i < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; i++)
        rates.dimensions[i] = filter.dilationRates[i];
    return rates;
}

- (MPSNDArrayDescriptor *)destinationArrayDescriptorForSourceArrays:(NSArray<MPSNDArray *> *)sources
                                                         sourceState:(MPSState *)state
{
    (void)state;
    if (![sources count])
        return nil;
    MPSNDArray *last = [sources lastObject];
    CharonMPSNDArrayFilter filter = [self charon_mps_filterAtSourceIndex:[sources count] - 1];
    NSUInteger sizes[CHARON_MPS_NDARRAY_MAX_DIMENSIONS];
    NSUInteger dimensions = last.numberOfDimensions;
    for (NSUInteger d = 0; d < dimensions && d < CHARON_MPS_NDARRAY_MAX_DIMENSIONS; d++) {
        NSInteger extent = (NSInteger)[last lengthOfDimension:d];
        NSInteger kernel = (NSInteger)filter.kernelSizes[d];
        NSInteger stride = filter.strides[d] ? filter.strides[d] : 1;
        NSInteger dilation = (NSInteger)filter.dilationRates[d] ? filter.dilationRates[d] : 1;
        NSInteger span = 1 + (kernel - 1) * dilation;
        NSInteger produced = (extent - span) / stride + 1;
        sizes[d] = (NSUInteger)(produced > 0 ? produced : 0);
    }
    return [MPSNDArrayDescriptor descriptorWithDataType:last.dataType dimensionCount:dimensions dimensionSizes:sizes];
}

- (MPSState *)resultStateForSourceArrays:(NSArray<MPSNDArray *> *)sources
                             sourceStates:(NSArray<MPSState *> *)sourceStates
                         destinationArray:(MPSNDArray *)destinationArray
{
    (void)sourceStates;
    (void)destinationArray;
    MPSNDArrayGradientState *state = [[MPSNDArrayGradientState alloc] initWithResource:nil];
    [state charon_mps_recordFor:self sources:sources];
    return state;
}

- (id)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device
{
    MPSNDArrayMultiaryBase *copy = [[[self class] allocWithZone:zone] initWithDevice:(device ? device : self.device)
                                                                    sourceCount:_sourceCount];
    for (NSUInteger i = 0; i < _sourceCount; i++)
        [copy charon_mps_setFilter:[self charon_mps_filterAtSourceIndex:i] atSourceIndex:i];
    copy.destinationArrayAllocator = _destinationArrayAllocator;
    return copy;
}

- (void)dealloc
{
    free(_filters);
}

@end

@implementation MPSNDArrayMultiaryKernel

- (BOOL)charon_mps_run:(NSArray<MPSNDArray *> *)sources state:(MPSState *)state destination:(MPSNDArray *)destination
{
    if (![sources count]) {
        CharonMPSRefuse(@"%@: an encode was given no source arrays", NSStringFromClass([self class]));
        return NO;
    }
    NSUInteger count = [sources count];
    CharonMPSNDArrayLayout *layouts = (CharonMPSNDArrayLayout *)calloc(count, sizeof(CharonMPSNDArrayLayout));
    if (!layouts)
        return NO;
    BOOL usable = YES;
    for (NSUInteger i = 0; i < count; i++) {
        NSString *what = [NSString stringWithFormat:@"%@: source %lu", NSStringFromClass([self class]), (unsigned long)i];
        if (!CharonMPSNDArrayTake([sources objectAtIndex:i], &layouts[i], what)) {
            usable = NO;
            break;
        }
    }
    if (usable) {
        if (destination) {
            CharonMPSNDArrayLayout out;
            if (!CharonMPSNDArrayTake(destination, &out, [NSString stringWithFormat:@"%@: destination", NSStringFromClass([self class])]))
                usable = NO;
            else {
                [self charon_mps_fillFromSources:layouts count:count state:state into:&out];
                CharonMPSNDArrayPut(destination, &out);
            }
        }
    }
    for (NSUInteger i = 0; i < count; i++)
        CharonMPSNDArrayGive(&layouts[i]);
    free(layouts);
    for (NSUInteger i = 0; i < count; i++)
        CharonMPSConsumeReadCount([sources objectAtIndex:i]);
    return usable;
}

- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(CharonMPSNDArrayLayout *)destination
{
    (void)sources;
    (void)count;
    (void)state;
    CharonMPSRefuse(@"%@: this class declares no arithmetic, so nothing was written. A subclass writes "
                    @"-charon_mps_fillFromSources:count:into:, which is where MPSNDArrayGather, "
                    @"MPSNDArrayStridedSlice and MPSNDArrayMatrixMultiplication put theirs",
                    NSStringFromClass([self class]));
    (void)destination;
}

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf sourceArrays:(NSArray<MPSNDArray *> *)sourceArrays
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return nil;
    MPSNDArrayDescriptor *descriptor = [self destinationArrayDescriptorForSourceArrays:sourceArrays sourceState:nil];
    if (!descriptor)
        return nil;
    id<MTLDevice> device = [cmdBuf respondsToSelector:@selector(device)] ? [cmdBuf device] : self.device;
    MPSNDArray *destination = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
    [self encodeToCommandBuffer:cmdBuf sourceArrays:sourceArrays destinationArray:destination];
    return destination;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                sourceArrays:(NSArray<MPSNDArray *> *)sourceArrays
            destinationArray:(MPSNDArray *)destination
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return;
    [self charon_mps_run:sourceArrays state:nil destination:destination];
}

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                        sourceArrays:(NSArray<MPSNDArray *> *)sourceArrays
                        resultState:(MPSState * __autoreleasing *)outGradientState
             outputStateIsTemporary:(BOOL)outputStateIsTemporary
{
    (void)outputStateIsTemporary;
    MPSNDArray *destination = [self encodeToCommandBuffer:cmdBuf sourceArrays:sourceArrays];
    if (outGradientState) {
        *outGradientState = [self resultStateForSourceArrays:sourceArrays sourceStates:nil destinationArray:destination];
    }
    return destination;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                sourceArrays:(NSArray<MPSNDArray *> *)sourceArrays
                 resultState:(MPSState *)outGradientState
            destinationArray:(MPSNDArray *)destination
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return;
    if (outGradientState && [outGradientState isKindOfClass:[MPSNDArrayGradientState class]])
        [(MPSNDArrayGradientState *)outGradientState charon_mps_recordFor:self sources:sourceArrays];
    [self charon_mps_run:sourceArrays state:outGradientState destination:destination];
}

@end

@implementation MPSNDArrayMultiaryGradientKernel {
    NSUInteger _sourceGradientIndex;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  sourceCount:(NSUInteger)count
          sourceGradientIndex:(NSUInteger)sourceGradientIndex
{
    if ((self = [super initWithDevice:device sourceCount:count])) {
        _sourceGradientIndex = sourceGradientIndex;
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device sourceCount:(NSUInteger)count
{
    NSLog(@"MPSNDArrayMultiaryGradientKernel: -initWithDevice:sourceCount: names no sourceGradientIndex; "
          @"use -initWithDevice:sourceCount:sourceGradientIndex:");
    (void)device;
    (void)count;
    return nil;
}

- (NSUInteger)charon_mps_sourceGradientIndex { return _sourceGradientIndex; }

- (void)charon_mps_fillFromSources:(CharonMPSNDArrayLayout *)sources count:(NSUInteger)count state:(MPSState *)state into:(CharonMPSNDArrayLayout *)destination
{
    (void)count;
    (void)state;
    CharonMPSRefuse(@"%@: this class declares no gradient arithmetic, so nothing was written. A "
                    @"subclass writes -charon_mps_fillFromSources:count:into:, which is where "
                    @"MPSNDArrayGatherGradient and MPSNDArrayStridedSliceGradient put theirs",
                    NSStringFromClass([self class]));
    (void)sources;
    (void)destination;
}

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                        sourceArrays:(NSArray<MPSNDArray *> *)sourceArrays
                      sourceGradient:(MPSNDArray *)gradient
                       gradientState:(MPSState *)state
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return nil;
    MPSNDArrayDescriptor *descriptor = [gradient descriptor];
    id<MTLDevice> device = [cmdBuf respondsToSelector:@selector(device)] ? [cmdBuf device] : self.device;
    MPSNDArray *destination = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
    [self encodeToCommandBuffer:cmdBuf sourceArrays:sourceArrays sourceGradient:gradient
                    gradientState:state destinationArray:destination];
    return destination;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                sourceArrays:(NSArray<MPSNDArray *> *)sourceArrays
              sourceGradient:(MPSNDArray *)gradient
               gradientState:(MPSState *)state
            destinationArray:(MPSNDArray *)destination
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return;
    NSMutableArray *sources = [NSMutableArray arrayWithArray:sourceArrays];
    [sources addObject:gradient];
    CharonMPSNDArrayLayout *layouts = (CharonMPSNDArrayLayout *)calloc([sources count], sizeof(CharonMPSNDArrayLayout));
    if (!layouts)
        return;
    BOOL usable = YES;
    for (NSUInteger i = 0; i < [sources count]; i++) {
        NSString *what = [NSString stringWithFormat:@"%@: gradient source %lu", NSStringFromClass([self class]), (unsigned long)i];
        if (!CharonMPSNDArrayTake([sources objectAtIndex:i], &layouts[i], what)) {
            usable = NO;
            break;
        }
    }
    if (usable) {
        CharonMPSNDArrayLayout out;
        if (destination) {
            if (!CharonMPSNDArrayTake(destination, &out, [NSString stringWithFormat:@"%@: destination", NSStringFromClass([self class])]))
                usable = NO;
            else {
                [self charon_mps_fillFromSources:layouts count:[sources count] state:state into:&out];
                CharonMPSNDArrayPut(destination, &out);
            }
        }
    }
    for (NSUInteger i = 0; i < [sources count]; i++)
        CharonMPSNDArrayGive(&layouts[i]);
    free(layouts);
    for (NSUInteger i = 0; i < [sources count]; i++)
        CharonMPSConsumeReadCount([sources objectAtIndex:i]);
}

@end

@implementation MPSNDArrayUnaryKernel

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device sourceCount:1];
}

- (MPSNDArrayOffsets)offsets { return [self offsetsAtSourceIndex:0]; }
- (MPSImageEdgeMode)edgeMode { return [self edgeModeAtSourceIndex:0]; }
- (MPSNDArraySizes)kernelSizes { return [self kernelSizesForSourceIndex:0]; }
- (MPSNDArrayOffsets)strides { return [self stridesForSourceIndex:0]; }
- (MPSNDArraySizes)dilationRates { return [self dilationRatesForSourceIndex:0]; }

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf sourceArray:(MPSNDArray *)sourceArray
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return nil;
    NSArray *sources = [NSArray arrayWithObject:sourceArray];
    MPSNDArrayDescriptor *descriptor = [self destinationArrayDescriptorForSourceArrays:sources sourceState:nil];
    if (!descriptor)
        return nil;
    id<MTLDevice> device = [cmdBuf respondsToSelector:@selector(device)] ? [cmdBuf device] : self.device;
    MPSNDArray *destination = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
    [self encodeToCommandBuffer:cmdBuf sourceArray:sourceArray destinationArray:destination];
    return destination;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                  sourceArray:(MPSNDArray *)sourceArray
             destinationArray:(MPSNDArray *)destination
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return;
    [self charon_mps_run:[NSArray arrayWithObject:sourceArray] state:nil destination:destination];
}

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                          sourceArray:(MPSNDArray *)sourceArray
                         resultState:(MPSState * __autoreleasing *)outGradientState
              outputStateIsTemporary:(BOOL)outputStateIsTemporary
{
    (void)outputStateIsTemporary;
    MPSNDArray *destination = [self encodeToCommandBuffer:cmdBuf sourceArray:sourceArray];
    if (outGradientState)
        *outGradientState = [self resultStateForSourceArrays:[NSArray arrayWithObject:sourceArray]
                                                 sourceStates:nil
                                             destinationArray:destination];
    return destination;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                  sourceArray:(MPSNDArray *)sourceArray
                 resultState:(MPSState *)outGradientState
            destinationArray:(MPSNDArray *)destination
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return;
    if (outGradientState && [outGradientState isKindOfClass:[MPSNDArrayGradientState class]])
        [(MPSNDArrayGradientState *)outGradientState charon_mps_recordFor:self
                                                                 sources:[NSArray arrayWithObject:sourceArray]];
    [self charon_mps_run:[NSArray arrayWithObject:sourceArray] state:outGradientState destination:destination];
}

@end

@implementation MPSNDArrayUnaryGradientKernel

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device sourceCount:1 sourceGradientIndex:0];
}

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                           sourceArray:(MPSNDArray *)sourceArray
                        sourceGradient:(MPSNDArray *)gradient
                         gradientState:(MPSState *)state
{
    return [self encodeToCommandBuffer:cmdBuf sourceArrays:[NSArray arrayWithObject:sourceArray]
                        sourceGradient:gradient gradientState:state];
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                  sourceArray:(MPSNDArray *)sourceArray
               sourceGradient:(MPSNDArray *)gradient
                gradientState:(MPSState *)state
             destinationArray:(MPSNDArray *)destination
{
    [self encodeToCommandBuffer:cmdBuf sourceArrays:[NSArray arrayWithObject:sourceArray]
                  sourceGradient:gradient gradientState:state destinationArray:destination];
}

@end

@implementation MPSNDArrayBinaryKernel

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device sourceCount:2];
}

- (MPSNDArrayOffsets)primaryOffsets { return [self offsetsAtSourceIndex:0]; }
- (MPSImageEdgeMode)primaryEdgeMode { return [self edgeModeAtSourceIndex:0]; }
- (MPSNDArraySizes)primaryKernelSizes { return [self kernelSizesForSourceIndex:0]; }
- (MPSNDArrayOffsets)primaryStrides { return [self stridesForSourceIndex:0]; }
- (MPSNDArraySizes)primaryDilationRates { return [self dilationRatesForSourceIndex:0]; }
- (MPSNDArrayOffsets)secondaryOffsets { return [self offsetsAtSourceIndex:1]; }
- (MPSImageEdgeMode)secondaryEdgeMode { return [self edgeModeAtSourceIndex:1]; }
- (MPSNDArraySizes)secondaryKernelSizes { return [self kernelSizesForSourceIndex:1]; }
- (MPSNDArrayOffsets)secondaryStrides { return [self stridesForSourceIndex:1]; }
- (MPSNDArraySizes)secondaryDilationRates { return [self dilationRatesForSourceIndex:1]; }

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                   primarySourceArray:(MPSNDArray *)primarySourceArray
                 secondarySourceArray:(MPSNDArray *)secondarySourceArray
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return nil;
    NSArray *sources = [NSArray arrayWithObjects:primarySourceArray, secondarySourceArray, nil];
    MPSNDArrayDescriptor *descriptor = [self destinationArrayDescriptorForSourceArrays:sources sourceState:nil];
    if (!descriptor)
        return nil;
    id<MTLDevice> device = [cmdBuf respondsToSelector:@selector(device)] ? [cmdBuf device] : self.device;
    MPSNDArray *destination = [[MPSNDArray alloc] initWithDevice:device descriptor:descriptor];
    [self encodeToCommandBuffer:cmdBuf primarySourceArray:primarySourceArray
               secondarySourceArray:secondarySourceArray destinationArray:destination];
    return destination;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
           primarySourceArray:(MPSNDArray *)primarySourceArray
         secondarySourceArray:(MPSNDArray *)secondarySourceArray
             destinationArray:(MPSNDArray *)destination
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return;
    [self charon_mps_run:[NSArray arrayWithObjects:primarySourceArray, secondarySourceArray, nil] state:nil
             destination:destination];
}

- (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                   primarySourceArray:(MPSNDArray *)primarySourceArray
                 secondarySourceArray:(MPSNDArray *)secondarySourceArray
                          resultState:(MPSState * __autoreleasing *)outGradientState
               outputStateIsTemporary:(BOOL)outputStateIsTemporary
{
    (void)outputStateIsTemporary;
    NSArray *sources = [NSArray arrayWithObjects:primarySourceArray, secondarySourceArray, nil];
    MPSNDArray *destination = [self encodeToCommandBuffer:cmdBuf primarySourceArray:primarySourceArray
                                       secondarySourceArray:secondarySourceArray];
    if (outGradientState)
        *outGradientState = [self resultStateForSourceArrays:sources sourceStates:nil destinationArray:destination];
    return destination;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
           primarySourceArray:(MPSNDArray *)primarySourceArray
         secondarySourceArray:(MPSNDArray *)secondarySourceArray
                  resultState:(MPSState *)outGradientState
             destinationArray:(MPSNDArray *)destination
{
    if (!CharonMPSCommandBufferPermits(cmdBuf))
        return;
    NSArray *sources = [NSArray arrayWithObjects:primarySourceArray, secondarySourceArray, nil];
    if (outGradientState && [outGradientState isKindOfClass:[MPSNDArrayGradientState class]])
        [(MPSNDArrayGradientState *)outGradientState charon_mps_recordFor:self sources:sources];
    [self charon_mps_run:sources state:outGradientState destination:destination];
}

@end

#define CHARON_MPS_BINARY_GRADIENT_ENCODES                                              \
    - (MPSNDArray *)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf                 \
                       primarySourceArray:(MPSNDArray *)primarySourceArray             \
                     secondarySourceArray:(MPSNDArray *)secondarySourceArray           \
                           sourceGradient:(MPSNDArray *)gradient                        \
                            gradientState:(MPSState *)state                              \
    {                                                                                  \
        return [self encodeToCommandBuffer:cmdBuf                                      \
                                 sourceArrays:[NSArray arrayWithObjects:primarySourceArray, \
                                                               secondarySourceArray, nil] \
                               sourceGradient:gradient gradientState:state];            \
    }                                                                                  \
                                                                                       \
    - (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cmdBuf                         \
                primarySourceArray:(MPSNDArray *)primarySourceArray                     \
              secondarySourceArray:(MPSNDArray *)secondarySourceArray                   \
                    sourceGradient:(MPSNDArray *)gradient                              \
                     gradientState:(MPSState *)state                                    \
                  destinationArray:(MPSNDArray *)destination                            \
    {                                                                                  \
        [self encodeToCommandBuffer:cmdBuf                                              \
                      sourceArrays:[NSArray arrayWithObjects:primarySourceArray,       \
                                                    secondarySourceArray, nil]         \
                    sourceGradient:gradient gradientState:state destinationArray:destination]; \
    }

@implementation MPSNDArrayBinaryPrimaryGradientKernel

CHARON_MPS_BINARY_GRADIENT_ENCODES

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device sourceCount:2 sourceGradientIndex:0];
}

@end

@implementation MPSNDArrayBinarySecondaryGradientKernel

CHARON_MPS_BINARY_GRADIENT_ENCODES

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return [super initWithDevice:device sourceCount:2 sourceGradientIndex:1];
}

@end
