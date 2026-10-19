#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

CGImageByteOrderInfo CGImageGetByteOrderInfo(CGImageRef image)
{
    return image ? (CGImageByteOrderInfo)(CGImageGetBitmapInfo(image) & 0x7000) : (CGImageByteOrderInfo)0;
}

CGImagePixelFormatInfo CGImageGetPixelFormatInfo(CGImageRef image)
{
    return image ? (CGImagePixelFormatInfo)(CGImageGetBitmapInfo(image) & 0xF0000) : (CGImagePixelFormatInfo)0;
}
