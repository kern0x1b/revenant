#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>

#import "RevenantPDFCopy.h"
#import "RevenantPDFImage.h"
#import "check.h"

static void expect(BOOL ok, const char *name, NSString *seen)
{
    revenant_check(ok != revenant_negative, name, seen);
}

static CGImageRef makeImage(size_t width, size_t height, int kind)
{
    CGColorSpaceRef space = kind == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo info = (CGBitmapInfo)(kind == 1 ? kCGImageAlphaNone : (kind == 2 ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNoneSkipLast));
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, info);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 0.95, 0.9, 0.3, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    for (size_t index = 0; index < 8; index++) {
        CGContextSetRGBFillColor(context, (CGFloat)index / 8, 0.2 + (CGFloat)index / 12, 1 - (CGFloat)index / 9, kind == 2 ? (index % 2 ? 0.35 : 1.0) : 1.0);
        CGContextFillRect(context, CGRectMake(width * index / 8, 0, width / 8, height * (index + 1) / 8));
    }
    CGContextSetRGBStrokeColor(context, 0.1, 0.1, 0.1, 1);
    CGContextSetLineWidth(context, 3);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, width, height);
    CGContextStrokePath(context);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static CGPDFDocumentRef openDocument(NSData *data)
{
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    return document;
}

static NSArray<NSNumber *> *matrixOf(CGPDFPageRef page)
{
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(page);
    CGPDFStreamRef stream = NULL;
    CGPDFArrayRef array = NULL;
    NSMutableData *joined = [NSMutableData data];
    if (CGPDFDictionaryGetStream(dictionary, "Contents", &stream)) {
        CGPDFDataFormat format;
        [joined appendData:(__bridge_transfer NSData *)CGPDFStreamCopyData(stream, &format)];
    } else if (CGPDFDictionaryGetArray(dictionary, "Contents", &array)) {
        for (size_t index = 0; index < CGPDFArrayGetCount(array); index++) {
            if (CGPDFArrayGetStream(array, index, &stream)) {
                CGPDFDataFormat format;
                [joined appendData:(__bridge_transfer NSData *)CGPDFStreamCopyData(stream, &format)];
                [joined appendBytes:" " length:1];
            }
        }
    }
    NSString *text = [[NSString alloc] initWithData:joined encoding:NSASCIIStringEncoding];
    NSArray<NSString *> *tokens = [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSUInteger index = 0; index < tokens.count; index++) {
        if ([tokens[index] isEqualToString:@"cm"] && index >= 6) {
            NSMutableArray *numbers = [NSMutableArray array];
            for (NSUInteger back = index - 6; back < index; back++)
                [numbers addObject:@([tokens[back] doubleValue])];
            return numbers;
        }
    }
    return nil;
}

static BOOL matricesMatch(NSArray<NSNumber *> *a, NSArray<NSNumber *> *b)
{
    if (a.count != 6 || b.count != 6)
        return NO;
    for (NSUInteger index = 0; index < 6; index++) {
        if (fabs(a[index].doubleValue - b[index].doubleValue) > 0.01)
            return NO;
    }
    return YES;
}

static NSData *pixelsOf(NSData *pdf, size_t *width, size_t *height)
{
    CGPDFDocumentRef document = openDocument(pdf);
    CGPDFPageRef page = CGPDFDocumentGetPage(document, 1);
    CGRect box = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
    *width = (size_t)ceil(box.size.width);
    *height = (size_t)ceil(box.size.height);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, *width, *height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, *width, *height));
    CGContextConcatCTM(context, CGPDFPageGetDrawingTransform(page, kCGPDFMediaBox, CGRectMake(0, 0, *width, *height), 0, true));
    CGContextDrawPDFPage(context, page);
    NSData *pixels = [NSData dataWithBytes:CGBitmapContextGetData(context) length:CGBitmapContextGetBytesPerRow(context) * *height];
    CGContextRelease(context);
    CGPDFDocumentRelease(document);
    return pixels;
}

