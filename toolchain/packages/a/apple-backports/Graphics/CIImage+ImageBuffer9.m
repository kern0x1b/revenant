#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CIImage (CharonImageBuffer)

static BOOL charon_is_pixel_buffer(CVImageBufferRef buffer)
{
    return buffer && CFGetTypeID(buffer) == CVPixelBufferGetTypeID();
}

- (instancetype)initWithCVImageBuffer:(CVImageBufferRef)imageBuffer
{
    return [self initWithCVImageBuffer:imageBuffer options:nil];
}

- (instancetype)initWithCVImageBuffer:(CVImageBufferRef)imageBuffer options:(NSDictionary<CIImageOption, id> *)options
{
    if (!charon_is_pixel_buffer(imageBuffer))
        return nil;
    return [self initWithCVPixelBuffer:imageBuffer options:options];
}

+ (CIImage *)imageWithCVImageBuffer:(CVImageBufferRef)imageBuffer
{
    return [[self alloc] initWithCVImageBuffer:imageBuffer options:nil];
}

+ (CIImage *)imageWithCVImageBuffer:(CVImageBufferRef)imageBuffer options:(NSDictionary<CIImageOption, id> *)options
{
    return [[self alloc] initWithCVImageBuffer:imageBuffer options:options];
}

@end
