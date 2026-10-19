#import "CharonPDFKit.h"

@implementation PDFView {
    PDFDocument *_document;
    PDFPage *_currentPage;
    CGFloat _scaleFactor;
    CGFloat _minScaleFactor;
    CGFloat _maxScaleFactor;
    BOOL _autoScales;
    NSInteger _displayMode;
    NSInteger _displayBox;
    NSInteger _displayDirection;
    BOOL _pageShadowsEnabled;
}

@synthesize document = _document;
@synthesize currentPage = _currentPage;
@synthesize scaleFactor = _scaleFactor;
@synthesize minScaleFactor = _minScaleFactor;
@synthesize maxScaleFactor = _maxScaleFactor;
@synthesize autoScales = _autoScales;
@synthesize displayMode = _displayMode;
@synthesize displayDirection = _displayDirection;
@synthesize displayBox = _displayBox;
@synthesize pageShadowsEnabled = _pageShadowsEnabled;

static const CGFloat kPDFViewDefaultScaleFactor = 1.0;
static const CGFloat kPDFViewDefaultMinScaleFactor = 0.1;
static const CGFloat kPDFViewDefaultMaxScaleFactor = 100.0;

- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _scaleFactor = kPDFViewDefaultScaleFactor;
    _minScaleFactor = kPDFViewDefaultMinScaleFactor;
    _maxScaleFactor = kPDFViewDefaultMaxScaleFactor;
    _autoScales = NO;
    _displayMode = 1;
    _displayBox = 1;
    _displayDirection = 0;
    _pageShadowsEnabled = YES;
    return self;
}

- (void)dealloc
{
    _currentPage = nil;
    _document = nil;
}

- (PDFDocument *)document
{
    return _document;
}

- (void)setDocument:(PDFDocument *)document
{
    if (_document == document)
        return;
    _document = document;
    _currentPage = document.pageCount > 0 ? [document pageAtIndex:0] : nil;
}

- (PDFPage *)currentPage
{
    return _currentPage;
}

- (CGFloat)scaleFactor
{
    return _scaleFactor;
}

- (void)setScaleFactor:(CGFloat)scaleFactor
{
    _scaleFactor = scaleFactor;
}

- (CGFloat)minScaleFactor
{
    return _minScaleFactor;
}

- (CGFloat)maxScaleFactor
{
    return _maxScaleFactor;
}

- (BOOL)autoScales
{
    return _autoScales;
}

- (void)setAutoScales:(BOOL)autoScales
{
    _autoScales = autoScales;
}

- (NSInteger)displayMode
{
    return _displayMode;
}

- (void)setDisplayMode:(NSInteger)displayMode
{
    _displayMode = displayMode;
}

- (NSInteger)displayDirection
{
    return _displayDirection;
}

- (void)setDisplayDirection:(NSInteger)displayDirection
{
    _displayDirection = displayDirection;
}

- (BOOL)pageShadowsEnabled
{
    return _pageShadowsEnabled;
}

- (void)setPageShadowsEnabled:(BOOL)enabled
{
    _pageShadowsEnabled = enabled;
}

- (NSInteger)displayBox
{
    return _displayBox;
}

- (void)setDisplayBox:(NSInteger)displayBox
{
    if (_document == nil) {
        _displayBox = displayBox;
        return;
    }
    PDFPage *page = _currentPage ?: (_document.pageCount ? [_document pageAtIndex:0] : nil);
    if (page == nil) {
        _displayBox = displayBox;
        return;
    }
    CGRect box = [page boundsForBox:(CGPDFBox)displayBox];
    if (CGRectIsEmpty(box) && displayBox != 0)
        return;
    _displayBox = displayBox;
}

- (void)goToPage:(PDFPage *)page
{
    if (_document == nil || page == nil)
        return;
    if ([_document pageAtIndex:0] == nil)
        return;
    _currentPage = page;
}

@end
