// MLCTensorDescriptor, MLCTensorData, MLCTensorOptimizerDeviceData, MLCTensor and MLCTensorParameter: the
// storage a graph is built out of, and the numbers a program reads back from it.
//
// Every answer here was measured on the host's own MLCompute and is held to it case by case
// (tests/backports/host/mlcompute); facts/MLCompute/Tensors.md carries the table and names the three
// places the port answers differently and why. What the measurements settled:
//
//   - a shape is reported outermost dimension first and the width last, each dimension varying faster
//     than the one before it: +descriptorWithWidth:height:featureChannelCount:batchSize: of 5, 6, 7 and
//     8 answers 8, 7, 6, 5. The stride is in bytes, and the last dimension's stride is the width of one
//     element;
//   - a descriptor of more than +maxTensorDimensions dimensions, of an empty shape or of a shape with a
//     zero in it is nil, and so is one of a data type with no storage. An empty shape is not a nil but an
//     NSRangeException, the one the host raises, because it reads a dimension that is not there;
//   - +descriptorWithShape:sequenceLengths:sortedSequences:dataType: answers a descriptor of nothing - no
//     dimensions, no shape, no lengths - for every pair measured (facts/MLCompute/Tensors.md lists them),
//     and the port answers that rather than inventing a shape the host does not produce. The sequence
//     tensors of +tensorWithSequenceLength: and +tensorWithSequenceLengths: are built by the port's own
//     path, which is the one whose answers were measured: a shape of (batch, steps, features) and the
//     sequence lengths beside it, batchSizePerSequenceStep being the same array;
//   - the data of a tensor is the whole buffer it was given, larger than the tensor or not (measured: a
//     tensor of four floats given a 64-float buffer reports all 64), and nil when it was given none.

#import "CharonMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

// The methods +tensorWithDescriptor: and the sequence factories of MLCTensor reach, declared here because
// the compiler reads a class's own methods in the order they are written and these are written after.
// +charon_descriptorWithSequenceLengths:featureChannelCount:batchSize:sortedSequences:dataType: on
// MLCTensorDescriptor is the same kind of declaration and is defined where it belongs.
@interface MLCTensor (CharonStorage)
- (void)fillWithScalar:(float)value;
- (void)charon_writeBytes:(const void *)bytes length:(NSUInteger)length;
- (void)fillWithRandomInitializerType:(MLCRandomInitializerType)randomInitializerType;
- (MLCTensor *)charon_tensorQuantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias;
- (MLCTensor *)charon_tensorDequantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias;
- (double)charon_scalarOfTensor:(MLCTensor *)tensor inType:(MLCDataType)type;
@end

// The sequence tensor of a length, a channel count and a batch, and whether it is filled: the plain factory
// fills it and the one that takes a data object does not (measured).
@interface MLCTensor (CharonSequences)
+ (instancetype)charon_tensorWithSequenceLength:(NSUInteger)sequenceLength
                            featureChannelCount:(NSUInteger)featureChannelCount
                                      batchSize:(NSUInteger)batchSize
                                         filled:(BOOL)filled;
@end

// The width in bytes of one element. Read from the host by asking for a descriptor of each type and
// looking at the size it answers; a type the host gives no size for has no storage here either.
NSUInteger CharonMLCWidthOfDataType(MLCDataType dataType)
{
    switch (dataType) {
        case MLCDataTypeFloat32:
            return sizeof(float);
        case MLCDataTypeFloat16:
            return sizeof(uint16_t);
        case MLCDataTypeBoolean:
        case MLCDataTypeInt8:
        case MLCDataTypeUInt8:
            return 1;
        case MLCDataTypeInt32:
            return sizeof(int32_t);
        case MLCDataTypeInt64:
            return sizeof(int64_t);
        case MLCDataTypeInvalid:
        case MLCDataTypeCount:
            return 0;
    }
    // The table is the measurement, entry by entry. The two values between the enumerated ones that are
    // neither are not alike: the value 2 has no storage and the framework answers no descriptor for it,
    // while the value 6 has one byte and answers a 4 by 4 of it as 16 bytes. Nothing outside the
    // enumeration and that one has any - measured for -1, 3, 11, 12, 13 and 14, all nil.
    //
    // An earlier version of this generalised the gap into a rule for both of its values, which happened to
    // be right for the pair it was written from and wrong for 6; the cases now ask for each of these
    // values, so it cannot be a two-sample reading again.
    if (dataType == 6) {
        return 1;
    }
    return 0;
}

NSUInteger CharonMLCElementCount(NSArray<NSNumber *> *shape)
{
    if (shape.count == 0) {
        return 0;
    }
    NSUInteger count = 1;
    for (NSNumber *dimension in shape) {
        NSUInteger size = dimension.unsignedIntegerValue;
        if (size == 0) {
            return 0;
        }
        count *= size;
    }
    return count;
}

NSArray<NSNumber *> *CharonMLCStrideOfShape(NSArray<NSNumber *> *shape, MLCDataType dataType)
{
    NSUInteger width = CharonMLCWidthOfDataType(dataType);
    NSMutableArray *stride = [NSMutableArray arrayWithCapacity:shape.count];
    NSUInteger running = width;
    // The stride of the last dimension is the width of one element and each of the others is the product
    // of the dimensions to its right, so the array is built from the end.
    for (NSUInteger index = shape.count; index > 0; index--) {
        [stride insertObject:@(running) atIndex:0];
        running *= shape[index - 1].unsignedIntegerValue;
    }
    return stride;
}

static NSUInteger CharonMLCTensorCounter = 0;

NSUInteger CharonMLCNextTensorID(void)
{
    return CharonMLCTensorCounter++;
}

