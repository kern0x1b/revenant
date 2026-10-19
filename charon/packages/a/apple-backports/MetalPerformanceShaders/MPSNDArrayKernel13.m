// The NDArray kernel base classes of iOS 13: MPSNDArrayMultiaryBase and the three that descend from
// it, the unary and binary specialisations of each, and MPSNDArrayGradientState. From
// MPSNDArray/MPSNDArrayKernel.h and MPSNDArray/MPSNDArrayGradientState.h in the SDK of iOS 16.4.
//
// WHAT THESE CLASSES ARE, which is what makes them real rather than declarations. Every one of them
// is ABSTRACT in the release - MPSNDArrayMultiaryBase:92-104 declares offsetsAtSourceIndex:,
// edgeModeAtSourceIndex:, kernelSizesForSourceIndex:, stridesForSourceIndex: and
// dilationRatesForSourceIndex: and no arithmetic at all, and MPSNDArrayMultiaryKernel's encodes take
// list of sources in an NSArray, with the ordering left to the subclass. So the
// arithmetic belongs to a subclass and the classes here own the three things every subclass needs and
// none of them re-implements:
//
//   - the FILTER, per source: the offsets, the kernel sizes, the strides, the dilation rates and the
//     edge mode, with the defaults the header states. MPSNDArrayUnaryKernel's own comment gives the
//     offsets' default as zero in every dimension, the kernelSizes' as 1, the strides' as 1, and
//     the edge mode's as MPSImageEdgeModeZero (MPSNDArrayKernel.h:227-266); MPSNDArrayBinaryKernel repeats all five
//     for a primary and a secondary source (:389-470). Those are stored once, here, and read back
//     through the accessors both spellings have - the plural one on the base and the singular one on
//     the unary and binary forms.
//   - the DESTINATION, which -destinationArrayDescriptorForSourceArrays:sourceState: and
//     -resultStateForSourceArrays:sourceStates:destinationArray: answer. The header is explicit that
//     the object's own properties need to be in place beforehand, since they may affect the results
//     (MPSNDArrayKernel.h:150-157), so the descriptor is built from them and not from the sources
//     alone.
//   - the ENCODE PLUMBING: taking each source into a host buffer, writing the destination back, and
//     the read-count bookkeeping, in one place, so a subclass writes its arithmetic and nothing else.
//
// WHAT A SUBCLASS WRITES is the loop, and the three concrete kernels in MPSNDArrayOps13.m are the
// three that have one. A subclass that does not override the walk is a class the release also has no
// arithmetic for, and its encode refuses and says which class it was rather than writing a number
// nothing computed - which is the same shape MPSMatrixMultiplication10.m's -initWithDevice: takes.

#import "CharonMPSNDArray.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
// Every class in this file is the SUBCLASS the header names, and each of those names
// -initWithDevice:sourceCount: and -initWithCoder:device: as a designated initializer while inheriting
// one of them from a superclass that names a different one. The chain is right - a unary kernel's
// -initWithDevice: IS its base's -initWithDevice:sourceCount: with the count of one - and the warning
// fires on the subclass that forwards rather than re-declares, which is the shape the header asks for.
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


