#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <dlfcn.h>
#import "check.h"

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

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

static void names(void)
{
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB(), gray = CGColorSpaceCreateDeviceGray(), cmyk = CGColorSpaceCreateDeviceCMYK();
    CHECK_EQUAL(text(CGColorSpaceGetName(rgb)), @"kCGColorSpaceDeviceRGB", "device RGB name");
    CHECK_EQUAL(text(CGColorSpaceGetName(gray)), @"kCGColorSpaceDeviceGray", "device gray name");
    CHECK_EQUAL(text(CGColorSpaceGetName(cmyk)), @"kCGColorSpaceDeviceCMYK", "device CMYK name");
    CHECK(CGColorSpaceGetName(rgb) == CGColorSpaceGetName(rgb), "the name is the same object every time");
    CGColorSpaceRef other = CGColorSpaceCreateDeviceRGB();
    CHECK(CGColorSpaceGetName(rgb) == CGColorSpaceGetName(other), "two spaces of one name give one object");
    CHECK(CGColorSpaceGetName(NULL) == NULL, "NULL space");
    CGColorSpaceRef pattern = CGColorSpaceCreatePattern(NULL);
    CHECK_EQUAL(text(CGColorSpaceGetName(pattern)), text(CGColorSpaceGetName(pattern)), "a pattern space answers alike twice");
    CGColorSpaceRelease(pattern);
    CGColorSpaceRef generic = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CHECK(generic != NULL, "a generic RGB space is made by name");
#ifndef CHARON_HOST
    CHECK_EQUAL(text(CGColorSpaceGetName(generic)), @"kCGColorSpaceDeviceRGB", "generic RGB is named as the device space on iOS 6");
    CGColorSpaceRef lab = CGColorSpaceCreateWithName(kCGColorSpaceGenericLab);
    CHECK(lab == NULL, "a Lab space cannot be made by name");
    CHECK_EQUAL(image_of((void *)&kCGColorSpaceGenericLab), @"libGraphicsBackports.dylib", "the Lab constant comes from the backports");
    CHECK_EQUAL(image_of((void *)&CGColorSpaceGetName), @"libGraphicsBackports.dylib", "CGColorSpaceGetName comes from the backports");
#endif
    CHECK_EQUAL(text(kCGColorSpaceGenericLab), @"kCGColorSpaceGenericLab", "the Lab constant");
#ifndef CHARON_HOST
    {
        static const struct { const CFStringRef *constant; NSString *text; } named[] = {
        {&kCGColorSpaceACESCGLinear, @"kCGColorSpaceACESCGLinear"},
        {&kCGColorSpaceDCIP3, @"kCGColorSpaceDCIP3"},
        {&kCGColorSpaceGenericXYZ, @"kCGColorSpaceGenericXYZ"},
        {&kCGColorSpaceITUR_2020, @"kCGColorSpaceITUR_2020"},
        {&kCGColorSpaceITUR_709, @"kCGColorSpaceITUR_709"},
        {&kCGColorSpaceROMMRGB, @"kCGColorSpaceROMMRGB"},
        {&kCGColorSpaceDisplayP3, @"kCGColorSpaceDisplayP3"},
        {&kCGColorSpaceExtendedGray, @"kCGColorSpaceExtendedGray"},
        {&kCGColorSpaceExtendedLinearGray, @"kCGColorSpaceExtendedLinearGray"},
        {&kCGColorSpaceExtendedLinearSRGB, @"kCGColorSpaceExtendedLinearSRGB"},
        {&kCGColorSpaceExtendedSRGB, @"kCGColorSpaceExtendedSRGB"},
        {&kCGColorSpaceLinearGray, @"kCGColorSpaceLinearGray"},
        {&kCGColorSpaceLinearSRGB, @"kCGColorSpaceLinearSRGB"},
        {&kCGColorSpaceDisplayP3_PQ, @"kCGColorSpaceDisplayP3_PQ"},
        {&kCGColorSpaceITUR_2020_PQ, @"kCGColorSpaceITUR_2100_PQ"},
        {&kCGColorSpaceExtendedDisplayP3, @"kCGColorSpaceExtendedDisplayP3"},
        {&kCGColorSpaceExtendedITUR_2020, @"kCGColorSpaceExtendedITUR_2020"},
        {&kCGColorSpaceITUR_2100_HLG, @"kCGColorSpaceITUR_2100_HLG"},
        {&kCGColorSpaceITUR_2100_PQ, @"kCGColorSpaceITUR_2100_PQ"},
        {&kCGColorSpaceLinearDisplayP3, @"kCGColorSpaceLinearDisplayP3"},
        {&kCGColorSpaceLinearITUR_2020, @"kCGColorSpaceLinearITUR_2020"},
        {&kCGColorSpaceITUR_2020_sRGBGamma, @"kCGColorSpaceITUR_2020_sRGBGamma"},
        {&kCGColorSpaceITUR_709_HLG, @"kCGColorSpaceITUR_709_HLG"},
        {&kCGColorSpaceITUR_709_PQ, @"kCGColorSpaceITUR_709_PQ"},
        {&kCGColorSpaceExtendedLinearDisplayP3, @"kCGColorSpaceExtendedLinearDisplayP3"},
        {&kCGColorSpaceExtendedLinearITUR_2020, @"kCGColorSpaceExtendedLinearITUR_2020"},
        {&kCGColorSpaceDisplayP3_HLG, @"kCGColorSpaceDisplayP3_HLG"},
        {&kCGColorSpaceITUR_2020_HLG, @"kCGColorSpaceITUR_2100_HLG"},
        {&kCGColorSpaceDisplayP3_PQ_EOTF, @"kCGColorSpaceDisplayP3_PQ"},
        {&kCGColorSpaceITUR_2020_PQ_EOTF, @"kCGColorSpaceITUR_2020_PQ_EOTF"},
        };
        int carried = 0, unmade = 0, valued = 0;
        for (size_t i = 0; i < sizeof named / sizeof named[0]; i++) {
            carried += [image_of((void *)named[i].constant) isEqualToString:@"libGraphicsBackports.dylib"];
            valued += [text(*named[i].constant) isEqualToString:named[i].text];
            CGColorSpaceRef made = CGColorSpaceCreateWithName(*named[i].constant);
            unmade += made == NULL;
            CGColorSpaceRelease(made);
        }
        CHECK(carried == 30, "the 30 colour space names the release lacks come from the backports");
        CHECK(valued == 30, "each has its measured string: the host's, or 12.0's for the one it first exports");
        CHECK(unmade == 30, "and CGColorSpaceCreateWithName makes no space of any of them");
    }
#endif
    CGColorSpaceRelease(generic);
    CGColorSpaceRelease(rgb);
    CGColorSpaceRelease(gray);
    CGColorSpaceRelease(cmyk);
    CGColorSpaceRelease(other);
}

