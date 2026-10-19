// One probe, two processes, on rendered bytes. Built once against the framework the host carries and
// once against the port's own CIImageAccumulator under a name of its own, so the two never meet in a
// runtime. Each is run over the same script, renders the same images through the same accumulator and
// writes what came out as canonical text: the extent and the format, and for every case the length and
// a checksum of the RGBA bytes the image renders to, with a few pixels spelled out so a difference can
// be looked at rather than only counted.
//
// Nothing here is tuned to agree. A line that differs is a line where the port and the system answer
// differently, and the tolerance is the one run.sh is given.
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// The three rows the port does not carry are not asked here, and the reason is measured rather than
// reasoned: -imageBySettingProperties: and -imageByUnpremultiplyingAlpha are `absent` in
// registry/CoreImage/ctxowner9.json and -imageByPremultiplyingAlpha in
// registry/CoreImage/algebra10.json, the port adds none of the three selectors, and a probe that
// asked them would be measuring the framework on both sides. What the measurements were is in
// facts/CoreImage/ContextOwner.md and facts/CoreImage/ImageAlgebra.md.

#import "port-support.h"

// The port's classes under the names its build gives them, and the framework's own where there is no
// port class at all: the framework's are in the same process and are never asked, so the two processes
// each answer for one set of objects and the two sets never meet.
#define ACCUMULATOR PORT_ACCUMULATOR

// One colour space for the whole probe, made once and kept: a space made and released around every
// render is a thing to get wrong, and nothing here is measured through one.
static CGColorSpaceRef probeSpace(void)
{
    static CGColorSpaceRef space;
    if (!space)
        space = CGColorSpaceCreateDeviceRGB();
    return space;
}

static void put(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void put(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
    printf("%s\n", line.UTF8String);
}

static void put_bytes(NSString *key, NSData *data)
{
    const uint8_t *bytes = data.bytes;
    uint32_t sum = 2166136261u;
    for (NSUInteger k = 0; k < data.length; k++) {
        sum ^= bytes[k];
        sum *= 16777619u;
    }
    put(@"%@ %lu %08x", key, (unsigned long)data.length, sum);
}

static void put_box(NSString *key, CGRect rect)
{
    put(@"%@ %.4f %.4f %.4f %.4f", key, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

// The rendered RGBA bytes of an image over the whole of its extent, in 8 bits a channel: the one
// rendering both sides do the same way, so what is compared is what the accumulator did with the
// bytes and not how either side renders.
static NSData *render(CIImage *image)
{
    if (!image)
        return nil;
    CGRect extent = image.extent;
    if (CGRectIsInfinite(extent) || CGRectIsEmpty(extent))
        return nil;
    NSUInteger width = (NSUInteger)ceil(extent.size.width), height = (NSUInteger)ceil(extent.size.height);
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CIContext *context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace: [NSNull null],
                                                        kCIContextOutputPremultiplied: @NO}];
    // The colour space is named and the same one every time: a byte format needs one, and the two
    // processes must be handed the same one or the bytes are not comparable.
    [context render:image toBitmap:data.mutableBytes rowBytes:(NSInteger)(width * 4) bounds:extent
              format:kCIFormatRGBA8 colorSpace:probeSpace()];
    return data;
}

// A few pixels spelled out, so a difference in the checksum can be seen rather than only counted.
static void put_pixels(NSString *key, NSData *data)
{
    if (!data || data.length < 16)
        return;
    const uint8_t *bytes = data.bytes;
    for (NSUInteger k = 0; k < 4 && (k + 1) * 4 <= data.length; k++)
        put(@"%@ pixel %lu %u %u %u %u", key, (unsigned long)k, bytes[k * 4], bytes[k * 4 + 1], bytes[k * 4 + 2],
            bytes[k * 4 + 3]);
}

// The image every case starts from: a red field on the left, a green one on the right, so a pixel of
// the accumulator says which half of the image it came from.
static CIImage *field(CGRect extent)
{
    CIImage *left = [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:1 green:0 blue:0 alpha:1]];
    CIImage *right = [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0 green:1 blue:0 alpha:1]];
    return [left imageByCompositingOverImage:[right imageByCroppingToRect:extent]];
}

static void report(NSString *key, ACCUMULATOR *accumulator)
{
    put(@"%@ extent %.4f %.4f %.4f %.4f", key, accumulator.extent.origin.x, accumulator.extent.origin.y,
        accumulator.extent.size.width, accumulator.extent.size.height);
    put(@"%@ format %ld", key, (long)accumulator.format);
    CIImage *image = [accumulator image];
    put(@"%@ image %@", key, image ? @"made" : @"none");
    if (image)
        put_box([key stringByAppendingString:@" image extent"], image.extent);
    put_bytes([key stringByAppendingString:@" pixels"], render(image));
    put_pixels([key stringByAppendingString:@" pixels"], render(image));
}

