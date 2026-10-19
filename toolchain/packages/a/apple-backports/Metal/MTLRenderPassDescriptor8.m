#import "CharonMetal.h"


@implementation MTLRenderPassAttachmentDescriptor

- (id)copyWithZone:(NSZone *)zone
{
    MTLRenderPassAttachmentDescriptor *d = [[[self class] alloc] init];
    d.texture = self.texture;
    d.level = self.level;
    d.slice = self.slice;
    d.loadAction = self.loadAction;
    d.storeAction = self.storeAction;
    return d;
}

@end

@implementation MTLRenderPassColorAttachmentDescriptor

- (instancetype)init
{
    if ((self = [super init]))
        self.clearColor = MTLClearColorMake(0, 0, 0, 1);
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLRenderPassColorAttachmentDescriptor *d = [super copyWithZone:zone];
    d.clearColor = self.clearColor;
    return d;
}

@end

@implementation MTLRenderPassColorAttachmentDescriptorArray {
    NSMutableArray *_items;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _items = [NSMutableArray array];
        for (int i = 0; i < 8; i++)
            [_items addObject:[[MTLRenderPassColorAttachmentDescriptor alloc] init]];
    }
    return self;
}

- (MTLRenderPassColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex
{
    return _items[attachmentIndex];
}

- (void)setObject:(MTLRenderPassColorAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)attachmentIndex
{
    _items[attachmentIndex] = [attachment copy];
}

@end

@implementation MTLRenderPassDepthAttachmentDescriptor

- (instancetype)init
{
    if ((self = [super init]))
        self.clearDepth = 1.0;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLRenderPassDepthAttachmentDescriptor *d = [super copyWithZone:zone];
    d.clearDepth = self.clearDepth;
    return d;
}

@end

@implementation MTLRenderPassStencilAttachmentDescriptor

- (id)copyWithZone:(NSZone *)zone
{
    MTLRenderPassStencilAttachmentDescriptor *d = [super copyWithZone:zone];
    d.clearStencil = self.clearStencil;
    return d;
}

@end

@implementation MTLRenderPassDescriptor {
    MTLRenderPassColorAttachmentDescriptorArray *_colorAttachments;
    MTLRenderPassDepthAttachmentDescriptor *_depthAttachment;
    MTLRenderPassStencilAttachmentDescriptor *_stencilAttachment;
}

+ (MTLRenderPassDescriptor *)renderPassDescriptor
{
    return [[MTLRenderPassDescriptor alloc] init];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _colorAttachments = [[MTLRenderPassColorAttachmentDescriptorArray alloc] init];
        _depthAttachment = [[MTLRenderPassDepthAttachmentDescriptor alloc] init];
        _stencilAttachment = [[MTLRenderPassStencilAttachmentDescriptor alloc] init];
    }
    return self;
}

- (MTLRenderPassDepthAttachmentDescriptor *)depthAttachment
{
    return _depthAttachment;
}

- (void)setDepthAttachment:(MTLRenderPassDepthAttachmentDescriptor *)depthAttachment
{
    _depthAttachment = depthAttachment ? [depthAttachment copy] : [[MTLRenderPassDepthAttachmentDescriptor alloc] init];
}

- (MTLRenderPassStencilAttachmentDescriptor *)stencilAttachment
{
    return _stencilAttachment;
}

- (void)setStencilAttachment:(MTLRenderPassStencilAttachmentDescriptor *)stencilAttachment
{
    _stencilAttachment = stencilAttachment ? [stencilAttachment copy] : [[MTLRenderPassStencilAttachmentDescriptor alloc] init];
}

- (MTLRenderPassColorAttachmentDescriptorArray *)colorAttachments
{
    return _colorAttachments;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLRenderPassDescriptor *d = [[MTLRenderPassDescriptor alloc] init];
    for (int i = 0; i < 8; i++)
        d.colorAttachments[i] = self.colorAttachments[i];
    d.depthAttachment = self.depthAttachment;
    d.stencilAttachment = self.stencilAttachment;
    return d;
}

@end
