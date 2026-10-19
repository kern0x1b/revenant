#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Differential test for the PDF renderer family of iOS 10.0. Both renderers draw the same
// documents in one process - the system's, and the backport's whose classes run.sh renamed with a
// CharonHost prefix - and what each produced is compared page by page: how many pages, each
// page's media box, and each page's pixels rasterised at 1x. The documents' bytes are never
// compared: a PDF carries a creation date and an identifier, so two documents that say the same
// thing never match byte for byte.
//
// The drawing block is written once and given to both renderers. It is typed on `id` rather than on
// either context class - the two class names are the only thing the rename touches - and cast at the
// call, which is the only way one block can serve both.

static int checks;
static int failures;

static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static void same(long ours, long theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: ours %ld, UIKit %ld", what, ours, theirs);
}

static void same_rect(CGRect ours, CGRect theirs, NSString *what)
{
    checks++;
    if (!CGRectEqualToRect(ours, theirs))
        fail(@"%@: ours %g %g %g %g, UIKit %g %g %g %g", what,
             ours.origin.x, ours.origin.y, ours.size.width, ours.size.height,
             theirs.origin.x, theirs.origin.y, theirs.size.width, theirs.size.height);
}

static Class ours_of(NSString *name)
{
    Class mine = NSClassFromString([@"CharonHost" stringByAppendingString:name]);
    if (!mine)
        fail(@"the backport defines no %@", name);
    return mine;
}

/* What a document says about itself, read back out of the bytes with CoreGraphics - the same reader
   for both. `ink` is the sum of the page's grey bytes at 1x: one number, and any difference in what
   was drawn moves it. */
typedef struct {
    int pages;
    CGRect boxes[4];
    unsigned long ink[4];
} Shape;

static CGPDFDocumentRef document_of(NSData *data, const char *who)
{
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGPDFDocumentRef document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    if (!document)
        fail(@"%s answered %lu bytes CoreGraphics cannot read as a PDF", who, (unsigned long)data.length);
    return document;
}

static unsigned long ink_of(CGPDFDocumentRef document, CGPDFPageRef page)
{
    CGRect box = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
    size_t width = (size_t)ceil(box.size.width), height = (size_t)ceil(box.size.height);
    if (!width || !height)
        return 0;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
    uint8_t *pixels = calloc(height, width);
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width, space, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(space);
    CGContextDrawPDFPage(context, page);
    CGContextRelease(context);
    unsigned long sum = 0;
    for (size_t at = 0; at < width * height; at++)
        sum += pixels[at];
    free(pixels);
    return sum;
}

static Shape shape_of(NSData *data, const char *who)
{
    Shape shape = { 0, { CGRectZero, CGRectZero, CGRectZero, CGRectZero }, { 0, 0, 0, 0 } };
    CGPDFDocumentRef document = document_of(data, who);
    if (!document)
        return shape;
    shape.pages = (int)CGPDFDocumentGetNumberOfPages(document);
    for (int index = 0; index < shape.pages && index < 4; index++) {
        CGPDFPageRef page = CGPDFDocumentGetPage(document, index + 1);
        shape.boxes[index] = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
        shape.ink[index] = ink_of(document, page);
    }
    CGPDFDocumentRelease(document);
    return shape;
}

static void same_shape(NSData *ours, NSData *theirs, NSString *what)
{
    Shape mine = shape_of(ours, "the backport");
    Shape other = shape_of(theirs, "UIKit");
    same(mine.pages, other.pages, [what stringByAppendingString:@" page count"]);
    for (int index = 0; index < mine.pages && index < other.pages && index < 4; index++)
        same_rect(mine.boxes[index], other.boxes[index],
                  ([what stringByAppendingFormat:@" page %d media box", index + 1]));
    for (int index = 0; index < mine.pages && index < other.pages && index < 4; index++)
        same((long)mine.ink[index], (long)other.ink[index],
             ([what stringByAppendingFormat:@" page %d pixels", index + 1]));
}

/* One document, drawn by `renderer` with `format`, both bounds and metadata given by the caller. The
   block is what the caller wants drawn; `log` collects what the block saw of its own context, so a
   renderer that runs no block is told apart from one that runs an empty one. */
