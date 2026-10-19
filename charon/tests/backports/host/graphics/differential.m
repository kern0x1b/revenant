#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static int checks;
static int failures;
static int skipped;

static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static void same_long(long ours, long theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: ours %ld, UIKit %ld", what, ours, theirs);
}

static void same_double(double ours, double theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: ours %.17g, UIKit %.17g", what, ours, theirs);
}

static void same_data(NSData *ours, NSData *theirs, NSString *what)
{
    checks++;
    if (ours == theirs || [ours isEqualToData:theirs])
        return;
    fail(@"%@: ours %lu bytes, UIKit %lu bytes%@", what, (unsigned long)ours.length, (unsigned long)theirs.length,
         ours.length == theirs.length ? @", contents differ" : @"");
}

/* Both images drawn into one bitmap of this test's own making, so what came out is compared
   whatever the renderer used underneath. */
static NSData *flattened(UIImage *image)
{
    size_t width = (size_t)(image.size.width * image.scale), height = (size_t)(image.size.height * image.scale);
    if (!width || !height)
        return [NSData data];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(space);
    if (!context)
        return [NSData data];
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
    NSData *pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:width * 4 * height];
    CGContextRelease(context);
    return pixels;
}

static Class ours_of(NSString *name)
{
    Class mine = NSClassFromString([@"CharonHost" stringByAppendingString:name]);
    if (!mine)
        fail(@"the backport defines no %@", name);
    return mine;
}

/* Everything the drawing block is given, recorded so the two runs can be compared. */
typedef struct {
    size_t width, height, bitsPerComponent, bitsPerPixel, bytesPerRow;
    uint32_t bitmapInfo, alphaInfo;
    int colorSpaceModel;
    CGAffineTransform transform;
} Shape;

static Shape shape_of(CGContextRef context)
{
    CGColorSpaceRef space = CGBitmapContextGetColorSpace(context);
    Shape shape = {
        CGBitmapContextGetWidth(context), CGBitmapContextGetHeight(context),
        CGBitmapContextGetBitsPerComponent(context), CGBitmapContextGetBitsPerPixel(context),
        CGBitmapContextGetBytesPerRow(context),
        (uint32_t)CGBitmapContextGetBitmapInfo(context), (uint32_t)CGBitmapContextGetAlphaInfo(context),
        space ? (int)CGColorSpaceGetModel(space) : -1,
        CGContextGetCTM(context)
    };
    return shape;
}

/* The renderer of the host this runs on need not be backed by a bitmap context - a UIKit
   newer than iOS 10 is not - and then none of a bitmap's properties can be read from it and
   there is nothing to compare. What the drawing came out as is compared either way, by
   redrawing both images into one bitmap of this test's own making. */
static BOOL comparable(Shape theirs)
{
    return theirs.width != 0 && theirs.height != 0;
}

static void same_shape(Shape ours, Shape theirs, NSString *what)
{
    same_long(ours.width, theirs.width, [what stringByAppendingString:@" width"]);
    same_long(ours.height, theirs.height, [what stringByAppendingString:@" height"]);
    same_long(ours.bitsPerComponent, theirs.bitsPerComponent, [what stringByAppendingString:@" bits per component"]);
    same_long(ours.bitsPerPixel, theirs.bitsPerPixel, [what stringByAppendingString:@" bits per pixel"]);
    same_long(ours.bytesPerRow, theirs.bytesPerRow, [what stringByAppendingString:@" bytes per row"]);
    same_long(ours.bitmapInfo, theirs.bitmapInfo, [what stringByAppendingString:@" bitmap info"]);
    same_long(ours.alphaInfo, theirs.alphaInfo, [what stringByAppendingString:@" alpha info"]);
    same_long(ours.colorSpaceModel, theirs.colorSpaceModel, [what stringByAppendingString:@" colour space model"]);
    checks++;
    if (!CGAffineTransformEqualToTransform(ours.transform, theirs.transform))
        fail(@"%@ transform: ours [%g %g %g %g %g %g], UIKit [%g %g %g %g %g %g]", what,
             ours.transform.a, ours.transform.b, ours.transform.c, ours.transform.d, ours.transform.tx, ours.transform.ty,
             theirs.transform.a, theirs.transform.b, theirs.transform.c, theirs.transform.d, theirs.transform.tx, theirs.transform.ty);
}

