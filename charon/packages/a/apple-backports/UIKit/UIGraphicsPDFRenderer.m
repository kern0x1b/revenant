#import "CharonGraphicsRenderer.h"

// UIGraphicsPDFRenderer, UIGraphicsPDFRendererFormat and UIGraphicsPDFRendererContext of iOS 10.0,
// written against the PDF context functions every release from 3.0 carries, and against nothing
// this release does not export: the whole family, CGPDFContextCreate and its nine siblings,
// CGDataConsumerCreateWithCFData and the two matrix calls, are first-rung 3.0.
//
// The private members the release keeps are named as it keeps them, read off the method bodies of
// the armv7s cache of iOS 10.3.4 with objc.code_map:
//   UIGraphicsPDFRendererFormat  _outputURL, _pdfData          (besides the public documentInfo)
//   UIGraphicsPDFRendererContext _documentBounds, _pageBounds, _inPage
// The format's two say where +contextWithFormat: writes; the context's three are what
// -pdfContextBounds and the page bookkeeping read.

// Private to CoreGraphics and declared in no header, public or current: it sets the matrix a
// context goes back to whenever the CTM is reset, which -beginPageWithBounds:pageInfo: relies on
// across the pages of one document. Every release from 3.0 exports it (first-rung 3.0), and the
// family already declares its three private neighbours the same way, in CharonGraphicsRenderer.h.
CG_EXTERN void CGContextSetBaseCTM(CGContextRef c, CGAffineTransform transform);

// The document bounds UIKit uses when neither the format's bounds nor its document info names one:
// a page of US Letter at 72 dpi. Read at 0x20985ba0 of that cache, where +prepareCGContext: puts
// its four floats (0, 0, 612, 792), and the same two floats are built by immediate in the
// comparison -beginPageWithBounds:pageInfo: makes (0x44460000 and 0x44190000).
static const CGRect charon_pdf_default_document_bounds = { { 0, 0 }, { 612, 792 } };

// The document media box as a dictionary value: an NSData of the sixteen bytes of a CGRect. Both
// the document and the page read it under this key, exactly as the release does.
static NSData *charon_pdf_media_box(CGRect box)
{
    return [NSData dataWithBytes:&box length:sizeof(CGRect)];
}

@interface UIGraphicsPDFRendererFormat (CharonPDF)
@property (nonatomic, copy) NSURL *outputURL;
@property (nonatomic, retain) NSMutableData *pdfData;
@end

@interface UIGraphicsPDFRendererContext (CharonPDF)
@property (nonatomic) CGRect documentBounds;
@property (nonatomic) CGRect pageBounds;
@property (nonatomic) BOOL inPage;
@end

@implementation UIGraphicsPDFRendererFormat {
@private
    NSDictionary *_documentInfo;
    NSURL *_outputURL;
    NSMutableData *_pdfData;
}

- (NSDictionary *)documentInfo
{
    return _documentInfo;
}

// copy, as the release's setter is: the release compiles this member to objc_setProperty with the
// copy flag set, and its -copyWithZone: copies the dictionary a second time before handing it over.
- (void)setDocumentInfo:(NSDictionary *)documentInfo
{
    _documentInfo = [documentInfo copy];
}

- (NSURL *)outputURL
{
    return _outputURL;
}

- (void)setOutputURL:(NSURL *)outputURL
{
    _outputURL = outputURL;
}

- (NSMutableData *)pdfData
{
    return _pdfData;
}

- (void)setPdfData:(NSMutableData *)pdfData
{
    _pdfData = pdfData;
}

// The release carries all three onto the copy, not just the bounds its superclass carries.
- (id)copyWithZone:(NSZone *)zone
{
    UIGraphicsPDFRendererFormat *copy = [super copyWithZone:zone];
    copy.documentInfo = self.documentInfo;
    copy.outputURL = self.outputURL;
    copy.pdfData = self.pdfData;
    return copy;
}

@end

@implementation UIGraphicsPDFRendererContext {
@private
    CGRect _documentBounds;
    CGRect _pageBounds;
    BOOL _inPage;
}

- (CGRect)documentBounds
{
    return _documentBounds;
}

- (void)setDocumentBounds:(CGRect)documentBounds
{
    _documentBounds = documentBounds;
}

- (CGRect)pageBounds
{
    return _pageBounds;
}

- (void)setPageBounds:(CGRect)pageBounds
{
    _pageBounds = pageBounds;
}

- (BOOL)inPage
{
    return _inPage;
}

- (void)setInPage:(BOOL)inPage
{
    _inPage = inPage;
}