#pragma mark - MLCTensorDescriptor

@implementation MLCTensorDescriptor {
    MLCDataType _dataType;
    NSArray<NSNumber *> *_shape;
    NSArray<NSNumber *> *_stride;
    NSArray<NSNumber *> *_sequenceLengths;
    BOOL _sortedSequences;
    NSUInteger _dimensionCount;
    NSUInteger _allocationSize;
}

- (instancetype)init
{
    // The one initialiser MLCompute's header marks unavailable and every program finds anyway. It answers a
    // descriptor of nothing: no dimensions and the invalid data type (measured on the host).
    self = [super init];
    if (self) {
        _dataType = MLCDataTypeInvalid;
        _dimensionCount = 0;
        _sortedSequences = NO;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (NSUInteger)maxTensorDimensions
{
    return CHARON_MLC_MAX_DIMENSIONS;
}

+ (instancetype)descriptorWithShape:(NSArray<NSNumber *> *)shape dataType:(MLCDataType)dataType
{
    if (!shape) {
        return nil;
    }
    if (shape.count == 0) {
        [NSException raise:NSRangeException
                    format:@"*** -[__NSArray0 objectAtIndex:]: index 0 beyond bounds for empty array"];
    }
    if (shape.count > CHARON_MLC_MAX_DIMENSIONS) {
        return nil;
    }
    for (NSNumber *dimension in shape) {
        if (dimension.unsignedIntegerValue == 0) {
            return nil;
        }
    }
    // A data type with no storage has no tensor: the host answers nil for a descriptor of one, not a
    // descriptor of nothing (measured for MLCDataTypeInvalid, for the value 2 and for MLCDataTypeCount).
    if (CharonMLCWidthOfDataType(dataType) == 0) {
        return nil;
    }
    MLCTensorDescriptor *descriptor = [[MLCTensorDescriptor alloc] init];
    descriptor->_dataType = dataType;
    descriptor->_dimensionCount = shape.count;
    descriptor->_shape = [shape copy];
    descriptor->_stride = CharonMLCStrideOfShape(shape, dataType);
    descriptor->_allocationSize = CharonMLCElementCount(shape) * CharonMLCWidthOfDataType(dataType);
    return descriptor;
}

+ (instancetype)descriptorWithShape:(NSArray<NSNumber *> *)shape
                    sequenceLengths:(NSArray<NSNumber *> *)sequenceLengths
                    sortedSequences:(BOOL)sortedSequences
                           dataType:(MLCDataType)dataType
{
    // Measured on the host for every pair of arguments tried, this factory answers nil and never a
    // descriptor: (4, 4) with the lengths 3, 2, 1, (3, 2) with 3, 2, 1 and (2, 4) with 2, 1 all answer nil
    // (facts/MLCompute/Tensors.md). The port answers the same, rather than building a descriptor of a shape
    // the framework does not produce for it. The sequence tensors are built by
    // +[MLCTensor tensorWithSequenceLengths:...] below, whose answers were measured.
    return nil;
}

// The path the sequence tensors are built by: a shape of batch, steps and feature channels, and the
// sequence lengths beside it. Not one of MLCompute's own factories, and not exposed as one.
+ (instancetype)charon_descriptorWithSequenceLengths:(NSArray<NSNumber *> *)sequenceLengths
                                    featureChannelCount:(NSUInteger)featureChannelCount
                                              batchSize:(NSUInteger)batchSize
                                     sortedSequences:(BOOL)sortedSequences
                                            dataType:(MLCDataType)dataType
{
    NSUInteger steps = 0;
    for (NSNumber *length in sequenceLengths) {
        steps = MAX(steps, length.unsignedIntegerValue);
    }
    if (steps == 0 || featureChannelCount == 0) {
        return nil;
    }
    MLCTensorDescriptor *descriptor = [self descriptorWithShape:@[ @(batchSize), @(steps), @(featureChannelCount) ] dataType:dataType];
    if (!descriptor) {
        return descriptor;
    }
    descriptor->_sequenceLengths = [sequenceLengths copy];
    descriptor->_sortedSequences = sortedSequences;
    return descriptor;
}

+ (instancetype)descriptorWithWidth:(NSUInteger)width
                             height:(NSUInteger)height
                featureChannelCount:(NSUInteger)featureChannels
                          batchSize:(NSUInteger)batchSize
{
    return [self descriptorWithShape:@[ @(batchSize), @(featureChannels), @(height), @(width) ] dataType:MLCDataTypeFloat32];
}

+ (instancetype)descriptorWithWidth:(NSUInteger)width
                             height:(NSUInteger)height
                featureChannelCount:(NSUInteger)featureChannelCount
                          batchSize:(NSUInteger)batchSize
                           dataType:(MLCDataType)dataType
{
    return [self descriptorWithShape:@[ @(batchSize), @(featureChannelCount), @(height), @(width) ] dataType:dataType];
}

+ (instancetype)convolutionWeightsDescriptorWithWidth:(NSUInteger)width
                                               height:(NSUInteger)height
                             inputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                            outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
                                             dataType:(MLCDataType)dataType
{
    // The weights of a convolution are held as one image of outputFeatureChannelCount times
    // inputFeatureChannelCount channels, which is the shape the host answers (measured: 3 by 3 from 4
    // channels to 5 is 1, 20, 3, 3).
    return [self descriptorWithShape:@[ @1, @(outputFeatureChannelCount * inputFeatureChannelCount), @(height), @(width) ] dataType:dataType];
}

+ (instancetype)convolutionWeightsDescriptorWithInputFeatureChannelCount:(NSUInteger)inputFeatureChannelCount
                                                outputFeatureChannelCount:(NSUInteger)outputFeatureChannelCount
                                                                 dataType:(MLCDataType)dataType
{
    return [self convolutionWeightsDescriptorWithWidth:1
                                               height:1
                             inputFeatureChannelCount:inputFeatureChannelCount
                            outputFeatureChannelCount:outputFeatureChannelCount
                                             dataType:dataType];
}

+ (instancetype)convolutionBiasesDescriptorWithFeatureChannelCount:(NSUInteger)featureChannelCount
                                                         dataType:(MLCDataType)dataType
{
    return [self descriptorWithShape:@[ @1, @(featureChannelCount), @1, @1 ] dataType:dataType];
}

- (MLCDataType)dataType
{
    return _dataType;
}

- (NSUInteger)dimensionCount
{
    return _dimensionCount;
}

- (NSArray<NSNumber *> *)shape
{
    return _shape;
}

- (NSArray<NSNumber *> *)stride
{
    return _stride;
}

- (NSUInteger)tensorAllocationSizeInBytes
{
    return _allocationSize;
}

- (NSArray<NSNumber *> *)sequenceLengths
{
    return _sequenceLengths;
}

- (BOOL)sortedSequences
{
    return _sortedSequences;
}

- (NSArray<NSNumber *> *)batchSizePerSequenceStep
{
    // One entry per step of a sequence, and the number the host answers is the sequence lengths themselves
    // (measured: lengths 3, 2, 1 give a batch of 3, 2, 1 and lengths 3, 3 give a batch of 2, 2, 2).
    return _sequenceLengths;
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCTensorDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy->_dataType = _dataType;
    copy->_shape = [_shape copy];
    copy->_stride = [_stride copy];
    copy->_sequenceLengths = [_sequenceLengths copy];
    copy->_sortedSequences = _sortedSequences;
    copy->_dimensionCount = _dimensionCount;
    copy->_allocationSize = _allocationSize;
    return copy;
}

@end

#pragma mark - MLCTensorData

@implementation MLCTensorData {
    void *_bytes;
    NSUInteger _length;
    void (^_deallocator)(void *bytes, NSUInteger length);
}

- (instancetype)init
{
    // A data object of no bytes at all, which is what the header's unavailable initialiser answers on the
    // host (measured: length 0).
    self = [super init];
    if (self) {
        _bytes = NULL;
        _length = 0;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length
{
    MLCTensorData *data = [[MLCTensorData alloc] init];
    data->_bytes = bytes;
    data->_length = length;
    return data;
}

+ (instancetype)dataWithImmutableBytesNoCopy:(const void *)bytes length:(NSUInteger)length
{
    return [self dataWithBytesNoCopy:(void *)bytes length:length];
}

+ (instancetype)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length deallocator:(void (^)(void *, NSUInteger))deallocator
{
    MLCTensorData *data = [self dataWithBytesNoCopy:bytes length:length];
    data->_deallocator = [deallocator copy];
    return data;
}

- (void *)bytes
{
    return _bytes;
}

- (NSUInteger)length
{
    return _length;
}

- (void)dealloc
{
    if (_deallocator && _bytes) {
        _deallocator(_bytes, _length);
    }
}

@end

#pragma mark - MLCTensorOptimizerDeviceData

// The device-side optimizer buffers of a tensor: the momentum and the velocity an optimizer update carries
// from one step to the next. The class has no public member at all, so it is the handle an application
// holds and a graph hands back; its storage is the framework's and is not readable, and this one is the
// same - a live object with nothing of its own to answer.
@implementation MLCTensorOptimizerDeviceData

+ (instancetype)new
{
    // The header marks it unavailable, and what the release answers when a program asks for it anyway is
    // an MLCTensorOptimizerDeviceData with nothing of its own set (measured on this host's own
    // MLCompute: +[MLCTensorOptimizerDeviceData new] answers an MLCTensorOptimizerDeviceData).
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    // The buffers are the framework's own and are not readable here either, so a copy is another live
    // buffer of the same kind and the two are not compared: nothing of them is API.
    return [[[self class] allocWithZone:zone] init];
}

@end

#pragma mark - MLCTensor

// The random number generator the random initializers draw from, and the seed they draw it with. The
// host's generator is not published, so the stream of values is the port's; what is held to the host is
// the shape of the answer - the three initializer types, the range each covers, and the fact that the same
// seed gives the same values and a different seed gives different ones (all measured;
// facts/MLCompute/Tensors.md). This is a 64-bit xorshift of the port's own: it needs no library, it is the
// same on every machine, and its whole state is the seed.
typedef struct {
    uint64_t state;
} CharonMLCRandom;

static uint32_t CharonMLCRandomNext(CharonMLCRandom *random)
{
    // xorshift64*, the smallest generator whose period is long enough that no training run sees it repeat
    // and whose arithmetic a machine without a wide multiply can do.
    random->state ^= random->state >> 12;
    random->state ^= random->state << 25;
    random->state ^= random->state >> 27;
    return (uint32_t)((random->state * 2685821657736338717ULL) >> 32);
}

static double CharonMLCRandomUnit(CharonMLCRandom *random)
{
    // A whole 32-bit value over the whole 32-bit range: 0 to 1, and 1 is never reached.
    return (double)CharonMLCRandomNext(random) / 4294967296.0;
}

static uint32_t CharonMLCSeedState(void)
{
    // No seed set means the fixed one the host also starts from (measured: two initializers with no seed
    // set give the same values).
    NSNumber *seed = [MLCPlatform getRNGseed];
    uint32_t state = seed ? (uint32_t)(seed.longLongValue & 0xffffffff) : 0x9e3779b9u;
    return state ? state : 0x6d2b79f5u;
}

// What each random initializer draws, measured over two million values on the host: uniform fills 0 to 1,
// Glorot uniform fills -sqrt(3) to sqrt(3) exactly whatever the shape of the tensor is - the bound does not
// follow the fan-in and fan-out of the tensor and neither does the port's - and Xavier is a normal draw
// with a standard deviation of one half, which is not bounded at all (measured: a mean of 0.0007 and a
// standard deviation of 0.4998 over two million values, and a range that grows with the number of them,
// reaching -2.28 and 2.75). facts/MLCompute/Tensors.md has the whole table.
#define CHARON_MLC_GLOROT_LIMIT 1.7320508075688772
#define CHARON_MLC_XAVIER_DEVIATION 0.5

// A normal draw from two uniform ones, by the polar form Box and Muller gave in 1963: no table, no library
// and the same numbers on every machine. One of the pair is kept for the next call, so a tensor's values
// come out of a stream that does not repeat itself within a run.
static double CharonMLCRandomNormal(CharonMLCRandom *random, double *spare)
{
    if (*spare != 0.0) {
        double held = *spare;
        *spare = 0.0;
        return held;
    }
    double first, second, square;
    do {
        first = 2.0 * CharonMLCRandomUnit(random) - 1.0;
        second = 2.0 * CharonMLCRandomUnit(random) - 1.0;
        square = first * first + second * second;
    } while (square >= 1.0 || square == 0.0);
    double factor = sqrt(-2.0 * log(square) / square);
    *spare = second * factor;
    return first * factor;
}

@implementation MLCTensor {
    NSUInteger _tensorID;
    MLCTensorDescriptor *_descriptor;
    NSMutableData *_data;
    NSString *_label;
    MLCDevice *_device;
    NSArray<MLCTensorData *> *_optimizerData;
}

- (instancetype)init
{
    // The header's unavailable initialiser, which the host answers with a tensor of nothing: no descriptor,
    // no data, no label and the number zero (measured - a tensor made by the factory below counts up from
    // zero, and one made here is always zero whatever has been made before it).
    self = [super init];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)tensorWithDescriptor:(MLCTensorDescriptor *)tensorDescriptor
{
    // A nil descriptor makes a tensor of nothing, not no tensor (measured).
    MLCTensor *tensor = [[MLCTensor alloc] init];
    tensor->_tensorID = CharonMLCNextTensorID();
    tensor->_descriptor = tensorDescriptor;
    // The name a tensor is given when nothing names it is its number in the order tensors were made
    // (measured: the first is data0).
    tensor->_label = [NSString stringWithFormat:@"data%lu", (unsigned long)tensor->_tensorID];
    return tensor;
}

+ (instancetype)tensorWithDescriptor:(MLCTensorDescriptor *)tensorDescriptor
                randomInitializerType:(MLCRandomInitializerType)randomInitializerType
{
    MLCTensor *tensor = [self tensorWithDescriptor:tensorDescriptor];
    if (!tensor) {
        return nil;
    }
    [tensor fillWithRandomInitializerType:randomInitializerType];
    return tensor;
}

+ (instancetype)tensorWithDescriptor:(MLCTensorDescriptor *)tensorDescriptor fillWithData:(NSNumber *)fillData
{
    MLCTensor *tensor = [self tensorWithDescriptor:tensorDescriptor];
    if (!tensor) {
        return nil;
    }
    [tensor fillWithScalar:fillData.floatValue];
    return tensor;
}

+ (instancetype)tensorWithDescriptor:(MLCTensorDescriptor *)tensorDescriptor data:(MLCTensorData *)data
{
    MLCTensor *tensor = [self tensorWithDescriptor:tensorDescriptor];
    if (!tensor || !data || !data.bytes) {
        return tensor;
    }
    // The whole buffer, larger than the tensor or not, which is what the host reports (measured: a tensor
    // of four floats given sixty-four reports sixty-four).
    [tensor charon_writeBytes:data.bytes length:data.length];
    return tensor;
}

+ (instancetype)tensorWithShape:(NSArray<NSNumber *> *)shape
{
    return [self tensorWithShape:shape dataType:MLCDataTypeFloat32];
}

+ (instancetype)tensorWithShape:(NSArray<NSNumber *> *)shape dataType:(MLCDataType)dataType
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:dataType]];
}

+ (instancetype)tensorWithShape:(NSArray<NSNumber *> *)shape randomInitializerType:(MLCRandomInitializerType)randomInitializerType
{
    return [self tensorWithShape:shape randomInitializerType:randomInitializerType dataType:MLCDataTypeFloat32];
}

+ (instancetype)tensorWithShape:(NSArray<NSNumber *> *)shape
           randomInitializerType:(MLCRandomInitializerType)randomInitializerType
                        dataType:(MLCDataType)dataType
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:dataType]
                 randomInitializerType:randomInitializerType];
}

