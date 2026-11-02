#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

CGImageByteOrderInfo BACKPORT_IMPL(CGImageGetByteOrderInfo)(CGImageRef image)
{
    return image ? (CGImageByteOrderInfo)(CGImageGetBitmapInfo(image) & 0x7000) : (CGImageByteOrderInfo)0;
}

CGImagePixelFormatInfo BACKPORT_IMPL(CGImageGetPixelFormatInfo)(CGImageRef image)
{
    return image ? (CGImagePixelFormatInfo)(CGImageGetBitmapInfo(image) & 0xF0000) : (CGImagePixelFormatInfo)0;
}
