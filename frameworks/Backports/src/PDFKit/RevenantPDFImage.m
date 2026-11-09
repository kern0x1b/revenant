#import "RevenantPDFImage.h"

#import <ImageIO/ImageIO.h>

const double RevenantPDFDefaultImageQuality = 0.9;

RevenantPDFImagePlacement RevenantPDFPlaceImage(size_t width, size_t height, BOOL hasMediaBox, CGRect mediaBox, NSInteger rotation,
                                                BOOL upscaleIfSmaller)
{
    NSInteger turns = (((rotation / 90) % 4) + 4) % 4;
    BOOL sideways = turns == 1 || turns == 3;
    CGFloat rotatedWidth = sideways ? (CGFloat)height : (CGFloat)width;
    CGFloat rotatedHeight = sideways ? (CGFloat)width : (CGFloat)height;
    CGRect box = hasMediaBox ? CGRectStandardize(mediaBox) : CGRectMake(0, 0, rotatedWidth, rotatedHeight);
    CGFloat fit = MIN(box.size.width / rotatedWidth, box.size.height / rotatedHeight);
    CGFloat scale = (fit < 1 || upscaleIfSmaller) ? fit : 1;
    CGFloat drawnWidth = (CGFloat)width * scale;
    CGFloat drawnHeight = (CGFloat)height * scale;
    CGFloat boxedWidth = rotatedWidth * scale;
    CGFloat boxedHeight = rotatedHeight * scale;
    CGFloat x = box.origin.x + (box.size.width - boxedWidth) / 2;
    CGFloat y = box.origin.y + (box.size.height - boxedHeight) / 2;
    RevenantPDFImagePlacement placement;
    placement.mediaBox = box;
    switch (turns) {
        case 1:
            placement.placement = CGAffineTransformMake(0, drawnWidth, -drawnHeight, 0, x + boxedWidth, y);
            break;
        case 2:
            placement.placement = CGAffineTransformMake(-drawnWidth, 0, 0, -drawnHeight, x + boxedWidth, y + boxedHeight);
            break;
        case 3:
            placement.placement = CGAffineTransformMake(0, -drawnWidth, drawnHeight, 0, x, y + boxedHeight);
            break;
        default:
            placement.placement = CGAffineTransformMake(drawnWidth, 0, 0, drawnHeight, x, y);
            break;
    }
    return placement;
}

static BOOL revenantImageMayHaveAlpha(CGImageRef image)
{
    switch (CGImageGetAlphaInfo(image)) {
        case kCGImageAlphaNone:
        case kCGImageAlphaNoneSkipFirst:
        case kCGImageAlphaNoneSkipLast:
            return NO;
        default:
            return YES;
    }
}

static CGImageRef revenantRenderOpaque(CGImageRef image, BOOL gray)
{
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGColorSpaceRef space = gray ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo info = (CGBitmapInfo)(gray ? kCGImageAlphaNone : kCGImageAlphaNoneSkipLast);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, info);
    CGColorSpaceRelease(space);
    if (context == NULL)
        return NULL;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGImageRef rendered = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return rendered;
}

static NSData *revenantJPEGData(CGImageRef image, double quality)
{
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.jpeg"), 1, NULL);
    if (destination == NULL)
        return nil;
    NSDictionary *options = @{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality : @(quality)};
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    BOOL finished = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return finished ? data : nil;
}

static BOOL revenantImageIsDirectlyEncodable(CGImageRef image, BOOL gray)
{
    if (CGImageGetBitsPerComponent(image) != 8)
        return NO;
    size_t bits = CGImageGetBitsPerPixel(image);
    return gray ? bits == 8 : (bits == 24 || bits == 32);
}

static NSDictionary *revenantImageDictionary(size_t width, size_t height, NSString *space)
{
    return @{
        @"Type" : [RevenantPDFName name:@"XObject"],
        @"Subtype" : [RevenantPDFName name:@"Image"],
        @"Width" : @(width),
        @"Height" : @(height),
        @"ColorSpace" : [RevenantPDFName name:space],
        @"BitsPerComponent" : @8,
        @"Interpolate" : @YES,
    };
}

static RevenantPDFReference *revenantAddJPEGImage(RevenantPDFWriter *writer, CGImageRef image, BOOL gray, double quality)
{
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGImageRef source = image;
    CGImageRef rendered = NULL;
    if (!revenantImageIsDirectlyEncodable(image, gray) || revenantImageMayHaveAlpha(image)) {
        rendered = revenantRenderOpaque(image, gray);
        if (rendered == NULL)
            return nil;
        source = rendered;
    }
    NSData *jpeg = revenantJPEGData(source, quality);
    if (rendered != NULL)
        CGImageRelease(rendered);
    if (jpeg == nil)
        return nil;
    NSMutableDictionary *dictionary = [revenantImageDictionary(width, height, gray ? @"DeviceGray" : @"DeviceRGB") mutableCopy];
    dictionary[@"Filter"] = [RevenantPDFName name:@"DCTDecode"];
    return [writer add:[RevenantPDFStream streamWithDictionary:dictionary data:jpeg]];
}