// What the state records is the FILTER and the SHAPES, which is what a gradient pass needs and what
// the header's own use says it records the kernel's properties at the time an encode runs, and that its contents are
// opaque (MPSNDArrayGradientState.h:17-23). That opacity is why this class adds no accessor of its own beyond the ones MPSState already has: a
// gradient kernel is handed the state and asks it, and the only public question a caller can ask of
// an MPSState is the one MPSState answers.
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
    // The axis, which is a property of the FORWARD KERNEL and not of any source: a gather on axis 0 of
    // a [3,2] source by three indices has a result of the SAME shape as its source, so nothing in the
    // two arrays says which axis was gathered, and deriving it from the shapes - which this did first -
    // fails on exactly the case where the index count happens to match. The header's RFC comment above
    // MPSNDArrayUnaryGradientKernel's declarations says where it belongs, and that the gradient state supplies it
    // (MPSNDArrayKernel.h:318-321).
    // So the state records it, read from the kernel through the one selector the release declares for
    // it - `axis`, which is MPSNDArrayGather's own public property (MPSNDArrayGather.h:44-48) - and a
    // kernel that declares no axis answers nothing and the zero is the default.
    _axis = [kernel conformsToProtocol:@protocol(CharonMPSNDArrayAxisKernel)]
         ? (NSUInteger)[(id<CharonMPSNDArrayAxisKernel>)kernel axis] : 0;
    // _recorded is a strong ivar, so this one store is the whole of it: the store retains the string
    // it is given and releases the one it held, which is the pair of messages that stood around it.
    _recorded = [NSString stringWithFormat:@"%lu sources, gradient of source %lu",
                    (unsigned long)_sourceCount, (unsigned long)_sourceGradientIndex];
}

// The recorded filter of one source, which is the whole of what a gradient pass reads. A state that
// recorded nothing answers the DEFAULTS, so a gradient kernel handed a state no forward pass made
// computes against a unit filter and no offset rather than reading uninitialised memory.
- (CharonMPSNDArrayFilter)charon_mps_filterOfSource:(NSUInteger)index
{
    if (!_filters || index >= _sourceCount)
        return CharonMPSNDArrayDefaultFilter();
    return _filters[index];
}

// The recorded shape of one source, in dimensions then lengths.
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

// The free is all that is left of -dealloc here, and it is not a choice: _filters is a malloc'd
// array of CharonMPSNDArrayFilter, a C struct, so no reference to it was ever anything ARC owned and
// this is the only place it is given back. The [_recorded release] and the [super dealloc] that
// stood beside it were both deleting ARC's own work - the first for a strong ivar, the second
// because ARC calls it itself.
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
        // HELD, and that is not a style choice. +[MPSNDArray defaultAllocator] answers the same
        // singleton every time - it is a class method on one class, so it has one answer to give -
        // and the ivar has to OWN a reference to it. Under ARC a strong ivar is exactly that: the
        // store below retains it and gives it back when this object goes away. Storing it with no
        // ownership at all made the second kernel ever built take the singleton's own retain count
        // down, and the harness found it as a SIGSEGV in objc_release at the end of the first case
        // that built one and let it go.
        _destinationArrayAllocator = [MPSNDArray defaultAllocator];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    // The header marks this unavailable: -(nonnull instancetype) initWithDevice: NS_UNAVAILABLE
    // (MPSNDArrayKernel.h:85), and gives -initWithDevice:sourceCount: as the designated initializer
    // that replaces it (:89-93). A count of one is the unary form's answer and the header's own
    // MPSNDArrayUnaryKernel declares -initWithDevice: as ITS designated initializer, so a caller that
    // reaches this one has asked for a filter that reads some number of sources and named none.
    NSLog(@"MPSNDArrayMultiaryBase: -initWithDevice: names no source count; use -initWithDevice:sourceCount:, "
          @"which MPSNDArrayUnaryKernel's -initWithDevice: calls with one");
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // The header's second designated initializer (:96-99). The filter and the source count are the
    // object's own state and the coder is the only record of them, so both are read back here rather
    // than left at the defaults a caller never asked for.
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

// A store to a strong ivar: it retains what it is given and releases what it held, which is the
// release-then-retain of the two lines this replaces, in that order, to the same net ownership - and
// to the same answer when the argument is the allocator already held.
- (void)setDestinationArrayAllocator:(id<MPSNDArrayAllocator>)destinationArrayAllocator
{
    _destinationArrayAllocator = destinationArrayAllocator;
}

// The filter of one source, as the base's five per-source accessors read it. A source index past the
// count this object was made with answers the DEFAULTS rather than reading past the allocation: the
// header's accessors take "The index of the source NDArray to which the list of offsets is applied"
// and the list does not exist for a source that was never counted.
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

