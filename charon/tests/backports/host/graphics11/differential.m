#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import "check.h"

extern CFStringRef charon_host_CGColorSpaceGetName(CGColorSpaceRef);
extern void charon_host_CGPathApplyWithBlock(CGPathRef, CGPathApplyBlock);
extern CGImageByteOrderInfo charon_host_CGImageGetByteOrderInfo(CGImageRef);
extern CGImagePixelFormatInfo charon_host_CGImageGetPixelFormatInfo(CGImageRef);
extern void charon_host_CGPDFArrayApplyBlock(CGPDFArrayRef, bool (^)(size_t, CGPDFObjectRef, void *), void *);
extern void charon_host_CGPDFDictionaryApplyBlock(CGPDFDictionaryRef, bool (^)(const char *, CGPDFObjectRef, void *), void *);
extern CFStringRef charon_host_CVColorPrimariesGetStringForIntegerCodePoint(int);
extern int charon_host_CVColorPrimariesGetIntegerCodePointForString(CFStringRef);
extern CFStringRef charon_host_CVTransferFunctionGetStringForIntegerCodePoint(int);
extern int charon_host_CVTransferFunctionGetIntegerCodePointForString(CFStringRef);
extern CFStringRef charon_host_CVYCbCrMatrixGetStringForIntegerCodePoint(int);
extern int charon_host_CVYCbCrMatrixGetIntegerCodePointForString(CFStringRef);
extern const CFStringRef charon_host_kCVImageBufferTransferFunction_sRGB, charon_host_kCVImageBufferTransferFunction_ITU_R_2100_HLG,
    charon_host_kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ, charon_host_kCVImageBufferTransferFunction_Linear,
    charon_host_kCVImageBufferContentLightLevelInfoKey, charon_host_kCVImageBufferMasteringDisplayColorVolumeKey,
    charon_host_kCVPixelFormatContainsGrayscale, charon_host_kCGColorSpaceGenericLab;

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

static NSString *text(CFStringRef s) { return s ? (__bridge NSString *)s : @"NULL"; }

static void colour_space_names(void)
{
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    unsigned char palette[6] = {0, 0, 0, 255, 255, 255};
    CFStringRef named[] = {kCGColorSpaceGenericRGB, kCGColorSpaceGenericGray, kCGColorSpaceGenericCMYK, kCGColorSpaceSRGB, kCGColorSpaceDisplayP3,
                           kCGColorSpaceGenericRGBLinear, kCGColorSpaceAdobeRGB1998, kCGColorSpaceLinearSRGB, kCGColorSpaceGenericLab};
    NSMutableArray *spaces = [NSMutableArray arrayWithObjects:(__bridge id)rgb, (__bridge_transfer id)CGColorSpaceCreateDeviceGray(), (__bridge_transfer id)CGColorSpaceCreateDeviceCMYK(),
        (__bridge_transfer id)CGColorSpaceCreateIndexed(rgb, 1, palette), (__bridge_transfer id)CGColorSpaceCreatePattern(rgb), (__bridge_transfer id)CGColorSpaceCreatePattern(NULL), nil];
    for (size_t i = 0; i < sizeof named / sizeof *named; i++) {
        CGColorSpaceRef space = CGColorSpaceCreateWithName(named[i]);
        if (space)
            [spaces addObject:(__bridge_transfer id)space];
    }
    for (NSUInteger i = 0; i < spaces.count; i++) {
        CGColorSpaceRef space = (__bridge CGColorSpaceRef)spaces[i];
        NSString *name = [NSString stringWithFormat:@"colourspace.%lu", (unsigned long)i];
        CFStringRef ours = charon_host_CGColorSpaceGetName(space), system = CGColorSpaceGetName(space);
        CHECK_EQUAL(text(ours), text(system), [[name stringByAppendingString:@".name"] UTF8String]);
        CHECK(ours == charon_host_CGColorSpaceGetName(space), [[name stringByAppendingString:@".stable"] UTF8String]);
        CHECK(!ours || CFGetRetainCount(ours) > 0, [[name stringByAppendingString:@".alive"] UTF8String]);
    }
    CHECK(charon_host_CGColorSpaceGetName(NULL) == NULL, "colourspace.null");
    CGColorSpaceRef a = CGColorSpaceCreateDeviceRGB(), b = CGColorSpaceCreateDeviceRGB();
    CHECK(charon_host_CGColorSpaceGetName(a) == charon_host_CGColorSpaceGetName(b), "colourspace.sameNameSameObject");
    CGColorSpaceRelease(a);
    CGColorSpaceRelease(b);
    CGColorSpaceRelease(rgb);
    CHECK_EQUAL(text(charon_host_kCGColorSpaceGenericLab), text(kCGColorSpaceGenericLab), "colourspace.genericLab");
}

