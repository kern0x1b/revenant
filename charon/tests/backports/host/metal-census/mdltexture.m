/* mdltexture.m - the port's MDL texture loader against Apple's own, pixel for pixel.
 *
 * A REAL DEVICE IS CREATED HERE, and that is the point of this case: `MTLCreateSystemDefaultDevice()`
 * answers on this machine (measured: `<AGXG16SDevice: 0x...>`, name "Apple M4 Pro", 16 GPU cores), so
 * there is no wall and the texels a loader produces can be compared instead of being asserted about.
 * An earlier facts page in this folder said the call HANGS on a machine with no GPU and was measured
 * hanging and killed; that is a statement about a machine this is not, and this case is the
 * measurement that replaces it.
 *
 * WHAT IS THE PORT'S AND WHAT IS THE SEAM, precisely:
 *
 *   * The loader under test is the port's own file. It is compiled with
 *     `-DMTKTextureLoader=charonHost_MTKTextureLoader`, together with the port's own
 *     MTKTextureLoader9.m, so the port has a COMPLETE loader of its own under another name and Apple's
 *     keeps the real one. The case asks each side by its own name.
 *   * The device is Apple's, and it is handed to the port's `-initWithDevice:` exactly as an
 *     application hands it one. That is the whole seam: the port's own device object is an EAGL
 *     context over OpenGL ES 2.0 and cannot be built on a host, so the port's loader is exercised over
 *     a real Metal device and every other line of it - the format table, the origin choice, the
 *     refusals - is the port's own.
 *   * The MDLTexture is Apple's too, and ONE of them, built once and given to both sides. It is the
 *     input, not the thing under test, and two MDLTextures would be two inputs.
 *
 * NOTHING IS COMPARED BY IDENTITY ACROSS THE SIDES. A pointer is only ever compared with a pointer of
 * the same side, because two objects have no address in common.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>
#include <simd/simd.h>

/* The port's loader, under the name the -D gave it. */
@interface charonHost_MTKTextureLoader : NSObject
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (id<MTLTexture>)newTextureWithMDLTexture:(MDLTexture *)texture
                                   options:(NSDictionary<MTKTextureLoaderOption, id> *)options
                                     error:(NSError **)error;
- (void)newTextureWithMDLTexture:(MDLTexture *)texture
                         options:(NSDictionary<MTKTextureLoaderOption, id> *)options
               completionHandler:(MTKTextureLoaderCallback)completionHandler;
@end

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) printf("  ok   %s\n", [what UTF8String]);
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

/* ONE MDLTEXTURE, filled with a pattern that is not a constant, so a row swap, a stride mistake and a
 * channel mix-up all show up: the value at (x, y, c) is a function of all three. */
/* isCube: is the macOS SDK's spelling of the designated initializer and iOS 16.4's has no such
   parameter; this case builds against the macOS ModelIO (there is no ModelIO in the iOSSupport
   frameworks, so the macabi slice takes macOS's), and the argument is written out rather than hidden
   behind a macro because the port's own MDLTexture9.m takes the iOS spelling and the two are the
   same initializer. */
static MDLTexture *makeTexture(vector_int2 dimensions, NSUInteger channels,
                               MDLTextureChannelEncoding encoding, NSInteger rowStride, BOOL isCube)
{
    size_t width = (size_t)dimensions.x, height = (size_t)dimensions.y;
    size_t texel = 0;
    switch (encoding) {
        case MDLTextureChannelEncodingUInt8:
        case MDLTextureChannelEncodingUInt16:
        case MDLTextureChannelEncodingUInt32:
        case MDLTextureChannelEncodingUInt24: texel = (encoding == MDLTextureChannelEncodingUInt8) ? 1 : 2; break;
        default: texel = (encoding == MDLTextureChannelEncodingFloat32) ? 4 : 2; break;
    }
    if (encoding == MDLTextureChannelEncodingUInt24) texel = 3;
    if (encoding == MDLTextureChannelEncodingUInt32) texel = 4;
    size_t stride = rowStride > 0 ? (size_t)rowStride : width * texel * channels;
    NSMutableData *bytes = [NSMutableData dataWithLength:stride * height];
    uint8_t *raw = bytes.mutableBytes;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++)
            for (size_t c = 0; c < channels; c++)
                for (size_t b = 0; b < texel; b++) {
                    size_t at = y * stride + (x * channels + c) * texel + b;
                    /* a byte that depends on the row, the column, the channel AND the byte within the
                       texel: any of the four being wrong changes it */
                    uint8_t value = (uint8_t)(at * 37u + (x + 1) * 11u + (y + 1) * 23u + c * 5u + b * 101u);
                    if (encoding == MDLTextureChannelEncodingFloat16 || encoding == MDLTextureChannelEncodingFloat32)
                        value = (uint8_t)(value & 0x3f);   /* keep the exponent small so it is a finite float */
                    raw[at] = value;
                }
    return [[MDLTexture alloc] initWithData:bytes
                               topLeftOrigin:NO
                                        name:@"vMetalMDLFixture"
                                  dimensions:dimensions
                                   rowStride:rowStride
                                channelCount:channels
                             channelEncoding:encoding
                                      isCube:isCube];
}

