#import "CharonMetal.h"
#import "CharonMetalDebugGroups.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static BOOL CharonMetalBlitRangeFits(NSUInteger offset, NSUInteger count, NSUInteger length, NSString *what)
{
    if (offset > length || count > length - offset) {
        NSLog(@"Metal: blit of %lu bytes at offset %lu runs past the %lu bytes of the %@",
              (unsigned long)count, (unsigned long)offset, (unsigned long)length, what);
        return NO;
    }
    return YES;
}

static BOOL CharonMetalBlit2D(NSUInteger offset, MTLSize size, NSUInteger width, NSUInteger height, NSString *what)
{
    if (size.width == 0 || size.height == 0)
        return YES;
    if (offset > width || size.width > width - offset || size.height > height) {
        NSLog(@"Metal: blit of a %lux%lu region at x %lu runs past the %lux%lu of the %@",
              (unsigned long)size.width, (unsigned long)size.height, (unsigned long)offset,
              (unsigned long)width, (unsigned long)height, what);
        return NO;
    }
    return YES;
}

@implementation CharonMetalBlitEncoder {
    NSMutableArray *_groups;
    uint64_t _encoded;
}

@synthesize label;

- (instancetype)init
{
    if ((self = [super init])) {
        _groups = [NSMutableArray array];
    }
    return self;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}

- (uint64_t)charonEncodedCount
{
    return _encoded;
}

- (BOOL)charonBlitTexture:(CharonMetalTexture *)source from:(MTLRegion)from level:(NSUInteger)sourceLevel
                      to:(CharonMetalTexture *)destination region:(MTLRegion)to level:(NSUInteger)destinationLevel
{
    NSUInteger channels = [source charonChannels];
    if (!channels || channels != [destination charonChannels]) {
        NSLog(@"Metal: blit between textures of %lu and %lu channels is refused: this port copies the bytes of a region, and those two formats hold a different number of them",
              (unsigned long)[source charonChannels], (unsigned long)[destination charonChannels]);
        return NO;
    }
    if (from.size.width != to.size.width || from.size.height != to.size.height) {
        NSLog(@"Metal: blit of a %lux%lu region into a %lux%lu one is refused: this port copies a region of the source's own shape",
              (unsigned long)from.size.width, (unsigned long)from.size.height,
              (unsigned long)to.size.width, (unsigned long)to.size.height);
        return NO;
    }
    if (!from.size.height)
        return YES;
    NSUInteger rowBytes = from.size.width * channels;
    void *scratch = calloc(1, rowBytes * from.size.height);
    if (!scratch)
        return NO;
    BOOL read = [source charonReadRegion:from level:sourceLevel bytesPerRow:rowBytes into:scratch];
    BOOL wrote = read ? [destination charonWriteRegion:to level:destinationLevel bytes:scratch bytesPerRow:rowBytes] : NO;
    free(scratch);
    if (!read || !wrote)
        NSLog(@"Metal: blit of a %lux%lu region of a texture of pixel format %d is refused: this port has no OpenGL ES 2.0 form of it",
              (unsigned long)from.size.width, (unsigned long)from.size.height, (int)source.pixelFormat);
    return read && wrote;
}


- (void)endEncoding
{
}

- (void)pushDebugGroup:(NSString *)string
{
    CharonMetalPushDebugGroup(_groups, string);
}

- (void)popDebugGroup
{
    CharonMetalPopDebugGroup(_groups, self);
}

- (void)insertDebugSignpost:(NSString *)string
{
}

- (void)copyFromBuffer:(id<MTLBuffer>)sourceBuffer sourceOffset:(NSUInteger)sourceOffset toBuffer:(id<MTLBuffer>)destinationBuffer destinationOffset:(NSUInteger)destinationOffset size:(NSUInteger)size
{
    if (![sourceBuffer isKindOfClass:[CharonMetalBuffer class]] || ![destinationBuffer isKindOfClass:[CharonMetalBuffer class]])
        return;
    CharonMetalBuffer *source = (CharonMetalBuffer *)sourceBuffer;
    CharonMetalBuffer *destination = (CharonMetalBuffer *)destinationBuffer;
    if (!CharonMetalBlitRangeFits(sourceOffset, size, source.length, @"source buffer") ||
        !CharonMetalBlitRangeFits(destinationOffset, size, destination.length, @"destination buffer"))
        return;
    ++_encoded;
    memmove(destination.bytes + destinationOffset, source.bytes + sourceOffset, size);
}