static NSString *element_text(const CGPathElement *element)
{
    static const int counts[] = {1, 1, 2, 3, 0};
    NSMutableString *out = [NSMutableString stringWithFormat:@"%d", (int)element->type];
    for (int i = 0; i < counts[element->type]; i++)
        [out appendFormat:@" %.3f,%.3f", element->points[i].x, element->points[i].y];
    return out;
}

static NSArray *elements(CGPathRef path, BOOL ours)
{
    NSMutableArray *out = [NSMutableArray array];
    CGPathApplyBlock block = ^(const CGPathElement *element) { [out addObject:element_text(element)]; };
    if (ours)
        charon_host_CGPathApplyWithBlock(path, block);
    else
        CGPathApplyWithBlock(path, block);
    return out;
}

static void path_apply(void)
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 1, 2);
    CGPathAddLineToPoint(path, NULL, 30, 4);
    CGPathAddQuadCurveToPoint(path, NULL, 5, 6, 7, 8);
    CGPathAddCurveToPoint(path, NULL, 9, 10, 11, 12, 13, 14);
    CGPathCloseSubpath(path);
    CGPathAddRect(path, NULL, CGRectMake(1, 2, 3, 4));
    CGPathAddEllipseInRect(path, NULL, CGRectMake(0, 0, 10, 20));
    CGPathAddArc(path, NULL, 5, 5, 4, 0.3, 2.1, false);
    CGPathAddRoundedRect(path, NULL, CGRectMake(0, 0, 50, 30), 4, 6);
    CHECK_EQUAL(elements(path, YES), elements(path, NO), "path.elements");
    CHECK(elements(path, YES).count > 20, "path.notTrivial");
    CGPathRef empty = CGPathCreateMutable();
    CHECK_EQUAL(elements(empty, YES), elements(empty, NO), "path.empty");
    CGPathRelease(empty);
    charon_host_CGPathApplyWithBlock(NULL, ^(const CGPathElement *element) { charon_check(NO, "path.nullPathCalled", @""); });
    charon_host_CGPathApplyWithBlock(path, NULL);
    CHECK(YES, "path.nullArguments");
    CGPathRelease(path);
}

