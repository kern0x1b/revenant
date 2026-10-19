// The one pyramid walk MPSImagePyramid10.m, MPSImageLaplacianPyramid12.m and MPSImagePyramid16.m share:
// three objects, one per release, because the release exports MPSImageGaussianPyramid from 10.0.1, the
// three Laplacian pyramid classes from 12.0 and MPSImagePyramid itself only from 16.0 - MPSImageConvolution.h
// annotates all five ios(10.0) and the releases do not agree, which is measured and written down where each
// class is implemented. An object carries one release.
#pragma once
#import "CharonMPS.h"

// The filter's own three values, which MPSImagePyramid16.m implements out of two private ivars and both
// kernels read: MPSImageConvolution.h declares kernelWidth and kernelHeight as properties and keeps the
// weights themselves private, so a subclass's category cannot see them - the compiler says so outright
// ("instance variable '_kernel' is private"). So the class publishes them under names no SDK header
// declares. This is the same arrangement as MPSCNNKernel10.m's charon_mps_setWindowWidth:, which exists
// because the convolution and the pooling file both read it.
//
// THE READER NEVER HAS TO ASK WHETHER IT IS THERE, and that is measured rather than assumed. An object is
// placed by what the release EXPORTS: a band keeps an object the release does not export, and re-exports one
// it does. The base is exported strictly later than both kernels over it - 16.0 against 10.0.1 and 12.0 - so
// every band that keeps a kernel is below 16.0 and keeps MPSImagePyramid16.m with it. That is why the two
// callers below read the accessors directly, and why there is no respondsToSelector: anywhere in this
// family: the release's own MPSImagePyramid, which answers none of them, is only in a band that carries
// neither kernel.
@interface MPSImagePyramid (CharonMPSImagePyramidFilter)
- (const float *)charon_mps_filter;
- (NSUInteger)charon_mps_filterWidth;
- (NSUInteger)charon_mps_filterHeight;
@end

// The shape of the twelve pixel formats MPSImage's own mapping produces (MPSImage13.m:50-73). The channel
// format back from a pixel format is MPSImage13.m's own function, and it is not called here: it is defined in
// MPSImage13.m, which is not an object every band keeps - a band whose release exports MPSImage links the
// release's class and drops that file - so a call to it would be an undefined symbol in exactly the bands
// these objects are kept for. This table is the pyramid family's own and answers the one question its kernels
// ask of a texture, which is how wide a pixel is.
static inline BOOL CharonMPSPyramidPixelShape(MTLPixelFormat pixel, NSUInteger *channels, size_t *elementSize)
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

// max(1, floor(base / 2^level)), MPSImageConvolution.h:510-511.
static inline NSUInteger CharonMPSPyramidExtent(NSUInteger base, NSUInteger level)
{
    NSUInteger extent = base >> level;
    return extent ? extent : 1;
}

// A level of a texture, read into or written from a buffer of its own shape. The texture's own read and write
// are the ones every other MPSImage kernel uses (CharonMPSImageReadRegion and CharonMPSImageWriteRegion,
// which go through -readBytes: and -writeBytes: on an MPSImage); a pyramid is given a TEXTURE and works on its
// MIP LEVELS, which no MPSImage of this port wraps, so the texture's own -getBytes:...-mipmapLevel: and
// -replaceRegion:...-mipmapLevel: are used directly here.
static inline BOOL CharonMPSPyramidRead(id<MTLTexture> texture, NSUInteger level, NSUInteger width, NSUInteger height,
                                        NSUInteger channels, size_t elementSize, void *buffer)
{
    size_t stride = width * channels * elementSize;
    if (level >= texture.mipmapLevelCount)
        return NO;
    [texture getBytes:buffer bytesPerRow:stride fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:level];
    return YES;
}

static inline BOOL CharonMPSPyramidWrite(id<MTLTexture> texture, NSUInteger level, NSUInteger width, NSUInteger height,
                                         NSUInteger channels, size_t elementSize, const void *buffer)
{
    size_t stride = width * channels * elementSize;
    if (level >= texture.mipmapLevelCount)
        return NO;
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:level withBytes:buffer bytesPerRow:stride];
    return YES;
}