// A representation, measured as the bytes and as what is in them: the length and checksum of the
// data, and the size, the format and four pixels of the image those bytes decode to. A file that is
// the same picture written the same way is the same data; a file that is a different picture is not.
static void put_representation(NSString *key, NSData *data)
{
    if (!data) {
        put(@"%@ none", key);
        return;
    }
    put_bytes(key, data);
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        put(@"%@ undecodable", key);
        return;
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    put(@"%@ type %@ size %zu %zu bits %zu %zu", key,
        (__bridge NSString *)CGImageSourceGetType(source), image ? CGImageGetWidth(image) : 0,
        image ? CGImageGetHeight(image) : 0, image ? CGImageGetBitsPerComponent(image) : 0,
        image ? CGImageGetBitsPerPixel(image) : 0);
    NSMutableData *rgba = nil;
    if (image) {
        rgba = [NSMutableData dataWithLength:CGImageGetWidth(image) * CGImageGetHeight(image) * 4];
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(rgba.mutableBytes, CGImageGetWidth(image), CGImageGetHeight(image), 8,
                                                     CGImageGetWidth(image) * 4, space,
                                                     (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
        CGContextRelease(context);
        CGColorSpaceRelease(space);
        CGImageRelease(image);
    }
    CFRelease(source);
    put_bytes([key stringByAppendingString:@" decoded"], rgba);
    put_pixels([key stringByAppendingString:@" decoded"], rgba);
}

static void reportRepresentations(void)
{
    CIImage *image = [[[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0.2 green:0.7 blue:0.4 alpha:1]]
        imageByCroppingToRect:CGRectMake(0, 0, 6, 4)];
    CIContext *context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace: [NSNull null]}];
    const CIFormat formats[3] = {kCIFormatRGBA8, kCIFormatL8, kCIFormatRGBAf};
    const char *names[3] = {"rgba8", "l8", "rgbaf"};
    for (int f = 0; f < 3; f++) {
        NSString *key = [NSString stringWithFormat:@"repr %s png", names[f]];
        put_representation(key, [context PNGRepresentationOfImage:image format:formats[f] colorSpace:NULL options:@{}]);
        put_representation([key stringByAppendingString:@" tiff"],
                           [context TIFFRepresentationOfImage:image format:formats[f] colorSpace:NULL options:@{}]);
    }
    put_representation(@"repr jpeg", [context JPEGRepresentationOfImage:image colorSpace:NULL options:@{}]);
    // The CGImage the deferred form gives, measured as the same picture.
    CGImageRef made = [context createCGImage:image fromRect:image.extent format:kCIFormatRGBA8 colorSpace:NULL
                                 deferred:NO];
    if (made) {
        put(@"repr cgimage %zu %zu %zu %zu", CGImageGetWidth(made), CGImageGetHeight(made),
            CGImageGetBitsPerComponent(made), CGImageGetBitsPerPixel(made));
        CGImageRelease(made);
    } else {
        put(@"repr cgimage none");
    }
    // And what a file of the same bytes holds, which is the write form's whole difference.
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-ci-repr.png"];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    BOOL written = [context writePNGRepresentationOfImage:image toURL:url format:kCIFormatRGBA8 colorSpace:NULL
                                                  options:@{} error:&error];
    put(@"repr write png %d", written);
    put_bytes(@"repr write png file", [NSData dataWithContentsOfURL:url]);
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

// The algebra of an image, measured as the extent of what comes out and the bytes it renders to. The
// input is a field with an alpha in it, so a step that multiplies by the alpha and one that divides by
// it are both visible in the result.
static void put_algebra(NSString *key, CIImage *image, CGRect bounds)
{
    if (!image) {
        put(@"%@ none", key);
        return;
    }
    put_box([key stringByAppendingString:@" extent"], image.extent);
    NSData *pixels = render([image imageByCroppingToRect:bounds]);
    put_bytes([key stringByAppendingString:@" pixels"], pixels);
    put_pixels([key stringByAppendingString:@" pixels"], pixels);
}

