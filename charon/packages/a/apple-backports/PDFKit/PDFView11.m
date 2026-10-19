#import "CharonPDFKit.h"

// PDFView without a window, which is what this release can offer: neither 6.1.3 nor 4.3 carries
// UIKit's PDFView and a port view has nowhere to be put.  What it is here is a document holder with
// the settings a caller sets and reads back, over the port's own PDFDocument.
//
// Every default below is the host's own, measured with NO WINDOW and never shown, by
// tests/backports/host/pdfkit-document/tools/host-view-windowless.m on box-all, charon-fixture-3 and
// box-rotated - identical on all three:
//
//   window (nil);  currentPage an-object as soon as a document is set;  document=nil takes currentPage
//   with it;  scaleFactor 1, minScaleFactor 0.1, maxScaleFactor 100, autoScales NO;
//   displayMode singlePage, displayBox cropBox, displayDirection vertical, pageShadowsEnabled YES

// THREE MEMBERS THE PLAN NAMED ARE NOT THIS API and are not implemented: the 26.2 PDFView.h declares
// no -pageCount, no -canDisplayPage:, no -usePageViewController: and no -scaleToFit, and the host
// answers canDisplayPage: supported=0 and scaleToFit supported=0.  A port that answered them would be
// answering a method no caller of this API can send.

@implementation PDFView {
    // The document this view is showing.  NOT weak: a view holds what it was given, and the header
    // declares PDFView.document a plain retain (PDFView.h:79).  It is the PAGE's document that is
    // weak (PDFPage.h:70), which is a different reference in a different direction.
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

// The properties the header declares and this file implements rather than stores, named so the
// compiler's -Wobjc-missing-property-synthesis is satisfied by a declaration rather than an ivar the
// port does not keep: each has a body below that reads or writes the ivar of the same meaning.
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

// Apple's own defaults, read off the host above rather than guessed.
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
    // displayMode 1 is singlePage, displayBox 1 is cropBox, displayDirection 0 is vertical, and the
    // host reports shadows on - measured, not chosen.
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

// Setting a document gives the view a current page at once - the host answers an-object with no
// window and no page shown - and clearing the document takes the current page with it, which the host
// does too.
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

// displayBox is a VALIDATING setter on the host: setting cropBox on a document with no crop box is
// refused and the old value reads back.  This mirrors that - a box the current document does not
// have is not taken - and it is the one member where the host's answer is a decision rather than a
// store, so the comparison carries it.
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
    // kPDFDisplayBoxMediaBox is 0, cropBox 1, bleedBox 2, trimBox 3, artBox 4.  The host refuses a box
    // the page does not carry, and a page answers the media box for any of the others, so the port
    // takes the box only when the page has it.
    CGRect box = [page boundsForBox:(CGPDFBox)displayBox];
    if (CGRectIsEmpty(box) && displayBox != 0)
        return;   // the host declined it, and so does the port
    _displayBox = displayBox;
}

// -goToPage: is the ONE windowful member in this set and the host implements it, but a view with no
// window has nothing to scroll: what is compared is the CURRENT PAGE it leaves behind, which is the
// part both sides can answer.  The scrolling half is the window-bound part and is not claimed.
- (void)goToPage:(PDFPage *)page
{
    if (_document == nil || page == nil)
        return;
    if ([_document pageAtIndex:0] == nil)
        return;
    _currentPage = page;
}

@end
