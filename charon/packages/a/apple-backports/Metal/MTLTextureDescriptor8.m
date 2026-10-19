#import "CharonMetal.h"


@implementation MTLTextureDescriptor

+ (MTLTextureDescriptor *)texture2DDescriptorWithPixelFormat:(MTLPixelFormat)pixelFormat width:(NSUInteger)width height:(NSUInteger)height mipmapped:(BOOL)mipmapped
{
    MTLTextureDescriptor *d = [[MTLTextureDescriptor alloc] init];
    d.textureType = MTLTextureType2D;
    d.pixelFormat = pixelFormat;
    d.width = width;
    d.height = height;
    d.mipmapLevelCount = 1;
    return d;
}

- (instancetype)init
{
    if ((self = [super init])) {
        self.textureType = MTLTextureType2D;
        self.pixelFormat = (MTLPixelFormat)70;
        self.width = 1;
        self.height = 1;
        self.depth = 1;
        self.mipmapLevelCount = 1;
        self.sampleCount = 1;
        self.arrayLength = 1;
        self.usage = MTLTextureUsageShaderRead;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLTextureDescriptor *d = [[MTLTextureDescriptor alloc] init];
    d.textureType = self.textureType;
    d.pixelFormat = self.pixelFormat;
    d.width = self.width;
    d.height = self.height;
    d.depth = self.depth;
    d.mipmapLevelCount = self.mipmapLevelCount;
    d.sampleCount = self.sampleCount;
    d.arrayLength = self.arrayLength;
    d.usage = self.usage;
    return d;
}

@end
