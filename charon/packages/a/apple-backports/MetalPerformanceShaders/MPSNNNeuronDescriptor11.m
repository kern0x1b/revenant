// MPSNNNeuronDescriptor, from the header of MPSCNNNeuron.h in the SDK of iOS 16.4: the type of a neuron filter and
// the parameters a, b and c it reads, and the PReLU data a PReLU neuron reads per channel. A plain shape object. The
// factories' defaults for the parameters they do not take are the ones the release answers (measured on the host).

#import "CharonMPS.h"

// The keys the release archives this descriptor under (measured in the archive the host writes): the type, the three
// parameters as reals, and, for a PReLU neuron only, the element count and the data. This port reads and writes the
// same keys, so an archive of either side is the same shape.
static NSString *const CharonMPSNeuronKeyType = @"MPSNNNeuronDescriptor.neuronType";
static NSString *const CharonMPSNeuronKeyA = @"MPSNNNeuronDescriptor.A";
static NSString *const CharonMPSNeuronKeyB = @"MPSNNNeuronDescriptor.B";
static NSString *const CharonMPSNeuronKeyC = @"MPSNNNeuronDescriptor.C";
static NSString *const CharonMPSNeuronKeyPReLUCount = @"MPSNNNeuronDescriptor.PReLuCount";
static NSString *const CharonMPSNeuronKeyPReLUData = @"MPSNNNeuronDescriptor.PReLuData";

// Whether a neuron type can be built by one of the parameter factories. The release asserts on PReLU there (its data
// comes from the PReLU factory alone), and on a type past MPSCNNNeuronTypeCount (measured: 16 and 99 abort, -1 is
// accepted, because the type is a signed enum and the test is the same one).
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

// -init is NS_UNAVAILABLE in the header and is not overridden here: a caller that reaches NSObject's -init gets the
// zeroed object the release answers too (measured on the host).

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
    // The release asserts on a data length that is not a positive whole number of floats (measured: 0 to 3 bytes and
    // 5 to 7 abort; 4, 8, 12 and 4096 are taken). The port refuses the same lengths by name and returns nil.
    if (data.length == 0 || data.length % sizeof(float) != 0) {
        CharonMPSRefuse(@"MPSNNNeuronDescriptor: PReLU data of %lu bytes is not a positive whole number of floats, so no descriptor is made",
                        (unsigned long)data.length);
        return nil;
    }
    // The data is retained as given, not copied: the header says so on the property, and a change made to the array
    // afterwards is seen through the descriptor (measured). noCopy is an allocation hint the release takes for a
    // buffer that is not copied, and changes nothing that can be read back here (measured: the same object either way).
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
    // Not checked on the setter (measured: a PReLU type and 16 are accepted here, and refused only by a factory).
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

// The release archives the PReLU data only for a PReLU neuron (measured: an ELU descriptor that holds data reads back
// without it), so the data is written and read back for that type alone.
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
            // The release's decoder answers zeros of PReLuCount floats for a PReLU neuron, whatever the archive holds
            // (measured on the host: data of 1.5 and 2.5 reads back as 0 and 0, and so on for 3 and 5 floats). The port
            // answers the same, so an archive reads the same on both. The encoder writes the data in full, as above.
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
    // The data is copied as an NSData: a copy of a mutable array is a snapshot, and a copy of an immutable one is the
    // same object (measured both ways), which is what -[NSData copy] answers.
    copy->_data = [_data copy];
    return copy;
}

@end
