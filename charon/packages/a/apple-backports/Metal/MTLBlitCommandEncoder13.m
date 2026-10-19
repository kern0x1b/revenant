#import "CharonMetal.h"


// The 13.0 blits between whole surfaces. -copyFromTexture:toTexture: is the convenience Metal
// documents: as many whole surfaces as the two textures can match, level by level, and both of them
// have to be laid out so that a level of one is the same size as a level of the other.

@implementation CharonMetalBlitEncoder (Surfaces)

- (void)copyFromTexture:(id<MTLTexture>)sourceTexture sourceSlice:(NSUInteger)sourceSlice sourceLevel:(NSUInteger)sourceLevel toTexture:(id<MTLTexture>)destinationTexture destinationSlice:(NSUInteger)destinationSlice destinationLevel:(NSUInteger)destinationLevel sliceCount:(NSUInteger)sliceCount levelCount:(NSUInteger)levelCount
{
    if (![sourceTexture isKindOfClass:[CharonMetalTexture class]] || ![destinationTexture isKindOfClass:[CharonMetalTexture class]])
        return;
    CharonMetalTexture *source = (CharonMetalTexture *)sourceTexture;
    CharonMetalTexture *destination = (CharonMetalTexture *)destinationTexture;
    if (source.pixelFormat != destination.pixelFormat) {
        NSLog(@"Metal: a blit of %d whole surfaces between pixel formats %d and %d is refused: Metal asks for the same format at both ends",
              (int)(levelCount * sliceCount), (int)source.pixelFormat, (int)destination.pixelFormat);
        return;
    }
    if (sourceSlice || destinationSlice || sliceCount > 1) {
        NSLog(@"Metal: a blit of %lu array slices is refused: this port has no array textures", (unsigned long)sliceCount);
        return;
    }
    for (NSUInteger level = 0; level < levelCount; level++) {
        NSUInteger from = sourceLevel + level;
        NSUInteger to = destinationLevel + level;
        if (from >= source.mipmapLevelCount || to >= destination.mipmapLevelCount) {
            NSLog(@"Metal: a blit asks for level %lu of %lu, and the textures have %lu and %lu",
                  (unsigned long)(from > to ? from : to), (unsigned long)level,
                  (unsigned long)source.mipmapLevelCount, (unsigned long)destination.mipmapLevelCount);
            return;
        }
        MTLSize size = MTLSizeMake(source.width >> from, source.height >> from, 1);
        MTLRegion fromRegion = MTLRegionMake2D(0, 0, size.width, size.height);
        MTLRegion toRegion = MTLRegionMake2D(0, 0, destination.width >> to, destination.height >> to);
        if (size.width != toRegion.size.width || size.height != toRegion.size.height) {
            NSLog(@"Metal: a blit of whole surfaces needs a source level and a destination level of the same size, and level %lu is %lux%lu against %lux%lu",
                  (unsigned long)level, (unsigned long)size.width, (unsigned long)size.height,
                  (unsigned long)toRegion.size.width, (unsigned long)toRegion.size.height);
            return;
        }
        if (![self charonBlitTexture:source from:fromRegion level:from to:destination region:toRegion level:to])
            return;
    }
}

- (void)copyFromTexture:(id<MTLTexture>)sourceTexture toTexture:(id<MTLTexture>)destinationTexture
{
    if (![sourceTexture isKindOfClass:[CharonMetalTexture class]] || ![destinationTexture isKindOfClass:[CharonMetalTexture class]])
        return;
    CharonMetalTexture *source = (CharonMetalTexture *)sourceTexture;
    CharonMetalTexture *destination = (CharonMetalTexture *)destinationTexture;
    // Metal's own rule for the convenience: one of the two textures has a mip of the size of the
    // other's first mip, and as many levels as both have from there.
    NSUInteger sourceLevel = 0, destinationLevel = 0;
    if (source.width == destination.width && source.height == destination.height) {
        sourceLevel = 0;
        destinationLevel = 0;
    } else {
        for (NSUInteger level = 1; level < source.mipmapLevelCount; level++) {
            if ((source.width >> level) == destination.width && (source.height >> level) == destination.height) {
                sourceLevel = level;
                destinationLevel = 0;
                break;
            }
        }
        if (sourceLevel) {
            NSUInteger levels = source.mipmapLevelCount - sourceLevel;
            NSUInteger other = destination.mipmapLevelCount - destinationLevel;
            [self copyFromTexture:sourceTexture sourceSlice:0 sourceLevel:sourceLevel toTexture:destinationTexture
                     destinationSlice:0 destinationLevel:destinationLevel sliceCount:1
                        levelCount:levels < other ? levels : other];
            return;
        }
        for (NSUInteger level = 1; level < destination.mipmapLevelCount; level++) {
            if ((destination.width >> level) == source.width && (destination.height >> level) == source.height) {
                destinationLevel = level;
                break;
            }
        }
        if (!destinationLevel) {
            NSLog(@"Metal: a blit of whole surfaces needs a mip of one texture the size of the other's first, and a %lux%lu and a %lux%lu have none",
                  (unsigned long)source.width, (unsigned long)source.height,
                  (unsigned long)destination.width, (unsigned long)destination.height);
            return;
        }
    }
    NSUInteger levels = source.mipmapLevelCount - sourceLevel;
    NSUInteger other = destination.mipmapLevelCount - destinationLevel;
    [self copyFromTexture:sourceTexture sourceSlice:0 sourceLevel:sourceLevel toTexture:destinationTexture
             destinationSlice:0 destinationLevel:destinationLevel sliceCount:1
                levelCount:levels < other ? levels : other];
}

@end
