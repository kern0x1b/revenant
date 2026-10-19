#import "CharonGraphicsRenderer.h"

CG_EXTERN void CGContextSetBaseCTM(CGContextRef c, CGAffineTransform transform);

static const CGRect charon_pdf_default_document_bounds = { { 0, 0 }, { 612, 792 } };

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

- (CGRect)pdfContextBounds
{
    return _inPage ? _pageBounds : _documentBounds;
}

- (void)beginPage
{
    UIGraphicsPDFRendererFormat *format = (UIGraphicsPDFRendererFormat *)self.format;
    NSDictionary *pageInfo = nil;
    [self beginPageWithBounds:format ? format.bounds : CGRectZero pageInfo:pageInfo];
}

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

    if (![pageInfo objectForKey:(id)kCGPDFContextMediaBox] &&
        !CGRectEqualToRect(box, _documentBounds) &&
        !CGRectEqualToRect(box, charon_pdf_default_document_bounds)) {
        NSMutableDictionary *withBox = [pageInfo mutableCopy];
        [withBox setObject:charon_pdf_media_box(box) forKey:(id)kCGPDFContextMediaBox];
        pageInfo = withBox;
    }

    CGPDFContextBeginPage(context, (CFDictionaryRef)pageInfo);
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

- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsPDFRendererFormat *)format
{
    format.pdfData = nil;
    format.outputURL = nil;
    return [super initWithBounds:bounds format:format];
}

- (void)pushContext:(UIGraphicsRendererContext *)context
{
    UIGraphicsPushContext(context.CGContext);
}

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

- (NSData *)PDFDataWithActions:(NS_NOESCAPE UIGraphicsPDFDrawingActions)actions
{
    NSMutableData *data = [[NSMutableData alloc] init];
    UIGraphicsPDFRendererFormat *format = (UIGraphicsPDFRendererFormat *)self.format;
    format.pdfData = data;
    BOOL drawn = [self runDrawingActions:actions completionActions:nil format:format error:NULL];
    return drawn ? [data copy] : [[NSData alloc] init];
}

@end