/* The drawing the two renderers are both given. It uses the rendererContext API rather than
   CoreGraphics directly wherever there is one, so fillRect:, strokeRect: and clipToRect: are
   exercised through the backport as an application would reach them. */
static void draw(id context, CGRect bounds)
{
    CGContextRef cg = ((CGContextRef (*)(id, SEL))objc_msgSend)(context, @selector(CGContext));
    CGContextSetRGBFillColor(cg, 0.2, 0.4, 0.9, 1);
    ((void (*)(id, SEL, CGRect))objc_msgSend)(context, @selector(fillRect:), CGRectInset(bounds, 2, 2));
    CGContextSetRGBStrokeColor(cg, 1, 0, 0, 1);
    CGContextSetLineWidth(cg, 4);
    ((void (*)(id, SEL, CGRect))objc_msgSend)(context, @selector(strokeRect:), CGRectInset(bounds, 6, 6));
    CGContextSetRGBFillColor(cg, 0, 1, 0, 0.5);
    ((void (*)(id, SEL, CGRect, CGBlendMode))objc_msgSend)(context, @selector(fillRect:blendMode:),
                                                          CGRectMake(bounds.origin.x, bounds.origin.y, 10, 10), kCGBlendModeMultiply);
    ((void (*)(id, SEL, CGRect))objc_msgSend)(context, @selector(clipToRect:), CGRectInset(bounds, 1, 1));
    CGContextSetRGBFillColor(cg, 1, 1, 0, 1);
    CGContextFillRect(cg, CGRectMake(bounds.origin.x + 3, bounds.origin.y + 3, 8, 8));
    CGContextSetRGBStrokeColor(cg, 0, 0, 0, 1);
    CGContextSetLineWidth(cg, 1);
    ((void (*)(id, SEL, CGRect, CGBlendMode))objc_msgSend)(context, @selector(strokeRect:blendMode:),
                                                          CGRectInset(bounds, 8, 8), kCGBlendModeNormal);
}

static void compare_case(CGRect bounds, CGFloat scale, BOOL opaque, NSString *what)
{
    Class theirRenderer = [UIGraphicsImageRenderer class], ourRenderer = ours_of(@"UIGraphicsImageRenderer");
    Class theirFormat = [UIGraphicsImageRendererFormat class], ourFormat = ours_of(@"UIGraphicsImageRendererFormat");
    if (!ourRenderer || !ourFormat)
        return;

    __block Shape theirShape, ourShape;
    __block NSData *theirPixels = nil, *ourPixels = nil;

    UIGraphicsImageRendererFormat *format = [[theirFormat alloc] init];
    format.scale = scale;
    format.opaque = opaque;
    UIGraphicsImageRenderer *renderer = [[theirRenderer alloc] initWithBounds:bounds format:format];
    UIImage *theirImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        theirShape = shape_of(context.CGContext);
        draw(context, bounds);
        CGContextRef cg = context.CGContext;
        theirPixels = [NSData dataWithBytes:CGBitmapContextGetData(cg)
                                     length:CGBitmapContextGetBytesPerRow(cg) * CGBitmapContextGetHeight(cg)];
    }];

    id ourFormatObject = [[ourFormat alloc] init];
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(ourFormatObject, @selector(setScale:), scale);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(ourFormatObject, @selector(setOpaque:), opaque);
    id ourRendererObject = ((id (*)(id, SEL, CGRect, id))objc_msgSend)([ourRenderer alloc],
                                                                      @selector(initWithBounds:format:), bounds, ourFormatObject);
    UIImage *ourImage = ((id (*)(id, SEL, id))objc_msgSend)(ourRendererObject, @selector(imageWithActions:),
        ^(id context) {
            ourShape = shape_of(((CGContextRef (*)(id, SEL))objc_msgSend)(context, @selector(CGContext)));
            draw(context, bounds);
            CGContextRef cg = ((CGContextRef (*)(id, SEL))objc_msgSend)(context, @selector(CGContext));
            ourPixels = [NSData dataWithBytes:CGBitmapContextGetData(cg)
                                       length:CGBitmapContextGetBytesPerRow(cg) * CGBitmapContextGetHeight(cg)];
        });

    if (comparable(theirShape)) {
        same_shape(ourShape, theirShape, what);
        same_data(ourPixels, theirPixels, [what stringByAppendingString:@" pixels"]);
    } else {
        skipped++;
    }
    same_data(flattened(ourImage), flattened(theirImage), [what stringByAppendingString:@" drawn pixels"]);
    same_double(ourImage.size.width, theirImage.size.width, [what stringByAppendingString:@" image width"]);
    same_double(ourImage.size.height, theirImage.size.height, [what stringByAppendingString:@" image height"]);
    same_double(ourImage.scale, theirImage.scale, [what stringByAppendingString:@" image scale"]);
    same_long(ourImage.imageOrientation, theirImage.imageOrientation, [what stringByAppendingString:@" image orientation"]);
    same_data(UIImagePNGRepresentation(ourImage), UIImagePNGRepresentation(theirImage), [what stringByAppendingString:@" PNG"]);

    NSData *theirPNG = [renderer PNGDataWithActions:^(UIGraphicsImageRendererContext *context) { draw(context, bounds); }];
    NSData *ourPNG = ((id (*)(id, SEL, id))objc_msgSend)(ourRendererObject, @selector(PNGDataWithActions:),
                                                         ^(id context) { draw(context, bounds); });
    same_data(ourPNG, theirPNG, [what stringByAppendingString:@" PNGDataWithActions:"]);

    NSData *theirJPEG = [renderer JPEGDataWithCompressionQuality:0.8 actions:^(UIGraphicsImageRendererContext *context) { draw(context, bounds); }];
    NSData *ourJPEG = ((id (*)(id, SEL, CGFloat, id))objc_msgSend)(ourRendererObject, @selector(JPEGDataWithCompressionQuality:actions:),
                                                                   0.8, ^(id context) { draw(context, bounds); });
    same_data(ourJPEG, theirJPEG, [what stringByAppendingString:@" JPEGDataWithCompressionQuality:"]);
}

