#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <OpenGLES/ES2/gl.h>
#import <objc/runtime.h>

static const char revenant_metal_texture_key;

@protocol RevenantMetalTextureName <NSObject>
@property (nonatomic, readonly) GLuint name;
@end

static BOOL revenant_texture_format(MTLPixelFormat pixelFormat)
{
    return pixelFormat == MTLPixelFormatBGRA8Unorm || pixelFormat == MTLPixelFormatRGBA8Unorm;
}

@implementation CIImage (RevenantMetalTexture)

- (instancetype)initWithMTLTexture:(id<MTLTexture>)texture options:(NSDictionary<CIImageOption, id> *)options
{
    Class backing = NSClassFromString(@"RevenantMetalTexture");
    if (!texture || !backing || ![(id)texture isKindOfClass:backing] || texture.textureType != MTLTextureType2D || !revenant_texture_format(texture.pixelFormat))
        return nil;
    GLuint name = [(id<RevenantMetalTextureName>)texture name];
    if (name == 0)
        return nil;
    id space = options[kCIImageColorSpace];
    CGColorSpaceRef colorSpace = space && ![space isKindOfClass:[NSNull class]] ? (__bridge CGColorSpaceRef)space : NULL;
    self = [self initWithTexture:name size:CGSizeMake(texture.width, texture.height) flipped:NO colorSpace:colorSpace];
    if (self && options.count == 0)
        objc_setAssociatedObject(self, &revenant_metal_texture_key, texture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

+ (CIImage *)imageWithMTLTexture:(id<MTLTexture>)texture options:(NSDictionary<CIImageOption, id> *)options
{
    return [[self alloc] initWithMTLTexture:texture options:options];
}

- (id<MTLTexture>)metalTexture
{
    return objc_getAssociatedObject(self, &revenant_metal_texture_key);
}

@end
