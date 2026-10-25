#import "../Foundation/check.h"
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import "RevenantCIRenderDestination.h"

static BOOL revenant_bytes_close(NSData *expected, NSData *actual, int tolerance)
{
    if (expected.length != actual.length)
        return NO;
    const uint8_t *a = expected.bytes, *b = actual.bytes;
    for (NSUInteger index = 0; index < expected.length; index++) {
        int difference = (int)a[index] - (int)b[index];
        if (difference < -tolerance || difference > tolerance)
            return NO;
    }
    return YES;
}

static NSString *revenant_first_pixel(NSData *data)
{
    const uint8_t *bytes = data.bytes;
    return [NSString stringWithFormat:@"%u %u %u %u", bytes[0], bytes[1], bytes[2], bytes[3]];
}

static void revenant_compare_value(NSString *key, id host, id backport)
{
    id expected = [host valueForKey:key];
    id actual = [backport valueForKey:key];
    revenant_check(expected == actual || [expected isEqual:actual], [key UTF8String], [NSString stringWithFormat:@"%@ != %@", expected, actual]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class destinationClass = NSClassFromString(@"CIRenderDestinationRevenant");
    revenant_check((destinationClass != Nil) != revenant_negative, "CIRenderDestination implementation is present", NSStringFromClass(destinationClass));
    if (!destinationClass)
        return revenant_finish();

    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *image = [[CIImage imageWithColor:[CIColor colorWithRed:0.2 green:0.6 blue:0.9 alpha:0.8]] imageByCroppingToRect:CGRectMake(0, 0, 8, 8)];

    const NSUInteger width = 8, height = 8, rowBytes = width * 4;
    NSMutableData *hostBytes = [NSMutableData dataWithLength:rowBytes * height];
    NSMutableData *backportBytes = [NSMutableData dataWithLength:rowBytes * height];

    CIRenderDestination *hostDestination = [[CIRenderDestination alloc] initWithBitmapData:hostBytes.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
    id backportDestination = [[destinationClass alloc] initWithBitmapData:backportBytes.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
    revenant_compare_value(@"width", hostDestination, backportDestination);
    revenant_compare_value(@"height", hostDestination, backportDestination);
    revenant_compare_value(@"alphaMode", hostDestination, backportDestination);
    revenant_compare_value(@"flipped", hostDestination, backportDestination);
    revenant_compare_value(@"dithered", hostDestination, backportDestination);
    revenant_compare_value(@"clamped", hostDestination, backportDestination);
    revenant_compare_value(@"blendsInDestinationColorSpace", hostDestination, backportDestination);

    NSError *error = nil;
    CIRenderTask *hostTask = [context startTaskToRender:image toDestination:hostDestination error:&error];
    revenant_check(hostTask != nil && error == nil, "the host renders the bitmap destination", error.localizedDescription ?: @"rendered");
    error = nil;
    [hostTask waitUntilCompletedAndReturnError:&error];
    id backportTask = [backportDestination revenant_renderImage:image context:context error:&error];
    revenant_check(backportTask != nil && error == nil, "the backport renders the bitmap destination", error.localizedDescription ?: @"rendered");
    revenant_check([hostBytes isEqualToData:backportBytes], "bitmap pixels match the host", [NSString stringWithFormat:@"host %@ backport %@", revenant_first_pixel(hostBytes), revenant_first_pixel(backportBytes)]);

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    revenant_check(device != nil, "the host has a Metal device", @"no device");
    if (!device)
        return revenant_finish();
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    descriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> hostTexture = [device newTextureWithDescriptor:descriptor];
    id<MTLTexture> backportTexture = [device newTextureWithDescriptor:descriptor];

    CIRenderDestination *hostTextureDestination = [[CIRenderDestination alloc] initWithMTLTexture:hostTexture commandBuffer:nil];
    error = nil;
    CIRenderTask *hostTextureTask = [context startTaskToRender:image toDestination:hostTextureDestination error:&error];
    revenant_check(hostTextureTask != nil && error == nil, "the host renders the texture destination", error.localizedDescription ?: @"rendered");
    [hostTextureTask waitUntilCompletedAndReturnError:nil];
    NSMutableData *hostTextureBytes = [NSMutableData dataWithLength:rowBytes * height];
    [hostTexture getBytes:hostTextureBytes.mutableBytes bytesPerRow:rowBytes fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];

    id backportTextureDestination = [[destinationClass alloc] initWithMTLTexture:backportTexture commandBuffer:nil];
    error = nil;
    id backportTextureTask = [backportTextureDestination revenant_renderImage:image context:context error:&error];
    revenant_check(backportTextureTask != nil && error == nil, "the backport renders the texture destination", error.localizedDescription ?: @"rendered");
    NSMutableData *backportTextureBytes = [NSMutableData dataWithLength:rowBytes * height];
    [backportTexture getBytes:backportTextureBytes.mutableBytes bytesPerRow:rowBytes fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];
    revenant_check(revenant_bytes_close(hostTextureBytes, backportTextureBytes, 2), "texture pixels match the host within rounding", [NSString stringWithFormat:@"host %@ backport %@", revenant_first_pixel(hostTextureBytes), revenant_first_pixel(backportTextureBytes)]);

    CIImage *asymmetric = [[CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:1 alpha:0.5]] imageByCroppingToRect:CGRectMake(0, 4, 8, 4)];
    asymmetric = [asymmetric imageByCompositingOverImage:[[CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0 alpha:1]] imageByCroppingToRect:CGRectMake(0, 0, 8, 4)]];
    NSArray<NSDictionary *> *configurations = @[@{@"flipped": @NO}, @{@"alphaMode": @0}, @{@"alphaMode": @2}];
    for (NSDictionary *configuration in configurations) {
        NSMutableData *hostPixels = [NSMutableData dataWithLength:rowBytes * height];
        NSMutableData *backportPixels = [NSMutableData dataWithLength:rowBytes * height];
        CIRenderDestination *hostConfigured = [[CIRenderDestination alloc] initWithBitmapData:hostPixels.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
        id backportConfigured = [[destinationClass alloc] initWithBitmapData:backportPixels.mutableBytes width:width height:height bytesPerRow:rowBytes format:kCIFormatRGBA8];
        [configuration enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            [hostConfigured setValue:value forKey:key];
            [backportConfigured setValue:value forKey:key];
        }];
        error = nil;
        [[context startTaskToRender:asymmetric toDestination:hostConfigured error:&error] waitUntilCompletedAndReturnError:nil];
        error = nil;
        id backportConfiguredTask = [backportConfigured revenant_renderImage:asymmetric context:context error:&error];
        revenant_check(backportConfiguredTask != nil && error == nil, [[NSString stringWithFormat:@"the backport renders %@", configuration] UTF8String], error.localizedDescription ?: @"rendered");
        revenant_check(revenant_bytes_close(hostPixels, backportPixels, 1), [[NSString stringWithFormat:@"%@ pixels match the host", configuration] UTF8String], [NSString stringWithFormat:@"host %@ backport %@", revenant_first_pixel(hostPixels), revenant_first_pixel(backportPixels)]);
    }

    return revenant_finish();
}
