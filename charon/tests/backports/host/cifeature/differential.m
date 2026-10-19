// differential.m - the three features of CoreImage the port carries (CIRectangleFeature, CIQRCodeFeature and CITextFeature),
// field by field, against the host's own. Built twice by run.sh: against the host's CoreImage (no -DPORT), and against the
// port's sources (-DPORT, with rename.h renaming the port's classes in that build only).
//
// The host side makes each feature with the host's own detector, on an input this program draws. The port side cannot
// detect, so it makes each feature with the port's own initializer, from the numbers the host printed (the fixtures
// below, rounded to two decimals the way every number here is printed). What is compared is what does not depend on
// detection: the class and its superclass, the type string, the members, the copy, the keyed-coding round trip, and a
// fresh instance's answers. Four known differences cannot agree yet, and their lines start with "known:": run.sh pins
// the exact lines of each side in known-host.txt and known-port.txt, so a change on either side is a red run:
//   1. symbolDescriptor: the host's detected QR feature carries a CIQRCodeDescriptor, the port answers nil (no detector).
//   2. the QR round trip: the host's keyed-coding round trip loses the geometry (measured, facts/CoreImage/Features.md);
//      the port's is the identity. The port keeps its lossless layout; the round trip's equal line and geometry lines
//      are the pin.
//   3. the fresh QR feature's messageString: the host raises NSInvalidArgumentException, the port answers nil.
//   4. the text feature's messageString: the host answers nil on CITextFeature, a selector the public header does not
//      declare there; the port does not answer it. Not copied.
// Everything else is a plain equality, and run.sh plants two changes that must turn it red.
//
// Output: one block per feature, the same lines in both builds.

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreText/CoreText.h>

#ifdef PORT
// The initializers the port's own makers use. They are private to CIFeature8.m and CIFeature9.m, so this category
// declares them for the test alone; no caller outside the family may make a feature.
@interface CIRectangleFeature (CharonTest)
- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint;
@end

@interface CIQRCodeFeature (CharonTest)
- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                        messageString:(NSString *)message;
@end

@interface CITextFeature (CharonTest)
- (instancetype)initWithCharonBounds:(CGRect)boundsRect
                              topLeft:(CGPoint)topLeftPoint
                             topRight:(CGPoint)topRightPoint
                           bottomLeft:(CGPoint)bottomLeftPoint
                          bottomRight:(CGPoint)bottomRightPoint
                         subFeatures:(NSArray *)subFeatureList;
@end
#endif

// The class name as the host names it: rename.h gives the port's classes a prefix in the port build only.
static NSString *className(Class c)
{
    NSString *n = NSStringFromClass(c);
#ifdef PORT
    if ([n hasPrefix:@"CharonPort"]) {
        n = [n substringFromIndex:strlen("CharonPort")];
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

// Every member the feature answers, in a fixed order. The same text is compared for the copy and the round trip.
// A line that is a known difference (see the header) starts with "known: ": the geometry of a round trip (roundTrip),
// and messageString of a fresh feature or of a text feature (fresh, or any feature that is not a QR code, since the
// public header declares messageString on CIQRCodeFeature only; the host answers it on CITextFeature as well).
static NSString *dump(id f, BOOL fresh, BOOL roundTrip)
{
    NSMutableString *s = [NSMutableString string];
    BOOL knownMessage = fresh || ![f isKindOfClass:[CIQRCodeFeature class]];
    [s appendFormat:@"class %@ superclass %@\n", className([f class]), className([[f class] superclass])];
    // Typed as CIFeature: an id receiver of "type" meets the Foundation classes that also declare it, and clang refuses.
    CIFeature *feature = f;
    [s appendFormat:@"type %@\n", [feature type] ?: @"(nil)"];
    [s appendFormat:@"%@bounds %@\n", roundTrip ? @"known: " : @"", R([f bounds])];
    if ([f respondsToSelector:@selector(topLeft)]) {
        [s appendFormat:@"%@corners topLeft %@ topRight %@ bottomLeft %@ bottomRight %@\n", roundTrip ? @"known: " : @"",
            P([f topLeft]), P([f topRight]), P([f bottomLeft]), P([f bottomRight])];
    }
    // The host's messageString is read from the descriptor, so a fresh feature without one raises: that is an answer too.
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

// lossyRoundTrip: the feature's round trip is a known difference (the host's loses the geometry), so its equal line and
// its geometry lines are printed as "known:" and pinned by run.sh; every other round-trip line stays a plain comparison.
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
        // The equal flag compares the plain text, so it is the identity check whatever the lines' known prefixes say.
        BOOL equal = [dump(back, NO, NO) isEqualToString:d];
        NSString *b = dump(back, NO, lossyRoundTrip);
        printf("%s%s round trip class %s equal %d\n%s", lossyRoundTrip ? "known: " : "", tag,
               [className([back class]) UTF8String], equal, [b UTF8String]);
    }
    printf("%s fresh\n%s", tag, [dump([[[f class] alloc] init], YES, NO) UTF8String]);
}

#ifndef PORT
// A bitmap of white with the draw block's marks on it, as a CIImage.
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
        // The host's detected values, at two decimals (the host's probe, measured 2026-10-15).
        CIQRCodeFeature *qr = [[CIQRCodeFeature alloc] initWithCharonBounds:CGRectMake(8, 8, 168, 168)
            topLeft:CGPointMake(8, 176) topRight:CGPointMake(176, 176)
            bottomLeft:CGPointMake(8, 8) bottomRight:CGPointMake(176, 8)
            messageString:@"Hello QR"];
        CIRectangleFeature *rect = [[CIRectangleFeature alloc] initWithCharonBounds:CGRectMake(79.34, 59.41, 240.77, 181.02)
            topLeft:CGPointMake(79.34, 240.16) topRight:CGPointMake(319.85, 240.42)
            bottomLeft:CGPointMake(79.59, 59.41) bottomRight:CGPointMake(320.10, 59.67)];
        CITextFeature *text = [[CITextFeature alloc] initWithCharonBounds:CGRectMake(23, 39, 352, 37)
            topLeft:CGPointMake(23, 76) topRight:CGPointMake(375, 76)
            bottomLeft:CGPointMake(23, 39) bottomRight:CGPointMake(375, 39)
            subFeatures:@[]];
#else
        // The QR code of "Hello QR" at 8x, from the host's own generator, and the host's own QR detector.
        CIFilter *gen = [CIFilter filterWithName:@"CIQRCodeGenerator"];
        [gen setValue:[@"Hello QR" dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
        [gen setValue:@"M" forKey:@"inputCorrectionLevel"];
        CIImage *qrImage = [[gen outputImage] imageByApplyingTransform:CGAffineTransformMakeScale(8, 8)];
        CIFeature *qr = [[[CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:nil]
                          featuresInImage:qrImage] firstObject];

        // A filled black rectangle, in a 400 by 300 bitmap, and the host's rectangle detector.
        CIImage *rectImage = drawn(400, 300, ^(CGContextRef cg) {
            CGContextSetRGBFillColor(cg, 0, 0, 0, 1);
            CGContextFillRect(cg, CGRectMake(80, 60, 240, 180));
        });
        CIFeature *rect = [[[CIDetector detectorOfType:CIDetectorTypeRectangle context:nil options:nil]
                            featuresInImage:rectImage] firstObject];

        // A line of Helvetica Bold drawn with CoreText, and the host's text detector with sub-features asked for.
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
