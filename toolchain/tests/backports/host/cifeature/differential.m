#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreText/CoreText.h>

#ifdef PORT
@interface CIRectangleFeature (RevenantTest)
- (instancetype)initWithRevenantBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint;
@end

@interface CIQRCodeFeature (RevenantTest)
- (instancetype)initWithRevenantBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                        messageString:(NSString *)message;
@end

@interface CITextFeature (RevenantTest)
- (instancetype)initWithRevenantBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                         subFeatures:(NSArray *)subFeatureList;
@end
#endif

static NSString *className(Class c)
{
    NSString *n = NSStringFromClass(c);
#ifdef PORT
    if ([n hasPrefix:@"RevenantPort"]) {
        n = [n substringFromIndex:strlen("RevenantPort")];
    }
#endif
    return n;
}

static NSString *R(CGRect r)
{
    return [NSString stringWithFormat:@"{%.2f %.2f %.2f %.2f}", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

static NSString *P(CGPoint p)
{
    return [NSString stringWithFormat:@"(%.2f %.2f)", p.x, p.y];
}

static NSString *dump(id f, BOOL fresh, BOOL roundTrip)
{
    NSMutableString *s = [NSMutableString string];
    BOOL knownMessage = fresh || ![f isKindOfClass:[CIQRCodeFeature class]];
    [s appendFormat:@"class %@ superclass %@\n", className([f class]), className([[f class] superclass])];
    CIFeature *feature = f;
    [s appendFormat:@"type %@\n", [feature type] ?: @"(nil)"];
    [s appendFormat:@"%@bounds %@\n", roundTrip ? @"known: " : @"", R([f bounds])];
    if ([f respondsToSelector:@selector(topLeft)]) {
        [s appendFormat:@"%@corners topLeft %@ topRight %@ bottomLeft %@ bottomRight %@\n", roundTrip ? @"known: " : @"",
            P([f topLeft]), P([f topRight]), P([f bottomLeft]), P([f bottomRight])];
    }
    @try {
        if ([f respondsToSelector:@selector(messageString)]) {
            [s appendFormat:@"%@messageString %@\n", knownMessage ? @"known: " : @"", [f messageString] ?: @"(nil)"];
        }
    } @catch (NSException *e) {
        [s appendFormat:@"%@messageString raises %@\n", knownMessage ? @"known: " : @"", e.name];
    }
    if ([f respondsToSelector:@selector(subFeatures)]) {
        [s appendFormat:@"subFeatures %lu\n", (unsigned long)[[f subFeatures] count]];
    }
    if ([f respondsToSelector:@selector(symbolDescriptor)]) {
        id descriptor = [f symbolDescriptor];
        [s appendFormat:@"known: symbolDescriptor %@\n", descriptor ? className([descriptor class]) : @"(nil)"];
    }
    return s;
}

static void report(const char *tag, id f, BOOL lossyRoundTrip)
{
    NSString *d = dump(f, NO, NO);
    printf("%s\n%s", tag, [d UTF8String]);
    BOOL secure = [f conformsToProtocol:@protocol(NSSecureCoding)];
    BOOL copying = [f conformsToProtocol:@protocol(NSCopying)];
    printf("%s conforms NSSecureCoding %d NSCopying %d\n", tag, secure, copying);
    if (copying) {
        printf("%s copy equal %d\n", tag, [dump([f copy], NO, NO) isEqualToString:d]);
    }
    if (secure) {
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:f];
        id back = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        BOOL equal = [dump(back, NO, NO) isEqualToString:d];
        NSString *b = dump(back, NO, lossyRoundTrip);
        printf("%s%s round trip class %s equal %d\n%s", lossyRoundTrip ? "known: " : "", tag,
               [className([back class]) UTF8String], equal, [b UTF8String]);
    }
    printf("%s fresh\n%s", tag, [dump([[[f class] alloc] init], YES, NO) UTF8String]);
}

#ifndef PORT
static CIImage *drawn(size_t w, size_t h, void (^draw)(CGContextRef))
{
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef cg = CGBitmapContextCreate(NULL, w, h, 8, 0, cs, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    CGContextSetRGBFillColor(cg, 1, 1, 1, 1);
    CGContextFillRect(cg, CGRectMake(0, 0, w, h));
    draw(cg);
    CGImageRef image = CGBitmapContextCreateImage(cg);
    CGContextRelease(cg);
    CIImage *out = [CIImage imageWithCGImage:image];
    CGImageRelease(image);
    return out;
}
#endif

int main(void)
{
    @autoreleasepool {
        printf("constants CIFeatureTypeQRCode=%s CIFeatureTypeRectangle=%s CIFeatureTypeText=%s\n",
               [CIFeatureTypeQRCode UTF8String], [CIFeatureTypeRectangle UTF8String], [CIFeatureTypeText UTF8String]);

#ifdef PORT
        CIQRCodeFeature *qr = [[CIQRCodeFeature alloc] initWithRevenantBounds:CGRectMake(8, 8, 168, 168)
            topLeft:CGPointMake(8, 176) topRight:CGPointMake(176, 176)
            bottomLeft:CGPointMake(8, 8) bottomRight:CGPointMake(176, 8)
            messageString:@"Hello QR"];
        CIRectangleFeature *rect = [[CIRectangleFeature alloc] initWithRevenantBounds:CGRectMake(79.34, 59.41, 240.77, 181.02)
            topLeft:CGPointMake(79.34, 240.16) topRight:CGPointMake(319.85, 240.42)
            bottomLeft:CGPointMake(79.59, 59.41) bottomRight:CGPointMake(320.10, 59.67)];
        CITextFeature *text = [[CITextFeature alloc] initWithRevenantBounds:CGRectMake(23, 39, 352, 37)
            topLeft:CGPointMake(23, 76) topRight:CGPointMake(375, 76)
            bottomLeft:CGPointMake(23, 39) bottomRight:CGPointMake(375, 39)
            subFeatures:@[]];
#else
        CIFilter *gen = [CIFilter filterWithName:@"CIQRCodeGenerator"];
        [gen setValue:[@"Hello QR" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
        [gen setValue:@"M" forKey:@"inputCorrectionLevel"];
        CIImage *qrImage = [[gen outputImage] imageByApplyingTransform:CGAffineTransformMakeScale(8, 8)];
        CIFeature *qr = [[[CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:nil]
                          featuresInImage:qrImage] firstObject];

        CIImage *rectImage = drawn(400, 300, ^(CGContextRef cg) {
            CGContextSetRGBFillColor(cg, 0, 0, 0, 1);
            CGContextFillRect(cg, CGRectMake(80, 60, 240, 180));
        });
        CIFeature *rect = [[[CIDetector detectorOfType:CIDetectorTypeRectangle context:nil options:nil]
                            featuresInImage:rectImage] firstObject];

        CIImage *textImage = drawn(600, 120, ^(CGContextRef cg) {
            CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 48, NULL);
            NSDictionary *attrs = @{ (id)kCTFontAttributeName: (__bridge id)font,
                                     (id)kCTForegroundColorFromContextAttributeName: @YES };
            NSAttributedString *as = [[NSAttributedString alloc] initWithString:@"HELLO WORLD" attributes:attrs];
            CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)as);
            CGContextSetRGBFillColor(cg, 0, 0, 0, 1);
            CGContextSetTextPosition(cg, 20, 40);
            CTLineDraw(line, cg);
            CFRelease(line);
            CFRelease(font);
        });
        CIFeature *text = [[[CIDetector detectorOfType:CIDetectorTypeText context:nil
                                               options:@{CIDetectorReturnSubFeatures: @YES}]
                            featuresInImage:textImage] firstObject];
#endif
        report("qr", qr, YES);
        report("rect", rect, NO);
        report("text", text, NO);
    }
    return 0;
}
