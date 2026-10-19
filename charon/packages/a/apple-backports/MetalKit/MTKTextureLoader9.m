#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>

#include <stdlib.h>
#include <string.h>

NSString *const MTKTextureLoaderOptionSRGB = @"MTKTextureLoaderOptionSRGB";
NSString *const MTKTextureLoaderErrorDomain = @"MTKTextureLoaderErrorDomain";
NSString *const MTKTextureLoaderErrorKey = @"MTKTextureLoaderErrorKey";
NSString *const MTKTextureLoaderOptionAllocateMipmaps = @"MTKTextureLoaderOptionAllocateMipmaps";
NSString *const MTKTextureLoaderOptionTextureUsage = @"MTKTextureLoaderOptionTextureUsage";
NSString *const MTKTextureLoaderOptionTextureCPUCacheMode = @"MTKTextureLoaderOptionTextureCPUCacheMode";

static void CharonMTKFlipRows(NSMutableData *rgba, size_t width, size_t height)
{
    size_t stride = width * 4;
    uint8_t *bytes = (uint8_t *)rgba.mutableBytes, *row = malloc(stride);
    if (!row)
        return;
    for (size_t top = 0, bottom = height - 1; top < bottom; top++, bottom--) {
        memcpy(row, bytes + top * stride, stride);
        memcpy(bytes + top * stride, bytes + bottom * stride, stride);
        memcpy(bytes + bottom * stride, row, stride);
    }
    free(row);
}

static BOOL CharonMTKShouldFlip(NSDictionary<NSString *, id> *options)
{
    NSString *origin = options[MTKTextureLoaderOptionOrigin];
    if ([origin isEqualToString:MTKTextureLoaderOriginFlippedVertically])
        return YES;
    return [origin isEqualToString:MTKTextureLoaderOriginTopLeft];
}

static id<MTLTexture> CharonMTKTextureFromCGImage(id<MTLDevice> device, CGImageRef image, NSDictionary<NSString *, id> *options, NSError **error)
{
    if (!image) {
        if (error)
            *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"no image to load a texture from"}];
        return nil;
    }
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    if (width == 0 || height == 0) {
        if (error)
            *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"the image has no pixels"}];
        return nil;
    }
    NSMutableData *rgba = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgba.mutableBytes, width, height, 8, width * 4, colorSpace,
                                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        if (error)
            *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"could not create a bitmap context to decode the image into"}];
        return nil;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);

    if (CharonMTKShouldFlip(options))
        CharonMTKFlipRows(rgba, width, height);

    BOOL srgb = [options[MTKTextureLoaderOptionSRGB] boolValue];
    MTLPixelFormat format = srgb ? MTLPixelFormatRGBA8Unorm_sRGB : MTLPixelFormatRGBA8Unorm;
    BOOL mipmapped = [options[MTKTextureLoaderOptionAllocateMipmaps] boolValue] ||
                     [options[MTKTextureLoaderOptionGenerateMipmaps] boolValue];
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:width height:height mipmapped:mipmapped];
    if ([options[MTKTextureLoaderOptionTextureUsage] isKindOfClass:[NSNumber class]])
        descriptor.usage = [options[MTKTextureLoaderOptionTextureUsage] unsignedIntegerValue];
    if ([options[MTKTextureLoaderOptionTextureCPUCacheMode] isKindOfClass:[NSNumber class]])
        descriptor.cpuCacheMode = (MTLCPUCacheMode)[options[MTKTextureLoaderOptionTextureCPUCacheMode] unsignedIntegerValue];
    if ([options[MTKTextureLoaderOptionTextureStorageMode] isKindOfClass:[NSNumber class]])
        descriptor.storageMode = (MTLStorageMode)[options[MTKTextureLoaderOptionTextureStorageMode] unsignedIntegerValue];
    if ([options[MTKTextureLoaderOptionCubeLayout] isKindOfClass:[NSString class]]) {
        if (![options[MTKTextureLoaderOptionCubeLayout] isEqualToString:MTKTextureLoaderCubeLayoutVertical]) {
            if (error)
                *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"the cube layout must be MTKTextureLoaderCubeLayoutVertical, which is the only one the header declares"}];
            return nil;
        }
        if (error)
            *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"a cube layout names six faces arranged vertically in one texture, and this loader was given one image"}];
        return nil;
    }
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    if (!texture) {
        if (error)
            *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"the device could not create a texture for this image"}];
        return nil;
    }
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:rgba.bytes bytesPerRow:width * 4];
    return texture;
}


@implementation MTKTextureLoader
{
    id<MTLDevice> _device;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super init]))
        _device = device;
    return self;
}

- (id<MTLDevice>)device
{
    return _device;
}

- (id<MTLTexture>)newTextureWithCGImage:(CGImageRef)cgImage options:(NSDictionary<NSString *, id> *)options error:(NSError **)error
{
    return CharonMTKTextureFromCGImage(_device, cgImage, options, error);
}

