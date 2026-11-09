#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import "RevenantPDFKit.h"
#import "check.h"

#define PDFPageImageInitializationOptionMediaBox @"PDFPageImageInitializationOptionMediaBox"
#define PDFPageImageInitializationOptionRotation @"PDFPageImageInitializationOptionRotation"
#define PDFPageImageInitializationOptionUpscaleIfSmaller @"PDFPageImageInitializationOptionUpscaleIfSmaller"
#define PDFPageImageInitializationOptionCompressionQuality @"PDFPageImageInitializationOptionCompressionQuality"
#define PDFDocumentPageIndexKey @"PDFDocumentPageIndex"
#define PDFDocumentDidBeginWriteNotification @"PDFDidBeginDocumentWrite"
#define PDFDocumentDidEndWriteNotification @"PDFDidEndDocumentWrite"
#define PDFDocumentDidBeginPageWriteNotification @"PDFDidBeginPageWrite"
#define PDFDocumentDidEndPageWriteNotification @"PDFDidEndPageWrite"
#define PDFDocumentTitleAttribute @"Title"
#define PDFDocumentAuthorAttribute @"Author"
#define PDFDocumentKeywordsAttribute @"Keywords"
#define PDFDocumentCreationDateAttribute @"CreationDate"
#define PDFDocumentModificationDateAttribute @"ModDate"
#define PDFDocumentOwnerPasswordOption @"PDFDocumentOwnerPasswordOption"
#define PDFDocumentUserPasswordOption @"PDFDocumentUserPasswordOption"

static void expect(BOOL ok, const char *name, NSString *seen)
{
    revenant_check(ok != revenant_negative, name, seen);
}

static UIImage *quadrantImage(size_t width, size_t height)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    CGFloat colours[4][3] = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {1, 1, 0}};
    for (int index = 0; index < 4; index++) {
        CGContextSetRGBFillColor(context, colours[index][0], colours[index][1], colours[index][2], 1);
        CGContextFillRect(context, CGRectMake((index % 2) * width / 2, (1 - index / 2) * height / 2, width / 2, height / 2));
    }
    CGImageRef cg = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return image;
}

static UIImage *noiseImage(size_t width, size_t height)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    uint8_t *pixels = CGBitmapContextGetData(context);
    size_t rowBytes = CGBitmapContextGetBytesPerRow(context);
    uint32_t seed = 12345;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            seed = seed * 1664525u + 1013904223u;
            uint8_t *p = pixels + y * rowBytes + x * 4;
            p[0] = (uint8_t)((x * 255 / width) ^ (seed >> 28));
            p[1] = (uint8_t)((y * 255 / height) ^ (seed >> 27));
            p[2] = (uint8_t)(((x + y) * 255 / (width + height)) ^ (seed >> 26));
            p[3] = 255;
        }
    }
    CGImageRef cg = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return image;
}

static UIImage *translucentImage(void)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 40, 40, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 1, 0, 0, 0.5);
    CGContextFillRect(context, CGRectMake(0, 0, 40, 40));
    CGImageRef cg = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return image;
}

static BOOL colourNear(const uint8_t *pixel, int red, int green, int blue, int tolerance)
{
    return abs(pixel[0] - red) <= tolerance && abs(pixel[1] - green) <= tolerance && abs(pixel[2] - blue) <= tolerance;
}

typedef struct {
    uint8_t topLeft[3];
    uint8_t topRight[3];
    uint8_t bottomLeft[3];
    uint8_t bottomRight[3];
} Quadrants;

static BOOL renderQuadrants(CGPDFPageRef page, Quadrants *out)
{
    CGRect box = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
    size_t width = (size_t)ceil(box.size.width), height = (size_t)ceil(box.size.height);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    if (context == NULL)
        return NO;
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextConcatCTM(context, CGPDFPageGetDrawingTransform(page, kCGPDFCropBox, CGRectMake(0, 0, width, height), 0, true));
    CGContextDrawPDFPage(context, page);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    size_t rowBytes = CGBitmapContextGetBytesPerRow(context);
    size_t xs[2] = {width / 4, width * 3 / 4};
    size_t ys[2] = {height / 4, height * 3 / 4};
    for (int row = 0; row < 2; row++) {
        for (int column = 0; column < 2; column++) {
            const uint8_t *source = pixels + (height - 1 - ys[row]) * rowBytes + xs[column] * 4;
            uint8_t *target = row == 0 ? (column == 0 ? out->bottomLeft : out->bottomRight) : (column == 0 ? out->topLeft : out->topRight);
            memcpy(target, source, 3);
        }
    }
    CGContextRelease(context);
    return YES;
}

