#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <OpenGLES/EAGL.h>

@protocol RevenantMetalDeviceContext <NSObject>
@property (nonatomic, readonly) EAGLContext *context;
@end

static BOOL revenant_ci_format(MTLPixelFormat pixelFormat, CIFormat *format, NSUInteger *bytesPerPixel)
{
    switch (pixelFormat) {
        case MTLPixelFormatBGRA8Unorm:
            *format = kCIFormatBGRA8;
            *bytesPerPixel = 4;
            return YES;
        case MTLPixelFormatRGBA8Unorm:
            *format = kCIFormatRGBA8;
            *bytesPerPixel = 4;
            return YES;
        case MTLPixelFormatRGBA16Float:
            *format = kCIFormatRGBAh;
            *bytesPerPixel = 8;
            return YES;
        case MTLPixelFormatRGBA32Float:
            *format = kCIFormatRGBAf;
            *bytesPerPixel = 16;
            return YES;
        default:
            return NO;
    }
}

@implementation CIContext (RevenantMetal)

+ (CIContext *)contextWithMTLDevice:(id<MTLDevice>)device
{
    return [self contextWithMTLDevice:device options:nil];
}

+ (CIContext *)contextWithMTLDevice:(id<MTLDevice>)device options:(NSDictionary<CIContextOption, id> *)options
{
    Class backing = NSClassFromString(@"RevenantMetalDevice");
    if (!backing || ![(id)device isKindOfClass:backing])
        return nil;
    EAGLContext *context = [(id<RevenantMetalDeviceContext>)device context];
    return context ? [self contextWithEAGLContext:context options:options] : nil;
}

+ (CIContext *)contextWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
{
    return [self contextWithMTLDevice:commandQueue.device options:nil];
}

+ (CIContext *)contextWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue options:(NSDictionary<CIContextOption, id> *)options
{
    return [self contextWithMTLDevice:commandQueue.device options:options];
}

- (void)render:(CIImage *)image toMTLTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer bounds:(CGRect)bounds colorSpace:(CGColorSpaceRef)colorSpace
{
    CIFormat format;
    NSUInteger bytesPerPixel;
    if (!image || !texture || texture.textureType != MTLTextureType2D || !revenant_ci_format(texture.pixelFormat, &format, &bytesPerPixel))
        return;
    if (CGRectIsNull(bounds) || CGRectIsInfinite(bounds))
        return;
    NSUInteger width = MIN(texture.width, (NSUInteger)MAX(0, floor(bounds.size.width)));
    NSUInteger height = MIN(texture.height, (NSUInteger)MAX(0, floor(bounds.size.height)));
    if (width == 0 || height == 0)
        return;
    CGAffineTransform toBottomRowFirst = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-bounds.origin.x, -bounds.origin.y), CGAffineTransformMake(1, 0, 0, -1, 0, (CGFloat)height));
    NSUInteger rowBytes = width * bytesPerPixel;
    NSMutableData *pixels = [NSMutableData dataWithLength:rowBytes * height];
    [self render:[image imageByApplyingTransform:toBottomRowFirst] toBitmap:pixels.mutableBytes rowBytes:(NSInteger)rowBytes bounds:CGRectMake(0, 0, width, height) format:format colorSpace:colorSpace];
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:pixels.bytes bytesPerRow:rowBytes];
}

@end