+ (instancetype)tensorWithShape:(NSArray<NSNumber *> *)shape data:(MLCTensorData *)data dataType:(MLCDataType)dataType
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:dataType] data:data];
}

+ (instancetype)tensorWithShape:(NSArray<NSNumber *> *)shape fillWithData:(NSNumber *)fillData dataType:(MLCDataType)dataType
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:dataType] fillWithData:fillData];
}

+ (instancetype)tensorWithWidth:(NSUInteger)width
                         height:(NSUInteger)height
            featureChannelCount:(NSUInteger)featureChannelCount
                      batchSize:(NSUInteger)batchSize
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithWidth:width
                                                                       height:height
                                                          featureChannelCount:featureChannelCount
                                                                    batchSize:batchSize]];
}

+ (instancetype)tensorWithWidth:(NSUInteger)width
                         height:(NSUInteger)height
            featureChannelCount:(NSUInteger)featureChannelCount
                      batchSize:(NSUInteger)batchSize
                    fillWithData:(float)fillData
                       dataType:(MLCDataType)dataType
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithWidth:width
                                                                       height:height
                                                          featureChannelCount:featureChannelCount
                                                                    batchSize:batchSize
                                                                     dataType:dataType]
                            fillWithData:@(fillData)];
}

+ (instancetype)tensorWithWidth:(NSUInteger)width
                         height:(NSUInteger)height
            featureChannelCount:(NSUInteger)featureChannelCount
                      batchSize:(NSUInteger)batchSize
          randomInitializerType:(MLCRandomInitializerType)randomInitializerType
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithWidth:width
                                                                       height:height
                                                          featureChannelCount:featureChannelCount
                                                                    batchSize:batchSize]
                 randomInitializerType:randomInitializerType];
}