static void image_info(void)
{
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB(), gray = CGColorSpaceCreateDeviceGray();
    struct { CGColorSpaceRef space; size_t bits; uint32_t info; } cases[] = {
        {rgb, 8, kCGImageAlphaPremultipliedLast}, {rgb, 8, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little},
        {rgb, 8, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Big}, {rgb, 8, kCGImageAlphaNoneSkipLast},
        {rgb, 16, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder16Little}, {rgb, 16, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder16Big},
        {gray, 8, kCGImageAlphaNone}, {gray, 16, kCGImageAlphaNone | kCGBitmapByteOrder16Little},
    };
    for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) {
        CGContextRef context = CGBitmapContextCreate(NULL, 2, 2, cases[i].bits, 0, cases[i].space, (CGBitmapInfo)cases[i].info);
        CGImageRef image = context ? CGBitmapContextCreateImage(context) : NULL;
        NSString *name = [NSString stringWithFormat:@"image.%zu", i];
        if (!image) {
            charon_check(YES, [[name stringByAppendingString:@".unsupported"] UTF8String], @"");
        } else {
            CHECK_EQUAL(@(charon_host_CGImageGetByteOrderInfo(image)), @(CGImageGetByteOrderInfo(image)), [[name stringByAppendingString:@".byteOrder"] UTF8String]);
            CHECK_EQUAL(@(charon_host_CGImageGetPixelFormatInfo(image)), @(CGImageGetPixelFormatInfo(image)), [[name stringByAppendingString:@".pixelFormat"] UTF8String]);
            CHECK_EQUAL(@(charon_host_CGImageGetByteOrderInfo(image)), @(CGImageGetBitmapInfo(image) & kCGBitmapByteOrderMask), [[name stringByAppendingString:@".mask"] UTF8String]);
            CGImageRelease(image);
        }
        CGContextRelease(context);
    }
    uint32_t formats[] = {0x10003, 0x11004, 0x13005, 0x20000, 0x21000, 0x23000, 0x30001, 0x32001, 0x34002, 0x50000};
    size_t bits[] = {5, 5, 5, 5, 5, 5, 10, 10, 10, 8};
    size_t pixel[] = {16, 16, 16, 16, 16, 16, 32, 32, 32, 32};
    unsigned char storage[64] = {0};
    for (size_t i = 0; i < sizeof formats / sizeof *formats; i++) {
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, storage, sizeof storage, NULL);
        CGImageRef image = CGImageCreate(2, 2, bits[i], pixel[i], pixel[i] / 8 * 2, rgb, (CGBitmapInfo)formats[i], provider, NULL, false, kCGRenderingIntentDefault);
        NSString *name = [NSString stringWithFormat:@"image.format.%zu", i];
        if (!image) {
            charon_check(YES, label(@"%@.unsupported", name), @"");
        } else {
            CHECK_EQUAL(@(charon_host_CGImageGetByteOrderInfo(image)), @(CGImageGetByteOrderInfo(image)), label(@"%@.byteOrder", name));
            CHECK_EQUAL(@(charon_host_CGImageGetPixelFormatInfo(image)), @(CGImageGetPixelFormatInfo(image)), label(@"%@.pixelFormat", name));
            CHECK_EQUAL(@(charon_host_CGImageGetPixelFormatInfo(image)), @(CGImageGetBitmapInfo(image) & 0xF0000), label(@"%@.mask", name));
            CGImageRelease(image);
        }
        CGDataProviderRelease(provider);
    }
    CHECK(charon_host_CGImageGetByteOrderInfo(NULL) == 0 && charon_host_CGImageGetPixelFormatInfo(NULL) == 0, "image.null");
    CGColorSpaceRelease(rgb);
    CGColorSpaceRelease(gray);
}

static NSString *object_text(CGPDFObjectRef object)
{
    CGPDFObjectType type = CGPDFObjectGetType(object);
    CGPDFInteger integer;
    CGPDFReal real;
    CGPDFBoolean flag;
    const char *name;
    CGPDFArrayRef array;
    CGPDFDictionaryRef dictionary;
    switch (type) {
    case kCGPDFObjectTypeInteger: return CGPDFObjectGetValue(object, type, &integer) ? [NSString stringWithFormat:@"int %ld", (long)integer] : @"?";
    case kCGPDFObjectTypeReal: return CGPDFObjectGetValue(object, type, &real) ? [NSString stringWithFormat:@"real %.3f", (double)real] : @"?";
    case kCGPDFObjectTypeBoolean: return CGPDFObjectGetValue(object, type, &flag) ? [NSString stringWithFormat:@"bool %d", flag] : @"?";
    case kCGPDFObjectTypeName: return CGPDFObjectGetValue(object, type, &name) ? [NSString stringWithFormat:@"name %s", name] : @"?";
    case kCGPDFObjectTypeArray: return CGPDFObjectGetValue(object, type, &array) ? [NSString stringWithFormat:@"array %zu", CGPDFArrayGetCount(array)] : @"?";
    case kCGPDFObjectTypeDictionary: return CGPDFObjectGetValue(object, type, &dictionary) ? [NSString stringWithFormat:@"dict %zu", CGPDFDictionaryGetCount(dictionary)] : @"?";
    default: return [NSString stringWithFormat:@"type %d", (int)type];
    }
}