static NSString *element_text(const CGPathElement *element)
{
    static const int counts[] = {1, 1, 2, 3, 0};
    NSMutableString *out = [NSMutableString stringWithFormat:@"%d", (int)element->type];
    for (int i = 0; i < counts[element->type]; i++)
        [out appendFormat:@" %.2f,%.2f", element->points[i].x, element->points[i].y];
    return out;
}

static void applier(void *info, const CGPathElement *element)
{
    [(__bridge NSMutableArray *)info addObject:element_text(element)];
}

static void path_walk(void)
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 1, 2);
    CGPathAddLineToPoint(path, NULL, 30, 4);
    CGPathAddQuadCurveToPoint(path, NULL, 5, 6, 7, 8);
    CGPathAddCurveToPoint(path, NULL, 9, 10, 11, 12, 13, 14);
    CGPathCloseSubpath(path);
    CGPathAddRect(path, NULL, CGRectMake(1, 2, 3, 4));
    CGPathAddEllipseInRect(path, NULL, CGRectMake(0, 0, 10, 20));
    NSMutableArray *expected = [NSMutableArray array], *seen = [NSMutableArray array];
    CGPathApply(path, (__bridge void *)expected, applier);
    CGPathApplyWithBlock(path, ^(const CGPathElement *element) { [seen addObject:element_text(element)]; });
    CHECK_EQUAL(seen, expected, "the block sees the elements CGPathApply sees, in order");
    CHECK(seen.count > 10, "the path has elements");
    CHECK_EQUAL(seen.firstObject, @"0 1.00,2.00", "the first element is the move");
    CHECK_EQUAL(seen[1], @"1 30.00,4.00", "the second element is the line");
    CHECK_EQUAL(seen[2], @"2 5.00,6.00 7.00,8.00", "a quad curve carries two points");
    CHECK_EQUAL(seen[3], @"3 9.00,10.00 11.00,12.00 13.00,14.00", "a curve carries three points");
    CHECK_EQUAL(seen[4], @"4", "a close carries none");
