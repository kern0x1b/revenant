#pragma once
#import "RevenantMPS.h"

@interface MPSImagePyramid (RevenantMPSImagePyramidFilter)
- (const float *)revenant_mps_filter;
- (NSUInteger)revenant_mps_filterWidth;
- (NSUInteger)revenant_mps_filterHeight;
@end

static inline BOOL RevenantMPSPyramidPixelShape(MTLPixelFormat pixel, NSUInteger *channels, size_t *elementSize)
{
    size_t element;
    NSUInteger count;
    switch (pixel) {
    case MTLPixelFormatR8Unorm:    element = 1; count = 1; break;
    case MTLPixelFormatRG8Unorm:   element = 1; count = 2; break;
    case MTLPixelFormatRGBA8Unorm: element = 1; count = 4; break;
    case MTLPixelFormatR16Unorm:   element = 2; count = 1; break;
    case MTLPixelFormatRG16Unorm:  element = 2; count = 2; break;
    case MTLPixelFormatRGBA16Unorm:element = 2; count = 4; break;
    case MTLPixelFormatR16Float:   element = 2; count = 1; break;
    case MTLPixelFormatRG16Float:  element = 2; count = 2; break;
    case MTLPixelFormatRGBA16Float:element = 2; count = 4; break;
    case MTLPixelFormatR32Float:   element = 4; count = 1; break;
    case MTLPixelFormatRG32Float:  element = 4; count = 2; break;
    case MTLPixelFormatRGBA32Float:element = 4; count = 4; break;
    default: return NO;
    }
    if (channels)
        *channels = count;
    if (elementSize)
        *elementSize = element;
    return YES;
}

static inline NSUInteger RevenantMPSPyramidExtent(NSUInteger base, NSUInteger level)
{
    NSUInteger extent = base >> level;
    return extent ? extent : 1;
}

static inline BOOL RevenantMPSPyramidRead(id<MTLTexture> texture, NSUInteger level, NSUInteger width, NSUInteger height,
                                        NSUInteger channels, size_t elementSize, void *buffer)
{
    size_t stride = width * channels * elementSize;
    if (level >= texture.mipmapLevelCount)
        return NO;
    [texture getBytes:buffer bytesPerRow:stride fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:level];
    return YES;
}

static inline BOOL RevenantMPSPyramidWrite(id<MTLTexture> texture, NSUInteger level, NSUInteger width, NSUInteger height,
                                         NSUInteger channels, size_t elementSize, const void *buffer)
{
    size_t stride = width * channels * elementSize;
    if (level >= texture.mipmapLevelCount)
        return NO;
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:level withBytes:buffer bytesPerRow:stride];
    return YES;
}
