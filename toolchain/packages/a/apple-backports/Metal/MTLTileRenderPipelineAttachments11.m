#import <Metal/Metal.h>
#import <Foundation/Foundation.h>

enum { CharonMetalTileColorAttachmentSlots = 8 };

@implementation MTLTileRenderPipelineColorAttachmentDescriptor {
    MTLPixelFormat _pixelFormat;
}

@synthesize pixelFormat = _pixelFormat;

- (id)copyWithZone:(NSZone *)zone
{
    MTLTileRenderPipelineColorAttachmentDescriptor *copy = [[MTLTileRenderPipelineColorAttachmentDescriptor alloc] init];
    copy.pixelFormat = _pixelFormat;
    return copy;
}

@end

@implementation MTLTileRenderPipelineColorAttachmentDescriptorArray {
    MTLTileRenderPipelineColorAttachmentDescriptor *_slots[CharonMetalTileColorAttachmentSlots];
}

- (MTLTileRenderPipelineColorAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= CharonMetalTileColorAttachmentSlots) {
        [NSException raise:NSRangeException
                    format:@"colorAttachments[%lu]: this array has %lu slots",
                           (unsigned long)attachmentIndex, (unsigned long)CharonMetalTileColorAttachmentSlots];
        return nil;
    }
    if (!_slots[attachmentIndex])
        _slots[attachmentIndex] = [[MTLTileRenderPipelineColorAttachmentDescriptor alloc] init];
    return _slots[attachmentIndex];
}

- (void)setObject:(MTLTileRenderPipelineColorAttachmentDescriptor *)attachment
    atIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachmentIndex >= CharonMetalTileColorAttachmentSlots) {
        [NSException raise:NSRangeException
                    format:@"setObject:atIndexedSubscript:%lu: this array has %lu slots",
                           (unsigned long)attachmentIndex, (unsigned long)CharonMetalTileColorAttachmentSlots];
        return;
    }
    if (attachment)
        _slots[attachmentIndex] = [attachment copy];
    else
        _slots[attachmentIndex] = [[MTLTileRenderPipelineColorAttachmentDescriptor alloc] init];
}

@end