static NSArray *array_walk(CGPDFArrayRef array, BOOL ours, size_t stopAfter)
{
    NSMutableArray *out = [NSMutableArray array];
    bool (^block)(size_t, CGPDFObjectRef, void *) = ^bool(size_t index, CGPDFObjectRef value, void *info) {
        [out addObject:[NSString stringWithFormat:@"%zu %@ %p", index, object_text(value), info]];
        return out.count < stopAfter;
    };
    if (ours)
        charon_host_CGPDFArrayApplyBlock(array, block, (void *)0x1234);
    else
        CGPDFArrayApplyBlock(array, block, (void *)0x1234);
    return out;
}

static NSArray *dictionary_walk(CGPDFDictionaryRef dictionary, BOOL ours, size_t stopAfter)
{
    NSMutableArray *out = [NSMutableArray array];
    bool (^block)(const char *, CGPDFObjectRef, void *) = ^bool(const char *key, CGPDFObjectRef value, void *info) {
        [out addObject:[NSString stringWithFormat:@"%s %@ %p", key, object_text(value), info]];
        return out.count < stopAfter;
    };
    if (ours)
        charon_host_CGPDFDictionaryApplyBlock(dictionary, block, (void *)0x5678);
    else
        CGPDFDictionaryApplyBlock(dictionary, block, (void *)0x5678);
    return out;
}

static void pdf_apply(void)
{
    NSMutableData *data = [NSMutableData data];
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
    CGRect box = CGRectMake(0, 0, 200, 100);
    NSDictionary *info = @{(__bridge NSString *)kCGPDFContextTitle: @"t", (__bridge NSString *)kCGPDFContextAuthor: @"a"};
    CGContextRef context = CGPDFContextCreate(consumer, &box, (__bridge CFDictionaryRef)info);
    CGPDFContextBeginPage(context, NULL);
    CGContextFillRect(context, CGRectMake(10, 10, 20, 20));
    CGPDFContextEndPage(context);
    CGPDFContextBeginPage(context, NULL);
    CGPDFContextEndPage(context);
    CGPDFContextClose(context);
    CGContextRelease(context);
    CGDataConsumerRelease(consumer);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    CHECK(document && CGPDFDocumentGetNumberOfPages(document) == 2, "pdf.document");
    CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(document), page = CGPDFPageGetDictionary(CGPDFDocumentGetPage(document, 1));
    CGPDFArrayRef mediaBox = NULL, kids = NULL;
    CGPDFDictionaryRef pages = NULL;
    CGPDFDictionaryGetDictionary(catalog, "Pages", &pages);
    CGPDFDictionaryGetArray(pages, "MediaBox", &mediaBox);
    CGPDFDictionaryGetArray(pages, "Kids", &kids);
    CHECK(mediaBox && kids, "pdf.fixture");
    CHECK_EQUAL(array_walk(mediaBox, YES, 100), array_walk(mediaBox, NO, 100), "pdf.array.all");
    CHECK_EQUAL(array_walk(mediaBox, YES, 2), array_walk(mediaBox, NO, 2), "pdf.array.stop");
    CHECK_EQUAL(array_walk(kids, YES, 100), array_walk(kids, NO, 100), "pdf.array.references");
    CHECK_EQUAL(dictionary_walk(page, YES, 100), dictionary_walk(page, NO, 100), "pdf.dictionary.page");
    CHECK_EQUAL(dictionary_walk(catalog, YES, 100), dictionary_walk(catalog, NO, 100), "pdf.dictionary.catalog");
    CHECK_EQUAL(dictionary_walk(page, YES, 1), dictionary_walk(page, NO, 1), "pdf.dictionary.stop");
    CHECK(dictionary_walk(page, YES, 100).count >= 3, "pdf.dictionary.notTrivial");
    CGPDFDictionaryRef documentInfo = CGPDFDocumentGetInfo(document);
    CHECK_EQUAL(dictionary_walk(documentInfo, YES, 100), dictionary_walk(documentInfo, NO, 100), "pdf.dictionary.info");
    charon_host_CGPDFArrayApplyBlock(NULL, ^bool(size_t i, CGPDFObjectRef v, void *p) { charon_check(NO, "pdf.nullArrayCalled", @""); return true; }, NULL);
    charon_host_CGPDFDictionaryApplyBlock(NULL, ^bool(const char *k, CGPDFObjectRef v, void *p) { charon_check(NO, "pdf.nullDictionaryCalled", @""); return true; }, NULL);
    charon_host_CGPDFArrayApplyBlock(mediaBox, NULL, NULL);
    charon_host_CGPDFDictionaryApplyBlock(page, NULL, NULL);
    CHECK(YES, "pdf.nullArguments");
    CGPDFDocumentRelease(document);
}