static void reportAlgebra(void)
{
    CGRect bounds = CGRectMake(0, 0, 6, 4);
    CIImage *image = [[[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0.6 green:0.3 blue:0.9 alpha:0.5]]
        imageByCroppingToRect:bounds];
    put_algebra(@"alg source", image, bounds);
    put_algebra(@"alg blurred", [image imageByApplyingGaussianBlurWithSigma:1.5], bounds);
    put_algebra(@"alg clamped extent", [image imageByClampingToExtent], bounds);
    put_algebra(@"alg clamped rect", [image imageByClampingToRect:CGRectMake(0, 0, 3, 2)], CGRectMake(0, 0, 6, 4));
    put_algebra(@"alg intermediate", [image imageByInsertingIntermediate], bounds);
    put_algebra(@"alg intermediate cached", [image imageByInsertingIntermediate:YES], bounds);
    // -imageByPremultiplyingAlpha is `absent` in registry/CoreImage/algebra10.json and is not
    // asked here at all, neither called nor asked through respondsToSelector:.  This probe is one
    // source built twice, and the port process is the framework's own CoreImage with the port's
    // categories on it, so a selector the port does not carry is still answered YES in both
    // processes and the two answers would be identical whatever the port does.
    // -imageBySettingAlphaOneInExtent: is `absent` in registry/CoreImage/algebra10.json and is not
    // asked here, for the reason the other three absent rows are not: this probe is one source built
    // twice, and the port process carries the framework's own CoreImage, so a call here would reach
    // the framework and the two processes would be asked the same question about the same code.
    put_algebra(@"alg transformed", [image imageByApplyingTransform:CGAffineTransformMakeScale(2, 2) highQualityDownsample:NO],
                 CGRectMake(0, 0, 12, 8));
    put_algebra(@"alg transformed hq",
                 [image imageByApplyingTransform:CGAffineTransformMakeScale(0.5, 0.5) highQualityDownsample:YES], bounds);
    put_algebra(@"alg properties", [image imageBySettingProperties:@{@"charonProbe": @"one"}], bounds);
    for (NSString *name in @[ @"blackImage", @"whiteImage", @"grayImage", @"redImage", @"greenImage", @"blueImage",
                              @"cyanImage", @"magentaImage", @"yellowImage", @"clearImage" ]) {
        SEL selector = NSSelectorFromString(name);
        CIImage *constant = [CIImage respondsToSelector:selector] ? [CIImage performSelector:selector] : nil;
        put_algebra([@"alg " stringByAppendingString:name], constant, CGRectMake(0, 0, 2, 2));
    }
}