#ifndef CHARON_HOST
    CGPathApplyWithBlock(NULL, ^(const CGPathElement *element) { charon_check(NO, "a NULL path calls the block", @""); });
    CGPathApplyWithBlock(path, NULL);
    CHECK(YES, "a NULL path and a NULL block are ignored");
#endif
    CGPathRelease(path);
#ifndef CHARON_HOST
    CHECK_EQUAL(image_of((void *)&CGPathApplyWithBlock), @"libGraphicsBackports.dylib", "CGPathApplyWithBlock comes from the backports");
#endif
}

static void image_bits(void)
{
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    struct { uint32_t info; size_t bits; size_t pixel; uint32_t order; uint32_t format; } cases[] = {
        {kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, 8, 32, 0x2000, 0},
        {kCGImageAlphaPremultipliedLast, 8, 32, 0, 0},
        {kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Big, 8, 32, 0x4000, 0},
        {0x10003, 5, 16, 0, 0x10000},
        {0x11004, 5, 16, 0x1000, 0x10000},
        {0x20000, 5, 16, 0, 0x20000},
        {0x32001, 10, 32, 0x2000, 0x30000},
    };
    unsigned char storage[64] = {0};
    for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) {
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, storage, sizeof storage, NULL);
        CGImageRef image = CGImageCreate(2, 2, cases[i].bits, cases[i].pixel, cases[i].pixel / 8 * 2, rgb, (CGBitmapInfo)cases[i].info, provider, NULL, false, kCGRenderingIntentDefault);
        NSString *name = [NSString stringWithFormat:@"image %zu", i];
        if (image) {
            CHECK_EQUAL(@(CGImageGetByteOrderInfo(image)), @(cases[i].order), [name stringByAppendingString:@" byte order"].UTF8String);
            CHECK_EQUAL(@(CGImageGetPixelFormatInfo(image)), @(cases[i].format), [name stringByAppendingString:@" pixel format"].UTF8String);
            CGImageRelease(image);
        } else {
            NSLog(@"%@ is not made here", name);
            CHECK(i >= 3, [name stringByAppendingString:@" must be made"].UTF8String);
        }
        CGDataProviderRelease(provider);
    }
    CHECK(CGImageGetByteOrderInfo(NULL) == 0 && CGImageGetPixelFormatInfo(NULL) == 0, "a NULL image has neither");
    CGColorSpaceRelease(rgb);
#ifndef CHARON_HOST
    CHECK_EQUAL(image_of((void *)&CGImageGetByteOrderInfo), @"libGraphicsBackports.dylib", "CGImageGetByteOrderInfo comes from the backports");
    CHECK_EQUAL(image_of((void *)&CGImageGetPixelFormatInfo), @"libGraphicsBackports.dylib", "CGImageGetPixelFormatInfo comes from the backports");
#endif
}

static NSString *object_text(CGPDFObjectRef object)
{
    CGPDFObjectType type = CGPDFObjectGetType(object);
    CGPDFInteger integer;
    CGPDFReal real;
    const char *name;
    if (type == kCGPDFObjectTypeInteger && CGPDFObjectGetValue(object, type, &integer))
        return [NSString stringWithFormat:@"int %ld", (long)integer];
    if (type == kCGPDFObjectTypeReal && CGPDFObjectGetValue(object, type, &real))
        return [NSString stringWithFormat:@"real %.2f", (double)real];
    if (type == kCGPDFObjectTypeName && CGPDFObjectGetValue(object, type, &name))
        return [NSString stringWithFormat:@"name %s", name];
    return [NSString stringWithFormat:@"type %d", (int)type];
}

static void dictionary_entry(const char *key, CGPDFObjectRef value, void *info)
{
    [(__bridge NSMutableArray *)info addObject:[NSString stringWithFormat:@"%s %@", key, object_text(value)]];
}