// The descriptor a result of these sources has, which is the shape of the LAST source with the
// stride and the dilation already applied - a filter with a stride of two and a kernel of three over
// a 2-D source of 5x5 produces 2x2, and the header's own -destinationArrayDescriptorForSourceArrays:
// the header's -destinationArrayDescriptorForSourceArrays: returns a descriptor for allocating the receiving array, so the result is
// what the descriptor is for. The edge mode does not change the SHAPE here: it decides what a walk
// reads off the end, and the release's -destinationArrayDescriptorForSourceArrays: is asked before an
// encode, so a shape that grew with the edge mode would be a shape no caller asked for.
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
    // The header describes such a state as one that records the kernel's properties as they stood when an encode ran
    // (MPSNDArrayGradientState.h:17-23). So the state this makes is one that recorded THIS object's
    // filter and THESE sources' shapes, which is what a gradient pass reads.
    (void)sourceStates;
    (void)destinationArray;
    // MPSState.h:173 marks -init unavailable, so a state is made through one of the initializers
    // that follow it. -initWithResource: is the one that takes a nullable resource (:172), and a
    // gradient state has no resource: the header says its contents are opaque
    // (MPSNDArrayGradientState.h:17-23), and what it records is the filter and the shapes, both of
    // which are set on the next line. So this is the release's own available path and not a private
    // one invented to get round the annotation.
    // No [.. autorelease]: this method returns an MPSState * and is not a family method, so ARC
    // hands the value back through objc_autoreleaseReturnValue - the same release, at the same
    // point, into the caller's pool - and the local holds it until then.
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

// The free is all that is left of -dealloc here, and it is not a choice: _filters is a malloc'd
// array of CharonMPSNDArrayFilter, a C struct, so no reference to it was ever anything ARC owned and
// this is the only place it is given back. The [_destinationArrayAllocator release] and the
// [super dealloc] that stood beside it were both deleting ARC's own work - the first for a strong
// ivar, the second because ARC calls it itself.
- (void)dealloc
{
    free(_filters);
}

@end

// The walk every subclass of this file shares: take each source, give the subclass a destination
// buffer to fill, write it back. A subclass overrides -charon_mps_fillFromSources:into: and nothing
// else, and this method is what turns that into an encode.
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

// The one a subclass must write. The base class has no arithmetic of its own - the release's declares
// none either - so this is where a class that is not one of the three concrete kernels says so.
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
        // the header says the state for the gradient is stored at the caller's address
        // (MPSNDArrayKernel.h:143-146), so a caller that asked for one gets a state that recorded
        // the filter and the shapes of THIS encode - the same object -resultStateForSourceArrays:
        // hands out, because the two are asked at the same moment about the same object.
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
    // The header marks this unavailable on the gradient kernel (:174-175): "the source index for
    // which gradient will be calculated" is part of what the object IS, and an object that did not
    // know which of its sources it differentiates would be answering a question nobody asked.
    NSLog(@"MPSNDArrayMultiaryGradientKernel: -initWithDevice:sourceCount: names no sourceGradientIndex; "
          @"use -initWithDevice:sourceCount:sourceGradientIndex:");
    (void)device;
    (void)count;
    return nil;
}

- (NSUInteger)charon_mps_sourceGradientIndex { return _sourceGradientIndex; }