// The context's own surface and options, and a draw into that surface: the bytes the CGContext ended
// up holding are the measurement, drawn the same way on both sides.
static void reportContextOwner(void)
{
    CGColorSpaceRef space = probeSpace();
    NSDictionary *options = @{kCIContextWorkingColorSpace: [NSNull null], kCIContextOutputPremultiplied: @NO};
    CIImage *image = [[[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0.4 green:0.6 blue:0.2 alpha:1]]
        imageByCroppingToRect:CGRectMake(0, 0, 5, 3)];
    for (int withSpace = 0; withSpace < 2; withSpace++) {
        NSString *key = withSpace ? @"ctx space srgb" : @"ctx space nil";
        NSMutableData *bytes = [NSMutableData dataWithLength:8 * 6 * 4];
        CGContextRef cgctx = CGBitmapContextCreate(bytes.mutableBytes, 8, 6, 8, 32, space,
                                                   (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        NSDictionary *given = withSpace ? @{kCIContextWorkingColorSpace: (__bridge id)space} : options;
        CIContext *context = [PORT_CONTEXT contextWithCGContext:cgctx options:given];
        put(@"%@ working format %ld", key, (long)context.workingFormat);
        put(@"%@ working space %@", key, context.workingColorSpace ? @"one" : @"none");
        [context drawImage:image inRect:CGRectMake(0, 0, 8, 6) fromRect:image.extent];
        CGContextFlush(cgctx);
        CGContextRelease(cgctx);
        put_bytes(key, bytes);
        put_pixels(key, bytes);
    }
}

// The four rows the port does not carry are not asked here: -imageBySettingProperties: and
// -imageByUnpremultiplyingAlpha are `absent` in registry/CoreImage/ctxowner9.json, and
// -imageByPremultiplyingAlpha and -imageBySettingAlphaOneInExtent: in
// registry/CoreImage/algebra10.json.  They are not called and they
// are not asked through respondsToSelector: either, because this probe is one source built twice
// and the port process carries the framework's own CoreImage: a selector the port does not add is
// answered YES in both processes, so the two answers would be identical whatever the port does.
// What they measured, and why none of them is carried, is in facts/CoreImage/ContextOwner.md and
// facts/CoreImage/ImageAlgebra.md.

// A colour, measured as the numbers the colour object holds and as the bytes an image of that colour
// renders to. The named colours and the two spellings of the colour-space initialisers are asked with
// the same components, so a conversion that is not the system's shows up as a different pixel.
static void put_color(NSString *key, CIColor *color)
{
    if (!color) {
        put(@"%@ none", key);
        return;
    }
    put(@"%@ components %lu red %.4f green %.4f blue %.4f alpha %.4f", key, (unsigned long)color.numberOfComponents,
        color.red, color.green, color.blue, color.alpha);
    put_bytes([key stringByAppendingString:@" pixels"], render([[CIImage alloc] initWithColor:color]));
}

static void reportColors(void)
{
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorSpaceRef generic = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    static const CGFloat triples[4][3] = {{1, 0, 0}, {0.2, 0.6, 0.9}, {0.5, 0.5, 0.5}, {0, 0, 0}};
    static const CGFloat alphas[2] = {1, 0.25};
    for (int t = 0; t < 4; t++)
        for (int a = 0; a < 2; a++) {
            NSString *key = [NSString stringWithFormat:@"color %d %d", t, a];
            CGFloat r = triples[t][0], g = triples[t][1], b = triples[t][2], alpha = alphas[a];
            put_color([key stringByAppendingString:@" srgb"], [CIColor colorWithRed:r green:g blue:b alpha:alpha colorSpace:srgb]);
            put_color([key stringByAppendingString:@" generic"], [CIColor colorWithRed:r green:g blue:b alpha:alpha colorSpace:generic]);
            put_color([key stringByAppendingString:@" opaque srgb"], [CIColor colorWithRed:r green:g blue:b colorSpace:srgb]);
            put_color([key stringByAppendingString:@" init srgb"], [[CIColor alloc] initWithRed:r green:g blue:b alpha:alpha colorSpace:srgb]);
            put_color([key stringByAppendingString:@" init noalpha srgb"], [[CIColor alloc] initWithRed:r green:g blue:b colorSpace:srgb]);
            put_color([key stringByAppendingString:@" init rgb"], [[CIColor alloc] initWithRed:r green:g blue:b]);
        }
    // The named colours, each asked twice so a cached one and a made one are the same answer.
    CIColor *(^named)(NSString *) = ^CIColor *(NSString *name) {
        SEL selector = NSSelectorFromString(name);
        return [CIColor respondsToSelector:selector] ? [CIColor performSelector:selector] : nil;
    };
    for (NSString *name in @[ @"blackColor", @"whiteColor", @"grayColor", @"redColor", @"greenColor", @"blueColor",
                              @"cyanColor", @"magentaColor", @"yellowColor", @"clearColor" ]) {
        put_color([@"named " stringByAppendingString:name], named(name));
        put_color([@"named again " stringByAppendingString:name], named(name));
    }
    CGColorSpaceRelease(srgb);
    CGColorSpaceRelease(generic);
}

// A filter shape, measured as a shape and as the region a render comes back over: the shape's own
// extent, and the extent and the bytes of an image cropped to it, which is the shape doing the job a
// caller asks of it.
static void put_shape(NSString *key, PORT_SHAPE *shape)
{
    if (!shape) {
        put(@"%@ none", key);
        return;
    }
    put_box(key, shape.extent);
    CGRect whole = CGRectIntegral(shape.extent);
    CIImage *image = [[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0.25 green:0.5 blue:0.75 alpha:1]];
    image = [image imageByCroppingToRect:shape.extent];
    put_box([key stringByAppendingString:@" cropped"], image.extent);
    put_bytes([key stringByAppendingString:@" cropped pixels"], render(image));
}

static void reportShapes(void)
{
    static const CGRect rects[3] = {{0, 0, 10, 10}, {5, 5, 10, 10}, {-4, 2, 3.5, 6.25}};
    for (int a = 0; a < 3; a++)
        for (int b = 0; b < 3; b++) {
            NSString *key = [NSString stringWithFormat:@"shape %d %d", a, b];
            PORT_SHAPE *left = [PORT_SHAPE shapeWithRect:rects[a]], *right = [PORT_SHAPE shapeWithRect:rects[b]];
            put_shape([key stringByAppendingString:@" left"], left);
            put_shape([key stringByAppendingString:@" union"], [left unionWith:right]);
            put_shape([key stringByAppendingString:@" unionRect"], [left unionWithRect:rects[b]]);
            put_shape([key stringByAppendingString:@" intersect"], [left intersectWith:right]);
            put_shape([key stringByAppendingString:@" intersectRect"], [left intersectWithRect:rects[b]]);
        }
    PORT_SHAPE *shape = [PORT_SHAPE shapeWithRect:rects[0]];
    put_shape(@"shape inset 1 2", [shape insetByX:1 Y:2]);
    put_shape(@"shape inset -3 4", [shape insetByX:-3 Y:4]);
    put_shape(@"shape moved", [shape transformBy:CGAffineTransformMakeTranslation(4, -6) interior:NO]);
    put_shape(@"shape moved interior", [shape transformBy:CGAffineTransformMakeTranslation(4, -6) interior:YES]);
    put_shape(@"shape turned", [shape transformBy:CGAffineTransformMakeRotation(0.6) interior:NO]);
    put_shape(@"shape turned interior", [shape transformBy:CGAffineTransformMakeRotation(0.6) interior:YES]);
    put_shape(@"shape scaled", [shape transformBy:CGAffineTransformMakeScale(2, 0.5) interior:NO]);
    put_shape(@"shape scaled interior", [shape transformBy:CGAffineTransformMakeScale(2, 0.5) interior:YES]);
}

// Which implementation the process actually reaches for a selector, by name: the port's methods are a
// category, and a category that is shadowed would make the two processes agree whatever the port did.
static void report_implementation(const char *key, Class cls, SEL selector)
{
    Method method = class_getInstanceMethod(cls, selector);
    IMP implementation = method ? method_getImplementation(method) : NULL;
    Dl_info info;
    memset(&info, 0, sizeof info);
    const char *owner = implementation && dladdr((const void *)implementation, &info) && info.dli_fname
                            ? strrchr(info.dli_fname, '/') ? strrchr(info.dli_fname, '/') + 1 : info.dli_fname
                            : "?";
    printf("%s %p %s\n", key, (void *)implementation, owner);
}

static void reportImplementations(void)
{
    // -imageBySettingProperties:, -properties, -imageByUnpremultiplyingAlpha and
    // -imageByPremultiplyingAlpha are not asked: the port adds none of the four selectors, and on
    // the host all four are the framework's own, so the two processes would be asked the same
    // question about the same code.
    report_implementation("imp imageByClampingToExtent", [CIImage class], @selector(imageByClampingToExtent));
}

int main(void)
{
    // Unbuffered: a probe that loses everything it printed when it dies cannot say where it died,
    // which is the one thing a probe is for.
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        put(@"probe %s", PORT_NAME);
        CGRect extent = CGRectMake(0, 0, 8, 4);

        // The two formats an accumulator is asked for most, and the two that disagree on the order of
        // the same bytes, so each is asked in its own turn.
        const CIFormat formats[2] = {kCIFormatRGBA8, kCIFormatBGRA8};
        for (int f = 0; f < 2; f++) {
            CIFormat format = formats[f];
            NSString *key = f == 0 ? @"rgba" : @"bgra";
            ACCUMULATOR *accumulator = [ACCUMULATOR imageAccumulatorWithExtent:extent format:format];
            report(key, accumulator);
            [accumulator setImage:field(extent)];
            report([key stringByAppendingString:@" set"], accumulator);
            [accumulator clear];
            report([key stringByAppendingString:@" cleared"], accumulator);
        }

        // A dirty rect: what is inside it changes and what is outside it does not.
        ACCUMULATOR *dirty = [ACCUMULATOR imageAccumulatorWithExtent:extent format:kCIFormatRGBA8];
        [dirty setImage:field(extent)];
        put_bytes(@"dirty before", render([dirty image]));
        [dirty setImage:[[CIImage alloc] initWithColor:[[CIColor alloc] initWithRed:0 green:0 blue:1 alpha:1]]
                dirtyRect:CGRectMake(0, 0, 4, 4)];
        put_bytes(@"dirty after", render([dirty image]));

        // An extent that is not integral and does not start at the origin: the accumulator's own extent
        // is what the header says it is, and the pixels are the ones inside it.
        CGRect odd = CGRectMake(1.5, -2.25, 5.5, 3.5);
        ACCUMULATOR *shifted = [ACCUMULATOR imageAccumulatorWithExtent:odd format:kCIFormatRGBA8];
        report(@"odd", shifted);
        [shifted setImage:field(odd)];
        report(@"odd set", shifted);

        // An accumulator nothing was ever set into, and one with a colour space.
        ACCUMULATOR *empty = [ACCUMULATOR imageAccumulatorWithExtent:extent format:kCIFormatRGBA8];
        report(@"empty", empty);
        ACCUMULATOR *spaced = [ACCUMULATOR imageAccumulatorWithExtent:extent format:kCIFormatRGBA8
                                                          colorSpace:probeSpace()];
        [spaced setImage:field(extent)];
        report(@"spaced", spaced);
        reportContextOwner();
        reportImplementations();
        reportAlgebra();
        reportColors();
        reportRepresentations();
        reportShapes();
    }
    return 0;
}