static void pdf_walk(void)
{
    NSMutableData *data = [NSMutableData data];
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
    CGRect box = CGRectMake(0, 0, 200, 100);
    CGContextRef context = CGPDFContextCreate(consumer, &box, NULL);
    CGPDFContextBeginPage(context, NULL);
    CGContextFillRect(context, CGRectMake(10, 10, 20, 20));
    CGPDFContextEndPage(context);
    CGPDFContextClose(context);
    CGContextRelease(context);
    CGDataConsumerRelease(consumer);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    CHECK(document != NULL, "the document is made");
    CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(document), pages = NULL;
    CGPDFDictionaryGetDictionary(catalog, "Pages", &pages);
    CGPDFArrayRef mediaBox = NULL;
    CGPDFDictionaryGetArray(pages, "MediaBox", &mediaBox);
    CHECK(mediaBox != NULL && CGPDFArrayGetCount(mediaBox) == 4, "the media box has four numbers");
    NSMutableArray *expected = [NSMutableArray array], *seen = [NSMutableArray array];
    for (size_t i = 0; i < CGPDFArrayGetCount(mediaBox); i++) {
        CGPDFObjectRef object;
        if (CGPDFArrayGetObject(mediaBox, i, &object))
            [expected addObject:[NSString stringWithFormat:@"%zu %@ 0x1234", i, object_text(object)]];
    }
    CGPDFArrayApplyBlock(mediaBox, ^bool(size_t index, CGPDFObjectRef value, void *info) {
        [seen addObject:[NSString stringWithFormat:@"%zu %@ %p", index, object_text(value), info]];
        return true;
    }, (void *)0x1234);
    CHECK_EQUAL(seen, expected, "the array walk gives each element with the info pointer");
    CHECK_EQUAL(seen.lastObject, @"3 int 100 0x1234", "the last element of the media box");
    NSMutableArray *stopped = [NSMutableArray array];
    CGPDFArrayApplyBlock(mediaBox, ^bool(size_t index, CGPDFObjectRef value, void *info) { [stopped addObject:@(index)]; return index < 1; }, NULL);
    CHECK_EQUAL(stopped, (@[@0, @1]), "the array walk stops on false");
    NSMutableArray *dictionaryExpected = [NSMutableArray array], *dictionarySeen = [NSMutableArray array];
    CGPDFDictionaryApplyFunction(pages, dictionary_entry, (__bridge void *)dictionaryExpected);
    CGPDFDictionaryApplyBlock(pages, ^bool(const char *key, CGPDFObjectRef value, void *info) {
        [dictionarySeen addObject:[NSString stringWithFormat:@"%s %@", key, object_text(value)]];
        return true;
    }, NULL);
    CHECK_EQUAL(dictionarySeen, dictionaryExpected, "the dictionary walk gives the entries the release's walk gives");
    CHECK(dictionarySeen.count >= 3, "the dictionary has entries");
    NSMutableArray *firstOnly = [NSMutableArray array];
    CGPDFDictionaryApplyBlock(pages, ^bool(const char *key, CGPDFObjectRef value, void *info) { [firstOnly addObject:@(key)]; return false; }, NULL);
    CHECK_EQUAL(@(firstOnly.count), @1, "the dictionary walk stops on false");
#ifndef CHARON_HOST
    CGPDFArrayApplyBlock(NULL, ^bool(size_t index, CGPDFObjectRef value, void *info) { charon_check(NO, "a NULL array calls the block", @""); return true; }, NULL);
    CGPDFDictionaryApplyBlock(NULL, ^bool(const char *key, CGPDFObjectRef value, void *info) { charon_check(NO, "a NULL dictionary calls the block", @""); return true; }, NULL);
    CGPDFArrayApplyBlock(mediaBox, NULL, NULL);
    CGPDFDictionaryApplyBlock(pages, NULL, NULL);
    CHECK(YES, "a NULL array, a NULL dictionary and a NULL block are ignored");
#endif
    CGPDFDocumentRelease(document);
#ifndef CHARON_HOST
    CHECK_EQUAL(image_of((void *)&CGPDFArrayApplyBlock), @"libGraphicsBackports.dylib", "CGPDFArrayApplyBlock comes from the backports");
    CHECK_EQUAL(image_of((void *)&CGPDFDictionaryApplyBlock), @"libGraphicsBackports.dylib", "CGPDFDictionaryApplyBlock comes from the backports");
#endif
}

