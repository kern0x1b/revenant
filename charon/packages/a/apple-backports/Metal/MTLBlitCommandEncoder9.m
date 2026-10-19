#import "CharonMetal.h"

// The 9.0 blits are the 8.0 ones with a set of options on top, so they live in a category beside the
// 8.0 class: a band from 9.0 on keeps both files and a band of 8.0 keeps only the class, which is
// what the release it is built for can have.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The 9.0 blits are the 8.0 ones with a set of options on top. This port has no compressed format to
// decompress a row of, and its depth and stencil are ES 2.0's own pair rather than Metal's packed
// one, so an option other than none names a blit the port does not do: it says so in the log and
// copies nothing.

@interface CharonMetalBlitEncoder (Options)
@end

@implementation CharonMetalBlitEncoder (Options)

static BOOL CharonMetalBlitAcceptsOptions(MTLBlitOption options, const char *what)
{
    if (options == MTLBlitOptionNone)
        return YES;
    NSLog(@"Metal: blit option 0x%lx on %s is refused: this port has no compressed format to decompress, and its depth and stencil are not Metal's packed pair",
          (unsigned long)options, what);
    return NO;
}

- (void)copyFromBuffer:(id<MTLBuffer>)sourceBuffer sourceOffset:(NSUInteger)sourceOffset sourceBytesPerRow:(NSUInteger)sourceBytesPerRow sourceBytesPerImage:(NSUInteger)sourceBytesPerImage sourceSize:(MTLSize)sourceSize toTexture:(id<MTLTexture>)destinationTexture destinationSlice:(NSUInteger)destinationSlice destinationLevel:(NSUInteger)destinationLevel destinationOrigin:(MTLOrigin)destinationOrigin options:(MTLBlitOption)options
{
    if (!CharonMetalBlitAcceptsOptions(options, "a copy from a buffer into a texture"))
        return;
    [self copyFromBuffer:sourceBuffer sourceOffset:sourceOffset sourceBytesPerRow:sourceBytesPerRow
        sourceBytesPerImage:sourceBytesPerImage sourceSize:sourceSize toTexture:destinationTexture
         destinationSlice:destinationSlice destinationLevel:destinationLevel destinationOrigin:destinationOrigin];
}

- (void)copyFromTexture:(id<MTLTexture>)sourceTexture sourceSlice:(NSUInteger)sourceSlice sourceLevel:(NSUInteger)sourceLevel sourceOrigin:(MTLOrigin)sourceOrigin sourceSize:(MTLSize)sourceSize toBuffer:(id<MTLBuffer>)destinationBuffer destinationOffset:(NSUInteger)destinationOffset destinationBytesPerRow:(NSUInteger)destinationBytesPerRow destinationBytesPerImage:(NSUInteger)destinationBytesPerImage options:(MTLBlitOption)options
{
    if (!CharonMetalBlitAcceptsOptions(options, "a copy from a texture into a buffer"))
        return;
    [self copyFromTexture:sourceTexture sourceSlice:sourceSlice sourceLevel:sourceLevel sourceOrigin:sourceOrigin
                 sourceSize:sourceSize toBuffer:destinationBuffer destinationOffset:destinationOffset
       destinationBytesPerRow:destinationBytesPerRow destinationBytesPerImage:destinationBytesPerImage];
}

@end