// The page being drawn, which is the document itself before the first -beginPage and the page
// after it. 0x209856f1 of the cache: -inPage, then -pageBounds or -documentBounds.
- (CGRect)pdfContextBounds
{
    return _inPage ? _pageBounds : _documentBounds;
}

- (void)beginPage
{
    UIGraphicsPDFRendererFormat *format = (UIGraphicsPDFRendererFormat *)self.format;
    // No page dictionary, which is what the release passes: its -beginPage loads the nil object
    // (___NSDictionary0__, 0x2098541e) for this argument.
    NSDictionary *pageInfo = nil;
    [self beginPageWithBounds:format ? format.bounds : CGRectZero pageInfo:pageInfo];
}

// 0x20985451 of the cache, in order:
//   1. CGPDFContextEndPage when a page is open,
//   2. the document's media box overrides the rectangle the caller asked for, and an empty
//      rectangle falls back to the document's own bounds,
//   3. the page records the rectangle and that it is in a page,
//   4. the page dictionary gains the media box when the page is neither the document's own page nor
//      US Letter, which are the two rectangles CoreGraphics already gives that box,
//   5. CGPDFContextBeginPage with that dictionary - it takes no rectangle of its own on iOS, the
//      rectangle travels in it as kCGPDFContextMediaBox,
//   6. the y axis is flipped once for the page, and the base CTM is that flip.
- (void)beginPageWithBounds:(CGRect)bounds pageInfo:(NSDictionary *)pageInfo
{
    CGContextRef context = self.CGContext;
    if (_inPage)
        CGPDFContextEndPage(context);

    CGRect box = bounds;
    NSData *documentBox = [((UIGraphicsPDFRendererFormat *)self.format).documentInfo
                           objectForKey:(id)kCGPDFContextMediaBox];
    if (documentBox)
        [documentBox getBytes:&box length:sizeof(CGRect)];
    if (CGRectIsEmpty(box))
        box = _documentBounds;
    _pageBounds = box;
    _inPage = YES;

    // The release's own rule, and it has an edge worth naming: the box is written into a COPY of the
    // page dictionary, so a caller who passes no dictionary at all gets none and the page takes the
    // document's media box (its -[nil mutableCopy] is nil, and -setObject:forKey: on nil does
    // nothing). That is what 0x20985652 does with the same two calls, and it is left as it is.
    if (![pageInfo objectForKey:(id)kCGPDFContextMediaBox] &&
        !CGRectEqualToRect(box, _documentBounds) &&
        !CGRectEqualToRect(box, charon_pdf_default_document_bounds)) {
        NSMutableDictionary *withBox = [pageInfo mutableCopy];
        [withBox setObject:charon_pdf_media_box(box) forKey:(id)kCGPDFContextMediaBox];
        pageInfo = withBox;
    }

    CGPDFContextBeginPage(context, (CFDictionaryRef)pageInfo);
    // 0x20985684 of the cache loads the FOURTH float of the page rectangle (its height) into the
    // second argument, not a zero: the flip is about the top edge of the page, so a caller draws
    // from the top down the way it does everywhere else in UIKit. Reading that instruction as a
    // zero is what made the first version of this file draw every page off the paper, and the
    // differential host test is what said so.
    CGContextTranslateCTM(context, 0, box.size.height);
    CGContextScaleCTM(context, 1, -1);
    CGContextSetBaseCTM(context, CGAffineTransformMakeScale(1, -1));
}

- (void)setURL:(NSURL *)url forRect:(CGRect)rect
{
    CGPDFContextSetURLForRect(self.CGContext, (__bridge CFURLRef)url, rect);
}

- (void)addDestinationWithName:(NSString *)name atPoint:(CGPoint)point
{
    CGPDFContextAddDestinationAtPoint(self.CGContext, (__bridge CFStringRef)name, point);
}

- (void)setDestinationWithName:(NSString *)name forRect:(CGRect)rect
{
    CGPDFContextSetDestinationForRect(self.CGContext, (__bridge CFStringRef)name, rect);
}

@end

@implementation UIGraphicsPDFRenderer

+ (Class)rendererContextClass
{
    return [UIGraphicsPDFRendererContext class];
}

