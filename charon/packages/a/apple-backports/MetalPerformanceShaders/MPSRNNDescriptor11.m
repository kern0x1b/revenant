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