static BOOL renderSamples(CGPDFPageRef page, const double points[][2], int count, uint8_t (*out)[3])
{
    CGRect box = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
    size_t width = (size_t)ceil(box.size.width), height = (size_t)ceil(box.size.height);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    if (context == NULL)
        return NO;
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextConcatCTM(context, CGPDFPageGetDrawingTransform(page, kCGPDFCropBox, CGRectMake(0, 0, width, height), 0, true));
    CGContextDrawPDFPage(context, page);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    size_t rowBytes = CGBitmapContextGetBytesPerRow(context);
    for (int index = 0; index < count; index++) {
        size_t column = (size_t)(points[index][0] * width), row = (size_t)(points[index][1] * height);
        memcpy(out[index], pixels + row * rowBytes + column * 4, 3);
    }
    CGContextRelease(context);
    return YES;
}

static CGPDFDocumentRef openDocument(NSData *data)
{
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    return document;
}

static BOOL quadrantsAre(NSData *data, const int colours[4][3], NSString **seen)
{
    CGPDFDocumentRef document = openDocument(data);
    CGPDFPageRef page = document != NULL ? CGPDFDocumentGetPage(document, 1) : NULL;
    Quadrants quadrants;
    BOOL rendered = page != NULL && renderQuadrants(page, &quadrants);
    BOOL match = rendered && colourNear(quadrants.topLeft, colours[0][0], colours[0][1], colours[0][2], 40) &&
                 colourNear(quadrants.topRight, colours[1][0], colours[1][1], colours[1][2], 40) &&
                 colourNear(quadrants.bottomLeft, colours[2][0], colours[2][1], colours[2][2], 40) &&
                 colourNear(quadrants.bottomRight, colours[3][0], colours[3][1], colours[3][2], 40);
    if (rendered)
        *seen = [NSString stringWithFormat:@"TL %d %d %d TR %d %d %d BL %d %d %d BR %d %d %d", quadrants.topLeft[0], quadrants.topLeft[1], quadrants.topLeft[2],
                                           quadrants.topRight[0], quadrants.topRight[1], quadrants.topRight[2], quadrants.bottomLeft[0], quadrants.bottomLeft[1],
                                           quadrants.bottomLeft[2], quadrants.bottomRight[0], quadrants.bottomRight[1], quadrants.bottomRight[2]];
    else
        *seen = @"no page";
    if (document != NULL)
        CGPDFDocumentRelease(document);
    return match;
}

static double milliseconds(uint64_t start, uint64_t end)
{
    mach_timebase_info_data_t base;
    mach_timebase_info(&base);
    return (double)(end - start) * base.numer / base.denom / 1e6;
}

@interface Writes : NSObject
@property (nonatomic) NSInteger began;
@property (nonatomic) NSInteger ended;
@property (nonatomic) NSInteger pageBegan;
@property (nonatomic) NSInteger pageEnded;
@property (nonatomic) NSMutableArray *indexes;
@end

@implementation Writes

- (instancetype)init
{
    self = [super init];
    _indexes = [NSMutableArray array];
    return self;
}

- (void)begin:(NSNotification *)n { self.began++; }
- (void)end:(NSNotification *)n { self.ended++; }
- (void)pageBegin:(NSNotification *)n { self.pageBegan++; [self.indexes addObject:n.userInfo[PDFDocumentPageIndexKey]]; }
- (void)pageEnd:(NSNotification *)n { self.pageEnded++; }

