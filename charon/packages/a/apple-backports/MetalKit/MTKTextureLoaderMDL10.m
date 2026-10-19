#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>
#import <ModelIO/ModelIO.h>

// Loading a Metal texture out of a Model I/O texture, which is what MetalKit's two MDL methods are.
//
// The header uses the same phrase for both - creating a Metal texture and loading pixel data from the supplied
// MDLTexture (MTKTextureLoader.h:268 and :332) - and the work is a real one: an MDLTexture is
// a block of texels of its own channel count and channel encoding (the Model I/O files carry that),
// and a Metal texture is a block of texels of a Metal pixel format. This maps the first onto the
// second and hands the bytes to the device.
//
// THE ROW ORDER IS THE RULE MTKTextureLoader9.m ALREADY STATES, for the same reason: a Metal
// texture's row 0 is its top row, this port's textures are OpenGL ES textures whose row 0 is the
// bottom one, and -replaceRegion: writes the bytes it is handed in the driver's own order. A
// CGImage carries no origin metadata, so that path copies the rows; an MDLTexture carries its own
// origin and exposes the two orders as two accessors, so here the rows are not copied at all:
// MTKTextureLoaderOptionOrigin picks the accessor. BottomLeft, and no option at all, read
// -texelDataWithBottomLeftOrigin; TopLeft and FlippedVertically read -texelDataWithTopLeftOrigin.
//
// WHAT IS REFUSED, and each refusal says why, is in facts/MetalKit/TextureLoaderMDL.md: the nine
// Metal pixel formats this port holds and nothing else (facts/Metal/PixelFormats.md), so a channel
// count or channel encoding with no Metal format of that shape is refused by name; an sRGB request
// is refused because the port holds no sRGB format; MTKTextureLoaderOptionCubeLayout is refused
// because MTKTextureLoader.h:90 says the option cannot be used with MDLTextures, which support cube
// textures directly; and an MDLTexture that is a cube is six faces, which this port's 2D textures
// are not.

// The Metal format of an MDLTexture's texels, or NO because this port holds no format of that shape.
// The channel count and the channel encoding are the MDLTexture's own two properties, and the nine
// formats this port holds are in facts/Metal/PixelFormats.md with the extension each one needs. A
// format whose extensions the device does not list is refused later and by the device, which is
// where facts/Metal/PixelFormats.md says that refusal belongs.
static BOOL CharonMTKFormatForMDL(MDLTexture *texture, MTLPixelFormat *out)
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
        // The sRGB half floats and the 16, 24 and 32 bit integers: this port holds no Metal format of
        // any of those shapes, and loading the bytes into a format that reads them as something else
        // would be a texture that is not the one the caller has.
        case MDLTextureChannelEncodingFloat16SR:
        case MDLTextureChannelEncodingUInt16:
        case MDLTextureChannelEncodingUInt24:
        case MDLTextureChannelEncodingUInt32:
            return NO;
    }
    return NO;
}

@implementation MTKTextureLoader (CharonMDLTexture10)

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
        if (!CharonMTKFormatForMDL(texture, &format)) {
            why = [NSString stringWithFormat:
                   @"an MDLTexture of %lu channel(s) with channel encoding %lu has no Metal pixel format this port holds (facts/Metal/PixelFormats.md)",
                   (unsigned long)texture.channelCount, (unsigned long)texture.channelEncoding];
        } else {
            size_t width = (size_t)MAX(texture.dimensions.x, 0);
            size_t height = (size_t)MAX(texture.dimensions.y, 0);
            // THE ROW ORDER, MEASURED against Apple's own loader rather than reasoned about.
            //
            // An MDLTexture carries its origin and exposes the two orders as two accessors. A Metal
            // texture's row 0 is its top row, so the top-left form is the one that puts the image the
            // right way up in it - and that is also what Apple's own loader produces, measured by
            // tests/backports/host/metal-census/mdltexture.sh on a real device: with no
            // MTKTextureLoaderOptionOrigin, with MTKTextureLoaderOptionOriginTopLeft and with
            // MTKTextureLoaderOptionOriginBottomLeft, all three against Apple's own answer byte for
            // byte. The default is therefore the TOP-LEFT form and MTKTextureLoaderOptionOriginBottomLeft
            // is the one that asks for the other; TopLeft and FlippedVertically ask for the default.
            //
            // This port's textures are OpenGL ES textures, whose row 0 is the bottom one, and
            // -replaceRegion: writes the bytes it is handed in the driver's own order, which is the
            // same rule MTKTextureLoader9.m states for the file path.
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
                    // facts/Metal/PixelFormats.md: a format whose extensions this device does not
                    // list is refused by the device, and the log there says which one is missing. The
                    // loader repeats the format here so the caller has it in the error too.
                    why = [NSString stringWithFormat:
                           @"the device could not create a texture of Metal pixel format %lu, the format this MDLTexture's texels have",
                           (unsigned long)format];
                } else {
                    // THE ROW STRIDE IS THE ONE THE ACCESSOR'S OWN DATA HAS, and not the MDLTexture's
                    // rowStride property. Measured: with an MDLTexture built with 40-byte rows over a
                    // 16-byte row, -texelDataWithTopLeftOrigin hands back data whose rows are 16 bytes,
                    // and -replaceRegion: told 40 writes a texture whose rows carry the padding. The
                    // stride that goes to the device is therefore the distance between two rows of the
                    // bytes actually in hand, which is what an MDLTexture may pad and what this port's
                    // textures, like Metal's, do not.
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