- (void)newTextureWithCGImage:(CGImageRef)cgImage options:(NSDictionary<NSString *, id> *)options completionHandler:(void (^)(id<MTLTexture>, NSError *))completionHandler
{
    NSError *error = nil;
    id<MTLTexture> texture = [self newTextureWithCGImage:cgImage options:options error:&error];
    if (completionHandler)
        completionHandler(texture, error);
}

- (id<MTLTexture>)newTextureWithData:(NSData *)data options:(NSDictionary<NSString *, id> *)options error:(NSError **)error
{
    UIImage *image = [UIImage imageWithData:data];
    if (!image) {
        if (error)
            *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"the data is not an image this port can decode"}];
        return nil;
    }
    return CharonMTKTextureFromCGImage(_device, image.CGImage, options, error);
}

- (void)newTextureWithData:(NSData *)data options:(NSDictionary<NSString *, id> *)options completionHandler:(void (^)(id<MTLTexture>, NSError *))completionHandler
{
    NSError *error = nil;
    id<MTLTexture> texture = [self newTextureWithData:data options:options error:&error];
    if (completionHandler)
        completionHandler(texture, error);
}

- (id<MTLTexture>)newTextureWithContentsOfURL:(NSURL *)URL options:(NSDictionary<NSString *, id> *)options error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfURL:URL options:0 error:error];
    return data ? [self newTextureWithData:data options:options error:error] : nil;
}

- (void)newTextureWithContentsOfURL:(NSURL *)URL options:(NSDictionary<NSString *, id> *)options completionHandler:(void (^)(id<MTLTexture>, NSError *))completionHandler
{
    NSError *error = nil;
    id<MTLTexture> texture = [self newTextureWithContentsOfURL:URL options:options error:&error];
    if (completionHandler)
        completionHandler(texture, error);
}

- (NSArray<id<MTLTexture>> *)newTexturesWithContentsOfURLs:(NSArray<NSURL *> *)URLs options:(NSDictionary<NSString *, id> *)options error:(NSError **)error
{
    NSMutableArray *textures = [NSMutableArray array];
    for (NSURL *URL in URLs) {
        id<MTLTexture> texture = [self newTextureWithContentsOfURL:URL options:options error:error];
        if (!texture)
            return nil;
        [textures addObject:texture];
    }
    return textures;
}

- (void)newTexturesWithContentsOfURLs:(NSArray<NSURL *> *)URLs options:(NSDictionary<NSString *, id> *)options completionHandler:(void (^)(NSArray<id<MTLTexture>> *, NSError *))completionHandler
{
    NSError *error = nil;
    NSArray *textures = [self newTexturesWithContentsOfURLs:URLs options:options error:&error];
    if (completionHandler)
        completionHandler(textures, error);
}

- (id<MTLTexture>)newTextureWithName:(NSString *)name scaleFactor:(CGFloat)scaleFactor bundle:(NSBundle *)bundle options:(NSDictionary<NSString *, id> *)options error:(NSError **)error
{
    UIImage *image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
    if (!image) {
        if (error)
            *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"no image named %@ in the given bundle", name]}];
        return nil;
    }
    return CharonMTKTextureFromCGImage(_device, image.CGImage, options, error);
}

- (void)newTextureWithName:(NSString *)name scaleFactor:(CGFloat)scaleFactor bundle:(NSBundle *)bundle options:(NSDictionary<NSString *, id> *)options completionHandler:(void (^)(id<MTLTexture>, NSError *))completionHandler
{
    NSError *error = nil;
    id<MTLTexture> texture = [self newTextureWithName:name scaleFactor:scaleFactor bundle:bundle options:options error:&error];
    if (completionHandler)
        completionHandler(texture, error);
}

- (NSArray<id<MTLTexture>> *)newTexturesWithNames:(NSArray<NSString *> *)names scaleFactor:(CGFloat)scaleFactor bundle:(NSBundle *)bundle options:(NSDictionary<NSString *, id> *)options error:(NSError **)error
{
    NSMutableArray *textures = [NSMutableArray array];
    for (NSString *name in names) {
        id<MTLTexture> texture = [self newTextureWithName:name scaleFactor:scaleFactor bundle:bundle options:options error:error];
        if (!texture)
            return nil;
        [textures addObject:texture];
    }
    return textures;
}

- (void)newTexturesWithNames:(NSArray<NSString *> *)names scaleFactor:(CGFloat)scaleFactor bundle:(NSBundle *)bundle options:(NSDictionary<NSString *, id> *)options completionHandler:(void (^)(NSArray<id<MTLTexture>> *, NSError *))completionHandler
{
    NSError *error = nil;
    NSArray *textures = [self newTexturesWithNames:names scaleFactor:scaleFactor bundle:bundle options:options error:&error];
    if (completionHandler)
        completionHandler(textures, error);
}

@end