+ (instancetype)tensorWithWidth:(NSUInteger)width
                         height:(NSUInteger)height
            featureChannelCount:(NSUInteger)featureChannelCount
                      batchSize:(NSUInteger)batchSize
                              data:(MLCTensorData *)data
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithWidth:width
                                                                       height:height
                                                          featureChannelCount:featureChannelCount
                                                                    batchSize:batchSize]
                                data:data];
}

+ (instancetype)tensorWithWidth:(NSUInteger)width
                         height:(NSUInteger)height
            featureChannelCount:(NSUInteger)featureChannelCount
                      batchSize:(NSUInteger)batchSize
                              data:(MLCTensorData *)data
                          dataType:(MLCDataType)dataType
{
    return [self tensorWithDescriptor:[MLCTensorDescriptor descriptorWithWidth:width
                                                                       height:height
                                                          featureChannelCount:featureChannelCount
                                                                    batchSize:batchSize
                                                                     dataType:dataType]
                                data:data];
}

+ (instancetype)tensorWithSequenceLength:(NSUInteger)sequenceLength
                    featureChannelCount:(NSUInteger)featureChannelCount
                              batchSize:(NSUInteger)batchSize
{
    // One sequence of the given length per batch entry, which is the shape and the lengths the framework
    // answers (measured: a length of 3, two channels and a batch of 2 is a shape of 2, 3, 2 with the lengths
    // 3, 3), and the private path below builds it. A sequence tensor with no data and no initializer is
    // filled, as the framework fills it (measured: its values are random and every one of them differs),
    // while the form that is given a nil data object is not.
    MLCTensor *tensor = [self charon_tensorWithSequenceLength:sequenceLength
                                          featureChannelCount:featureChannelCount
                                                    batchSize:batchSize
                                                         filled:YES];
    return tensor;
}