typedef CFStringRef (*string_for_code)(int);
typedef int (*code_for_string)(CFStringRef);

static void compare_table(const char *table, string_for_code ours, string_for_code system, code_for_string oursBack, code_for_string systemBack, NSSet<NSNumber *> *tolerated)
{
    NSMutableArray<NSNumber *> *sweep = [NSMutableArray array];
    for (int code = -300; code <= 300; code++)
        [sweep addObject:@(code)];
    for (int code = -70000; code < 70000; code += 977)
        [sweep addObject:@(code)];
    for (NSNumber *number in sweep) {
        int code = number.intValue;
        const char *name = label(@"cv.%s.string.%d", table, code);
        if ([tolerated containsObject:@(code)])
            continue;
        CHECK_EQUAL(text(ours(code)), text(system(code)), name);
        CFStringRef s = system(code);
        if (s)
            CHECK_EQUAL(@(oursBack(s)), @(systemBack(s)), label(@"%s.back", name));
    }
    for (int code = 0; code < 40; code++) {
        if ([tolerated containsObject:@(code)])
            continue;
        CFStringRef s = ours(code);
        if (s)
            CHECK_EQUAL(@(oursBack(s)), @(systemBack(s)), label(@"cv.%s.roundTrip.%d", table, code));
    }
    CFStringRef inputs[] = {NULL, CFSTR(""), CFSTR("junk"), CFSTR("#"), CFSTR("itu_r_709_2"), CFSTR("ITU_R_709_2 "), CFSTR("ColorPrimaries#7"), CFSTR("ColorPrimaries#-4"), CFSTR("ColorPrimaries#"),
        CFSTR("ColorPrimaries#x"), CFSTR("ColorPrimaries#12abc"), CFSTR("ColorPrimaries# 5"), CFSTR("ColorPrimaries#99999999999"), CFSTR("TransferFunction#7"), CFSTR("TransferFunction#5"),
        CFSTR("YCbCrMatrix#14"), CFSTR("YCbCrMatrix#3"), CFSTR("ITU_R_709_2"), CFSTR("EBU_3213"), CFSTR("SMPTE_C"), CFSTR("P22"), CFSTR("DCI_P3"), CFSTR("P3_D65"), CFSTR("ITU_R_2020"),
        CFSTR("ITU_R_601_4"), CFSTR("SMPTE_240M_1995"), CFSTR("Linear"), CFSTR("IEC_sRGB"), CFSTR("SMPTE_ST_2084_PQ"), CFSTR("SMPTE_ST_428_1"), CFSTR("ITU_R_2100_HLG"), CFSTR("UseGamma"), CFSTR("aYCC"),
        (__bridge CFStringRef)@"ITU_R_2100_HLG"};
    for (size_t i = 0; i < sizeof inputs / sizeof *inputs; i++)
        CHECK_EQUAL(@(oursBack(inputs[i])), @(systemBack(inputs[i])), label(@"cv.%s.input.%zu", table, i));
    CHECK_EQUAL(@(oursBack((__bridge CFStringRef)(id)@42)), @(systemBack((__bridge CFStringRef)(id)@42)), label(@"cv.%s.notAString", table));
    CFStringRef first = ours(7777), second = ours(7777);
    CHECK(first && first == second, label(@"cv.%s.unrecognizedStable", table));
    CHECK_EQUAL(text(ours(INT_MAX)), text(system(INT_MAX)), label(@"cv.%s.max", table));
    CHECK_EQUAL(text(ours(INT_MIN)), text(system(INT_MIN)), label(@"cv.%s.min", table));
}