/* THE READBACK IS AT THE TEXTURE'S OWN STRIDE. Metal packs a texel in the format's own width - an R8
 * texture hands back ONE byte per texel - so a readback at four bytes a pixel would compare whatever
 * followed the row instead of the row. The two sides' formats are compared before this is called, so
 * one stride serves both. */
static NSUInteger bytesPerTexel(MTLPixelFormat format)
{
    switch (format) {
        case MTLPixelFormatR8Unorm: return 1;
        case MTLPixelFormatRG8Unorm: return 2;
        case MTLPixelFormatRGBA8Unorm: return 4;
        case MTLPixelFormatR16Float: return 2;
        case MTLPixelFormatRG16Float: return 4;
        case MTLPixelFormatRGBA16Float: return 8;
        case MTLPixelFormatR32Float: return 4;
        case MTLPixelFormatRGBA32Float: return 16;
        default: return 4;
    }
}

/* EVERY BYTE OF A TEXTURE, through the same readback on both sides. */
static NSData *bytesOf(id<MTLTexture> texture, NSUInteger width, NSUInteger height)
{
    if (!texture) return nil;
    NSUInteger stride = width * bytesPerTexel(texture.pixelFormat);
    NSMutableData *out = [NSMutableData dataWithLength:stride * height];
    [texture getBytes:out.mutableBytes bytesPerRow:stride
          fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];
    return out;
}

/* THE COMPARISON: the same MDLTexture into both loaders, then format, size and every byte. */
static void compare(MDLTexture *source, NSDictionary *options, NSString *label)
{
    printf("%s\n", [label UTF8String]);
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) { check(NO, @"there is a Metal device on this machine"); return; }

    MTKTextureLoader *apple = [[MTKTextureLoader alloc] initWithDevice:device];
    charonHost_MTKTextureLoader *port = [[charonHost_MTKTextureLoader alloc] initWithDevice:device];

    NSError *appleError = nil, *portError = nil;
    id<MTLTexture> a = [apple newTextureWithMDLTexture:source options:options error:&appleError];
    id<MTLTexture> p = [port newTextureWithMDLTexture:source options:options error:&portError];

    size_t width = (size_t)MAX(source.dimensions.x, 0), height = (size_t)MAX(source.dimensions.y, 0);
    if (!a || !p) {
        check(NO, ([NSString stringWithFormat:@"%@: Apple's loader answered %@ and the port's answered %@",
                    label, a ? @"a texture" : ([NSString stringWithFormat:@"nil (%@)", [appleError localizedDescription]]),
                    p ? @"a texture" : ([NSString stringWithFormat:@"nil (%@)", [portError localizedDescription]])]));
        return;
    }
    check(p.pixelFormat == a.pixelFormat,
          ([NSString stringWithFormat:@"%@: pixel format, the port %lu and Apple's own %lu",
            label, (unsigned long)p.pixelFormat, (unsigned long)a.pixelFormat]));
    check(p.width == a.width && p.height == a.height,
          ([NSString stringWithFormat:@"%@: size, the port %lux%lu and Apple's own %lux%lu",
            label, (unsigned long)p.width, (unsigned long)p.height,
            (unsigned long)a.width, (unsigned long)a.height]));
    NSData *ab = bytesOf(a, width, height), *pb = bytesOf(p, width, height);
    check(pb && ab && [pb isEqualToData:ab],
          ([NSString stringWithFormat:@"%@: every byte of the texels, %lu of them",
            label, (unsigned long)(pb.length)]));
}

/* A REFUSAL: what the port answers where a format, an option or a shape has no Metal texture here.
 * Apple's side is asked too and PRINTED, because whether Apple accepts an input the port refuses is a
 * measurement and not a thing this case may assume: where Apple accepts it, the port's answer is a
 * documented refusal and the case says only that. */
