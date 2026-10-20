#import "RevenantMLCompute.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

@interface MLCTensor (RevenantStorage)
- (void)fillWithScalar:(float)value;
- (void)revenant_writeBytes:(const void *)bytes length:(NSUInteger)length;
- (void)fillWithRandomInitializerType:(MLCRandomInitializerType)randomInitializerType;
- (MLCTensor *)revenant_tensorQuantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias;
- (MLCTensor *)revenant_tensorDequantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias;
- (double)revenant_scalarOfTensor:(MLCTensor *)tensor inType:(MLCDataType)type;
@end

@interface MLCTensor (RevenantSequences)
+ (instancetype)revenant_tensorWithSequenceLength:(NSUInteger)sequenceLength
                            featureChannelCount:(NSUInteger)featureChannelCount
                                      batchSize:(NSUInteger)batchSize
                                         filled:(BOOL)filled;
@end

NSUInteger RevenantMLCWidthOfDataType(MLCDataType dataType)
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
    if (dataType == 6) {
        return 1;
    }
    return 0;
}

NSUInteger RevenantMLCElementCount(NSArray<NSNumber *> *shape)
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

NSArray<NSNumber *> *RevenantMLCStrideOfShape(NSArray<NSNumber *> *shape, MLCDataType dataType)
{
    NSUInteger width = RevenantMLCWidthOfDataType(dataType);
    NSMutableArray *stride = [NSMutableArray arrayWithCapacity:shape.count];
    NSUInteger running = width;
    for (NSUInteger index = shape.count; index > 0; index--) {
        [stride insertObject:@(running) atIndex:0];
        running *= shape[index - 1].unsignedIntegerValue;
    }
    return stride;
}

static NSUInteger RevenantMLCTensorCounter = 0;

NSUInteger RevenantMLCNextTensorID(void)
{
    return RevenantMLCTensorCounter++;
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
    return REVENANT_MLC_MAX_DIMENSIONS;
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
    if (shape.count > REVENANT_MLC_MAX_DIMENSIONS) {
        return nil;
    }
    for (NSNumber *dimension in shape) {
        if (dimension.unsignedIntegerValue == 0) {
            return nil;
        }
    }
    if (RevenantMLCWidthOfDataType(dataType) == 0) {
        return nil;
    }
    MLCTensorDescriptor *descriptor = [[MLCTensorDescriptor alloc] init];
    descriptor->_dataType = dataType;
    descriptor->_dimensionCount = shape.count;
    descriptor->_shape = [shape copy];
    descriptor->_stride = RevenantMLCStrideOfShape(shape, dataType);
    descriptor->_allocationSize = RevenantMLCElementCount(shape) * RevenantMLCWidthOfDataType(dataType);
    return descriptor;
}

+ (instancetype)descriptorWithShape:(NSArray<NSNumber *> *)shape
                    sequenceLengths:(NSArray<NSNumber *> *)sequenceLengths
                    sortedSequences:(BOOL)sortedSequences
                           dataType:(MLCDataType)dataType
{
    return nil;
}

+ (instancetype)revenant_descriptorWithSequenceLengths:(NSArray<NSNumber *> *)sequenceLengths
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

@implementation MLCTensorOptimizerDeviceData

+ (instancetype)new
{
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] init];
}

@end

#pragma mark - MLCTensor

typedef struct {
    uint64_t state;
} RevenantMLCRandom;

static uint32_t RevenantMLCRandomNext(RevenantMLCRandom *random)
{
    random->state ^= random->state >> 12;
    random->state ^= random->state << 25;
    random->state ^= random->state >> 27;
    return (uint32_t)((random->state * 2685821657736338717ULL) >> 32);
}

static double RevenantMLCRandomUnit(RevenantMLCRandom *random)
{
    return (double)RevenantMLCRandomNext(random) / 4294967296.0;
}

static uint32_t RevenantMLCSeedState(void)
{
    NSNumber *seed = [MLCPlatform getRNGseed];
    uint32_t state = seed ? (uint32_t)(seed.longLongValue & 0xffffffff) : 0x9e3779b9u;
    return state ? state : 0x6d2b79f5u;
}