- (void)copyFromBuffer:(id<MTLBuffer>)sourceBuffer sourceOffset:(NSUInteger)sourceOffset sourceBytesPerRow:(NSUInteger)sourceBytesPerRow sourceBytesPerImage:(NSUInteger)sourceBytesPerImage sourceSize:(MTLSize)sourceSize toTexture:(id<MTLTexture>)destinationTexture destinationSlice:(NSUInteger)destinationSlice destinationLevel:(NSUInteger)destinationLevel destinationOrigin:(MTLOrigin)destinationOrigin
{
    if (![sourceBuffer isKindOfClass:[CharonMetalBuffer class]] || ![destinationTexture isKindOfClass:[CharonMetalTexture class]])
        return;
    CharonMetalBuffer *source = (CharonMetalBuffer *)sourceBuffer;
    CharonMetalTexture *destination = (CharonMetalTexture *)destinationTexture;
    NSUInteger channels = [destination charonChannels];
    if (!channels) {
        NSLog(@"Metal: blit into a texture of pixel format %d is refused: this port has no OpenGL ES 2.0 form of it", (int)destination.pixelFormat);
        return;
    }
    if (destinationSlice) {
        NSLog(@"Metal: blit into array slice %lu is refused: this port has no array textures", (unsigned long)destinationSlice);
        return;
    }
    if (sourceBytesPerRow < sourceSize.width * channels) {
        NSLog(@"Metal: blit of %lu bytes per row into a region %lu pixels wide of %lu channels needs %lu",
              (unsigned long)sourceBytesPerRow, (unsigned long)sourceSize.width, (unsigned long)channels,
              (unsigned long)(sourceSize.width * channels));
        return;
    }
    NSUInteger height = sourceSize.height;
    if (sourceBytesPerImage && sourceBytesPerImage < sourceBytesPerRow * height) {
        NSLog(@"Metal: blit of %lu bytes per image needs at least %lu", (unsigned long)sourceBytesPerImage, (unsigned long)(sourceBytesPerRow * height));
        return;
    }
    NSUInteger imageBytes = sourceBytesPerImage ? sourceBytesPerImage : sourceBytesPerRow * height;
    if (!CharonMetalBlitRangeFits(sourceOffset, imageBytes, source.length, @"source buffer"))
        return;
    if (!CharonMetalBlit2D(destinationOrigin.x, sourceSize, destination.width >> destinationLevel, destination.height >> destinationLevel, @"destination texture"))
        return;
    MTLRegion to = MTLRegionMake2D(destinationOrigin.x, destinationOrigin.y, sourceSize.width, sourceSize.height);
    ++_encoded;
    if (![destination charonWriteRegion:to level:destinationLevel bytes:(const uint8_t *)source.bytes + sourceOffset bytesPerRow:sourceBytesPerRow])
        NSLog(@"Metal: blit of a %lux%lu region into a texture of pixel format %d is refused", (unsigned long)sourceSize.width, (unsigned long)sourceSize.height, (int)destination.pixelFormat);
}