static NSData *draw(Class renderer, Class formatClass, CGRect bounds, NSDictionary *documentInfo,
                    void (^body)(id context, NSMutableArray *log), NSMutableArray *log)
{
    id format = [[formatClass alloc] init];
    [format setValue:[NSValue valueWithCGRect:bounds] forKey:@"bounds"];
    if (documentInfo)
        [format setValue:documentInfo forKey:@"documentInfo"];
    id instance = [[renderer alloc] initWithBounds:bounds format:format];
    void (^actions)(id) = ^(id context) { body(context, log); };
    return [instance PDFDataWithActions:(UIGraphicsPDFDrawingActions)actions];
}

int main(void)
{
    @autoreleasepool {
        Class oursRenderer = ours_of(@"UIGraphicsPDFRenderer");
        Class oursFormat = ours_of(@"UIGraphicsPDFRendererFormat");
        Class oursContext = ours_of(@"UIGraphicsPDFRendererContext");

        /* The rename moves the whole chain, so the backport's base classes are the renamed ones:
           what is checked here is that each class extends the port's own base and not the system's. */
        Class base = ours_of(@"UIGraphicsRenderer");
        Class baseContext = ours_of(@"UIGraphicsRendererContext");
        Class baseFormat = ours_of(@"UIGraphicsRendererFormat");
        checks++;
        if (![oursRenderer isSubclassOfClass:base] ||
            ![oursContext isSubclassOfClass:baseContext] ||
            ![oursFormat isSubclassOfClass:baseFormat]) {
            fail(@"a backported class does not extend the backport's own base class");
            return 1;
        }
        printf("ok  the three backported classes extend the backport's own bases\n");

        /* One page, and what the block is told it is drawing on. */
        NSMutableArray *ourLog = [NSMutableArray array], *theirLog = [NSMutableArray array];
        void (^onePage)(id, NSMutableArray *) = ^(id context, NSMutableArray *log) {
            [log addObject:[NSValue valueWithCGRect:[context pdfContextBounds]]];
            [context beginPage];
            [log addObject:[NSValue valueWithCGRect:[context pdfContextBounds]]];
            CGContextSetRGBFillColor([context CGContext], 1, 0, 0, 1);
            [context fillRect:CGRectMake(0, 0, 40, 20)];
        };
        NSData *ourPDF = draw(oursRenderer, oursFormat, CGRectMake(0, 0, 100, 50), nil,
                              onePage, ourLog);
        NSData *theirPDF = draw([UIGraphicsPDFRenderer class], [UIGraphicsPDFRendererFormat class],
                                CGRectMake(0, 0, 100, 50), nil, onePage, theirLog);
        same((long)ourLog.count, (long)theirLog.count, @"the block ran on both");
        if (ourLog.count == 2 && theirLog.count == 2) {
            same_rect([ourLog[0] CGRectValue], [theirLog[0] CGRectValue],
                      @"pdfContextBounds before the first page");
            same_rect([ourLog[1] CGRectValue], [theirLog[1] CGRectValue],
                      @"pdfContextBounds after -beginPage");
            same_rect(CGRectMake(0, 0, 100, 50), [ourLog[0] CGRectValue],
                      @"the block is handed the renderer's own bounds");
            same_rect(CGRectMake(0, 0, 100, 50), [ourLog[1] CGRectValue],
                      @"the page is the document's own rectangle");
        }
        same_shape(ourPDF, theirPDF, @"one page");

        /* Two pages of different sizes, begun by the caller rather than by the renderer. */
        NSMutableArray *ourTwoLog = [NSMutableArray array], *theirTwoLog = [NSMutableArray array];
        void (^twoPages)(id, NSMutableArray *) = ^(id context, NSMutableArray *log) {
            [log addObject:@"first"];
            CGRect first = CGRectMake(0, 0, 60, 30);
            [context beginPageWithBounds:first
                               pageInfo:@{ (__bridge NSString *)kCGPDFContextMediaBox:
                                               [NSData dataWithBytes:&first length:sizeof(CGRect)] }];
            CGContextSetRGBFillColor([context CGContext], 0, 0, 1, 1);
            [context fillRect:CGRectMake(0, 0, 60, 30)];
            [log addObject:[NSValue valueWithCGRect:[context pdfContextBounds]]];
            NSDictionary *none = nil;
            [context beginPageWithBounds:CGRectMake(0, 0, 20, 10) pageInfo:none];
            [log addObject:[NSValue valueWithCGRect:[context pdfContextBounds]]];
            CGContextSetRGBFillColor([context CGContext], 0, 1, 0, 1);
            [context fillRect:CGRectMake(0, 0, 20, 10)];
        };
        NSData *ourTwo = draw(oursRenderer, oursFormat, CGRectMake(0, 0, 40, 20), nil,
                              twoPages, ourTwoLog);
        NSData *theirTwo = draw([UIGraphicsPDFRenderer class], [UIGraphicsPDFRendererFormat class],
                                CGRectMake(0, 0, 40, 20), nil, twoPages, theirTwoLog);
        same((long)ourTwoLog.count, (long)theirTwoLog.count, @"the two-page block ran on both");
        same_shape(ourTwo, theirTwo, @"two pages");

        /* The document's own dictionary reaches CoreGraphics. Of its keys only the media box is
           visible from outside, so that is what this compares: a document whose format carries a
           77x33 media box has to come out 77x33 on both. */
        /* The key is the VALUE of kCGPDFContextMediaBox and not its name, which is the same trap as
           every other CFString key in this tree: the dictionary is written with the symbol itself. */
        CGRect box = CGRectMake(0, 0, 77, 33);
        NSString *mediaBoxKey = (__bridge NSString *)kCGPDFContextMediaBox;
        NSDictionary *info = @{ mediaBoxKey: [NSData dataWithBytes:&box length:sizeof(CGRect)] };
        printf("     the key is %s\n", mediaBoxKey.UTF8String);
        NSMutableArray *ignore = [NSMutableArray array];
        /* No bounds of its own, so the media box in the dictionary is what decides: with bounds the
           argument to CGPDFContextCreate wins and the dictionary's box is not consulted at all. */
        NSData *ourInfo = draw(oursRenderer, oursFormat, CGRectZero, info,
                               ^(id context, NSMutableArray *log) { [context beginPage]; }, ignore);
        NSData *theirInfo = draw([UIGraphicsPDFRenderer class], [UIGraphicsPDFRendererFormat class],
                                 CGRectZero, info,
                                 ^(id context, NSMutableArray *log) { [context beginPage]; }, ignore);
        /* iOS 10.0's +prepareCGContext:withRendererContext: reads the media box out of the format's
           dictionary over the format's bounds (0x20985ab8 of the armv7s cache of 10.3.4:
           -objectForKey: with _kCGPDFContextMediaBox, then -getBytes:length:0x10), so a format with
           no bounds of its own comes out at the box its dictionary names - and the host answers the
           same, which is only visible because the key is the symbol's VALUE and not its name: with
           the name the lookup misses on both sides and both answer US Letter, and the comparison
           below would pass without ever having read the dictionary. */
        Shape ourInfoShape = shape_of(ourInfo, "the backport");
        same_rect(box, ourInfoShape.boxes[0],
                  @"with no bounds of its own the dictionary's media box is the page that comes out");
        same_shape(ourInfo, theirInfo, @"a document whose format carries a media box");

        /* A renderer of no size is not a renderer that draws nothing: the document it makes is a
           page of US Letter, which is the constant the release carries and the one this port reads
           out of it. Both sides are asked the same question and the page that comes out compared. */
        NSMutableArray *ourEmptyLog = [NSMutableArray array], *theirEmptyLog = [NSMutableArray array];
        void (^noSize)(id, NSMutableArray *) = ^(id context, NSMutableArray *log) {
            [log addObject:[NSValue valueWithCGRect:[context pdfContextBounds]]];
            [context beginPage];
            CGContextSetRGBFillColor([context CGContext], 0, 0, 1, 1);
            [context fillRect:CGRectMake(0, 0, 612, 792)];
        };
        NSData *ourEmpty = draw(oursRenderer, oursFormat, CGRectZero, nil, noSize, ourEmptyLog);
        NSData *theirEmpty = draw([UIGraphicsPDFRenderer class], [UIGraphicsPDFRendererFormat class],
                                  CGRectZero, nil, noSize, theirEmptyLog);
        same((long)ourEmptyLog.count, (long)theirEmptyLog.count, @"a renderer of no size ran the block on both");
        if (ourEmptyLog.count == 1 && theirEmptyLog.count == 1)
            same_rect([ourEmptyLog[0] CGRectValue], [theirEmptyLog[0] CGRectValue],
                      @"the page a renderer of no size hands the block");
        same_shape(ourEmpty, theirEmpty, @"a renderer of no size");

        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures ? 1 : 0;
}