static void expectRefusal(MDLTexture *source, NSDictionary *options, NSString *label, NSString *why)
{
    printf("%s\n", [label UTF8String]);
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    MTKTextureLoader *apple = [[MTKTextureLoader alloc] initWithDevice:device];
    charonHost_MTKTextureLoader *port = [[charonHost_MTKTextureLoader alloc] initWithDevice:device];
    NSError *portError = nil, *appleError = nil;
    id<MTLTexture> p = [port newTextureWithMDLTexture:source options:options error:&portError];
    id<MTLTexture> a = [apple newTextureWithMDLTexture:source options:options error:&appleError];
    printf("       Apple's own loader on this input: %s\n",
           a ? "a texture" : [[NSString stringWithFormat:@"nil (%@)", [appleError localizedDescription]] UTF8String]);
    check(p == nil && [portError.domain isEqualToString:MTKTextureLoaderErrorDomain],
          ([NSString stringWithFormat:@"%@: the port answers nil in MTKTextureLoaderErrorDomain", label]));
    NSString *message = [portError localizedDescription] ?: @"";
    check([message rangeOfString:why].location != NSNotFound,
          ([NSString stringWithFormat:@"%@: the reason names %@, and it says \"%s\"", label, why, [message UTF8String]]));
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("the port's MDL loader against Apple's own, on a real Metal device\n");
        checks++;
        if (MTLCreateSystemDefaultDevice())
            printf("  ok   the control: MTLCreateSystemDefaultDevice() answers on this machine\n");
        else {
            printf("  FAIL the control: there is no Metal device here, so nothing below means anything\n");
            printf("mdltexture: %d check(s), %d failure(s)\n", checks, failures + 1);
            return 1;
        }

        compare(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt8, 0, NO), nil,
                @"four 8-bit channels, packed rows");
        compare(makeTexture(simd_make_int2(4, 3), 1, MDLTextureChannelEncodingUInt8, 0, NO), nil,
                @"one 8-bit channel");
        compare(makeTexture(simd_make_int2(4, 3), 2, MDLTextureChannelEncodingUInt8, 0, NO), nil,
                @"two 8-bit channels");
        compare(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingFloat16, 0, NO), nil,
                @"four 16-bit float channels");
        compare(makeTexture(simd_make_int2(5, 4), 1, MDLTextureChannelEncodingFloat32, 0, NO), nil,
                @"one 32-bit float channel");
        compare(makeTexture(simd_make_int2(4, 3), 2, MDLTextureChannelEncodingFloat16, 0, NO), nil,
                @"two 16-bit float channels");
        /* A row stride wider than the row needs: 4x3 RGBA8 with 40-byte rows. A loader that computed
           bytesPerRow from the width would read the wrong rows and the padding with them. */
        compare(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt8, 40, NO), nil,
                @"four 8-bit channels, rows padded to 40 bytes");
        /* The origin option: Apple's own loader reads the same option, so both sides are told the same
           thing about where row 0 is. */
        compare(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt8, 0, NO),
                @{ MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginTopLeft },
                @"four 8-bit channels, MTKTextureLoaderOptionOriginTopLeft");
        compare(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt8, 0, NO),
                @{ MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginBottomLeft },
                @"four 8-bit channels, MTKTextureLoaderOptionOriginBottomLeft");

        expectRefusal(makeTexture(simd_make_int2(4, 3), 3, MDLTextureChannelEncodingUInt8, 0, NO), nil,
                      @"three 8-bit channels, which has no Metal format this port holds", @"3 channel");
        expectRefusal(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt24, 0, NO), nil,
                      @"24-bit integers, which have no Metal format this port holds", @"channel encoding");
        expectRefusal(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt16, 0, NO), nil,
                      @"16-bit integers, which have no Metal format this port holds", @"channel encoding");
        expectRefusal(makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt8, 0, NO),
                      @{ MTKTextureLoaderOptionSRGB: @YES },
                      @"an sRGB request, which this port holds no format for", @"sRGB");

        /* THE CUBE: an MDLTexture of six faces. The port refuses it and says so; the cube layout option
           is refused with the header's own sentence. */
        MDLTexture *cube = makeTexture(simd_make_int2(2, 12), 4, MDLTextureChannelEncodingUInt8, 0, YES);
        printf("a cube MDLTexture, six faces in one texture\n");
        {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            charonHost_MTKTextureLoader *port = [[charonHost_MTKTextureLoader alloc] initWithDevice:device];
            NSError *portError = nil;
            check([port newTextureWithMDLTexture:cube options:nil error:&portError] == nil &&
                  [portError localizedDescription].length > 0,
                  @"a cube MDLTexture: the port answers nil and says why");
        }

        /* THE COMPLETION-HANDLER FORM: the header's contract is a block called with the texture or
           with the error, so both are exercised. */
        printf("the completion-handler form\n");
        {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            charonHost_MTKTextureLoader *port = [[charonHost_MTKTextureLoader alloc] initWithDevice:device];
            __block id<MTLTexture> got = nil; __block NSError *gotError = nil; __block int calls = 0;
            [port newTextureWithMDLTexture:makeTexture(simd_make_int2(4, 3), 4, MDLTextureChannelEncodingUInt8, 0, NO)
                                   options:nil
                         completionHandler:^(id<MTLTexture> texture, NSError *error) {
                got = texture; gotError = error; calls++;
            }];
            check(calls == 1 && got != nil && gotError == nil,
                  @"a texture: the handler is called once with the texture and no error");
            got = nil; gotError = nil; calls = 0;
            [port newTextureWithMDLTexture:nil options:nil
                         completionHandler:^(id<MTLTexture> texture, NSError *error) {
                got = texture; gotError = error; calls++;
            }];
            check(calls == 1 && got == nil && [gotError.domain isEqualToString:MTKTextureLoaderErrorDomain],
                  @"a refusal: the handler is called once with nil and the error");
        }
    }
    printf("mdltexture: %d check(s), %d failure(s)\n", checks, failures);
    return failures == 0 ? 0 : 1;
}