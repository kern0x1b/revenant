#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <ModelIO/ModelIO.h>

static BOOL RevenantMTKFormatForMDL(MDLTexture *texture, MTLPixelFormat *out)
{
    NSUInteger channels = texture.channelCount;
    switch (texture.channelEncoding) {
        case MDLTextureChannelEncodingUInt8:
            if (channels == 1) { *out = MTLPixelFormatR8Unorm; return YES; }
            if (channels == 2) { *out = MTLPixelFormatRG8Unorm; return YES; }
            if (channels == 4) { *out = MTLPixelFormatRGBA8Unorm; return YES; }
            return NO;
        case MDLTextureChannelEncodingFloat16:
            if (channels == 1) { *out = MTLPixelFormatR16Float; return YES; }
            if (channels == 2) { *out = MTLPixelFormatRG16Float; return YES; }
            if (channels == 4) { *out = MTLPixelFormatRGBA16Float; return YES; }
            return NO;
        case MDLTextureChannelEncodingFloat32:
            if (channels == 1) { *out = MTLPixelFormatR32Float; return YES; }
            if (channels == 4) { *out = MTLPixelFormatRGBA32Float; return YES; }
            return NO;
        case MDLTextureChannelEncodingFloat16SR:
        case MDLTextureChannelEncodingUInt16:
        case MDLTextureChannelEncodingUInt24:
        case MDLTextureChannelEncodingUInt32:
            return NO;
    }
    return NO;
}

@implementation MTKTextureLoader (RevenantMDLTexture10)

- (id<MTLTexture>)newTextureWithMDLTexture:(MDLTexture *)texture
                                   options:(NSDictionary<MTKTextureLoaderOption, id> *)options
                                     error:(NSError **)error
{
    NSString *why = nil;
    id<MTLTexture> made = nil;
    if (!texture) {
        why = @"there is no MDLTexture to load a Metal texture from";
    } else if ([options[MTKTextureLoaderOptionSRGB] boolValue]) {
        why = @"this port holds no sRGB pixel format, so a texture loaded as sRGB would not be the one asked for (facts/Metal/PixelFormats.md)";
    } else if (options[MTKTextureLoaderOptionCubeLayout] != nil) {
        why = @"MTKTextureLoaderOptionCubeLayout cannot be used by MTKTextureLoader with an MDLTexture, which supports cube textures directly";
    } else if (texture.isCube) {
        why = @"an MDLTexture that is a cube is six faces and this port holds 2D textures only, so its texels are loaded as the single 2D texture they are";
    } else {
        MTLPixelFormat format = MTLPixelFormatInvalid;
        if (!RevenantMTKFormatForMDL(texture, &format)) {
            why = [NSString stringWithFormat:
                   @"an MDLTexture of %lu channel(s) with channel encoding %lu has no Metal pixel format this port holds (facts/Metal/PixelFormats.md)",
                   (unsigned long)texture.channelCount, (unsigned long)texture.channelEncoding];
        } else {
            size_t width = (size_t)MAX(texture.dimensions.x, 0);
            size_t height = (size_t)MAX(texture.dimensions.y, 0);
            NSString *origin = options[MTKTextureLoaderOptionOrigin];
            BOOL bottomLeft = [origin isEqualToString:MTKTextureLoaderOriginBottomLeft];
            BOOL topLeft = !bottomLeft;
            NSData *texels = bottomLeft ? [texture texelDataWithBottomLeftOrigin] : [texture texelDataWithTopLeftOrigin];
            if (width == 0 || height == 0 || !texels) {
                why = @"the MDLTexture has no texels to load";
            } else {
                MTLTextureDescriptor *descriptor =
                    [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
                                                                        width:width height:height
                                                                     mipmapped:texture.mipLevelCount > 1];
                if ([options[MTKTextureLoaderOptionTextureUsage] isKindOfClass:[NSNumber class]])
                    descriptor.usage = [options[MTKTextureLoaderOptionTextureUsage] unsignedIntegerValue];
                if ([options[MTKTextureLoaderOptionTextureCPUCacheMode] isKindOfClass:[NSNumber class]])
                    descriptor.cpuCacheMode =
                        (MTLCPUCacheMode)[options[MTKTextureLoaderOptionTextureCPUCacheMode] unsignedIntegerValue];
                if ([options[MTKTextureLoaderOptionTextureStorageMode] isKindOfClass:[NSNumber class]])
                    descriptor.storageMode =
                        (MTLStorageMode)[options[MTKTextureLoaderOptionTextureStorageMode] unsignedIntegerValue];
                id<MTLTexture> built = [self.device newTextureWithDescriptor:descriptor];
                if (!built) {
                    why = [NSString stringWithFormat:
                           @"the device could not create a texture of Metal pixel format %lu, the format this MDLTexture's texels have",
                           (unsigned long)format];
                } else {
                    NSUInteger stride = (NSUInteger)(texels.length / height);
                    [built replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0
                               withBytes:texels.bytes bytesPerRow:stride];
                    made = built;
                }
            }
        }
    }
    if (!made && error)
        *error = [NSError errorWithDomain:MTKTextureLoaderErrorDomain code:0
                                  userInfo:@{NSLocalizedDescriptionKey: why}];
    return made;
}

- (void)newTextureWithMDLTexture:(MDLTexture *)texture
                         options:(NSDictionary<MTKTextureLoaderOption, id> *)options
               completionHandler:(MTKTextureLoaderCallback)completionHandler
{
    NSError *error = nil;
    id<MTLTexture> made = [self newTextureWithMDLTexture:texture options:options error:&error];
    if (completionHandler)
        completionHandler(made, made ? nil : error);
}

@end