@end

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        NSString *seen = nil;
        UIImage *quadrants = quadrantImage(200, 100);

        PDFPage *plain = [[PDFPage alloc] initWithImage:quadrants];
        expect(plain != nil && plain.pageRef != NULL && plain.document == nil, "an image page has a page and no document", @"");
        expect(CGRectEqualToRect(plain.mediaBox, CGRectMake(0, 0, 200, 100)), "the media box is the image size", NSStringFromCGRect(plain.mediaBox));
        int identity[4][3] = {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 0}};
        expect(quadrantsAre(plain.dataRepresentation, identity, &seen), "the four quadrants of the image keep their place", seen);

        int turned90[4][3] = {{0, 255, 0}, {255, 255, 0}, {255, 0, 0}, {0, 0, 255}};
        PDFPage *rotated = [[PDFPage alloc] initWithImage:quadrants options:@{PDFPageImageInitializationOptionRotation: @90}];
        expect(CGRectEqualToRect(rotated.mediaBox, CGRectMake(0, 0, 100, 200)), "a quarter turn swaps the box", NSStringFromCGRect(rotated.mediaBox));
        expect(quadrantsAre(rotated.dataRepresentation, turned90, &seen), "a quarter turn puts the top right quadrant top left", seen);
        int turned180[4][3] = {{255, 255, 0}, {0, 0, 255}, {0, 255, 0}, {255, 0, 0}};
        PDFPage *half = [[PDFPage alloc] initWithImage:quadrants options:@{PDFPageImageInitializationOptionRotation: @180}];
        expect(quadrantsAre(half.dataRepresentation, turned180, &seen), "a half turn reverses the quadrants", seen);
        int turned270[4][3] = {{0, 0, 255}, {255, 0, 0}, {255, 255, 0}, {0, 255, 0}};
        PDFPage *threeQuarters = [[PDFPage alloc] initWithImage:quadrants options:@{PDFPageImageInitializationOptionRotation: @270}];
        expect(quadrantsAre(threeQuarters.dataRepresentation, turned270, &seen), "three quarter turns put the bottom left quadrant top left", seen);

        PDFPage *boxed = [[PDFPage alloc] initWithImage:quadrants options:@{PDFPageImageInitializationOptionMediaBox: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 300)]}];
        expect(CGRectEqualToRect(boxed.mediaBox, CGRectMake(0, 0, 300, 300)), "the media box option sets the page box", NSStringFromCGRect(boxed.mediaBox));
        CGPDFDocumentRef boxedDocument = openDocument(boxed.dataRepresentation);
        const double boxedPoints[2][2] = {{0.1, 0.5}, {0.4, 0.4}};
        uint8_t boxedColours[2][3];
        BOOL boxedRendered = renderSamples(CGPDFDocumentGetPage(boxedDocument, 1), boxedPoints, 2, boxedColours);
        expect(boxedRendered && colourNear(boxedColours[0], 255, 255, 255, 8) && colourNear(boxedColours[1], 255, 0, 0, 24), "a smaller image is not enlarged inside a larger box", boxedRendered ? [NSString stringWithFormat:@"%d,%d,%d and %d,%d,%d", boxedColours[0][0], boxedColours[0][1], boxedColours[0][2], boxedColours[1][0], boxedColours[1][1], boxedColours[1][2]] : @"no render");
        CGPDFDocumentRelease(boxedDocument);
        PDFPage *upscaled = [[PDFPage alloc] initWithImage:quadrants options:@{PDFPageImageInitializationOptionMediaBox: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 300)], PDFPageImageInitializationOptionUpscaleIfSmaller: @YES}];
        CGPDFDocumentRef upscaledDocument = openDocument(upscaled.dataRepresentation);
        const double upscaledPoints[4][2] = {{0.1, 0.4}, {0.9, 0.6}, {0.5, 0.1}, {0.5, 0.9}};
        uint8_t upscaledColours[4][3];
        BOOL upscaledRendered = renderSamples(CGPDFDocumentGetPage(upscaledDocument, 1), upscaledPoints, 4, upscaledColours);
        expect(upscaledRendered && colourNear(upscaledColours[0], 255, 0, 0, 24) && colourNear(upscaledColours[1], 255, 255, 0, 24) && colourNear(upscaledColours[2], 255, 255, 255, 8) && colourNear(upscaledColours[3], 255, 255, 255, 8), "an upscaled image fills the width and leaves bands above and below",
            upscaledRendered ? [NSString stringWithFormat:@"%d,%d,%d %d,%d,%d %d,%d,%d %d,%d,%d", upscaledColours[0][0], upscaledColours[0][1], upscaledColours[0][2], upscaledColours[1][0], upscaledColours[1][1], upscaledColours[1][2], upscaledColours[2][0], upscaledColours[2][1], upscaledColours[2][2], upscaledColours[3][0], upscaledColours[3][1], upscaledColours[3][2]] : @"no render");
        CGPDFDocumentRelease(upscaledDocument);

        BOOL raised = NO;
        @try {
            (void)[[PDFPage alloc] initWithImage:quadrants options:@{PDFPageImageInitializationOptionRotation: @45}];
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        expect(raised, "a rotation that is not a multiple of 90 raises", @"");
        raised = NO;
        @try {
            (void)[[PDFPage alloc] initWithImage:quadrants options:@{PDFPageImageInitializationOptionCompressionQuality: @1.5}];
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        expect(raised, "a quality above one raises", @"");

        UIImage *noise = noiseImage(256, 256);
        NSUInteger low = [[[PDFPage alloc] initWithImage:noise options:@{PDFPageImageInitializationOptionCompressionQuality: @0.1}] dataRepresentation].length;
        NSUInteger high = [[[PDFPage alloc] initWithImage:noise options:@{PDFPageImageInitializationOptionCompressionQuality: @1.0}] dataRepresentation].length;
        expect(low > 0 && high > low * 2, "the compression quality sets the size of the picture", [NSString stringWithFormat:@"%lu against %lu", (unsigned long)low, (unsigned long)high]);

        PDFPage *glass = [[PDFPage alloc] initWithImage:translucentImage()];
        CGPDFDocumentRef glassDocument = openDocument(glass.dataRepresentation);
        Quadrants glassColours;
        BOOL glassRendered = renderQuadrants(CGPDFDocumentGetPage(glassDocument, 1), &glassColours);
        expect(glassRendered && colourNear(glassColours.topLeft, 255, 128, 128, 12), "a half transparent red lies pink on the white page", glassRendered ? [NSString stringWithFormat:@"%d %d %d", glassColours.topLeft[0], glassColours.topLeft[1], glassColours.topLeft[2]] : @"no page");
        CGPDFDocumentRelease(glassDocument);

        PDFDocument *document = [[PDFDocument alloc] init];
        expect(document != nil && document.pageCount == 0 && [document dataRepresentation] == nil, "an empty document has no data", @"");
        PDFPage *first = [[PDFPage alloc] initWithImage:quadrantImage(200, 100)];
        PDFPage *second = [[PDFPage alloc] initWithImage:quadrantImage(120, 160)];
        PDFPage *third = [[PDFPage alloc] initWithImage:quadrantImage(90, 90)];
        [document insertPage:first atIndex:0];
        [document insertPage:second atIndex:1];
        [document insertPage:third atIndex:2];
        expect(document.pageCount == 3 && first.document == document && [document indexForPage:third] == 2 && third.pageIndex == 2, "three pages are inserted in order", [NSString stringWithFormat:@"%lu", (unsigned long)document.pageCount]);
        raised = NO;
        @try {
            [document insertPage:[[PDFPage alloc] init] atIndex:9];
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSRangeException];
        }
        expect(raised && document.pageCount == 3, "an index beyond the count raises", @"");
        [document removePageAtIndex:42];
        expect(document.pageCount == 3, "an index beyond the count is ignored by remove", @"");

        Writes *writes = [[Writes alloc] init];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:writes selector:@selector(begin:) name:PDFDocumentDidBeginWriteNotification object:document];
        [center addObserver:writes selector:@selector(end:) name:PDFDocumentDidEndWriteNotification object:document];
        [center addObserver:writes selector:@selector(pageBegin:) name:PDFDocumentDidBeginPageWriteNotification object:document];
        [center addObserver:writes selector:@selector(pageEnd:) name:PDFDocumentDidEndPageWriteNotification object:document];
        uint64_t start = mach_absolute_time();
        NSData *data = [document dataRepresentation];
        double elapsed = milliseconds(start, mach_absolute_time());
        printf("measured: three small pages written in %.1f ms, %lu bytes\n", elapsed, (unsigned long)data.length);
        expect(writes.began == 1 && writes.ended == 1 && writes.pageBegan == 3 && writes.pageEnded == 3 && [writes.indexes isEqualToArray:(@[@0, @1, @2])], "a write posts one begin and end and one pair per page", [NSString stringWithFormat:@"%ld %ld %ld %ld", (long)writes.began, (long)writes.ended, (long)writes.pageBegan, (long)writes.pageEnded]);
        [center removeObserver:writes];

        PDFDocument *reread = [[PDFDocument alloc] initWithData:data];
        expect(reread != nil && reread.pageCount == 3, "the written document opens with three pages", [NSString stringWithFormat:@"%lu", (unsigned long)reread.pageCount]);
        expect(CGRectEqualToRect([reread pageAtIndex:0].mediaBox, CGRectMake(0, 0, 200, 100)) && CGRectEqualToRect([reread pageAtIndex:1].mediaBox, CGRectMake(0, 0, 120, 160)) && CGRectEqualToRect([reread pageAtIndex:2].mediaBox, CGRectMake(0, 0, 90, 90)), "each page keeps its box", @"");
        expect(reread.majorVersion == 1 && reread.minorVersion >= 3, "the header version is read", [NSString stringWithFormat:@"%ld.%ld", (long)reread.majorVersion, (long)reread.minorVersion]);
        expect(reread.documentRef != NULL, "a read document has a CGPDFDocument", @"");

        [document exchangePageAtIndex:0 withPageAtIndex:2];
        expect([document pageAtIndex:0] == third && [document pageAtIndex:2] == first && first.pageIndex == 2 && third.pageIndex == 0, "two pages are exchanged", @"");
        PDFDocument *exchanged = [[PDFDocument alloc] initWithData:[document dataRepresentation]];
        expect(CGRectEqualToRect([exchanged pageAtIndex:0].mediaBox, CGRectMake(0, 0, 90, 90)) && CGRectEqualToRect([exchanged pageAtIndex:2].mediaBox, CGRectMake(0, 0, 200, 100)), "the exchange is written", @"");
        [document removePageAtIndex:1];
        expect(document.pageCount == 2 && second.document == nil && first.pageIndex == 1, "a removed page leaves the document", @"");
        CGPDFDocumentRef snapshot = document.documentRef;
        expect(snapshot != NULL && CGPDFDocumentGetNumberOfPages(snapshot) == 2, "documentRef follows the edits", @"");

        PDFDocument *copy = [document copy];
        [copy removePageAtIndex:0];
        expect(copy.pageCount == 1 && document.pageCount == 2 && [copy pageAtIndex:0].document == copy && [copy pageAtIndex:0] != [document pageAtIndex:1], "a copy edits on its own", @"");

        PDFPage *edited = [[PDFPage alloc] initWithImage:quadrantImage(200, 100)];
        [edited setBounds:CGRectMake(0, 0, 50, 40) forBox:kCGPDFCropBox];
        expect(CGRectEqualToRect([edited boundsForBox:kCGPDFCropBox], CGRectMake(0, 0, 50, 40)) && CGRectEqualToRect(edited.mediaBox, CGRectMake(0, 0, 200, 100)), "a crop box is set apart from the media box", NSStringFromCGRect([edited boundsForBox:kCGPDFCropBox]));
        edited.rotation = 90;
        PDFDocument *editedReread = [[PDFDocument alloc] initWithData:edited.dataRepresentation];
        expect(editedReread.pageCount == 1 && [editedReread pageAtIndex:0].rotation == 90 && CGRectEqualToRect([editedReread pageAtIndex:0].cropBox, CGRectMake(0, 0, 50, 40)), "a crop box and a rotation are written", [NSString stringWithFormat:@"%ld %@", (long)[editedReread pageAtIndex:0].rotation, NSStringFromCGRect([editedReread pageAtIndex:0].cropBox)]);
        raised = NO;
        @try {
            edited.rotation = 45;
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        expect(raised, "a page rotation that is not a multiple of 90 raises", @"");

        PDFDocument *shared = [[PDFDocument alloc] init];
        PDFPage *heavy = [[PDFPage alloc] initWithImage:noise options:@{PDFPageImageInitializationOptionCompressionQuality: @1.0}];
        [shared insertPage:heavy atIndex:0];
        NSUInteger once = [shared dataRepresentation].length;
        [shared insertPage:heavy atIndex:1];
        NSUInteger twice = [shared dataRepresentation].length;
        expect(shared.pageCount == 2 && twice < once * 1.3, "one picture on two pages is written once", [NSString stringWithFormat:@"%lu against %lu", (unsigned long)once, (unsigned long)twice]);

        PDFDocument *attributed = [[PDFDocument alloc] init];
        [attributed insertPage:[[PDFPage alloc] init] atIndex:0];
        NSDate *created = [NSDate dateWithTimeIntervalSince1970:1000000000];
        attributed.documentAttributes = @{PDFDocumentTitleAttribute: @"Scan", PDFDocumentAuthorAttribute: @"Tester", PDFDocumentKeywordsAttribute: @[@"alpha", @"beta"], PDFDocumentCreationDateAttribute: created};
        PDFDocument *attributedReread = [[PDFDocument alloc] initWithData:[attributed dataRepresentation]];
        NSDictionary *attributes = attributedReread.documentAttributes;
        expect([attributes[PDFDocumentTitleAttribute] isEqual:@"Scan"] && [attributes[PDFDocumentAuthorAttribute] isEqual:@"Tester"], "the title and the author are written", [attributes description]);
        expect([attributes[PDFDocumentKeywordsAttribute] isEqual:(@[@"alpha", @"beta"])], "the keywords come back as an array", [attributes[PDFDocumentKeywordsAttribute] description] ?: @"nil");
        expect([attributes[PDFDocumentCreationDateAttribute] isKindOfClass:[NSDate class]] && fabs([attributes[PDFDocumentCreationDateAttribute] timeIntervalSinceDate:created]) < 2, "the creation date is a date and survives", [attributes[PDFDocumentCreationDateAttribute] description] ?: @"nil");
        expect([attributes[PDFDocumentModificationDateAttribute] isKindOfClass:[NSDate class]], "the modification date is written", @"");

        NSData *locked = [document dataRepresentationWithOptions:@{PDFDocumentOwnerPasswordOption: @"owner", PDFDocumentUserPasswordOption: @"reader"}];
        PDFDocument *lockedDocument = [[PDFDocument alloc] initWithData:locked];
        expect(lockedDocument != nil && lockedDocument.isEncrypted && lockedDocument.isLocked, "a password makes a locked document", @"");
        expect(![lockedDocument unlockWithPassword:@"wrong"] && lockedDocument.isLocked, "a wrong password does not unlock", @"");
        expect([lockedDocument unlockWithPassword:@"reader"] && !lockedDocument.isLocked && lockedDocument.pageCount == 2, "the user password unlocks both pages", [NSString stringWithFormat:@"%lu", (unsigned long)lockedDocument.pageCount]);
        PDFDocument *ownerDocument = [[PDFDocument alloc] initWithData:locked];
        expect([ownerDocument unlockWithPassword:@"owner"] && ownerDocument.pageCount == 2, "the owner password unlocks too", @"");
        Quadrants lockedColours;
        BOOL lockedRendered = renderQuadrants([lockedDocument pageAtIndex:0].pageRef, &lockedColours);
        expect(lockedRendered && colourNear(lockedColours.topLeft, 255, 0, 0, 40), "an encrypted page draws its decrypted picture", lockedRendered ? [NSString stringWithFormat:@"%d %d %d", lockedColours.topLeft[0], lockedColours.topLeft[1], lockedColours.topLeft[2]] : @"no page");

        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pdfwriter-probe.pdf"];
        expect([document writeToFile:path] && [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]].pageCount == 2, "a document is written to a file and read back", @"");
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        expect(![[[PDFDocument alloc] init] writeToFile:path], "an empty document is not written", @"");

        start = mach_absolute_time();
        PDFDocument *scan = [[PDFDocument alloc] init];
        for (NSUInteger index = 0; index < 4; index++) {
            PDFPage *page = [[PDFPage alloc] initWithImage:noiseImage(1536, 2048)];
            [scan insertPage:page atIndex:index];
        }
        double built = milliseconds(start, mach_absolute_time());
        start = mach_absolute_time();
        NSData *scanData = [scan dataRepresentation];
        double written = milliseconds(start, mach_absolute_time());
        printf("measured: four 1536 by 2048 pages: pages built in %.0f ms, document written in %.0f ms, %lu bytes\n", built, written, (unsigned long)scanData.length);
        PDFDocument *scanReread = [[PDFDocument alloc] initWithData:scanData];
        expect(scanReread.pageCount == 4 && CGRectEqualToRect([scanReread pageAtIndex:3].mediaBox, CGRectMake(0, 0, 1536, 2048)), "a four page scan of full size round trips", [NSString stringWithFormat:@"%lu", (unsigned long)scanReread.pageCount]);

        start = mach_absolute_time();
        CGPDFDocumentRef preview = openDocument(scanData);
        CGPDFPageRef previewPage = CGPDFDocumentGetPage(preview, 1);
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(NULL, 256, 256, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
        CGColorSpaceRelease(space);
        CGContextConcatCTM(context, CGPDFPageGetDrawingTransform(previewPage, kCGPDFCropBox, CGRectMake(0, 0, 256, 256), 0, true));
        CGContextDrawPDFPage(context, previewPage);
        double drawn = milliseconds(start, mach_absolute_time());
        printf("measured: the first page drawn at 256 by 256 in %.0f ms\n", drawn);
        const uint8_t *previewPixels = CGBitmapContextGetData(context);
        size_t previewRow = CGBitmapContextGetBytesPerRow(context);
        const uint8_t *middle = previewPixels + 128 * previewRow + 96 * 4;
        expect(middle[0] != 255 || middle[1] != 255 || middle[2] != 255, "the preview of the first page is not blank", @"");
        CGContextRelease(context);
        CGPDFDocumentRelease(preview);
    }
    return revenant_finish();
}
