#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface RevenantMetalBlitEncoder (Options)
@end

@implementation RevenantMetalBlitEncoder (Options)

static BOOL RevenantMetalBlitAcceptsOptions(MTLBlitOption options, const char *what)
{
    if (options == MTLBlitOptionNone)
        return YES;
    NSLog(@"Metal: blit option 0x%lx on %s is refused: this port has no compressed format to decompress, and its depth and stencil are not Metal's packed pair",
          (unsigned long)options, what);
    return NO;
}

- (void)copyFromBuffer:(id<MTLBuffer>)sourceBuffer sourceOffset:(NSUInteger)sourceOffset sourceBytesPerRow:(NSUInteger)sourceBytesPerRow sourceBytesPerImage:(NSUInteger)sourceBytesPerImage sourceSize:(MTLSize)sourceSize toTexture:(id<MTLTexture>)destinationTexture destinationSlice:(NSUInteger)destinationSlice destinationLevel:(NSUInteger)destinationLevel destinationOrigin:(MTLOrigin)destinationOrigin options:(MTLBlitOption)options
{
    if (!RevenantMetalBlitAcceptsOptions(options, "a copy from a buffer into a texture"))
        return;
    [self copyFromBuffer:sourceBuffer sourceOffset:sourceOffset sourceBytesPerRow:sourceBytesPerRow
        sourceBytesPerImage:sourceBytesPerImage sourceSize:sourceSize toTexture:destinationTexture
         destinationSlice:destinationSlice destinationLevel:destinationLevel destinationOrigin:destinationOrigin];
}

- (void)copyFromTexture:(id<MTLTexture>)sourceTexture sourceSlice:(NSUInteger)sourceSlice sourceLevel:(NSUInteger)sourceLevel sourceOrigin:(MTLOrigin)sourceOrigin sourceSize:(MTLSize)sourceSize toBuffer:(id<MTLBuffer>)destinationBuffer destinationOffset:(NSUInteger)destinationOffset destinationBytesPerRow:(NSUInteger)destinationBytesPerRow destinationBytesPerImage:(NSUInteger)destinationBytesPerImage options:(MTLBlitOption)options
{
    if (!RevenantMetalBlitAcceptsOptions(options, "a copy from a texture into a buffer"))
        return;
    [self copyFromTexture:sourceTexture sourceSlice:sourceSlice sourceLevel:sourceLevel sourceOrigin:sourceOrigin
                 sourceSize:sourceSize toBuffer:destinationBuffer destinationOffset:destinationOffset
       destinationBytesPerRow:destinationBytesPerRow destinationBytesPerImage:destinationBytesPerImage];
}

@end