static double meanDifference(NSData *a, NSData *b)
{
    if (a.length != b.length || a.length == 0)
        return 255;
    const uint8_t *x = a.bytes, *y = b.bytes;
    unsigned long long total = 0;
    for (NSUInteger index = 0; index < a.length; index++)
        total += (unsigned)abs((int)x[index] - (int)y[index]);
    return (double)total / (double)a.length;
}

static NSData *hostPDF(CGImageRef image, NSDictionary *options)
{
    NSImage *picture = [[NSImage alloc] initWithCGImage:image size:NSMakeSize(CGImageGetWidth(image), CGImageGetHeight(image))];
    PDFPage *page = options != nil ? [[PDFPage alloc] initWithImage:picture options:options] : [[PDFPage alloc] initWithImage:picture];
    PDFDocument *document = [[PDFDocument alloc] init];
    [document insertPage:page atIndex:0];
    return document.dataRepresentation;
}

static void compareWithHost(const char *label, CGImageRef image, NSDictionary *hostOptions, RevenantPDFImagePage ours, BOOL compareOrigin)
{
    NSData *mine = RevenantPDFImagePageData(image, ours);
    NSData *host = hostPDF(image, hostOptions);
    expect(mine != nil && host != nil, [[NSString stringWithFormat:@"%s: both produce a document", label] UTF8String], @"nil");
    if (mine == nil || host == nil)
        return;
    CGPDFDocumentRef a = openDocument(mine);
    CGPDFDocumentRef b = openDocument(host);
    expect(a != NULL && CGPDFDocumentGetNumberOfPages(a) == 1, [[NSString stringWithFormat:@"%s: the document has one page", label] UTF8String], @"pages");
    if (a == NULL || b == NULL)
        return;
    CGRect mineBox = CGPDFPageGetBoxRect(CGPDFDocumentGetPage(a, 1), kCGPDFMediaBox);
    CGRect hostBox = CGPDFPageGetBoxRect(CGPDFDocumentGetPage(b, 1), kCGPDFMediaBox);
    if (!compareOrigin)
        mineBox.origin = hostBox.origin;
    expect(CGRectEqualToRect(mineBox, hostBox), [[NSString stringWithFormat:@"%s: the media box is the host's", label] UTF8String],
           [NSString stringWithFormat:@"%@ against %@", NSStringFromRect(mineBox), NSStringFromRect(hostBox)]);
    NSArray *mineMatrix = matrixOf(CGPDFDocumentGetPage(a, 1));
    NSArray *hostMatrix = matrixOf(CGPDFDocumentGetPage(b, 1));
    if (compareOrigin) {
        expect(matricesMatch(mineMatrix, hostMatrix), [[NSString stringWithFormat:@"%s: the placement matrix is the host's", label] UTF8String],
               [NSString stringWithFormat:@"%@ against %@", mineMatrix, hostMatrix]);
        size_t w1, h1, w2, h2;
        NSData *p1 = pixelsOf(mine, &w1, &h1);
        NSData *p2 = pixelsOf(host, &w2, &h2);
        double difference = meanDifference(p1, p2);
        expect(w1 == w2 && h1 == h2 && difference < 2.5, [[NSString stringWithFormat:@"%s: the rendered pixels are the host's within JPEG tolerance", label] UTF8String],
               [NSString stringWithFormat:@"%zux%zu against %zux%zu, mean difference %.3f", w1, h1, w2, h2, difference]);
    }
    CGPDFDocumentRelease(a);
    CGPDFDocumentRelease(b);
}

static RevenantPDFImagePage options(BOOL hasBox, CGRect box, NSInteger rotation, BOOL upscale, double quality)
{
    RevenantPDFImagePage page = {hasBox, box, rotation, upscale, quality};
    return page;
}