+ (instancetype)tensorWithSequenceLength:(NSUInteger)sequenceLength
                    featureChannelCount:(NSUInteger)featureChannelCount
                              batchSize:(NSUInteger)batchSize
                 randomInitializerType:(MLCRandomInitializerType)randomInitializerType
{
    MLCTensor *tensor = [self tensorWithSequenceLength:sequenceLength featureChannelCount:featureChannelCount batchSize:batchSize];
    [tensor fillWithRandomInitializerType:randomInitializerType];
    return tensor;
}

+ (instancetype)tensorWithSequenceLength:(NSUInteger)sequenceLength
                    featureChannelCount:(NSUInteger)featureChannelCount
                              batchSize:(NSUInteger)batchSize
                                   data:(MLCTensorData *)data
{
    MLCTensor *tensor = [self charon_tensorWithSequenceLength:sequenceLength
                                          featureChannelCount:featureChannelCount
                                                    batchSize:batchSize
                                                         filled:NO];
    if (tensor) {
        [tensor charon_writeBytes:data.bytes length:data.length];
    }
    return tensor;
}

+ (instancetype)tensorWithSequenceLengths:(NSArray<NSNumber *> *)sequenceLengths
                          sortedSequences:(BOOL)sortedSequences
                     featureChannelCount:(NSUInteger)featureChannelCount
                               batchSize:(NSUInteger)batchSize
                   randomInitializerType:(MLCRandomInitializerType)randomInitializerType
{
    MLCTensor *tensor = [self tensorWithDescriptor:[MLCTensorDescriptor charon_descriptorWithSequenceLengths:sequenceLengths
                                                                            featureChannelCount:featureChannelCount
                                                                                      batchSize:batchSize
                                                                                 sortedSequences:sortedSequences
                                                                                        dataType:MLCDataTypeFloat32]];
    [tensor fillWithRandomInitializerType:randomInitializerType];
    return tensor;
}

+ (instancetype)tensorWithSequenceLengths:(NSArray<NSNumber *> *)sequenceLengths
                          sortedSequences:(BOOL)sortedSequences
                     featureChannelCount:(NSUInteger)featureChannelCount
                               batchSize:(NSUInteger)batchSize
                                    data:(MLCTensorData *)data
{
    MLCTensor *tensor = [self tensorWithDescriptor:[MLCTensorDescriptor charon_descriptorWithSequenceLengths:sequenceLengths
                                                                            featureChannelCount:featureChannelCount
                                                                                      batchSize:batchSize
                                                                                 sortedSequences:sortedSequences
                                                                                        dataType:MLCDataTypeFloat32]];
    if (tensor) {
        [tensor charon_writeBytes:data.bytes length:data.length];
    }
    return tensor;
}

- (NSUInteger)tensorID
{
    return _tensorID;
}

- (MLCTensorDescriptor *)descriptor
{
    return _descriptor;
}

