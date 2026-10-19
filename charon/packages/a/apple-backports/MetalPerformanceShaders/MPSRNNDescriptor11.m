// MPSRNNDescriptor, from the header of MPSRNNLayer.h in the SDK of iOS 16.4: the shape and the switches
// every recurrent layer descriptor shares, as a plain object with no storage of its own beyond its members.
//
// The declared members are the five the 16.4 header gives, and nothing else. The host's own MPS also
// carries inputTransform, outputTransform, recurrentOutputTransform and internalKernelSelector on this
// class; the 16.4 header does not declare them, so this port does not either (see facts/MetalPerformanceShaders/MPSRNNDescriptor.md).
//
// The defaults are the host's, read from Apple's own object: inputFeatureChannels and outputFeatureChannels
// are 1, the two flags are NO and layerSequenceDirection is MPSRNNSequenceDirectionForward. The object is
// not NSCopying and not NSSecureCoding on the host, so this port is not either: copy raises there, and it
// raises here, because no copyWithZone: is defined. Equality and hash are NSObject's, identity, as there.

#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MPSRNNDescriptor {
    NSUInteger _inputFeatureChannels;
    NSUInteger _outputFeatureChannels;
    BOOL _useLayerInputUnitTransformMode;
    BOOL _useFloat32Weights;
    MPSRNNSequenceDirection _layerSequenceDirection;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _inputFeatureChannels = 1;
        _outputFeatureChannels = 1;
        _useLayerInputUnitTransformMode = NO;
        _useFloat32Weights = NO;
        _layerSequenceDirection = MPSRNNSequenceDirectionForward;
    }
    return self;
}

// The members are plain values the header declares as properties: a getter and a setter over one field
// each, written out so the compiler checks every spelling against the header rather than a macro hiding them.

- (NSUInteger)inputFeatureChannels
{
    return _inputFeatureChannels;
}

- (void)setInputFeatureChannels:(NSUInteger)value
{
    _inputFeatureChannels = value;
}

- (NSUInteger)outputFeatureChannels
{
    return _outputFeatureChannels;
}

- (void)setOutputFeatureChannels:(NSUInteger)value
{
    _outputFeatureChannels = value;
}

- (BOOL)useLayerInputUnitTransformMode
{
    return _useLayerInputUnitTransformMode;
}

- (void)setUseLayerInputUnitTransformMode:(BOOL)value
{
    _useLayerInputUnitTransformMode = value;
}

- (BOOL)useFloat32Weights
{
    return _useFloat32Weights;
}

- (void)setUseFloat32Weights:(BOOL)value
{
    _useFloat32Weights = value;
}

- (MPSRNNSequenceDirection)layerSequenceDirection
{
    return _layerSequenceDirection;
}

- (void)setLayerSequenceDirection:(MPSRNNSequenceDirection)value
{
    _layerSequenceDirection = value;
}

@end
