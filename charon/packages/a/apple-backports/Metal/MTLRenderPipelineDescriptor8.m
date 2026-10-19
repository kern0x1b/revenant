#import "CharonMetal.h"

// The defaults a new colour attachment has, written into an object that already exists. Apple's nil store into
// a slot does this in place: the slot's object stays and its fields go back to these (measured on the macOS host,
// tests/backports/host/color-attachment-nil). The index of the slot is checked by the array, as Apple's is.
static void CharonResetColorAttachment(MTLRenderPipelineColorAttachmentDescriptor *d)
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
        CharonResetColorAttachment(self);
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

// Apple's array has eight slots and asserts on any other index, both to read and to write (measured: status 134,
// "attachmentIndex(8) must be < 8").
- (MTLRenderPipelineColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= 8)
        [NSException raise:NSInternalInconsistencyException format:@"attachmentIndex(%lu) must be < 8",
                                                                   (unsigned long)attachmentIndex];
    return _items[attachmentIndex];
}

// A nil attachment resets the slot in place, as Apple's does; any other attachment is stored as a copy.
- (void)setObject:(MTLRenderPipelineColorAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= 8)
        [NSException raise:NSInternalInconsistencyException format:@"attachmentIndex(%lu) must be < 8",
                                                                   (unsigned long)attachmentIndex];
    if (!attachment) {
        CharonResetColorAttachment(_items[attachmentIndex]);
        return;
    }
    _items[attachmentIndex] = [attachment copy];
}

@end

// A copy of a linked-functions object, with the same four arrays. MTLLinkedFunctions carries no copy of its own in
// this port, so the copy is written here, as the mesh descriptor's is.
static MTLLinkedFunctions *CharonCopyLinkedFunctions(MTLLinkedFunctions *source)
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
        // A fresh descriptor answers an empty linked-functions object for each stage, never nil (measured on the host).
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

// null_resettable, as Apple's properties are: a nil store gives a NEW empty object (measured: not the object that
// was there before, and not the fresh one), and any other store keeps a copy.
- (MTLLinkedFunctions *)vertexLinkedFunctions
{
    return _vertexLinkedFunctions;
}

- (void)setVertexLinkedFunctions:(MTLLinkedFunctions *)linkedFunctions
{
    _vertexLinkedFunctions = linkedFunctions ? CharonCopyLinkedFunctions(linkedFunctions)
                                             : [[MTLLinkedFunctions alloc] init];
}

- (MTLLinkedFunctions *)fragmentLinkedFunctions
{
    return _fragmentLinkedFunctions;
}

- (void)setFragmentLinkedFunctions:(MTLLinkedFunctions *)linkedFunctions
{
    _fragmentLinkedFunctions = linkedFunctions ? CharonCopyLinkedFunctions(linkedFunctions)
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