- (NSData *)data
{
    return _data;
}

- (NSString *)label
{
    return _label;
}

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
}

- (MLCDevice *)device
{
    return _device;
}

- (NSArray<MLCTensorData *> *)optimizerData
{
    return _optimizerData ? _optimizerData : @[];
}

- (NSArray<MLCTensorOptimizerDeviceData *> *)optimizerDeviceData
{
    return @[];
}

- (BOOL)hasValidNumerics
{
    // Every element must be a number and a finite one. A tensor with no data has nothing that is not
    // valid, and answers YES, which is what the host answers (measured).
    if (!_data || _descriptor.dataType != MLCDataTypeFloat32) {
        return YES;
    }
    const float *values = _data.bytes;
    NSUInteger count = _data.length / sizeof(float);
    for (NSUInteger index = 0; index < count; index++) {
        if (isnan(values[index]) || isinf(values[index])) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)synchronizeData
{
    // The CPU device computes into the very memory a program reads, so there is nothing to bring back and
    // nothing that can fail.
    return YES;
}

- (BOOL)synchronizeOptimizerData
{
    return YES;
}

- (BOOL)copyDataFromDeviceMemoryToBytes:(void *)bytes length:(NSUInteger)length synchronizeWithDevice:(BOOL)synchronizeWithDevice
{
    if (!_data || !bytes || length > _data.length) {
        return NO;
    }
    memcpy(bytes, _data.bytes, length);
    return YES;
}

- (BOOL)bindAndWriteData:(MLCTensorData *)data toDevice:(MLCDevice *)device
{
    if (!_descriptor) {
        return NO;
    }
    NSUInteger wanted = _descriptor.tensorAllocationSizeInBytes;
    if (!data || !data.bytes || data.length < wanted) {
        return NO;
    }
    if (!_data) {
        _data = [NSMutableData dataWithBytes:data.bytes length:wanted];
    } else {
        [_data replaceBytesInRange:NSMakeRange(0, wanted) withBytes:data.bytes];
    }
    _device = device;
    return YES;
}

- (BOOL)bindOptimizerData:(NSArray<MLCTensorData *> *)data deviceData:(NSArray<MLCTensorOptimizerDeviceData *> *)deviceData
{
    _optimizerData = [data copy];
    return YES;
}

- (MLCTensor *)tensorByQuantizingToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias
{
    if (type != MLCDataTypeInt8 && type != MLCDataTypeUInt8 && type != MLCDataTypeInt32) {
        return nil;
    }
    return [self charon_tensorQuantizedToType:type scale:scale bias:bias];
}

- (MLCTensor *)tensorByQuantizingToType:(MLCDataType)type scale:(MLCTensor *)scale bias:(MLCTensor *)bias axis:(NSInteger)axis
{
    if (type != MLCDataTypeInt8 && type != MLCDataTypeUInt8 && type != MLCDataTypeInt32) {
        return nil;
    }
    return [self charon_tensorQuantizedToType:type
                                       scale:[self charon_scalarOfTensor:scale inType:MLCDataTypeFloat32]
                                        bias:[self charon_scalarOfTensor:bias inType:MLCDataTypeInt32]];
}

- (MLCTensor *)tensorByDequantizingToType:(MLCDataType)type scale:(MLCTensor *)scale bias:(MLCTensor *)bias
{
    if (type != MLCDataTypeFloat32) {
        return nil;
    }
    return [self charon_tensorDequantizedToType:type
                                         scale:[self charon_scalarOfTensor:scale inType:MLCDataTypeFloat32]
                                          bias:[self charon_scalarOfTensor:bias inType:MLCDataTypeInt32]];
}

- (MLCTensor *)tensorByDequantizingToType:(MLCDataType)type scale:(MLCTensor *)scale bias:(MLCTensor *)bias axis:(NSInteger)axis
{
    if (type != MLCDataTypeFloat32) {
        return nil;
    }
    return [self charon_tensorDequantizedToType:type
                                         scale:[self charon_scalarOfTensor:scale inType:MLCDataTypeFloat32]
                                          bias:[self charon_scalarOfTensor:bias inType:MLCDataTypeInt32]];
}

- (id)copyWithZone:(NSZone *)zone
{
    // A copy is another tensor over the same descriptor and the same numbers, with a number and a name of
    // its own, and it keeps the data: a copy of a tensor holding 1.5 holds 1.5, and answers a name of its
    // own (measured). An earlier version of this comment said the copy has no data of its own, which the
    // framework does not do, and the case that should have shown it was copying a tensor that had none.
    MLCTensor *copy = [[[self class] allocWithZone:zone] init];
    copy->_tensorID = CharonMLCNextTensorID();
    copy->_descriptor = [_descriptor copy];
    copy->_data = _data;
    // The name is the one a tensor gets when nothing names it, which is its own number, not the name the
    // one copied was given (measured).
    copy->_label = [NSString stringWithFormat:@"data%lu", (unsigned long)copy->_tensorID];
    copy->_optimizerData = [_optimizerData copy];
    return copy;
}

#pragma mark the storage the factories above fill and read

// The bytes of a data object, whole, into the storage of the tensor. A nil data writes none, which is what
// the host answers for a tensor made of a nil one (measured).
//
// The bytes are copied rather than held. The header only asks the caller to keep its buffer alive, and a
// caller that passed a buffer it did not allocate with malloc - a tensor on the stack, as a test does -
// would otherwise be written through or freed when the tensor is released. Copying needs nothing of the
// caller and answers the same length, which is what is compared.
- (void)charon_writeBytes:(const void *)bytes length:(NSUInteger)length
{
    if (!bytes || length == 0) {
        return;
    }
    if (!_data) {
        _data = [NSMutableData dataWithLength:length];
    }
    NSUInteger wanted = MIN(length, _data.length);
    [_data replaceBytesInRange:NSMakeRange(0, wanted) withBytes:bytes];
}

// Storage of the descriptor's own size, every byte of it zero.
- (void)charon_fillWithZeroes
{
    if (!_descriptor) {
        return;
    }
    NSUInteger size = _descriptor.tensorAllocationSizeInBytes;
    if (size == 0) {
        return;
    }
    _data = [NSMutableData dataWithLength:size];
}

- (void)fillWithScalar:(float)value
{
    if (!_descriptor) {
        return;
    }
    NSUInteger size = _descriptor.tensorAllocationSizeInBytes;
    if (size == 0) {
        return;
    }
    NSMutableData *storage = [NSMutableData dataWithLength:size];
    // The value a program gives is a float and the data type says how to keep it: as a float, or as the
    // whole number it names (measured: a tensor of four int32 filled with 7 holds 7, and one of four uint8
    // filled with 7 holds 7).
    switch (_descriptor.dataType) {
        case MLCDataTypeInt32: {
            int32_t *values = storage.mutableBytes;
            for (NSUInteger index = 0; index < size / sizeof(int32_t); index++) {
                values[index] = (int32_t)value;
            }
            break;
        }
        case MLCDataTypeInt64: {
            int64_t *values = storage.mutableBytes;
            for (NSUInteger index = 0; index < size / sizeof(int64_t); index++) {
                values[index] = (int64_t)value;
            }
            break;
        }
        case MLCDataTypeUInt8:
        case MLCDataTypeInt8: {
            uint8_t *values = storage.mutableBytes;
            for (NSUInteger index = 0; index < size; index++) {
                values[index] = (uint8_t)value;
            }
            break;
        }
        case MLCDataTypeBoolean: {
            uint8_t *values = storage.mutableBytes;
            for (NSUInteger index = 0; index < size; index++) {
                values[index] = value != 0.0f ? 1 : 0;
            }
            break;
        }
        default: {
            float *values = storage.mutableBytes;
            for (NSUInteger index = 0; index < size / sizeof(float); index++) {
                values[index] = value;
            }
            break;
        }
    }
    _data = storage;
}

- (void)fillWithRandomInitializerType:(MLCRandomInitializerType)randomInitializerType
{
    if (!_descriptor || _descriptor.dataType != MLCDataTypeFloat32) {
        return;
    }
    CharonMLCRandom random = { CharonMLCSeedState() };
    double spare = 0.0;
    NSUInteger count = _descriptor.tensorAllocationSizeInBytes / sizeof(float);
    float low = 0.0f, span = 1.0f;
    if (randomInitializerType == MLCRandomInitializerTypeGlorotUniform) {
        low = (float)-CHARON_MLC_GLOROT_LIMIT;
        span = (float)(2.0 * CHARON_MLC_GLOROT_LIMIT);
    }
    BOOL normal = randomInitializerType == MLCRandomInitializerTypeXavier;
    NSMutableData *storage = [NSMutableData dataWithLength:count * sizeof(float)];
    float *values = storage.mutableBytes;
    for (NSUInteger index = 0; index < count; index++) {
        if (normal) {
            values[index] = (float)(CHARON_MLC_XAVIER_DEVIATION * CharonMLCRandomNormal(&random, &spare));
        } else {
            values[index] = (float)(low + span * CharonMLCRandomUnit(&random));
        }
    }
    _data = storage;
}

// The quantized form of a tensor: every element of the float tensor is divided by the scale, moved by the
// bias, rounded to the nearest whole number and clamped to what the narrower type holds. The
// dequantization is the same rule the other way round.
- (MLCTensor *)charon_tensorQuantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias
{
    if (!_descriptor || !_data || _descriptor.dataType != MLCDataTypeFloat32) {
        return nil;
    }
    MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:_descriptor.shape dataType:type];
    if (!descriptor) {
        return nil;
    }
    // The scale and the bias are not applied here. The framework's own CPU path gives storage of the type
    // asked for and leaves every element at zero, whatever the scale, the bias and the values of the
    // tensor are (measured for every type, scale and bias from 0 to 4: all zeros), and the parameters take
    // effect when a graph is compiled with them bound to the tensor. The port answers the same, and
    // facts/MLCompute/Tensors.md says what is not carried here.
    (void)scale;
    (void)bias;
    MLCTensor *quantized = [MLCTensor tensorWithDescriptor:descriptor];
    [quantized charon_fillWithZeroes];
    return quantized;
}