- (void)copyFromTexture:(id<MTLTexture>)sourceTexture sourceSlice:(NSUInteger)sourceSlice sourceLevel:(NSUInteger)sourceLevel sourceOrigin:(MTLOrigin)sourceOrigin sourceSize:(MTLSize)sourceSize toBuffer:(id<MTLBuffer>)destinationBuffer destinationOffset:(NSUInteger)destinationOffset destinationBytesPerRow:(NSUInteger)destinationBytesPerRow destinationBytesPerImage:(NSUInteger)destinationBytesPerImage
{
    if (![sourceTexture isKindOfClass:[CharonMetalTexture class]] || ![destinationBuffer isKindOfClass:[CharonMetalBuffer class]])
        return;
    CharonMetalTexture *source = (CharonMetalTexture *)sourceTexture;
    CharonMetalBuffer *destination = (CharonMetalBuffer *)destinationBuffer;
    NSUInteger channels = [source charonChannels];
    if (!channels) {
        NSLog(@"Metal: blit out of a texture of pixel format %d is refused: this port has no OpenGL ES 2.0 form of it", (int)source.pixelFormat);
        return;
    }
    if (sourceSlice) {
        NSLog(@"Metal: blit out of array slice %lu is refused: this port has no array textures", (unsigned long)sourceSlice);
        return;
    }
    if (destinationBytesPerRow < sourceSize.width * channels) {
        NSLog(@"Metal: blit of a region %lu pixels wide of %lu channels into %lu bytes per row does not fit", (unsigned long)sourceSize.width, (unsigned long)channels, (unsigned long)destinationBytesPerRow);
        return;
    }
    NSUInteger height = sourceSize.height;
    if (destinationBytesPerImage && destinationBytesPerImage < destinationBytesPerRow * height) {
        NSLog(@"Metal: blit of %lu bytes per image needs at least %lu", (unsigned long)destinationBytesPerImage, (unsigned long)(destinationBytesPerRow * height));
        return;
    }
    NSUInteger imageBytes = destinationBytesPerImage ? destinationBytesPerImage : destinationBytesPerRow * height;
    if (!CharonMetalBlitRangeFits(destinationOffset, imageBytes, destination.length, @"destination buffer"))
        return;
    if (!CharonMetalBlit2D(sourceOrigin.x, sourceSize, source.width >> sourceLevel, source.height >> sourceLevel, @"source texture"))
        return;
    MTLRegion from = MTLRegionMake2D(sourceOrigin.x, sourceOrigin.y, sourceSize.width, sourceSize.height);
    ++_encoded;
    if (![source charonReadRegion:from level:sourceLevel bytesPerRow:destinationBytesPerRow into:(uint8_t *)destination.bytes + destinationOffset])
        NSLog(@"Metal: blit of a %lux%lu region out of a texture of pixel format %d is refused", (unsigned long)sourceSize.width, (unsigned long)sourceSize.height, (int)source.pixelFormat);
}

- (void)copyFromTexture:(id<MTLTexture>)sourceTexture sourceSlice:(NSUInteger)sourceSlice sourceLevel:(NSUInteger)sourceLevel sourceOrigin:(MTLOrigin)sourceOrigin sourceSize:(MTLSize)sourceSize toTexture:(id<MTLTexture>)destinationTexture destinationSlice:(NSUInteger)destinationSlice destinationLevel:(NSUInteger)destinationLevel destinationOrigin:(MTLOrigin)destinationOrigin
{
    if (![sourceTexture isKindOfClass:[CharonMetalTexture class]] || ![destinationTexture isKindOfClass:[CharonMetalTexture class]])
        return;
    CharonMetalTexture *source = (CharonMetalTexture *)sourceTexture;
    CharonMetalTexture *destination = (CharonMetalTexture *)destinationTexture;
    if (sourceSlice || destinationSlice) {
        NSLog(@"Metal: blit of array slice %lu is refused: this port has no array textures", (unsigned long)(sourceSlice ? sourceSlice : destinationSlice));
        return;
    }
    if (!CharonMetalBlit2D(sourceOrigin.x, sourceSize, source.width >> sourceLevel, source.height >> sourceLevel, @"source texture") ||
        !CharonMetalBlit2D(destinationOrigin.x, sourceSize, destination.width >> destinationLevel, destination.height >> destinationLevel, @"destination texture"))
        return;
    MTLRegion from = MTLRegionMake2D(sourceOrigin.x, sourceOrigin.y, sourceSize.width, sourceSize.height);
    MTLRegion to = MTLRegionMake2D(destinationOrigin.x, destinationOrigin.y, sourceSize.width, sourceSize.height);
    ++_encoded;
    [self charonBlitTexture:source from:from level:sourceLevel to:destination region:to level:destinationLevel];
}

- (void)fillBuffer:(id<MTLBuffer>)buffer range:(NSRange)range value:(uint8_t)value
{
    if (![buffer isKindOfClass:[CharonMetalBuffer class]])
        return;
    CharonMetalBuffer *target = (CharonMetalBuffer *)buffer;
    if (!CharonMetalBlitRangeFits(range.location, range.length, target.length, @"filled buffer"))
        return;
    ++_encoded;
    memset(target.bytes + range.location, value, range.length);
}

- (void)generateMipmapsForTexture:(id<MTLTexture>)texture
{
    if (![texture isKindOfClass:[CharonMetalTexture class]])
        return;
    ++_encoded;
    if (![(CharonMetalTexture *)texture charonGenerateMipmaps])
        NSLog(@"Metal: mipmaps were asked of a texture of pixel format %d with %lu levels, which this port cannot build",
              (int)[(id<MTLTexture>)texture pixelFormat], (unsigned long)[(id<MTLTexture>)texture mipmapLevelCount]);
}

@end