// 0x2098590d of the cache: where the document goes is the format's own answer - an output URL or
// the data the caller wants it in - and the bounds are the format's, with an empty rectangle passed
// as no rectangle at all, which is what lets the media box in the document info decide. Neither
// destination named means no context, and the drawing block then does not run.
+ (CGContextRef)contextWithFormat:(UIGraphicsPDFRendererFormat *)format
{
    CGRect bounds = format ? format.bounds : CGRectZero;
    NSDictionary *documentInfo = ((UIGraphicsPDFRendererFormat *)format).documentInfo;
    const CGRect *mediaBox = CGRectIsEmpty(bounds) ? NULL : &bounds;

    NSURL *url = format.outputURL;
    if (url)
        return CGPDFContextCreateWithURL((__bridge CFURLRef)url, mediaBox, (__bridge CFDictionaryRef)documentInfo);

    NSMutableData *data = format.pdfData;
    if (!data)
        return NULL;
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
    if (!consumer)
        return NULL;
    CGContextRef context = CGPDFContextCreate(consumer, mediaBox, (__bridge CFDictionaryRef)documentInfo);
    CGDataConsumerRelease(consumer);
    return context;
}

// 0x20985a41 of the cache: the document's page is the format's bounds unless the document info
// names a media box, and a page of no size is US Letter. The page bounds start empty and no page is
// open, so -pdfContextBounds answers the document until the first -beginPage.
+ (void)prepareCGContext:(CGContextRef)context withRendererContext:(UIGraphicsPDFRendererContext *)rendererContext
{
    UIGraphicsPDFRendererFormat *format = (UIGraphicsPDFRendererFormat *)rendererContext.format;
    CGRect bounds = format ? format.bounds : CGRectZero;
    NSData *documentBox = [((UIGraphicsPDFRendererFormat *)format).documentInfo
                           objectForKey:(id)kCGPDFContextMediaBox];
    if (documentBox)
        [documentBox getBytes:&bounds length:sizeof(CGRect)];
    if (CGRectIsEmpty(bounds))
        bounds = charon_pdf_default_document_bounds;
    rendererContext.documentBounds = bounds;
    rendererContext.pageBounds = CGRectZero;
    rendererContext.inPage = NO;
}

- (instancetype)init
{
    return [self initWithBounds:CGRectZero format:[UIGraphicsPDFRendererFormat defaultFormat]];
}

- (instancetype)initWithBounds:(CGRect)bounds
{
    return [self initWithBounds:bounds format:[UIGraphicsPDFRendererFormat defaultFormat]];
}

// 0x20985c81 of the cache: the destination is cleared off the format before the superclass copies
// it, so a renderer built around one format writes nowhere until a -writePDFToURL: names a place.
- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsPDFRendererFormat *)format
{
    format.pdfData = nil;
    format.outputURL = nil;
    return [super initWithBounds:bounds format:format];
}

// A PDF context draws with UIKit's own primitives, so the context is current for the whole block,
// not only when the renderer allows image output as the base class does.
- (void)pushContext:(UIGraphicsRendererContext *)context
{
    UIGraphicsPushContext(context.CGContext);
}

// 0x202e6961 of the cache: an open page is closed, the context is popped, and the PDF context is
// closed - which is what finishes the document. The pop is the release's own, so it does not go
// through the superclass: the flag the superclass consults is what keeps an image renderer from
// pushing a context it draws no image into, and a PDF renderer draws into this one either way.
- (void)popContext:(UIGraphicsRendererContext *)context
{
    UIGraphicsPDFRendererContext *pdfContext = (UIGraphicsPDFRendererContext *)context;
    if (pdfContext.inPage)
        CGPDFContextEndPage(pdfContext.CGContext);
    UIGraphicsPopContext();
    CGPDFContextClose(pdfContext.CGContext);
}

- (BOOL)writePDFToURL:(NSURL *)url withActions:(NS_NOESCAPE UIGraphicsPDFDrawingActions)actions error:(NSError **)error
{
    UIGraphicsPDFRendererFormat *format = (UIGraphicsPDFRendererFormat *)self.format;
    format.outputURL = url;
    return [self runDrawingActions:actions completionActions:nil format:format error:error];
}

// 0x20985d91 of the cache: the data is made first and named on the format, the block runs into it,
// and what comes back is a copy of it - or, when there was no context to draw into, an empty NSData
// rather than nil, as the image renderer's three drawing members do.
- (NSData *)PDFDataWithActions:(NS_NOESCAPE UIGraphicsPDFDrawingActions)actions
{
    NSMutableData *data = [[NSMutableData alloc] init];
    UIGraphicsPDFRendererFormat *format = (UIGraphicsPDFRendererFormat *)self.format;
    format.pdfData = data;
    BOOL drawn = [self runDrawingActions:actions completionActions:nil format:format error:NULL];
    return drawn ? [data copy] : [[NSData alloc] init];
}

@end