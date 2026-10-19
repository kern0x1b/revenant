#import "CharonMetal.h"


@implementation MTLStencilDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        self.stencilCompareFunction = MTLCompareFunctionAlways;
        self.stencilFailureOperation = MTLStencilOperationKeep;
        self.depthFailureOperation = MTLStencilOperationKeep;
        self.depthStencilPassOperation = MTLStencilOperationKeep;
        self.readMask = 0xFFFFFFFF;
        self.writeMask = 0xFFFFFFFF;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLStencilDescriptor *d = [[MTLStencilDescriptor alloc] init];
    d.stencilCompareFunction = self.stencilCompareFunction;
    d.stencilFailureOperation = self.stencilFailureOperation;
    d.depthFailureOperation = self.depthFailureOperation;
    d.depthStencilPassOperation = self.depthStencilPassOperation;
    d.readMask = self.readMask;
    d.writeMask = self.writeMask;
    return d;
}

@end

@implementation MTLDepthStencilDescriptor {
    MTLStencilDescriptor *_frontFaceStencil;
    MTLStencilDescriptor *_backFaceStencil;
}

- (instancetype)init
{
    if ((self = [super init])) {
        self.depthCompareFunction = MTLCompareFunctionAlways;
        _frontFaceStencil = [[MTLStencilDescriptor alloc] init];
        _backFaceStencil = [[MTLStencilDescriptor alloc] init];
    }
    return self;
}

- (MTLStencilDescriptor *)frontFaceStencil
{
    return _frontFaceStencil;
}

- (void)setFrontFaceStencil:(MTLStencilDescriptor *)frontFaceStencil
{
    _frontFaceStencil = frontFaceStencil ? [frontFaceStencil copy] : [[MTLStencilDescriptor alloc] init];
}

- (MTLStencilDescriptor *)backFaceStencil
{
    return _backFaceStencil;
}

- (void)setBackFaceStencil:(MTLStencilDescriptor *)backFaceStencil
{
    _backFaceStencil = backFaceStencil ? [backFaceStencil copy] : [[MTLStencilDescriptor alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLDepthStencilDescriptor *d = [[MTLDepthStencilDescriptor alloc] init];
    d.depthCompareFunction = self.depthCompareFunction;
    d.depthWriteEnabled = self.depthWriteEnabled;
    d.frontFaceStencil = self.frontFaceStencil;
    d.backFaceStencil = self.backFaceStencil;
    d.label = self.label;
    return d;
}

@end