static void compare_formats(void)
{
    Class theirFormat = [UIGraphicsImageRendererFormat class], ourFormat = ours_of(@"UIGraphicsImageRendererFormat");
    Class theirBase = [UIGraphicsRendererFormat class], ourBase = ours_of(@"UIGraphicsRendererFormat");
    if (!ourFormat || !ourBase)
        return;
    UIGraphicsImageRendererFormat *theirs = [[theirFormat alloc] init];
    id ours = [[ourFormat alloc] init];
    same_double(((CGFloat (*)(id, SEL))objc_msgSend)(ours, @selector(scale)), theirs.scale, @"a fresh format's scale");
    same_long(((BOOL (*)(id, SEL))objc_msgSend)(ours, @selector(opaque)), theirs.opaque, @"a fresh format's opacity");

    UIGraphicsImageRendererFormat *theirDefault = [theirFormat defaultFormat];
    id ourDefault = ((id (*)(id, SEL))objc_msgSend)(ourFormat, @selector(defaultFormat));
    same_double(((CGFloat (*)(id, SEL))objc_msgSend)(ourDefault, @selector(scale)), theirDefault.scale, @"the default format's scale");
    same_long(((BOOL (*)(id, SEL))objc_msgSend)(ourDefault, @selector(opaque)), theirDefault.opaque, @"the default format's opacity");

    UIGraphicsRendererFormat *theirBaseFormat = [theirBase defaultFormat];
    id ourBaseFormat = ((id (*)(id, SEL))objc_msgSend)(ourBase, @selector(defaultFormat));
    CGRect theirBounds = theirBaseFormat.bounds;
    CGRect ourBounds = ((CGRect (*)(id, SEL))objc_msgSend)(ourBaseFormat, @selector(bounds));
    checks++;
    if (!CGRectEqualToRect(ourBounds, theirBounds))
        fail(@"the base default format's bounds: ours %@, UIKit %@", NSStringFromCGRect(ourBounds), NSStringFromCGRect(theirBounds));

    /* The renderer keeps the bounds it was made with on its own copy of the format. */
    CGRect bounds = CGRectMake(1, 2, 30, 40);
    UIGraphicsImageRenderer *theirRenderer = [[UIGraphicsImageRenderer alloc] initWithBounds:bounds format:theirs];
    id ourRenderer = ((id (*)(id, SEL, CGRect, id))objc_msgSend)([ours_of(@"UIGraphicsImageRenderer") alloc],
                                                                 @selector(initWithBounds:format:), bounds, ours);
    CGRect theirRendererBounds = theirRenderer.format.bounds;
    CGRect ourRendererBounds = ((CGRect (*)(id, SEL))objc_msgSend)(
        ((id (*)(id, SEL))objc_msgSend)(ourRenderer, @selector(format)), @selector(bounds));
    checks++;
    if (!CGRectEqualToRect(ourRendererBounds, theirRendererBounds))
        fail(@"the renderer's format bounds: ours %@, UIKit %@", NSStringFromCGRect(ourRendererBounds), NSStringFromCGRect(theirRendererBounds));
    same_long(((BOOL (*)(id, SEL))objc_msgSend)(ourRenderer, @selector(allowsImageOutput)),
              theirRenderer.allowsImageOutput, @"an image renderer allows image output");
    same_long((long)((Class (*)(id, SEL))objc_msgSend)(ours_of(@"UIGraphicsRenderer"), @selector(rendererContextClass))
                  == (long)ours_of(@"UIGraphicsRendererContext"),
              (long)([UIGraphicsRenderer rendererContextClass] == [UIGraphicsRendererContext class]),
              @"the base renderer's context class");
}

