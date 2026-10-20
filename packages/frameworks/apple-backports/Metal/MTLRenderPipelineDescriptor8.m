#import "RevenantMetal.h"

static void RevenantResetColorAttachment(MTLRenderPipelineColorAttachmentDescriptor *d)
{
    d.pixelFormat = MTLPixelFormatInvalid;
    d.blendingEnabled = NO;
    d.writeMask = MTLColorWriteMaskAll;
    d.sourceRGBBlendFactor = MTLBlendFactorOne;
    d.sourceAlphaBlendFactor = MTLBlendFactorOne;
    d.destinationRGBBlendFactor = MTLBlendFactorZero;
    d.destinationAlphaBlendFactor = MTLBlendFactorZero;
    d.rgbBlendOperation = MTLBlendOperationAdd;
    d.alphaBlendOperation = MTLBlendOperationAdd;
}

@implementation MTLRenderPipelineColorAttachmentDescriptor

- (instancetype)init
{
    if ((self = [super init]))
        RevenantResetColorAttachment(self);
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLRenderPipelineColorAttachmentDescriptor *d = [[MTLRenderPipelineColorAttachmentDescriptor alloc] init];
    d.pixelFormat = self.pixelFormat;
    d.blendingEnabled = self.blendingEnabled;
    d.sourceRGBBlendFactor = self.sourceRGBBlendFactor;
    d.destinationRGBBlendFactor = self.destinationRGBBlendFactor;
    d.rgbBlendOperation = self.rgbBlendOperation;
    d.sourceAlphaBlendFactor = self.sourceAlphaBlendFactor;
    d.destinationAlphaBlendFactor = self.destinationAlphaBlendFactor;
    d.alphaBlendOperation = self.alphaBlendOperation;
    d.writeMask = self.writeMask;
    return d;
}

@end

@implementation MTLRenderPipelineColorAttachmentDescriptorArray {
    NSMutableArray *_items;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _items = [NSMutableArray array];
        for (int i = 0; i < 8; i++)
            [_items addObject:[[MTLRenderPipelineColorAttachmentDescriptor alloc] init]];
    }
    return self;
}

- (MTLRenderPipelineColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= 8)
        [NSException raise:NSInternalInconsistencyException format:@"attachmentIndex(%lu) must be < 8",
                                                                   (unsigned long)attachmentIndex];
    return _items[attachmentIndex];
}

- (void)setObject:(MTLRenderPipelineColorAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= 8)
        [NSException raise:NSInternalInconsistencyException format:@"attachmentIndex(%lu) must be < 8",
                                                                   (unsigned long)attachmentIndex];
    if (!attachment) {
        RevenantResetColorAttachment(_items[attachmentIndex]);
        return;
    }
    _items[attachmentIndex] = [attachment copy];
}

@end

static MTLLinkedFunctions *RevenantCopyLinkedFunctions(MTLLinkedFunctions *source)
{
    MTLLinkedFunctions *copy = [[MTLLinkedFunctions alloc] init];
    copy.functions = source.functions;
    copy.binaryFunctions = source.binaryFunctions;
    copy.groups = source.groups;
    copy.privateFunctions = source.privateFunctions;
    return copy;
}

@implementation MTLRenderPipelineDescriptor {
    MTLRenderPipelineColorAttachmentDescriptorArray *_colorAttachments;
    MTLLinkedFunctions *_vertexLinkedFunctions;
    MTLLinkedFunctions *_fragmentLinkedFunctions;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _colorAttachments = [[MTLRenderPipelineColorAttachmentDescriptorArray alloc] init];
        _vertexLinkedFunctions = [[MTLLinkedFunctions alloc] init];
        _fragmentLinkedFunctions = [[MTLLinkedFunctions alloc] init];
        self.rasterSampleCount = 1;
        self.rasterizationEnabled = YES;
    }
    return self;
}

- (MTLRenderPipelineColorAttachmentDescriptorArray *)colorAttachments
{
    return _colorAttachments;
}

- (MTLLinkedFunctions *)vertexLinkedFunctions
{
    return _vertexLinkedFunctions;
}

- (void)setVertexLinkedFunctions:(MTLLinkedFunctions *)linkedFunctions
{
    _vertexLinkedFunctions = linkedFunctions ? RevenantCopyLinkedFunctions(linkedFunctions)
                                             : [[MTLLinkedFunctions alloc] init];
}

- (MTLLinkedFunctions *)fragmentLinkedFunctions
{
    return _fragmentLinkedFunctions;
}

- (void)setFragmentLinkedFunctions:(MTLLinkedFunctions *)linkedFunctions
{
    _fragmentLinkedFunctions = linkedFunctions ? RevenantCopyLinkedFunctions(linkedFunctions)
                                               : [[MTLLinkedFunctions alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLRenderPipelineDescriptor *d = [[MTLRenderPipelineDescriptor alloc] init];
    d.vertexFunction = self.vertexFunction;
    d.fragmentFunction = self.fragmentFunction;
    d.label = self.label;
    for (int i = 0; i < 8; i++)
        d.colorAttachments[i] = self.colorAttachments[i];
    d.vertexLinkedFunctions = self.vertexLinkedFunctions;
    d.fragmentLinkedFunctions = self.fragmentLinkedFunctions;
    d.depthAttachmentPixelFormat = self.depthAttachmentPixelFormat;
    d.vertexDescriptor = self.vertexDescriptor;
    return d;
}

@end