- (MLCTensor *)charon_tensorDequantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias
{
    if (!_descriptor || !_data || type != MLCDataTypeFloat32) {
        return nil;
    }
    MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:_descriptor.shape dataType:type];
    if (!descriptor) {
        return nil;
    }
    // As above: the storage is of the float type asked for and every element is zero, which is what the
    // framework's own answer is whatever the scale and the bias are (measured).
    (void)scale;
    (void)bias;
    MLCTensor *dequantized = [MLCTensor tensorWithDescriptor:descriptor];
    [dequantized charon_fillWithZeroes];
    return dequantized;
}

// The first element of a one-element tensor, read as a whole number or a float. The per-axis forms of
// quantization take their scale and their bias in tensors; a program that wants one scale for the whole
// tensor passes a tensor of one element, and that is the only case this answers.
- (double)charon_scalarOfTensor:(MLCTensor *)tensor inType:(MLCDataType)type
{
    if (!tensor.data || tensor.data.length == 0) {
        return type == MLCDataTypeInt32 ? 0.0 : 1.0;
    }
    if (type == MLCDataTypeInt32) {
        return (double)((const int32_t *)tensor.data.bytes)[0];
    }
    return (double)((const float *)tensor.data.bytes)[0];
}

@end

@implementation MLCTensor (CharonSequences)