static void compare_empty(void)
{
    /* A renderer of no size cannot make a context. UIKit answers an empty image, not nil,
       and an empty NSData, not nil; an application that only checks for nil walks on. */
    Class ourRenderer = ours_of(@"UIGraphicsImageRenderer");
    if (!ourRenderer)
        return;
    UIGraphicsImageRenderer *theirs = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeZero];
    id ours = ((id (*)(id, SEL, CGSize))objc_msgSend)([ourRenderer alloc], @selector(initWithSize:), CGSizeZero);
    __block BOOL theirRan = NO, ourRan = NO;
    UIImage *theirImage = [theirs imageWithActions:^(UIGraphicsImageRendererContext *context) { theirRan = YES; }];
    UIImage *ourImage = ((id (*)(id, SEL, id))objc_msgSend)(ours, @selector(imageWithActions:), ^(id context) { ourRan = YES; });
    same_long(ourRan, theirRan, @"a renderer of no size runs the drawing actions");
    same_long(ourImage != nil, theirImage != nil, @"a renderer of no size answers an image");
    same_double(ourImage.size.width, theirImage.size.width, @"the empty image's width");
    same_double(ourImage.size.height, theirImage.size.height, @"the empty image's height");
    NSData *theirData = [theirs PNGDataWithActions:^(UIGraphicsImageRendererContext *context) { }];
    NSData *ourData = ((id (*)(id, SEL, id))objc_msgSend)(ours, @selector(PNGDataWithActions:), ^(id context) { });
    same_long(ourData != nil, theirData != nil, @"a renderer of no size answers data");
    same_long(ourData.length, theirData.length, @"the empty data's length");
}

int main(void)
{
    @autoreleasepool {
        compare_formats();
        compare_empty();
        const CGFloat scales[] = {1, 2, 3, 0};
        const BOOL opacities[] = {NO, YES};
        const CGRect boundses[] = {CGRectMake(0, 0, 40, 30), CGRectMake(5, 7, 33, 21), CGRectMake(-4, -2, 20, 20),
                                   CGRectMake(0, 0, 10.5, 10.5)};
        for (unsigned b = 0; b < sizeof(boundses) / sizeof(*boundses); b++)
            for (unsigned s = 0; s < sizeof(scales) / sizeof(*scales); s++)
                for (unsigned o = 0; o < sizeof(opacities) / sizeof(*opacities); o++)
                    compare_case(boundses[b], scales[s], opacities[o],
                                 [NSString stringWithFormat:@"%@ at scale %g%@", NSStringFromCGRect(boundses[b]),
                                                            scales[s], opacities[o] ? @" opaque" : @""]);
        printf("%d checks, %d failures, %d cases the host cannot be held to\n", checks, failures, skipped);
        if (skipped)
            printf("(the host's own renderer is not backed by a bitmap context, so its bitmap has nothing to compare;\n what was drawn is compared in every case)\n");
    }
    return failures;
}