static void code_points(void)
{
    static const struct { int code; const char *name; } primaries[] = {{1, "ITU_R_709_2"}, {5, "EBU_3213"}, {6, "SMPTE_C"}, {9, "ITU_R_2020"}, {11, "DCI_P3"}, {12, "P3_D65"}, {22, "P22"}};
    static const struct { int code; const char *name; } transfer[] = {{1, "ITU_R_709_2"}, {6, "ITU_R_709_2"}, {14, "ITU_R_709_2"}, {15, "ITU_R_709_2"}, {7, "SMPTE_240M_1995"}, {8, "Linear"},
                                                                       {13, "IEC_sRGB"}, {16, "SMPTE_ST_2084_PQ"}, {17, "SMPTE_ST_428_1"}, {18, "ITU_R_2100_HLG"}};
    static const struct { int code; const char *name; } matrix[] = {{1, "ITU_R_709_2"}, {6, "ITU_R_601_4"}, {7, "SMPTE_240M_1995"}, {9, "ITU_R_2020"}};
    for (size_t i = 0; i < sizeof primaries / sizeof *primaries; i++)
        CHECK_EQUAL(text(CVColorPrimariesGetStringForIntegerCodePoint(primaries[i].code)), @(primaries[i].name), label(@"primaries code %d", primaries[i].code));
    for (size_t i = 0; i < sizeof transfer / sizeof *transfer; i++)
        CHECK_EQUAL(text(CVTransferFunctionGetStringForIntegerCodePoint(transfer[i].code)), @(transfer[i].name), label(@"transfer code %d", transfer[i].code));
    for (size_t i = 0; i < sizeof matrix / sizeof *matrix; i++)
        CHECK_EQUAL(text(CVYCbCrMatrixGetStringForIntegerCodePoint(matrix[i].code)), @(matrix[i].name), label(@"matrix code %d", matrix[i].code));
    CHECK(CVColorPrimariesGetStringForIntegerCodePoint(0) == NULL && CVColorPrimariesGetStringForIntegerCodePoint(2) == NULL, "primaries 0 and 2 are unspecified");
    CHECK(CVTransferFunctionGetStringForIntegerCodePoint(0) == NULL && CVTransferFunctionGetStringForIntegerCodePoint(2) == NULL, "transfer 0 and 2 are unspecified");
    CHECK(CVYCbCrMatrixGetStringForIntegerCodePoint(0) == NULL && CVYCbCrMatrixGetStringForIntegerCodePoint(2) == NULL, "matrix 0 and 2 are unspecified");
    CHECK_EQUAL(text(CVColorPrimariesGetStringForIntegerCodePoint(7)), @"ColorPrimaries#7", "an unnamed primaries code");
    CHECK_EQUAL(text(CVColorPrimariesGetStringForIntegerCodePoint(-1)), @"ColorPrimaries#-1", "a negative primaries code");
    CHECK_EQUAL(text(CVTransferFunctionGetStringForIntegerCodePoint(5)), @"TransferFunction#5", "an unnamed transfer code");
    CHECK_EQUAL(text(CVTransferFunctionGetStringForIntegerCodePoint(19)), @"TransferFunction#19", "the transfer code after the last");
    CHECK_EQUAL(text(CVYCbCrMatrixGetStringForIntegerCodePoint(3)), @"YCbCrMatrix#3", "an unnamed matrix code");
    CHECK_EQUAL(text(CVColorPrimariesGetStringForIntegerCodePoint(INT_MAX)), @"ColorPrimaries#2147483647", "the largest code");
    CHECK_EQUAL(text(CVColorPrimariesGetStringForIntegerCodePoint(INT_MIN)), @"ColorPrimaries#-2147483648", "the smallest code");
    CHECK(CVColorPrimariesGetStringForIntegerCodePoint(7777) == CVColorPrimariesGetStringForIntegerCodePoint(7777), "an unnamed code gives one object");
#ifndef CHARON_HOST
    CHECK_EQUAL(text(CVYCbCrMatrixGetStringForIntegerCodePoint(14)), @"YCbCrMatrix#14", "iOS 12 names no matrix 14");
    CHECK_EQUAL(text(CVYCbCrMatrixGetStringForIntegerCodePoint(15)), @"YCbCrMatrix#15", "iOS 12 names no matrix 15");
    CHECK_EQUAL(text(CVYCbCrMatrixGetStringForIntegerCodePoint(248)), @"YCbCrMatrix#248", "iOS 12 names no matrix 248");
#endif
    for (size_t i = 0; i < sizeof primaries / sizeof *primaries; i++)
        CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString((__bridge CFStringRef)@(primaries[i].name))), @(primaries[i].code), label(@"primaries name %s", primaries[i].name));
    for (size_t i = 0; i < sizeof matrix / sizeof *matrix; i++)
        CHECK_EQUAL(@(CVYCbCrMatrixGetIntegerCodePointForString((__bridge CFStringRef)@(matrix[i].name))), @(matrix[i].code), label(@"matrix name %s", matrix[i].name));
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("ITU_R_709_2"))), @1, "transfer 709");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("ITU_R_2020"))), @1, "transfer 2020 is 1");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("UseGamma"))), @2, "transfer gamma is 2");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("SMPTE_240M_1995"))), @7, "transfer 240M");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("Linear"))), @8, "transfer linear");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("IEC_sRGB"))), @13, "transfer sRGB");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("SMPTE_ST_2084_PQ"))), @16, "transfer PQ");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("SMPTE_ST_428_1"))), @17, "transfer 428.1");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("ITU_R_2100_HLG"))), @18, "transfer HLG");
    CHECK_EQUAL(@(CVYCbCrMatrixGetIntegerCodePointForString(CFSTR("DCI_P3"))), @2, "a matrix name that is no code");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(NULL)), @2, "NULL is unspecified");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(CFSTR("junk"))), @2, "a string of no code is unspecified");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString((__bridge CFStringRef)(id)@42)), @2, "a number is unspecified");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(CFSTR("ColorPrimaries#7"))), @7, "an unnamed code is read back");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(CFSTR("ColorPrimaries#-4"))), @-4, "a negative code is read back");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(CFSTR("ColorPrimaries#12abc"))), @12, "digits are read and the rest is dropped");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(CFSTR("ColorPrimaries#x"))), @0, "no digits read as 0");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(CFSTR("ColorPrimaries#"))), @0, "an empty number reads as 0");
    CHECK_EQUAL(@(CVColorPrimariesGetIntegerCodePointForString(CFSTR("TransferFunction#7"))), @2, "another table's prefix is not read");
    CHECK_EQUAL(@(CVTransferFunctionGetIntegerCodePointForString(CFSTR("TransferFunction#5"))), @5, "an unnamed transfer code is read back");
    CHECK_EQUAL(@(CVYCbCrMatrixGetIntegerCodePointForString(CFSTR("YCbCrMatrix#14"))), @14, "an unnamed matrix code is read back");
    CHECK_EQUAL(text(CVColorPrimariesGetStringForIntegerCodePoint(CVColorPrimariesGetIntegerCodePointForString(CFSTR("ColorPrimaries#7")))), @"ColorPrimaries#7", "a name goes round");