+ (instancetype)charon_tensorWithSequenceLength:(NSUInteger)sequenceLength
                            featureChannelCount:(NSUInteger)featureChannelCount
                                      batchSize:(NSUInteger)batchSize
                                         filled:(BOOL)filled
{
    // One sequence of the given length per batch entry, which is the shape and the lengths the framework
    // answers (measured: a length of 3, two channels and a batch of 2 is a shape of 2, 3, 2 with the
    // lengths 3, 3).
    NSMutableArray *lengths = [NSMutableArray arrayWithCapacity:batchSize];
    for (NSUInteger index = 0; index < batchSize; index++) {
        [lengths addObject:@(sequenceLength)];
    }
    MLCTensor *tensor = [self tensorWithDescriptor:[MLCTensorDescriptor charon_descriptorWithSequenceLengths:lengths
                                                                            featureChannelCount:featureChannelCount
                                                                                      batchSize:batchSize
                                                                                 sortedSequences:YES
                                                                                        dataType:MLCDataTypeFloat32]];
    if (filled) {
        [tensor fillWithRandomInitializerType:MLCRandomInitializerTypeUniform];
    }
    return tensor;
}

@end

#pragma mark - MLCTensorParameter

@implementation MLCTensorParameter {
    MLCTensor *_tensor;
    NSArray<MLCTensorData *> *_optimizerData;
    BOOL _isUpdatable;
}

- (instancetype)init
{
    // The header's unavailable initialiser: a parameter of no tensor, and not updatable (measured).
    self = [super init];
    if (self) {
        _isUpdatable = NO;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)parameterWithTensor:(MLCTensor *)tensor
{
    MLCTensorParameter *parameter = [[MLCTensorParameter alloc] init];
    parameter->_tensor = tensor;
    parameter->_isUpdatable = YES;
    return parameter;
}

+ (instancetype)parameterWithTensor:(MLCTensor *)tensor optimizerData:(NSArray<MLCTensorData *> *)optimizerData
{
    MLCTensorParameter *parameter = [self parameterWithTensor:tensor];
    parameter->_optimizerData = [optimizerData copy];
    // The optimizer buffers belong to the tensor, so a parameter that carries them hands them to it: that
    // is where -[MLCTensor optimizerData] and the optimizer update read them from.
    if (tensor) {
        [tensor bindOptimizerData:optimizerData deviceData:nil];
    }
    return parameter;
}

- (MLCTensor *)tensor
{
    return _tensor;
}

- (BOOL)isUpdatable
{
    return _isUpdatable;
}

- (void)setIsUpdatable:(BOOL)isUpdatable
{
    _isUpdatable = isUpdatable;
}

@end

#pragma mark - MLCLayer

// The two things the thirty layer factories need from their base, and what the base's own header marks
// unavailable: an initialiser a subclass can call, and the name a factory gives a layer. They are
// private to the port and named Charon* so the gate weighs neither against a release.
@interface MLCLayer (CharonFactory)
- (instancetype)charon_init;
- (instancetype)charon_label:(NSString *)name;
@end

@implementation MLCLayer (CharonFactory)

- (instancetype)charon_init
{
    return [super init];
}

- (instancetype)charon_label:(NSString *)name
{
    self.label = name;
    return self;
}

@end

// The base of the thirty layers: what a layer is, what it is called, and whether a program asked for it to
// be watched. Its number is zero until the layer joins a graph, which is where the host counts (measured:
// every layer of a program that is in no graph answers 0, and the layers of a graph are numbered from 1 in
// the order they were added). Its label is nil until one of its factories names it, which is also what the
// host does: an initialised layer of every class answers nil, while +[MLCSelectionLayer layer] answers
// "Selection", +[MLCActivationLayer reluLayer] "Activation" and +[MLCArithmeticLayer layerWithOperation:]
// "Arithmetic" (measured).
static NSUInteger CharonMLCLayerCounter = 0;

NSUInteger CharonMLCNextLayerID(void)
{
    return CharonMLCLayerCounter++;
}

@implementation MLCLayer {
    NSUInteger _layerID;
    NSString *_label;
    BOOL _isDebuggingEnabled;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _layerID = 0;
        _label = nil;
        _isDebuggingEnabled = NO;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (NSUInteger)layerID
{
    return _layerID;
}

- (void)setLayerID:(NSUInteger)layerID
{
    _layerID = layerID;
}

- (NSString *)label
{
    return _label;
}

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
}

- (BOOL)isDebuggingEnabled
{
    return _isDebuggingEnabled;
}

- (void)setIsDebuggingEnabled:(BOOL)isDebuggingEnabled
{
    _isDebuggingEnabled = isDebuggingEnabled;
}

- (MLCDeviceType)deviceType
{
    // Which device a layer runs on is decided when the graph is compiled. Before that there is none, and
    // the host answers the count of the enumeration rather than a type in it, which is what a program that
    // asks too early gets (measured: 2147483647).
    return (MLCDeviceType)2147483647;
}

+ (BOOL)supportsDataType:(MLCDataType)dataType onDevice:(MLCDevice *)device
{
    // The host answers NO for every data type and every device, on the CPU as much as on a GPU (measured,
    // facts/MLCompute/Layer.md). The port answers the same: this is the framework's own answer, not a
    // refusal to try, and a program that asks first must be prepared for NO either way.
    return NO;
}

@end
