#import "CharonGraphicsRenderer.h"

static CGColorSpaceRef charon_renderer_color_space(void)
{
    static CGColorSpaceRef space;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        if (!space)
            space = CGColorSpaceCreateDeviceRGB();
    });
    return space;
}

@implementation UIGraphicsImageRenderer

+ (Class)rendererContextClass
{
    return [UIGraphicsImageRendererContext class];
}

+ (CGContextRef)contextWithFormat:(UIGraphicsImageRendererFormat *)format
{
    CGFloat scale = [format _contextScale];
    CGRect bounds = format ? format.bounds : CGRectZero;
    size_t width = (size_t)ceilf(scale * bounds.size.width);
    size_t height = (size_t)ceilf(scale * bounds.size.height);
    if (!width || !height)
        return NULL;
    CGBitmapInfo info = kCGBitmapByteOrder32Little
                      | (format.opaque ? kCGImageAlphaNoneSkipFirst : kCGImageAlphaPremultipliedFirst);
    return CGBitmapContextCreate(NULL, width, height, 8, CGBitmapGetAlignedBytesPerRow(width * 4), charon_renderer_color_space(), info);
}

+ (void)prepareCGContext:(CGContextRef)context withRendererContext:(UIGraphicsImageRendererContext *)rendererContext
{
    UIGraphicsImageRendererFormat *format = rendererContext.format;
    CGFloat scale = [format _contextScale];
    size_t height = CGBitmapContextGetHeight(context);
    CGContextClearRect(context, CGRectMake(0, 0, CGBitmapContextGetWidth(context), height));
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, scale, -scale);
    CGRect bounds = format ? format.bounds : CGRectZero;
    CGContextTranslateCTM(context, -bounds.origin.x, -bounds.origin.y);
}

- (instancetype)init
{
    return [self initWithSize:CGSizeZero];
}

- (instancetype)initWithSize:(CGSize)size
{
    return [self initWithSize:size format:[UIGraphicsImageRendererFormat defaultFormat]];
}

- (instancetype)initWithSize:(CGSize)size format:(UIGraphicsImageRendererFormat *)format
{
    return [super initWithBounds:CGRectMake(0, 0, size.width, size.height) format:format];
}

- (instancetype)initWithBounds:(CGRect)bounds
{
    return [self initWithBounds:bounds format:[UIGraphicsImageRendererFormat defaultFormat]];
}

- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsImageRendererFormat *)format
{
    return [super initWithBounds:bounds format:format];
}

- (BOOL)allowsImageOutput
{
    return YES;
}

- (void)pushContext:(UIGraphicsRendererContext *)context
{
    UIGraphicsPushContext(context.CGContext);
}

- (void)popContext:(UIGraphicsRendererContext *)context
{
    UIGraphicsPopContext();
}

- (UIImage *)imageWithActions:(NS_NOESCAPE UIGraphicsImageDrawingActions)actions
{
    __block UIImage *image = nil;
    [self runDrawingActions:(UIGraphicsDrawingActions)actions
          completionActions:^(UIGraphicsImageRendererContext *rendererContext) {
              image = rendererContext.currentImage;
          }
                      error:NULL];
    return image ? image : [[UIImage alloc] init];
}

- (NSData *)PNGDataWithActions:(NS_NOESCAPE UIGraphicsImageDrawingActions)actions
{
    __block NSData *data = nil;
    [self runDrawingActions:(UIGraphicsDrawingActions)actions
          completionActions:^(UIGraphicsImageRendererContext *rendererContext) {
              data = UIImagePNGRepresentation(rendererContext.currentImage);
          }
                      error:NULL];
    return data ? data : [[NSData alloc] init];
}

- (NSData *)JPEGDataWithCompressionQuality:(CGFloat)compressionQuality actions:(NS_NOESCAPE UIGraphicsImageDrawingActions)actions
{
    __block NSData *data = nil;
    [self runDrawingActions:(UIGraphicsDrawingActions)actions
          completionActions:^(UIGraphicsImageRendererContext *rendererContext) {
              data = UIImageJPEGRepresentation(rendererContext.currentImage, compressionQuality);
          }
                      error:NULL];
    return data ? data : [[NSData alloc] init];
}

@end