#ifndef CHARON_HOST
    CHECK_EQUAL(image_of((void *)&CVColorPrimariesGetStringForIntegerCodePoint), @"libGraphicsBackports.dylib", "the primaries function comes from the backports");
    CHECK_EQUAL(image_of((void *)&CVTransferFunctionGetIntegerCodePointForString), @"libGraphicsBackports.dylib", "the transfer function comes from the backports");
    CHECK_EQUAL(image_of((void *)&CVYCbCrMatrixGetStringForIntegerCodePoint), @"libGraphicsBackports.dylib", "the matrix function comes from the backports");
    CHECK_EQUAL(image_of((void *)&kCVImageBufferTransferFunction_ITU_R_2100_HLG), @"libGraphicsBackports.dylib", "the HLG constant comes from the backports");
#endif
    CHECK_EQUAL(text(kCVImageBufferTransferFunction_sRGB), @"IEC_sRGB", "constant sRGB");
    CHECK_EQUAL(text(kCVImageBufferTransferFunction_ITU_R_2100_HLG), @"ITU_R_2100_HLG", "constant HLG");
    CHECK_EQUAL(text(kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ), @"SMPTE_ST_2084_PQ", "constant PQ");
    CHECK_EQUAL(text(kCVImageBufferTransferFunction_Linear), @"Linear", "constant linear");
    CHECK_EQUAL(text(kCVImageBufferContentLightLevelInfoKey), @"ContentLightLevelInfo", "constant light level");
    CHECK_EQUAL(text(kCVImageBufferMasteringDisplayColorVolumeKey), @"MasteringDisplayColorVolume", "constant mastering display");
    CHECK_EQUAL(text(kCVPixelFormatContainsGrayscale), @"ContainsGrayscale", "constant grayscale");
    CHECK_EQUAL(text(kCVImageBufferTransferFunction_ITU_R_709_2), @"ITU_R_709_2", "the release's own 709 transfer constant");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        names();
        path_walk();
        image_bits();
        pdf_walk();
        code_points();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