#define REVENANT_MLC_GLOROT_LIMIT 1.7320508075688772
#define REVENANT_MLC_XAVIER_DEVIATION 0.5

static double RevenantMLCRandomNormal(RevenantMLCRandom *random, double *spare)
{
    if (*spare != 0.0) {
        double held = *spare;
        *spare = 0.0;
        return held;
    }
    double first, second, square;
    do {
        first = 2.0 * RevenantMLCRandomUnit(random) - 1.0;
        second = 2.0 * RevenantMLCRandomUnit(random) - 1.0;
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
    self = [super init];
    return self;
}

+ (instancetype)new
{
    return [[self alloc] init];
}

+ (instancetype)tensorWithDescriptor:(MLCTensorDescriptor *)tensorDescriptor
{
    MLCTensor *tensor = [[MLCTensor alloc] init];
    tensor->_tensorID = RevenantMLCNextTensorID();
    tensor->_descriptor = tensorDescriptor;
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
    [tensor revenant_writeBytes:data.bytes length:data.length];
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
    MLCTensor *tensor = [self revenant_tensorWithSequenceLength:sequenceLength
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
    MLCTensor *tensor = [self revenant_tensorWithSequenceLength:sequenceLength
                                          featureChannelCount:featureChannelCount
                                                    batchSize:batchSize
                                                         filled:NO];
    if (tensor) {
        [tensor revenant_writeBytes:data.bytes length:data.length];
    }
    return tensor;
}

+ (instancetype)tensorWithSequenceLengths:(NSArray<NSNumber *> *)sequenceLengths
                          sortedSequences:(BOOL)sortedSequences
                     featureChannelCount:(NSUInteger)featureChannelCount
                               batchSize:(NSUInteger)batchSize
                   randomInitializerType:(MLCRandomInitializerType)randomInitializerType
{
    MLCTensor *tensor = [self tensorWithDescriptor:[MLCTensorDescriptor revenant_descriptorWithSequenceLengths:sequenceLengths
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
    MLCTensor *tensor = [self tensorWithDescriptor:[MLCTensorDescriptor revenant_descriptorWithSequenceLengths:sequenceLengths
                                                                            featureChannelCount:featureChannelCount
                                                                                      batchSize:batchSize
                                                                                 sortedSequences:sortedSequences
                                                                                        dataType:MLCDataTypeFloat32]];
    if (tensor) {
        [tensor revenant_writeBytes:data.bytes length:data.length];
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
    return [self revenant_tensorQuantizedToType:type scale:scale bias:bias];
}

- (MLCTensor *)tensorByQuantizingToType:(MLCDataType)type scale:(MLCTensor *)scale bias:(MLCTensor *)bias axis:(NSInteger)axis
{
    if (type != MLCDataTypeInt8 && type != MLCDataTypeUInt8 && type != MLCDataTypeInt32) {
        return nil;
    }
    return [self revenant_tensorQuantizedToType:type
                                       scale:[self revenant_scalarOfTensor:scale inType:MLCDataTypeFloat32]
                                        bias:[self revenant_scalarOfTensor:bias inType:MLCDataTypeInt32]];
}

- (MLCTensor *)tensorByDequantizingToType:(MLCDataType)type scale:(MLCTensor *)scale bias:(MLCTensor *)bias
{
    if (type != MLCDataTypeFloat32) {
        return nil;
    }
    return [self revenant_tensorDequantizedToType:type
                                         scale:[self revenant_scalarOfTensor:scale inType:MLCDataTypeFloat32]
                                          bias:[self revenant_scalarOfTensor:bias inType:MLCDataTypeInt32]];
}

- (MLCTensor *)tensorByDequantizingToType:(MLCDataType)type scale:(MLCTensor *)scale bias:(MLCTensor *)bias axis:(NSInteger)axis
{
    if (type != MLCDataTypeFloat32) {
        return nil;
    }
    return [self revenant_tensorDequantizedToType:type
                                         scale:[self revenant_scalarOfTensor:scale inType:MLCDataTypeFloat32]
                                          bias:[self revenant_scalarOfTensor:bias inType:MLCDataTypeInt32]];
}

- (id)copyWithZone:(NSZone *)zone
{
    MLCTensor *copy = [[[self class] allocWithZone:zone] init];
    copy->_tensorID = RevenantMLCNextTensorID();
    copy->_descriptor = [_descriptor copy];
    copy->_data = _data;
    copy->_label = [NSString stringWithFormat:@"data%lu", (unsigned long)copy->_tensorID];
    copy->_optimizerData = [_optimizerData copy];
    return copy;
}

#pragma mark the storage the factories above fill and read

- (void)revenant_writeBytes:(const void *)bytes length:(NSUInteger)length
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

- (void)revenant_fillWithZeroes
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
    RevenantMLCRandom random = { RevenantMLCSeedState() };
    double spare = 0.0;
    NSUInteger count = _descriptor.tensorAllocationSizeInBytes / sizeof(float);
    float low = 0.0f, span = 1.0f;
    if (randomInitializerType == MLCRandomInitializerTypeGlorotUniform) {
        low = (float)-REVENANT_MLC_GLOROT_LIMIT;
        span = (float)(2.0 * REVENANT_MLC_GLOROT_LIMIT);
    }
    BOOL normal = randomInitializerType == MLCRandomInitializerTypeXavier;
    NSMutableData *storage = [NSMutableData dataWithLength:count * sizeof(float)];
    float *values = storage.mutableBytes;
    for (NSUInteger index = 0; index < count; index++) {
        if (normal) {
            values[index] = (float)(REVENANT_MLC_XAVIER_DEVIATION * RevenantMLCRandomNormal(&random, &spare));
        } else {
            values[index] = (float)(low + span * RevenantMLCRandomUnit(&random));
        }
    }
    _data = storage;
}

- (MLCTensor *)revenant_tensorQuantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias
{
    if (!_descriptor || !_data || _descriptor.dataType != MLCDataTypeFloat32) {
        return nil;
    }
    MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:_descriptor.shape dataType:type];
    if (!descriptor) {
        return nil;
    }
    (void)scale;
    (void)bias;
    MLCTensor *quantized = [MLCTensor tensorWithDescriptor:descriptor];
    [quantized revenant_fillWithZeroes];
    return quantized;
}

- (MLCTensor *)revenant_tensorDequantizedToType:(MLCDataType)type scale:(float)scale bias:(NSInteger)bias
{
    if (!_descriptor || !_data || type != MLCDataTypeFloat32) {
        return nil;
    }
    MLCTensorDescriptor *descriptor = [MLCTensorDescriptor descriptorWithShape:_descriptor.shape dataType:type];
    if (!descriptor) {
        return nil;
    }
    (void)scale;
    (void)bias;
    MLCTensor *dequantized = [MLCTensor tensorWithDescriptor:descriptor];
    [dequantized revenant_fillWithZeroes];
    return dequantized;
}

- (double)revenant_scalarOfTensor:(MLCTensor *)tensor inType:(MLCDataType)type
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

@implementation MLCTensor (RevenantSequences)

+ (instancetype)revenant_tensorWithSequenceLength:(NSUInteger)sequenceLength
                            featureChannelCount:(NSUInteger)featureChannelCount
                                      batchSize:(NSUInteger)batchSize
                                         filled:(BOOL)filled
{
    NSMutableArray *lengths = [NSMutableArray arrayWithCapacity:batchSize];
    for (NSUInteger index = 0; index < batchSize; index++) {
        [lengths addObject:@(sequenceLength)];
    }
    MLCTensor *tensor = [self tensorWithDescriptor:[MLCTensorDescriptor revenant_descriptorWithSequenceLengths:lengths
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

@interface MLCLayer (RevenantFactory)
- (instancetype)revenant_init;
- (instancetype)revenant_label:(NSString *)name;
@end

@implementation MLCLayer (RevenantFactory)

- (instancetype)revenant_init
{
    return [super init];
}

- (instancetype)revenant_label:(NSString *)name
{
    self.label = name;
    return self;
}

@end

static NSUInteger RevenantMLCLayerCounter = 0;

NSUInteger RevenantMLCNextLayerID(void)
{
    return RevenantMLCLayerCounter++;
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
    return (MLCDeviceType)2147483647;
}

+ (BOOL)supportsDataType:(MLCDataType)dataType onDevice:(MLCDevice *)device
{
    return NO;
}

@end