static NSData *sourceDocument(void)
{
    NSMutableData *data = [NSMutableData data];
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
    CGRect box = CGRectMake(0, 0, 300, 200);
    NSDictionary *auxiliary = @{(__bridge NSString *)kCGPDFContextTitle : @"Source title", (__bridge NSString *)kCGPDFContextAuthor : @"Alice"};
    CGContextRef context = CGPDFContextCreate(consumer, &box, (__bridge CFDictionaryRef)auxiliary);
    CGDataConsumerRelease(consumer);
    CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 18, NULL);
    for (int page = 0; page < 3; page++) {
        CGPDFContextBeginPage(context, NULL);
        NSAttributedString *text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Page %d text", page + 1]
                                                                   attributes:@{(__bridge NSString *)kCTFontAttributeName : (__bridge id)font}];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
        CGContextSetTextPosition(context, 20, 100);
        CTLineDraw(line, context);
        CFRelease(line);
        CGPDFContextSetURLForRect(context, (__bridge CFURLRef)[NSURL URLWithString:[NSString stringWithFormat:@"https://example.com/%d", page]],
                                  CGRectMake(10, 90, 100, 30));
        CGPDFContextEndPage(context);
    }
    CFRelease(font);
    CGPDFContextClose(context);
    CGContextRelease(context);
    return data;
}

