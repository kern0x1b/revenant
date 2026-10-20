#import <ARKit/ARKit.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface ARReferenceImage ()
@property (nonatomic, assign) CGSize imageSize;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, strong, nullable) NSString *resourceGroupName;
@end

@implementation ARReferenceImage

@synthesize name = _name;
@synthesize physicalSize = _physicalSize;
@synthesize resourceGroupName = _resourceGroupName;
@synthesize imageSize = _imageSize;
@synthesize width = _width;

static CGSize RevenantPhysicalSize(CGSize pixels, CGFloat physicalWidth)
{
    if (pixels.width <= 0 || pixels.height <= 0)
        return CGSizeZero;
    if (physicalWidth <= 0)
        return CGSizeZero;
    return CGSizeMake(physicalWidth, physicalWidth * pixels.height / pixels.width);
}

- (instancetype)initWithCGImage:(CGImageRef)image
                     orientation:(CGImagePropertyOrientation)orientation
                  physicalWidth:(CGFloat)physicalWidth
{
    if (!image)
        return nil;
    self = [super init];
    if (!self)
        return nil;
    _imageSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    _width = physicalWidth;
    _physicalSize = RevenantPhysicalSize(_imageSize, physicalWidth);
    return self;
}

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                         orientation:(CGImagePropertyOrientation)orientation
                      physicalWidth:(CGFloat)physicalWidth
{
    if (!pixelBuffer)
        return nil;
    self = [super init];
    if (!self)
        return nil;
    _imageSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    _width = physicalWidth;
    _physicalSize = RevenantPhysicalSize(_imageSize, physicalWidth);
    return self;
}

+ (nullable NSSet<ARReferenceImage *> *)referenceImagesInGroupNamed:(NSString *)name
                                                            bundle:(nullable NSBundle *)bundle
{
    if (!name)
        return nil;
    NSBundle *where = bundle ?: [NSBundle mainBundle];
    NSString *folder = [where pathForResource:name ofType:@"arreferenceimage"];
    if (!folder)
        return nil;

    NSString *contents = [folder stringByAppendingPathComponent:@"Contents.json"];
    NSData *json = [NSData dataWithContentsOfFile:contents];
    if (!json)
        return nil;
    NSDictionary *described = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
    if (![described isKindOfClass:[NSDictionary class]])
        return nil;

    NSString *picture = described[@"image"];
    NSNumber *width = described[@"width"];
    if (![picture isKindOfClass:[NSString class]] || ![width isKindOfClass:[NSNumber class]])
        return nil;
    NSString *path = [folder stringByAppendingPathComponent:picture];
    NSData *bytes = [NSData dataWithContentsOfFile:path];
    if (!bytes)
        return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)bytes, NULL);
    if (!source)
        return nil;
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (!image)
        return nil;

    ARReferenceImage *reference = [[self alloc] initWithCGImage:image
                                                     orientation:kCGImagePropertyOrientationUp
                                                  physicalWidth:(CGFloat)width.doubleValue];
    CGImageRelease(image);
    if (!reference)
        return nil;
    reference.name = name;
    reference.resourceGroupName = name;
    return [NSSet setWithObject:reference];
}

- (void)validateWithCompletionHandler:(void (^)(NSError *_Nullable))completionHandler
{
    if (!completionHandler)
        return;
    NSError *error = nil;
    if (_imageSize.width <= 0 || _imageSize.height <= 0)
        error = [NSError errorWithDomain:@"space.kern0x1b.arkit" code:10
                                userInfo:@{ NSLocalizedDescriptionKey:
                                                @"the reference image has no pixels" }];
    else if (_width <= 0)
        error = [NSError errorWithDomain:@"space.kern0x1b.arkit" code:11
                                userInfo:@{ NSLocalizedDescriptionKey:
                                                @"the reference image has no physical width, so a tracked shape has nothing to be measured against" }];
    dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(error); });
}

@end

NS_ASSUME_NONNULL_END
