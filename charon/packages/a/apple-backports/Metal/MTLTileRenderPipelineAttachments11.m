#import <Metal/Metal.h>
#import <Foundation/Foundation.h>

// THE TILE RENDER PIPELINE'S COLOUR ATTACHMENTS, and they arrived with the SDK of iOS 11, so they are
// in an object of their own and not in MTL4Descriptors26.m: an object holds the API of ONE release,
// and these two classes are 11.0 while everything beside them is 26.0. The 16.4 SDK this package
// compiles against declares both, so there is nothing to transcribe - only bodies to write.
//
// THE HEADER DECLARES EXACTLY THREE MEMBERS between the two classes, and the port implements exactly
// those: the attachment's one property, pixelFormat, and the array's two indexed members. There is no
// -count, no -reset and no NSCopying on the array here, and the port does not add any.
//
// EIGHT SLOTS, measured against Apple's own array rather than read off a header: indices 0 to 7 answer
// a descriptor and index 8 fails the framework's own assertion. The measurement is out of process,
// one index per invocation, because that assertion STOPS the process - measured here, and it is the
// same shape as the four-slot measurement facts/Metal/Descriptors16.md records for the 14.0 family.
//
// A NIL AT A LEGAL INDEX RESETS the slot to the defaults, which is what the header's own sentence says about setting it:
// the attachment state may be set to nil at any legal index, and the defaults are restored. The only default there is one member, and it is MTLPixelFormatInvalid.

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