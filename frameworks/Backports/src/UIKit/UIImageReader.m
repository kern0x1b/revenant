#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

@implementation UIImageReaderConfiguration {
    BOOL _prefersHighDynamicRange;
    BOOL _preparesImagesForDisplay;
    CGSize _preferredThumbnailSize;
    CGFloat _pixelsPerInch;
}

- (BOOL)prefersHighDynamicRange
{
    return _prefersHighDynamicRange;
}

- (void)setPrefersHighDynamicRange:(BOOL)prefersHighDynamicRange
{
    _prefersHighDynamicRange = prefersHighDynamicRange;
}

- (BOOL)preparesImagesForDisplay
{
    return _preparesImagesForDisplay;
}

- (void)setPreparesImagesForDisplay:(BOOL)preparesImagesForDisplay
{
    _preparesImagesForDisplay = preparesImagesForDisplay;
}

- (CGSize)preferredThumbnailSize
{
    return _preferredThumbnailSize;
}

- (void)setPreferredThumbnailSize:(CGSize)preferredThumbnailSize
{
    _preferredThumbnailSize = preferredThumbnailSize;
}

- (CGFloat)pixelsPerInch
{
    return _pixelsPerInch;
}

- (void)setPixelsPerInch:(CGFloat)pixelsPerInch
{
    _pixelsPerInch = pixelsPerInch;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIImageReaderConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy->_prefersHighDynamicRange = _prefersHighDynamicRange;
    copy->_preparesImagesForDisplay = _preparesImagesForDisplay;
    copy->_preferredThumbnailSize = _preferredThumbnailSize;
    copy->_pixelsPerInch = _pixelsPerInch;
    return copy;
}

@end

static UIImageOrientation revenant_orientation(NSNumber *exif)
{
    switch (exif.intValue) {
    case 2: return UIImageOrientationUpMirrored;
    case 3: return UIImageOrientationDown;
    case 4: return UIImageOrientationDownMirrored;
    case 5: return UIImageOrientationLeftMirrored;
    case 6: return UIImageOrientationRight;
    case 7: return UIImageOrientationRightMirrored;
    case 8: return UIImageOrientationLeft;
    default: return UIImageOrientationUp;
    }
}

static CGImageRef revenant_decoded(CGImageRef image)
{
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    if (!context)
        return CGImageRetain(image);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGImageRef drawn = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return drawn ?: CGImageRetain(image);
}

static UIImage *revenant_read(CGImageSourceRef source, UIImageReaderConfiguration *configuration)
{
    if (!source || !CGImageSourceGetCount(source))
        return nil;
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    UIImageOrientation orientation = revenant_orientation(properties[(__bridge NSString *)kCGImagePropertyOrientation]);
    CGSize thumbnail = configuration.preferredThumbnailSize;
    CGFloat scale = [UIScreen mainScreen].scale;
    CGImageRef image;
    if (thumbnail.width > 0 && thumbnail.height > 0) {
        NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                                  (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
                                  (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(MAX(thumbnail.width, thumbnail.height) * scale)};
        image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
        orientation = UIImageOrientationUp;
    } else {
        image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        scale = 1;
    }
    if (!image)
        return nil;
    if (configuration.preparesImagesForDisplay) {
        CGImageRef decoded = revenant_decoded(image);
        CGImageRelease(image);
        image = decoded;
    }
    UIImage *result = [UIImage imageWithCGImage:image scale:scale orientation:orientation];
    CGImageRelease(image);
    return result;
}

@implementation UIImageReader {
    UIImageReaderConfiguration *_configuration;
}

+ (UIImageReader *)defaultReader
{
    static UIImageReader *reader;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        reader = [UIImageReader readerWithConfiguration:[[UIImageReaderConfiguration alloc] init]];
    });
    return reader;
}

+ (instancetype)readerWithConfiguration:(UIImageReaderConfiguration *)configuration
{
    UIImageReader *reader = [[self alloc] init];
    reader->_configuration = [configuration copy];
    return reader;
}

- (UIImageReaderConfiguration *)configuration
{
    return [_configuration copy];
}

- (UIImage *)imageWithContentsOfFileURL:(NSURL *)url
{
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    UIImage *image = revenant_read(source, _configuration);
    if (source)
        CFRelease(source);
    return image;
}

- (UIImage *)imageWithData:(NSData *)data
{
    CGImageSourceRef source = data ? CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL) : NULL;
    UIImage *image = revenant_read(source, _configuration);
    if (source)
        CFRelease(source);
    return image;
}

- (void)imageWithContentsOfFileURL:(NSURL *)url completion:(void (^)(UIImage *))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self imageWithContentsOfFileURL:url];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    });
}

- (void)imageWithData:(NSData *)data completion:(void (^)(UIImage *))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self imageWithData:data];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    });
}

@end