// The gradient pass of a multiary kernel. The arithmetic is not here for the same reason it is not on
// the forward pass: MPSNDArrayMultiaryGradientKernel declares only the two encodes
// (MPSNDArrayKernel.h:186-201) and no arithmetic, so the three classes that differentiate a gather and
// a strided slice put their own loops where they belong - in MPSNDArrayOps13.m - and a class with no
// loop says so.
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
    // The gradient array is a source of this pass, and it is the one the read count of a temporary
    // belongs to: a caller that hands a temporary as the gradient has just lent it to this encode.
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
        // The state is READ here and not written. It was made by the forward kernel's own
        // -resultStateForSourceArrays: and it records the FORWARD filter - which is the whole point of
        // the header's "this information is automatically set by the gradient state"
        // (MPSNDArrayKernel.h:318-321). Re-recording it from the gradient kernel replaced the forward
        // strides and offsets with the gradient's own defaults, and a strided slice's gradient then
        // scattered its gradient packed: the harness reported 7 8 9 0 0 where the forward pass read
        // positions 0, 2 and 4.
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
    // -initWithDevice: is this class's own designated initializer (MPSNDArrayKernel.h:270-271), and
    // it is the base's -initWithDevice:sourceCount: with the unary count of one.
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
    // The gradient kernel's own designated initializer is -initWithDevice: (MPSNDArrayKernel.h:332-333)
    // and -initWithDevice:sourceCount:sourceGradientIndex: is marked unavailable on it (:334-335), so
    // the gradient of a unary filter differentiates its only source and the index is 0 - which is what
    // the RFC comment above the declaration says the design costs: the gradient cannot be given this by hand, and
    // the header does not count that as a real cost, because the gradient state fills it in on its own.
    return [super initWithDevice:device sourceCount:1 sourceGradientIndex:0];
}

// The two gradient encodes the UNARY form declares and the multiary one does not:
// -encodeToCommandBuffer:sourceArray:sourceGradient:gradientState: and its destination-taking form
// (MPSNDArrayKernel.h:344-353). The multiary gradient's own pair takes an ARRAY of sources, so
// without these a caller of the header's own unary signature gets '-[MPSNDArrayStridedSliceGradient
// encodeToCommandBuffer:sourceArray:sourceGradient:gradientState:destinationArray:]: unrecognized
// selector' - which the harness reported by name.
//
// The source array is the one the forward pass read, and the gradient is the RESULT's shape, so the
// two are handed on as a one-element array and the walk, the read counts and the state recording all
// happen in the multiary gradient's own implementation.
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
    // The header's own designated initializer for the binary form (:475-476), and the binary count is
    // two - a primary and a secondary source, which is what every one of its encodes takes.
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

// The two ENCODE FORMS the binary gradient declares and the multiary gradient does not:
// -encodeToCommandBuffer:primarySourceArray:secondarySourceArray:sourceGradient:gradientState: and its
// destination-taking form (MPSNDArrayKernel.h:532-539 for the primary, :572-580 for the secondary).
// They are the same two methods on both classes - the header gives both classes the same pair - and
// both forward to the multiary gradient's own implementation with the two sources in one array, so
// the read-count bookkeeping and the state recording happen in one place.
//
// This was missing and the harness found it by name: with only the multiary spellings present, a
// caller of the header's own signature got '-[MPSNDArrayGatherGradient
// encodeToCommandBuffer:primarySourceArray:secondarySourceArray:sourceGradient:gradientState:
// destinationArray:]: unrecognized selector'.
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
    // The gradient of a BINARY filter has two sources and one of them is differentiated, and the
    // header's initializer for that is -initWithDevice: (MPSNDArrayKernel.h:525-526) with
    // -initWithDevice:sourceCount:sourceGradientIndex: marked unavailable above it (:521-523). Which
    // of the two is the primary is what the class name says and what the header's own encode says
    // about its arguments: the pair is "primarySourceArray" and "secondarySourceArray" (:532-539).
    return [super initWithDevice:device sourceCount:2 sourceGradientIndex:0];
}

@end

@implementation MPSNDArrayBinarySecondaryGradientKernel

CHARON_MPS_BINARY_GRADIENT_ENCODES

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    // The same two sources and the same unavailable initializer (:561-563), differentiating the
    // SECONDARY one, which is the only difference between this class and the primary gradient above.
    return [super initWithDevice:device sourceCount:2 sourceGradientIndex:1];
}

@end