static RevenantPDFPageBoxes boxesOf(CGPDFPageRef page, NSInteger rotation)
{
    RevenantPDFPageBoxes boxes;
    boxes.media = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
    boxes.crop = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
    boxes.bleed = CGPDFPageGetBoxRect(page, kCGPDFBleedBox);
    boxes.trim = CGPDFPageGetBoxRect(page, kCGPDFTrimBox);
    boxes.art = CGPDFPageGetBoxRect(page, kCGPDFArtBox);
    boxes.rotation = rotation;
    return boxes;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        CGImageRef color = makeImage(120, 80, 0);
        CGImageRef gray = makeImage(64, 48, 1);
        CGImageRef alpha = makeImage(64, 48, 2);
        CGImageRef small = makeImage(100, 50, 0);

        compareWithHost("a colour image with default options", color, nil, options(NO, CGRectZero, 0, NO, RevenantPDFDefaultImageQuality), YES);
        compareWithHost("a grey image with default options", gray, nil, options(NO, CGRectZero, 0, NO, RevenantPDFDefaultImageQuality), YES);
        compareWithHost("a translucent image with default options", alpha, nil, options(NO, CGRectZero, 0, NO, RevenantPDFDefaultImageQuality), YES);
        for (NSNumber *turn in @[ @90, @180, @270 ]) {
            NSString *label = [NSString stringWithFormat:@"a colour image turned %@ degrees", turn];
            compareWithHost(label.UTF8String, color, @{PDFPageImageInitializationOptionRotation : turn},
                            options(NO, CGRectZero, turn.integerValue, NO, RevenantPDFDefaultImageQuality), YES);
        }
        CGRect letter = CGRectMake(0, 0, 612, 792);
        for (NSNumber *upscale in @[ @NO, @YES ]) {
            for (NSNumber *turn in @[ @0, @90, @180, @270 ]) {
                NSString *label = [NSString stringWithFormat:@"a small image on a letter page, upscale %@, turned %@", upscale, turn];
                compareWithHost(label.UTF8String, small,
                                @{PDFPageImageInitializationOptionMediaBox : [NSValue valueWithRect:letter],
                                  PDFPageImageInitializationOptionUpscaleIfSmaller : upscale, PDFPageImageInitializationOptionRotation : turn},
                                options(YES, letter, turn.integerValue, upscale.boolValue, RevenantPDFDefaultImageQuality), YES);
                label = [NSString stringWithFormat:@"a large image on a letter page, upscale %@, turned %@", upscale, turn];
                compareWithHost(label.UTF8String, color,
                                @{PDFPageImageInitializationOptionMediaBox : [NSValue valueWithRect:CGRectMake(0, 0, 60, 90)],
                                  PDFPageImageInitializationOptionUpscaleIfSmaller : upscale, PDFPageImageInitializationOptionRotation : turn},
                                options(YES, CGRectMake(0, 0, 60, 90), turn.integerValue, upscale.boolValue, RevenantPDFDefaultImageQuality), YES);
            }
        }

        CGRect offset = CGRectMake(10, 20, 300, 400);
        NSData *offsetData = RevenantPDFImagePageData(small, options(YES, offset, 0, YES, 0.5));
        CGPDFDocumentRef offsetDocument = openDocument(offsetData);
        CGRect offsetBox = CGPDFPageGetBoxRect(CGPDFDocumentGetPage(offsetDocument, 1), kCGPDFMediaBox);
        expect(CGRectEqualToRect(offsetBox, offset), "a media box with an origin keeps its origin",
               NSStringFromRect(offsetBox));
        CGPDFDocumentRelease(offsetDocument);

        NSData *low = RevenantPDFImagePageData(color, options(NO, CGRectZero, 0, NO, 0.05));
        NSData *high = RevenantPDFImagePageData(color, options(NO, CGRectZero, 0, NO, 1.0));
        expect(low != nil && high != nil && low.length < high.length, "a lower compression quality makes a smaller document",
               [NSString stringWithFormat:@"%lu against %lu bytes", (unsigned long)low.length, (unsigned long)high.length]);

        NSData *source = sourceDocument();
        CGPDFDocumentRef sourceRef = openDocument(source);
        expect(sourceRef != NULL && CGPDFDocumentGetNumberOfPages(sourceRef) == 3, "the source document has three pages", @"");
        NSData *imageDocument = RevenantPDFImagePageData(color, options(NO, CGRectZero, 0, NO, 0.9));
        CGPDFDocumentRef imageRef = openDocument(imageDocument);
        RevenantPDFPageBoxes reorderedCrop = boxesOf(CGPDFDocumentGetPage(sourceRef, 1), 90);
        reorderedCrop.crop = CGRectMake(10, 10, 100, 100);
        NSDate *created = [NSDate dateWithTimeIntervalSince1970:1700000000];
        NSMutableArray<NSNumber *> *steps = [NSMutableArray array];
        NSData *assembled = RevenantPDFAssemble(
            @[ [RevenantPDFPageEntry entryWithPage:CGPDFDocumentGetPage(sourceRef, 3) boxes:boxesOf(CGPDFDocumentGetPage(sourceRef, 3), 0)],
               [RevenantPDFPageEntry entryWithPage:CGPDFDocumentGetPage(sourceRef, 1) boxes:reorderedCrop],
               [RevenantPDFPageEntry entryWithPage:CGPDFDocumentGetPage(imageRef, 1) boxes:boxesOf(CGPDFDocumentGetPage(imageRef, 1), 0)] ],
            @{@"Title" : @"Assembled é中", @"Author" : @"Bob (a\\b)", @"CreationDate" : created}, nil, nil, 0,
            ^(NSUInteger index, BOOL finished) { [steps addObject:@(index * 2 + finished)]; });
        expect(assembled != nil, "a document is assembled from pages of two documents", @"nil");
        expect([steps isEqualToArray:@[ @0, @1, @2, @3, @4, @5 ]], "each page reports its begin and end in order", steps.description);
        PDFDocument *read = [[PDFDocument alloc] initWithData:assembled];
        expect(read.pageCount == 3, "the assembled document has the three pages", [NSString stringWithFormat:@"%lu", (unsigned long)read.pageCount]);
        expect([[read pageAtIndex:0].string containsString:@"Page 3 text"], "the first page is the source's third", [read pageAtIndex:0].string ?: @"nil");
        expect([[read pageAtIndex:1].string containsString:@"Page 1 text"], "the second page is the source's first", [read pageAtIndex:1].string ?: @"nil");
        expect([[read pageAtIndex:2].string length] == 0 || [[read pageAtIndex:2].string isEqualToString:@""], "the image page has no text", [read pageAtIndex:2].string ?: @"nil");
        expect([read pageAtIndex:1].rotation == 90, "an overridden rotation is written", [NSString stringWithFormat:@"%ld", (long)[read pageAtIndex:1].rotation]);
        expect(CGRectEqualToRect([[read pageAtIndex:1] boundsForBox:kPDFDisplayBoxCropBox], CGRectMake(10, 10, 100, 100)), "an overridden crop box is written",
               NSStringFromRect([[read pageAtIndex:1] boundsForBox:kPDFDisplayBoxCropBox]));
        expect(CGRectEqualToRect([[read pageAtIndex:0] boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 300, 200)), "the media box of a copied page is kept",
               NSStringFromRect([[read pageAtIndex:0] boundsForBox:kPDFDisplayBoxMediaBox]));
        NSArray<PDFAnnotation *> *links = [read pageAtIndex:0].annotations;
        expect(links.count == 1 && [links.firstObject.URL.absoluteString isEqualToString:@"https://example.com/2"], "the link of a copied page is kept with its address",
               [NSString stringWithFormat:@"%lu %@", (unsigned long)links.count, links.firstObject.URL]);
        expect([read.documentAttributes[PDFDocumentTitleAttribute] isEqualToString:@"Assembled é中"], "a title with non-Latin characters survives",
               [read.documentAttributes[PDFDocumentTitleAttribute] description]);
        expect([read.documentAttributes[PDFDocumentAuthorAttribute] isEqualToString:@"Bob (a\\b)"], "parentheses and backslashes in a string survive",
               [read.documentAttributes[PDFDocumentAuthorAttribute] description]);
        expect(fabs([read.documentAttributes[PDFDocumentCreationDateAttribute] timeIntervalSinceDate:created]) < 1, "a creation date survives",
               [read.documentAttributes[PDFDocumentCreationDateAttribute] description]);
        expect(RevenantPDFDateFromString(RevenantPDFDateString(created)).timeIntervalSince1970 == 1700000000, "a date formatted for a document reads back", @"");
        expect([RevenantPDFDateFromString(@"D:20240229235959+05'30'") timeIntervalSince1970] == 1709231399, "a date with an offset reads to the instant",
               [NSString stringWithFormat:@"%f", [RevenantPDFDateFromString(@"D:20240229235959+05'30'") timeIntervalSince1970]]);
        expect([RevenantPDFDateFromString(@"D:2024") timeIntervalSince1970] == 1704067200 && RevenantPDFDateFromString(@"nonsense") == nil, "a date with only a year reads and nonsense does not",
               [NSString stringWithFormat:@"%@", RevenantPDFDateFromString(@"D:2024")]);

        NSData *rewritten = RevenantPDFAssemble(@[ [RevenantPDFPageEntry entryWithPage:CGPDFDocumentGetPage(sourceRef, 2) boxes:boxesOf(CGPDFDocumentGetPage(sourceRef, 2), 0)] ], @{}, nil, nil, 0, nil);
        PDFDocument *reread = [[PDFDocument alloc] initWithData:rewritten];
        expect(reread.pageCount == 1 && [[reread pageAtIndex:0].string containsString:@"Page 2 text"], "a document of one copied page reads back with its text",
               [reread pageAtIndex:0].string ?: @"nil");

        NSData *locked = RevenantPDFAssemble(@[ [RevenantPDFPageEntry entryWithPage:CGPDFDocumentGetPage(sourceRef, 2) boxes:boxesOf(CGPDFDocumentGetPage(sourceRef, 2), 0)] ], @{@"Title" : @"Secret"},
                                             @"owner-secret", @"user-secret", RevenantPDFPermissionBits(PDFAllowsLowQualityPrinting), nil);
        CGPDFDocumentRef lockedRef = openDocument(locked);
        expect(lockedRef != NULL && CGPDFDocumentIsEncrypted(lockedRef) && !CGPDFDocumentIsUnlocked(lockedRef), "an encrypted document is locked until a password is given", @"");
        expect(!CGPDFDocumentUnlockWithPassword(lockedRef, "wrong"), "a wrong password does not unlock", @"");
        expect(CGPDFDocumentUnlockWithPassword(lockedRef, "user-secret") && CGPDFDocumentIsUnlocked(lockedRef), "the user password unlocks", @"");
        expect(!CGPDFDocumentAllowsCopying(lockedRef) && CGPDFDocumentAllowsPrinting(lockedRef), "the permissions are the ones given", @"");
        CGPDFDocumentRef ownerRef = openDocument(locked);
        expect(CGPDFDocumentUnlockWithPassword(ownerRef, "owner-secret") && CGPDFDocumentAllowsCopying(ownerRef), "the owner password unlocks with every permission", @"");
        PDFDocument *hostLocked = [[PDFDocument alloc] initWithData:locked];
        expect(hostLocked.isLocked && [hostLocked unlockWithPassword:@"user-secret"] && [[hostLocked pageAtIndex:0].string containsString:@"Page 2 text"],
               "the host's PDFKit decrypts the page content", [hostLocked pageAtIndex:0].string ?: @"nil");
        expect([hostLocked.documentAttributes[PDFDocumentTitleAttribute] isEqualToString:@"Secret"], "an encrypted string reads back", [hostLocked.documentAttributes[PDFDocumentTitleAttribute] description]);
        CGPDFDocumentRelease(lockedRef);
        CGPDFDocumentRelease(ownerRef);

        RevenantPDFWriter *writer = [[RevenantPDFWriter alloc] init];
        RevenantPDFReference *contents = [writer add:[RevenantPDFStream deflatedStreamWithDictionary:@{} data:[NSMutableData dataWithLength:4096]]];
        RevenantPDFReference *tree = [writer reserve];
        RevenantPDFReference *page = [writer add:@{@"Type" : [RevenantPDFName name:@"Page"], @"Parent" : tree, @"MediaBox" : @[ @0, @0, @10.5, @-0.0000001 ], @"Contents" : contents,
                                                   @"Odd Name#(1)" : [RevenantPDFName name:@"a b/c"], @"Flag" : @YES, @"Nothing" : [NSNull null]}];
        RevenantPDFReference *root = [writer addCatalogWithPages:tree kids:@[ page ]];
        NSData *odd = [writer dataWithRoot:root info:nil];
        CGPDFDocumentRef oddRef = openDocument(odd);
        CGPDFDictionaryRef oddPage = oddRef != NULL ? CGPDFPageGetDictionary(CGPDFDocumentGetPage(oddRef, 1)) : NULL;
        const char *oddName = NULL;
        CGPDFBoolean flag = 0;
        CGPDFStreamRef stream = NULL;
        CGPDFDataFormat format;
        expect(oddPage != NULL && CGPDFDictionaryGetName(oddPage, "Odd Name#(1)", &oddName) && strcmp(oddName, "a b/c") == 0, "names with spaces, delimiters and hashes are escaped and read back", @(oddName ?: "nil"));
        expect(oddPage != NULL && CGPDFDictionaryGetBoolean(oddPage, "Flag", &flag) && flag, "a boolean is written", @"");
        expect(oddPage != NULL && CGPDFDictionaryGetStream(oddPage, "Contents", &stream) && [(__bridge_transfer NSData *)CGPDFStreamCopyData(stream, &format) length] == 4096, "a deflated stream inflates to its length", @"");
        CGPDFDocumentRelease(oddRef);
        CGPDFDocumentRelease(sourceRef);
        CGPDFDocumentRelease(imageRef);
        CGImageRelease(color);
        CGImageRelease(gray);
        CGImageRelease(alpha);
        CGImageRelease(small);
    }
    return revenant_finish();
}