static void code_points(void)
{
    compare_table("primaries", charon_host_CVColorPrimariesGetStringForIntegerCodePoint, CVColorPrimariesGetStringForIntegerCodePoint,
                  charon_host_CVColorPrimariesGetIntegerCodePointForString, CVColorPrimariesGetIntegerCodePointForString, [NSSet set]);
    compare_table("transfer", charon_host_CVTransferFunctionGetStringForIntegerCodePoint, CVTransferFunctionGetStringForIntegerCodePoint,
                  charon_host_CVTransferFunctionGetIntegerCodePointForString, CVTransferFunctionGetIntegerCodePointForString, [NSSet set]);
    compare_table("matrix", charon_host_CVYCbCrMatrixGetStringForIntegerCodePoint, CVYCbCrMatrixGetStringForIntegerCodePoint,
                  charon_host_CVYCbCrMatrixGetIntegerCodePointForString, CVYCbCrMatrixGetIntegerCodePointForString, [NSSet setWithObjects:@14, @15, @248, nil]);
    CHECK_EQUAL(text(charon_host_CVYCbCrMatrixGetStringForIntegerCodePoint(14)), @"YCbCrMatrix#14", "cv.matrix.14.iOS12");
    CHECK_EQUAL(text(charon_host_CVYCbCrMatrixGetStringForIntegerCodePoint(15)), @"YCbCrMatrix#15", "cv.matrix.15.iOS12");
    CHECK_EQUAL(text(charon_host_CVYCbCrMatrixGetStringForIntegerCodePoint(248)), @"YCbCrMatrix#248", "cv.matrix.248.iOS12");
    CHECK_EQUAL(@(charon_host_CVYCbCrMatrixGetIntegerCodePointForString(CFSTR("ITU_R_2100_ICtCp"))), @2, "cv.matrix.ICtCp.iOS12");
    CHECK_EQUAL(@(charon_host_CVYCbCrMatrixGetIntegerCodePointForString(CFSTR("IPT"))), @2, "cv.matrix.IPT.iOS12");
}

static void constants(void)
{
    CHECK_EQUAL(text(charon_host_kCVImageBufferTransferFunction_sRGB), text(kCVImageBufferTransferFunction_sRGB), "constant.sRGB");
    CHECK_EQUAL(text(charon_host_kCVImageBufferTransferFunction_ITU_R_2100_HLG), text(kCVImageBufferTransferFunction_ITU_R_2100_HLG), "constant.HLG");
    CHECK_EQUAL(text(charon_host_kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ), text(kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ), "constant.PQ");
    CHECK_EQUAL(text(charon_host_kCVImageBufferTransferFunction_Linear), text(kCVImageBufferTransferFunction_Linear), "constant.linear");
    CHECK_EQUAL(text(charon_host_kCVImageBufferContentLightLevelInfoKey), text(kCVImageBufferContentLightLevelInfoKey), "constant.lightLevel");
    CHECK_EQUAL(text(charon_host_kCVImageBufferMasteringDisplayColorVolumeKey), text(kCVImageBufferMasteringDisplayColorVolumeKey), "constant.masteringDisplay");
    CHECK_EQUAL(text(charon_host_kCVPixelFormatContainsGrayscale), text(kCVPixelFormatContainsGrayscale), "constant.containsGrayscale");
}

int main(void)
{
    @autoreleasepool {
        colour_space_names();
        path_apply();
        image_info();
        pdf_apply();
        code_points();
        constants();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
