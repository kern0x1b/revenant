#import "CharonMPS.h"

static NSString *const CharonMPSNeuronKeyType = @"MPSNNNeuronDescriptor.neuronType";
static NSString *const CharonMPSNeuronKeyA = @"MPSNNNeuronDescriptor.A";
static NSString *const CharonMPSNeuronKeyB = @"MPSNNNeuronDescriptor.B";
static NSString *const CharonMPSNeuronKeyC = @"MPSNNNeuronDescriptor.C";
static NSString *const CharonMPSNeuronKeyPReLUCount = @"MPSNNNeuronDescriptor.PReLuCount";
static NSString *const CharonMPSNeuronKeyPReLUData = @"MPSNNNeuronDescriptor.PReLuData";

static inline BOOL CharonMPSNeuronTypeTakesParameters(MPSCNNNeuronType neuronType)
{
    return neuronType != MPSCNNNeuronTypePReLU && neuronType < MPSCNNNeuronTypeCount;
}

@implementation MPSNNNeuronDescriptor {
    MPSCNNNeuronType _neuronType;
    float _a;
    float _b;
    float _c;
    NSData *_data;
}

+ (MPSNNNeuronDescriptor *)cnnNeuronDescriptorWithType:(MPSCNNNeuronType)neuronType
{
    return [self cnnNeuronDescriptorWithType:neuronType a:1.0f b:1.0f c:1.0f];
}

+ (MPSNNNeuronDescriptor *)cnnNeuronDescriptorWithType:(MPSCNNNeuronType)neuronType a:(float)a
{
    return [self cnnNeuronDescriptorWithType:neuronType a:a b:1.0f c:1.0f];
}

+ (MPSNNNeuronDescriptor *)cnnNeuronDescriptorWithType:(MPSCNNNeuronType)neuronType a:(float)a b:(float)b
{
    return [self cnnNeuronDescriptorWithType:neuronType a:a b:b c:1.0f];
}

+ (MPSNNNeuronDescriptor *)cnnNeuronDescriptorWithType:(MPSCNNNeuronType)neuronType a:(float)a b:(float)b c:(float)c
{
    if (!CharonMPSNeuronTypeTakesParameters(neuronType)) {
        CharonMPSRefuse(@"MPSNNNeuronDescriptor: neuron type %d takes no parameters from a parameter factory, so no descriptor is made",
                        (int)neuronType);
        return nil;
    }
    MPSNNNeuronDescriptor *descriptor = [[self alloc] init];
    descriptor->_neuronType = neuronType;
    descriptor->_a = a;
    descriptor->_b = b;
    descriptor->_c = c;
    return descriptor;
}

+ (MPSNNNeuronDescriptor *)cnnNeuronPReLUDescriptorWithData:(NSData *)data noCopy:(bool)noCopy
{
    if (data.length == 0 || data.length % sizeof(float) != 0) {
        CharonMPSRefuse(@"MPSNNNeuronDescriptor: PReLU data of %lu bytes is not a positive whole number of floats, so no descriptor is made",
                        (unsigned long)data.length);
        return nil;
    }
    (void)noCopy;
    MPSNNNeuronDescriptor *descriptor = [[self alloc] init];
    descriptor->_neuronType = MPSCNNNeuronTypePReLU;
    descriptor->_a = 0.0f;
    descriptor->_b = 0.0f;
    descriptor->_c = 0.0f;
    descriptor->_data = data;
    return descriptor;
}

- (MPSCNNNeuronType)neuronType
{
    return _neuronType;
}

- (void)setNeuronType:(MPSCNNNeuronType)neuronType
{
    _neuronType = neuronType;
}

- (float)a
{
    return _a;
}

- (void)setA:(float)a
{
    _a = a;
}

- (float)b
{
    return _b;
}

- (void)setB:(float)b
{
    _b = b;
}

- (float)c
{
    return _c;
}

- (void)setC:(float)c
{
    _c = c;
}

- (NSData *)data
{
    return _data;
}

- (void)setData:(NSData *)data
{
    _data = data;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:(int32_t)_neuronType forKey:CharonMPSNeuronKeyType];
    [aCoder encodeFloat:_a forKey:CharonMPSNeuronKeyA];
    [aCoder encodeFloat:_b forKey:CharonMPSNeuronKeyB];
    [aCoder encodeFloat:_c forKey:CharonMPSNeuronKeyC];
    if (_neuronType == MPSCNNNeuronTypePReLU && _data) {
        [aCoder encodeInt32:(int32_t)(_data.length / sizeof(float)) forKey:CharonMPSNeuronKeyPReLUCount];
        [aCoder encodeObject:_data forKey:CharonMPSNeuronKeyPReLUData];
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super init])) {
        _neuronType = (MPSCNNNeuronType)[aDecoder decodeInt32ForKey:CharonMPSNeuronKeyType];
        _a = [aDecoder decodeFloatForKey:CharonMPSNeuronKeyA];
        _b = [aDecoder decodeFloatForKey:CharonMPSNeuronKeyB];
        _c = [aDecoder decodeFloatForKey:CharonMPSNeuronKeyC];
        if (_neuronType == MPSCNNNeuronTypePReLU) {
            NSUInteger count = (NSUInteger)[aDecoder decodeInt32ForKey:CharonMPSNeuronKeyPReLUCount];
            NSMutableData *zeros = [NSMutableData dataWithLength:count * sizeof(float)];
            _data = [zeros copy];
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPSNNNeuronDescriptor *copy = [[[self class] allocWithZone:zone] init];
    copy->_neuronType = _neuronType;
    copy->_a = _a;
    copy->_b = _b;
    copy->_c = _c;
    copy->_data = [_data copy];
    return copy;
}

@end