static RevenantPDFReference *revenantAddAlphaImage(RevenantPDFWriter *writer, CGImageRef image, BOOL gray, double quality)
{
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    if (width > SIZE_MAX / 4 / height)
        return nil;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (context == NULL)
        return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    size_t rowBytes = CGBitmapContextGetBytesPerRow(context);
    BOOL translucent = NO;
    for (size_t y = 0; y < height && !translucent; y++) {
        const uint8_t *row = pixels + y * rowBytes;
        for (size_t x = 0; x < width; x++) {
            if (row[x * 4 + 3] != 255) {
                translucent = YES;
                break;
            }
        }
    }
    if (!translucent) {
        CGContextRelease(context);
        return revenantAddJPEGImage(writer, image, gray, quality);
    }
    NSMutableData *color = [NSMutableData dataWithLength:width * height * (gray ? 1 : 3)];
    NSMutableData *alpha = [NSMutableData dataWithLength:width * height];
    uint8_t *colorOut = color.mutableBytes;
    uint8_t *alphaOut = alpha.mutableBytes;
    for (size_t y = 0; y < height; y++) {
        const uint8_t *row = pixels + y * rowBytes;
        for (size_t x = 0; x < width; x++) {
            uint8_t a = row[x * 4 + 3];
            unsigned r = row[x * 4], g = row[x * 4 + 1], b = row[x * 4 + 2];
            if (a == 0) {
                r = g = b = 0;
            } else if (a != 255) {
                r = MIN(255u, (r * 255 + a / 2) / a);
                g = MIN(255u, (g * 255 + a / 2) / a);
                b = MIN(255u, (b * 255 + a / 2) / a);
            }
            alphaOut[y * width + x] = a;
            if (gray) {
                colorOut[y * width + x] = (uint8_t)((r * 306 + g * 601 + b * 117 + 512) >> 10);
            } else {
                uint8_t *out = colorOut + (y * width + x) * 3;
                out[0] = (uint8_t)r;
                out[1] = (uint8_t)g;
                out[2] = (uint8_t)b;
            }
        }
    }
    CGContextRelease(context);
    RevenantPDFReference *mask = [writer add:[RevenantPDFStream deflatedStreamWithDictionary:revenantImageDictionary(width, height, @"DeviceGray") data:alpha]];
    NSMutableDictionary *dictionary = [revenantImageDictionary(width, height, gray ? @"DeviceGray" : @"DeviceRGB") mutableCopy];
    dictionary[@"SMask"] = mask;
    return [writer add:[RevenantPDFStream deflatedStreamWithDictionary:dictionary data:color]];
}

RevenantPDFReference *RevenantPDFAddImage(RevenantPDFWriter *writer, CGImageRef image, double quality)
{
    if (CGImageGetWidth(image) == 0 || CGImageGetHeight(image) == 0)
        return nil;
    CGColorSpaceRef space = CGImageGetColorSpace(image);
    BOOL gray = space != NULL && CGColorSpaceGetModel(space) == kCGColorSpaceModelMonochrome;
    if (revenantImageMayHaveAlpha(image))
        return revenantAddAlphaImage(writer, image, gray, quality);
    return revenantAddJPEGImage(writer, image, gray, quality);
}

static NSData *revenantSinglePageData(RevenantPDFWriter *writer, CGRect box, NSDictionary *resources, NSData *content)
{
    RevenantPDFReference *contents = [writer add:[RevenantPDFStream deflatedStreamWithDictionary:@{} data:content]];
    RevenantPDFReference *pages = [writer reserve];
    RevenantPDFReference *leaf = [writer add:@{
        @"Type" : [RevenantPDFName name:@"Page"],
        @"Parent" : pages,
        @"MediaBox" : @[ @(box.origin.x), @(box.origin.y), @(CGRectGetMaxX(box)), @(CGRectGetMaxY(box)) ],
        @"Resources" : resources,
        @"Contents" : contents,
    }];
    RevenantPDFReference *catalog = [writer addCatalogWithPages:pages kids:@[ leaf ]];
    return [writer dataWithRoot:catalog info:nil];
}

NSData *RevenantPDFImagePageData(CGImageRef image, RevenantPDFImagePage page)
{
    RevenantPDFWriter *writer = [[RevenantPDFWriter alloc] init];
    RevenantPDFReference *picture = RevenantPDFAddImage(writer, image, page.quality);
    if (picture == nil)
        return nil;
    RevenantPDFImagePlacement placed = RevenantPDFPlaceImage(CGImageGetWidth(image), CGImageGetHeight(image), page.hasMediaBox,
                                                             page.mediaBox, page.rotation, page.upscaleIfSmaller);
    CGRect box = placed.mediaBox;
    CGAffineTransform m = placed.placement;
    NSString *content = [NSString stringWithFormat:@"q %.6f %.6f %.6f %.6f re W n %.6f %.6f %.6f %.6f %.6f %.6f cm /Im1 Do Q\n",
                                                   box.origin.x, box.origin.y, box.size.width, box.size.height, m.a, m.b, m.c, m.d,
                                                   m.tx, m.ty];
    return revenantSinglePageData(writer, box, @{@"XObject" : @{@"Im1" : picture}}, [content dataUsingEncoding:NSASCIIStringEncoding]);
}

NSData *RevenantPDFBlankPageData(CGRect mediaBox)
{
    return revenantSinglePageData([[RevenantPDFWriter alloc] init], CGRectStandardize(mediaBox), @{}, [NSData data]);
}
