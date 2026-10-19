#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#import "CharonMPSNN.h"

@implementation MPSNNStateNode {
    id<MPSHandle> _handle;
    BOOL _exportFromGraph;
    MPSState *_charonState;
}

@synthesize handle = _handle;
@synthesize exportFromGraph = _exportFromGraph;

- (MPSState *)charon_mps_state { return _charonState; }
- (void)charon_mps_setState:(MPSState *)state { _charonState = state; }

@end


@implementation MPSNNBinaryArithmeticNode {
    MPSKernel *_kernel;
    float _primaryScale, _secondaryScale, _bias, _minimumValue, _maximumValue;
    NSUInteger _primaryStrideInPixelsX, _primaryStrideInPixelsY, _primaryStrideInFeatureChannels;
    NSUInteger _secondaryStrideInPixelsX, _secondaryStrideInPixelsY, _secondaryStrideInFeatureChannels;
}

@synthesize primaryScale = _primaryScale;
@synthesize secondaryScale = _secondaryScale;
@synthesize bias = _bias;
@synthesize minimumValue = _minimumValue;
@synthesize maximumValue = _maximumValue;
@synthesize primaryStrideInPixelsX = _primaryStrideInPixelsX;
@synthesize primaryStrideInPixelsY = _primaryStrideInPixelsY;
@synthesize primaryStrideInFeatureChannels = _primaryStrideInFeatureChannels;
@synthesize secondaryStrideInPixelsX = _secondaryStrideInPixelsX;
@synthesize secondaryStrideInPixelsY = _secondaryStrideInPixelsY;
@synthesize secondaryStrideInFeatureChannels = _secondaryStrideInFeatureChannels;

+ (Class)charon_mps_kernelClass { return [MPSImageAdd class]; }

- (instancetype)initWithLeftSource:(MPSNNImageNode *)left rightSource:(MPSNNImageNode *)right
{
    if ((self = [super initWithDevice:nil])) {
        _primaryScale = 1.0f;
        _secondaryScale = 1.0f;
        _bias = 0.0f;
        _minimumValue = -FLT_MAX;
        _maximumValue = FLT_MAX;
        [self charon_mps_addSourceNode:left];
        [self charon_mps_addSourceNode:right];
    }
    return self;
}

+ (instancetype)nodeWithLeftSource:(MPSNNImageNode *)left rightSource:(MPSNNImageNode *)right
{
    return [[self alloc] initWithLeftSource:left rightSource:right];
}

- (instancetype)initWithSources:(NSArray<MPSNNImageNode *> *)sourceNodes
{
    if (sourceNodes.count != 2) {
        CharonMPSRefuse(@"%@: an arithmetic node needs exactly two sources and was given %lu, so none was made",
                        NSStringFromClass([self class]), (unsigned long)sourceNodes.count);
        return nil;
    }
    return [self initWithLeftSource:sourceNodes[0] rightSource:sourceNodes[1]];
}

+ (instancetype)nodeWithSources:(NSArray<MPSNNImageNode *> *)sourceNodes
{
    return [[self alloc] initWithSources:sourceNodes];
}

- (MPSKernel *)charon_mps_kernel
{
    if (!_kernel) {
        id<MTLDevice> device = [self charon_mps_device];
        if (!device)
            device = MTLCreateSystemDefaultDevice();
        _kernel = [[[self class] charon_mps_kernelClass] alloc];
        _kernel = [_kernel initWithDevice:device];
    }
    return _kernel;
}

- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    MPSImage *primary = [self charon_mps_sourceImageAtIndex:0];
    MPSImage *secondary = [self charon_mps_sourceImageAtIndex:1];
    MPSImage *destination = [self charon_mps_destinationImage];
    if (!primary || !secondary || !destination) {
        CharonMPSRefuse(@"%@: an arithmetic node needs two sources and a destination and was not given all three",
                        NSStringFromClass([self class]));
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    [self charon_mps_kernel];
    MPSImageArithmetic *kernel = (MPSImageArithmetic *)_kernel;
    kernel.primaryScale = self.primaryScale;
    kernel.secondaryScale = self.secondaryScale;
    kernel.bias = self.bias;
    kernel.minimumValue = self.minimumValue;
    kernel.maximumValue = self.maximumValue;
    kernel.primaryStrideInPixels = MTLSizeMake(self.primaryStrideInPixelsX, self.primaryStrideInPixelsY,
                                               self.primaryStrideInFeatureChannels);
    kernel.secondaryStrideInPixels = MTLSizeMake(self.secondaryStrideInPixelsX, self.secondaryStrideInPixelsY,
                                                 self.secondaryStrideInFeatureChannels);
    [kernel encodeToCommandBuffer:commandBuffer
                     primaryImage:primary
                   secondaryImage:secondary
                destinationImage:destination];
    [self.resultImage charon_mps_setImage:destination];
}

@end


@implementation MPSCNNPoolingNode {
    MPSCNNPooling *_kernel;
    NSUInteger _kernelWidth, _kernelHeight, _strideX, _strideY;
}

+ (Class)charon_mps_kernelClass { return nil; }

- (instancetype)initWithSource:(MPSNNImageNode *)sourceNode
                  kernelWidth:(NSUInteger)kernelWidth
                 kernelHeight:(NSUInteger)kernelHeight
              strideInPixelsX:(NSUInteger)strideX
              strideInPixelsY:(NSUInteger)strideY
{
    if ((self = [super initWithDevice:nil])) {
        _kernelWidth = kernelWidth ? kernelWidth : 1;
        _kernelHeight = kernelHeight ? kernelHeight : 1;
        _strideX = strideX ? strideX : 1;
        _strideY = strideY ? strideY : 1;
        [self charon_mps_addSourceNode:sourceNode];
    }
    return self;
}

- (instancetype)initWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size
{
    return [self initWithSource:sourceNode kernelWidth:size kernelHeight:size strideInPixelsX:size strideInPixelsY:size];
}

- (instancetype)initWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size stride:(NSUInteger)stride
{
    return [self initWithSource:sourceNode kernelWidth:size kernelHeight:size strideInPixelsX:stride strideInPixelsY:stride];
}

+ (instancetype)nodeWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size
{
    return [[self alloc] initWithSource:sourceNode filterSize:size];
}

+ (instancetype)nodeWithSource:(MPSNNImageNode *)sourceNode filterSize:(NSUInteger)size stride:(NSUInteger)stride
{
    return [[self alloc] initWithSource:sourceNode filterSize:size stride:stride];
}

- (MPSKernel *)charon_mps_kernel
{
    if (!_kernel) {
        Class kernelClass = [[self class] charon_mps_kernelClass];
        if (!kernelClass)
            return nil;
        id<MTLDevice> device = [self charon_mps_device];
        if (!device)
            device = MTLCreateSystemDefaultDevice();
        _kernel = [kernelClass alloc];
        _kernel = [_kernel initWithDevice:device
                              kernelWidth:_kernelWidth
                             kernelHeight:_kernelHeight
                            strideInPixelsX:_strideX
                            strideInPixelsY:_strideY];
    }
    return _kernel;
}

- (void)charon_mps_encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    MPSImage *source = [self charon_mps_sourceImageAtIndex:0];
    MPSImage *destination = [self charon_mps_destinationImage];
    if (!source || !destination) {
        CharonMPSRefuse(@"%@: a pooling node needs a source and a destination and was not given both",
                        NSStringFromClass([self class]));
        return;
    }
    if (!CharonMPSCommandBufferPermits(commandBuffer))
        return;
    MPSCNNPooling *kernel = (MPSCNNPooling *)[self charon_mps_kernel];
    if (!kernel) {
        CharonMPSRefuse(@"%@: no pooling kernel to run, so it was not run", NSStringFromClass([self class]));
        return;
    }
    [kernel encodeToCommandBuffer:commandBuffer sourceImage:source destinationImage:destination];
    [self.resultImage charon_mps_setImage:destination];
}

@end

#pragma clang diagnostic pop
