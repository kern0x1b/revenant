#import "RevenantPDFView.h"
#import "RevenantPDFLayout.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

static const CGFloat RevenantPDFDefaultScale = 1.0;
static const CGFloat RevenantPDFDefaultMinimumScale = 0.1;
static const CGFloat RevenantPDFDefaultMaximumScale = 100.0;
static const CGFloat RevenantPDFZoomStep = 1.41421356237;
static const CGFloat RevenantPDFDoubleTapZoom = 2.0;
static const NSUInteger RevenantPDFHistoryLimit = 64;

typedef NS_ENUM(NSInteger, RevenantPDFInterpolation) {
    RevenantPDFInterpolationNone = 0,
    RevenantPDFInterpolationLow = 1,
    RevenantPDFInterpolationHigh = 2,
};

static CGInterpolationQuality RevenantPDFInterpolationQuality(NSInteger quality)
{
    switch (quality) {
    case RevenantPDFInterpolationNone:
        return kCGInterpolationNone;
    case RevenantPDFInterpolationLow:
        return kCGInterpolationLow;
    default:
        return kCGInterpolationHigh;
    }
}

static CGSize RevenantPDFDisplaySize(PDFPage *page, NSInteger box)
{
    CGRect bounds = [page boundsForBox:(CGPDFBox)box];
    NSInteger rotation = page.rotation;
    BOOL sideways = rotation == 90 || rotation == 270;
    return sideways ? CGSizeMake(bounds.size.height, bounds.size.width) : bounds.size;
}

static UIColor *RevenantPDFHighlightColour(void)
{
    return [UIColor colorWithRed:1.0 green:0.9 blue:0.0 alpha:0.5];
}

static UIColor *RevenantPDFSelectionColour(void)
{
    return [UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:0.35];
}

@interface RevenantPDFHighlight : NSObject
@property (nonatomic) CGRect rect;
@property (nonatomic, strong) UIColor *color;
@end

@implementation RevenantPDFHighlight
@synthesize rect = _rect;
@synthesize color = _color;
@end

@interface RevenantPDFPageRender : NSObject
@property (nonatomic, strong) PDFPage *page;
@property (nonatomic) CGSize size;
@property (nonatomic) CGFloat scale;
@property (nonatomic) NSInteger box;
@property (nonatomic) CGInterpolationQuality quality;
@property (nonatomic, copy) NSArray<RevenantPDFHighlight *> *highlights;
@property (nonatomic) NSUInteger generation;
@end

@implementation RevenantPDFPageRender
@synthesize page = _page;
@synthesize size = _size;
@synthesize scale = _scale;
@synthesize box = _box;
@synthesize quality = _quality;
@synthesize highlights = _highlights;
@synthesize generation = _generation;
@end

@interface RevenantPDFTileLayer : CATiledLayer
@end

@implementation RevenantPDFTileLayer

+ (CFTimeInterval)fadeDuration
{
    return 0;
}

@end

@interface RevenantPDFPageView : UIView
@property (atomic, strong) RevenantPDFPageRender *render;
@property (nonatomic, weak) PDFView *owner;
@end

@implementation RevenantPDFPageView

@synthesize render = _render;
@synthesize owner = _owner;

+ (Class)layerClass
{
    return [RevenantPDFTileLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self == nil)
        return nil;
    self.contentMode = UIViewContentModeRedraw;
    self.backgroundColor = [UIColor whiteColor];
    CATiledLayer *tiles = (CATiledLayer *)self.layer;
    tiles.tileSize = CGSizeMake(512, 512);
    tiles.levelsOfDetail = 1;
    tiles.levelsOfDetailBias = 0;
    return self;
}

- (void)drawRect:(CGRect)rect
{
    RevenantPDFPageRender *render = self.render;
    PDFView *owner = self.owner;
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (render == nil || owner == nil || context == NULL)
        return;
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, rect);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, render.size.height);
    CGContextScaleCTM(context, render.scale, -render.scale);
    CGContextSetInterpolationQuality(context, render.quality);
    [owner drawPage:render.page toContext:context];
    if (render.highlights.count > 0) {
        CGContextSaveGState(context);
        CGContextConcatCTM(context, [render.page transformForBox:render.box]);
        CGContextSetBlendMode(context, kCGBlendModeMultiply);
        for (RevenantPDFHighlight *highlight in render.highlights) {
            CGContextSetFillColorWithColor(context, highlight.color.CGColor);
            CGContextFillRect(context, highlight.rect);
        }
        CGContextRestoreGState(context);
    }
    CGContextRestoreGState(context);
    [owner drawPagePost:render.page toContext:context];
}

@end

@interface PDFView (RevenantInternals)
- (void)revenant_scrolled;
@end

@interface RevenantPDFScrollView : UIScrollView
@property (nonatomic, weak) PDFView *owner;
@end

@implementation RevenantPDFScrollView

@synthesize owner = _owner;

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self.owner revenant_scrolled];
}

@end

@implementation PDFView {
    RevenantPDFScrollView *_scrollView;
    UIView *_documentView;
    NSMutableDictionary<NSNumber *, RevenantPDFPageView *> *_pageViews;
    NSMutableArray<RevenantPDFPageView *> *_reusablePageViews;
    RevenantPDFLayout *_layout;
    BOOL _layoutDirty;
    BOOL _framesValid;
    BOOL _updating;
    NSInteger _programmaticScrolls;
    CGSize _laidOutSize;
    NSUInteger _renderGeneration;
    NSIndexSet *_visibleIndexes;
    PDFDocument *_document;
    NSUInteger _currentIndex;
    CGFloat _scaleFactor;
    CGFloat _minScaleFactor;
    CGFloat _maxScaleFactor;
    BOOL _autoScales;
    NSInteger _displayMode;
    NSInteger _displayDirection;
    NSInteger _displayBox;
    BOOL _displaysPageBreaks;
    UIEdgeInsets _pageBreakMargins;
    BOOL _displaysAsBook;
    BOOL _displaysRTL;
    NSInteger _interpolationQuality;
    BOOL _pageShadowsEnabled;
    __weak id _delegate;
    PDFSelection *_currentSelection;
    NSArray<PDFSelection *> *_highlightedSelections;
    NSMutableArray<PDFDestination *> *_history;
    NSInteger _historyIndex;
    CGFloat _pinchStartScale;
}

@synthesize document = _document;
@synthesize delegate = _delegate;
@synthesize displayMode = _displayMode;
@synthesize displayDirection = _displayDirection;
@synthesize displaysPageBreaks = _displaysPageBreaks;
@synthesize displayBox = _displayBox;
@synthesize displaysAsBook = _displaysAsBook;
@synthesize displaysRTL = _displaysRTL;
@synthesize interpolationQuality = _interpolationQuality;
@synthesize pageShadowsEnabled = _pageShadowsEnabled;
@synthesize currentSelection = _currentSelection;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        [self revenant_setUp];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self != nil)
        [self revenant_setUp];
    return self;
}

- (void)revenant_setUp
{
    _scaleFactor = RevenantPDFDefaultScale;
    _minScaleFactor = RevenantPDFDefaultMinimumScale;
    _maxScaleFactor = RevenantPDFDefaultMaximumScale;
    _displayMode = RevenantPDFLayoutSinglePageContinuous;
    _displayDirection = RevenantPDFLayoutVertical;
    _displayBox = kCGPDFCropBox;
    _displaysPageBreaks = YES;
    _pageBreakMargins = UIEdgeInsetsMake(4.75, 4, 4.75, 4);
    _interpolationQuality = RevenantPDFInterpolationLow;
    _pageShadowsEnabled = YES;
    _currentIndex = NSNotFound;
    _historyIndex = -1;
    _history = [NSMutableArray array];
    _pageViews = [NSMutableDictionary dictionary];
    _reusablePageViews = [NSMutableArray array];
    _layoutDirty = YES;
    self.backgroundColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    _scrollView = [[RevenantPDFScrollView alloc] initWithFrame:self.bounds];
    _scrollView.owner = self;
    _documentView = [[UIView alloc] init];
    [_scrollView addSubview:_documentView];
    [self addSubview:_scrollView];
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_pinched:)];
    pinch.delegate = self;
    [_scrollView addGestureRecognizer:pinch];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_doubleTapped:)];
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.delegate = self;
    [_scrollView addGestureRecognizer:doubleTap];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_tapped:)];
    tap.delegate = self;
    [tap requireGestureRecognizerToFail:doubleTap];
    [_scrollView addGestureRecognizer:tap];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (UIView *)documentView
{
    return _documentView;
}

- (BOOL)revenant_vertical
{
    return _displayDirection == RevenantPDFLayoutVertical;
}

- (BOOL)revenant_continuous
{
    return _displayMode == RevenantPDFLayoutSinglePageContinuous || _displayMode == RevenantPDFLayoutTwoUpContinuous;
}

- (RevenantPDFInsets)revenant_insets
{
    UIEdgeInsets margins = self.pageBreakMargins;
    return (RevenantPDFInsets){margins.top, margins.left, margins.bottom, margins.right};
}

- (void)revenant_prepareLayout
{
    if (!_layoutDirty && _layout != nil)
        return;
    NSUInteger count = _document.pageCount;
    CGSize *sizes = calloc(count + 1, sizeof(CGSize));
    for (NSUInteger index = 0; index < count; index++)
        sizes[index] = RevenantPDFDisplaySize([_document pageAtIndex:index], _displayBox);
    _layout = [[RevenantPDFLayout alloc] initWithPageSizes:sizes
                                                     count:count
                                               displayMode:(RevenantPDFLayoutMode)_displayMode
                                                 direction:(RevenantPDFLayoutDirection)_displayDirection
                                        displaysPageBreaks:_displaysPageBreaks
                                                   margins:[self revenant_insets]
                                            displaysAsBook:_displaysAsBook
                                               rightToLeft:_displaysRTL];
    free(sizes);
    _layoutDirty = NO;
    _framesValid = NO;
}

- (NSUInteger)revenant_layoutPage
{
    return _currentIndex == NSNotFound ? 0 : _currentIndex;
}

- (CGFloat)revenant_crossExtent
{
    return [self revenant_vertical] ? self.bounds.size.width : self.bounds.size.height;
}

- (void)revenant_ensureFrames
{
    [self revenant_prepareLayout];
    if (_framesValid)
        return;
    [self revenant_relayout];
}

- (void)revenant_relayout
{
    [self revenant_prepareLayout];
    [_layout layoutAtScale:_scaleFactor currentPage:[self revenant_layoutPage] crossExtent:[self revenant_crossExtent]];
    _framesValid = YES;
    CGSize content = _layout.contentSize;
    BOOL wasUpdating = _updating;
    _updating = YES;
    _documentView.frame = CGRectMake(0, 0, content.width, content.height);
    _scrollView.contentSize = content;
    _updating = wasUpdating;
    _renderGeneration++;
    [self revenant_updatePageViews];
}

- (CGPoint)revenant_clampedOffset:(CGPoint)offset
{
    UIEdgeInsets inset = _scrollView.contentInset;
    CGSize content = _scrollView.contentSize;
    CGSize size = _scrollView.bounds.size;
    CGFloat maximumX = MAX(-inset.left, content.width - size.width + inset.right);
    CGFloat maximumY = MAX(-inset.top, content.height - size.height + inset.bottom);
    return CGPointMake(MIN(MAX(offset.x, -inset.left), maximumX), MIN(MAX(offset.y, -inset.top), maximumY));
}

- (void)revenant_scrollTo:(CGPoint)offset
{
    _programmaticScrolls++;
    _scrollView.contentOffset = [self revenant_clampedOffset:offset];
    [_scrollView layoutIfNeeded];
    _programmaticScrolls--;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _scrollView.frame = self.bounds;
    BOOL resized = !CGSizeEqualToSize(self.bounds.size, _laidOutSize);
    if (!resized && !_layoutDirty)
        return;
    _laidOutSize = self.bounds.size;
    if (_document == nil || CGRectIsEmpty(self.bounds)) {
        _framesValid = NO;
        return;
    }
    [self revenant_prepareLayout];
    if (_autoScales) {
        CGFloat fit = [self scaleFactorForSizeToFit];
        if (fit != _scaleFactor) {
            [self revenant_applyScale:fit anchor:CGPointZero];
            return;
        }
    }
    [self revenant_relayout];
    [self revenant_scrollTo:_scrollView.contentOffset];
}

- (CGFloat)scaleFactorForSizeToFit
{
    [self revenant_prepareLayout];
    if (_document == nil || CGRectIsEmpty(self.bounds))
        return _scaleFactor;
    return [_layout fitScaleForViewSize:self.bounds.size currentPage:[self revenant_layoutPage]];
}

- (CGFloat)scaleFactor
{
    return _scaleFactor;
}

- (CGFloat)revenant_clampedScale:(CGFloat)scale
{
    return MIN(MAX(scale, _minScaleFactor), _maxScaleFactor);
}

- (void)revenant_applyScale:(CGFloat)scale anchor:(CGPoint)anchor
{
    [self revenant_ensureFrames];
    CGPoint offset = _scrollView.contentOffset;
    CGPoint documentPoint = CGPointMake(offset.x + anchor.x, offset.y + anchor.y);
    NSUInteger page = [_layout pageNearestToPoint:documentPoint];
    CGRect before = page == NSNotFound ? CGRectNull : [_layout frameOfPageAtIndex:page];
    CGPoint fraction = CGPointZero;
    BOOL anchored = !CGRectIsNull(before) && before.size.width > 0 && before.size.height > 0;
    if (anchored)
        fraction = CGPointMake((documentPoint.x - before.origin.x) / before.size.width, (documentPoint.y - before.origin.y) / before.size.height);
    BOOL changed = scale != _scaleFactor;
    _scaleFactor = scale;
    [self revenant_relayout];
    CGPoint target = offset;
    CGRect after = anchored ? [_layout frameOfPageAtIndex:page] : CGRectNull;
    if (!CGRectIsNull(after))
        target = CGPointMake(after.origin.x + fraction.x * after.size.width - anchor.x, after.origin.y + fraction.y * after.size.height - anchor.y);
    [self revenant_scrollTo:target];
    if (changed)
        [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewScaleChangedNotification object:self];
}

- (void)setScaleFactor:(CGFloat)scaleFactor
{
    _autoScales = NO;
    CGFloat clamped = [self revenant_clampedScale:scaleFactor];
    if (clamped == _scaleFactor || _document == nil) {
        _scaleFactor = clamped;
        return;
    }
    CGSize size = _scrollView.bounds.size;
    [self revenant_applyScale:clamped anchor:CGPointMake(size.width / 2, size.height / 2)];
}

- (CGFloat)minScaleFactor
{
    return _minScaleFactor;
}

- (void)setMinScaleFactor:(CGFloat)minScaleFactor
{
    _minScaleFactor = minScaleFactor;
    _autoScales = NO;
    if (_scaleFactor < minScaleFactor)
        [self setScaleFactor:minScaleFactor];
}

- (CGFloat)maxScaleFactor
{
    return _maxScaleFactor;
}

- (void)setMaxScaleFactor:(CGFloat)maxScaleFactor
{
    _maxScaleFactor = maxScaleFactor;
    _autoScales = NO;
    if (_scaleFactor > maxScaleFactor)
        [self setScaleFactor:maxScaleFactor];
}

- (BOOL)autoScales
{
    return _autoScales;
}

- (void)setAutoScales:(BOOL)autoScales
{
    if (_autoScales == autoScales)
        return;
    _autoScales = autoScales;
    if (autoScales)
        [self setNeedsLayout];
    if (autoScales && _document != nil && !CGRectIsEmpty(self.bounds)) {
        CGFloat fit = [self scaleFactorForSizeToFit];
        if (fit != _scaleFactor)
            [self revenant_applyScale:fit anchor:CGPointZero];
    }
}

- (void)zoomIn:(id)sender
{
    [self setScaleFactor:_scaleFactor * RevenantPDFZoomStep];
}

- (BOOL)canZoomIn
{
    return _document != nil && _scaleFactor < _maxScaleFactor;
}

- (void)zoomOut:(id)sender
{
    [self setScaleFactor:_scaleFactor / RevenantPDFZoomStep];
}

- (BOOL)canZoomOut
{
    return _document != nil && _scaleFactor > _minScaleFactor;
}

- (void)revenant_pinched:(UIPinchGestureRecognizer *)recognizer
{
    if (_document == nil)
        return;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _pinchStartScale = _scaleFactor;
        _autoScales = NO;
    }
    if (recognizer.state != UIGestureRecognizerStateBegan && recognizer.state != UIGestureRecognizerStateChanged)
        return;
    CGFloat scale = [self revenant_clampedScale:_pinchStartScale * recognizer.scale];
    if (scale == _scaleFactor)
        return;
    CGPoint location = [recognizer locationInView:_scrollView];
    CGPoint offset = _scrollView.contentOffset;
    [self revenant_applyScale:scale anchor:CGPointMake(location.x - offset.x, location.y - offset.y)];
}

- (void)revenant_doubleTapped:(UITapGestureRecognizer *)recognizer
{
    if (_document == nil)
        return;
    CGFloat fit = [self scaleFactorForSizeToFit];
    BOOL fitted = fabs(_scaleFactor - fit) < 0.01 * fit;
    CGFloat target = [self revenant_clampedScale:fitted ? fit * RevenantPDFDoubleTapZoom : fit];
    CGPoint location = [recognizer locationInView:_scrollView];
    CGPoint offset = _scrollView.contentOffset;
    _autoScales = NO;
    [self revenant_applyScale:target anchor:CGPointMake(location.x - offset.x, location.y - offset.y)];
}

- (void)revenant_tapped:(UITapGestureRecognizer *)recognizer
{
    if (_document == nil)
        return;
    CGPoint point = [recognizer locationInView:_documentView];
    PDFPage *page = [self revenant_pageAtDocumentPoint:point nearest:NO];
    if (page == nil)
        return;
    CGPoint local = CGPointApplyAffineTransform(point, CGAffineTransformInvert([self revenant_transformForPage:page]));
    for (PDFAnnotation *annotation in page.annotations) {
        if (!CGRectContainsPoint(annotation.bounds, local))
            continue;
        PDFAction *action = annotation.action;
        PDFDestination *destination = annotation.destination;
        if (action == nil && destination == nil)
            continue;
        NSDictionary *info = @{@"PDFAnnotationHit": annotation};
        [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewAnnotationWillHitNotification object:self userInfo:info];
        if (action != nil)
            [self performAction:action];
        else
            [self goToDestination:destination];
        [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewAnnotationHitNotification object:self userInfo:info];
        return;
    }
}

- (void)performAction:(PDFAction *)action
{
    id delegate = _delegate;
    if ([action isKindOfClass:[PDFActionGoTo class]]) {
        PDFDestination *destination = ((PDFActionGoTo *)action).destination;
        if (destination != nil)
            [self goToDestination:destination];
    } else if ([action isKindOfClass:[PDFActionURL class]]) {
        NSURL *URL = ((PDFActionURL *)action).URL;
        if ([delegate respondsToSelector:@selector(PDFViewWillClickOnLink:withURL:)])
            ((void (*)(id, SEL, PDFView *, NSURL *))objc_msgSend)(delegate, @selector(PDFViewWillClickOnLink:withURL:), self, URL);
        else if (URL != nil)
            [[UIApplication sharedApplication] openURL:URL];
    } else if ([action isKindOfClass:[PDFActionRemoteGoTo class]]) {
        if ([delegate respondsToSelector:@selector(PDFViewOpenPDF:forRemoteGoToAction:)])
            ((void (*)(id, SEL, PDFView *, PDFAction *))objc_msgSend)(delegate, @selector(PDFViewOpenPDF:forRemoteGoToAction:), self, action);
    } else if ([action isKindOfClass:[PDFActionNamed class]]) {
        switch (((PDFActionNamed *)action).name) {
        case kPDFActionNamedNextPage:
            [self goToNextPage:nil];
            break;
        case kPDFActionNamedPreviousPage:
            [self goToPreviousPage:nil];
            break;
        case kPDFActionNamedFirstPage:
            [self goToFirstPage:nil];
            break;
        case kPDFActionNamedLastPage:
            [self goToLastPage:nil];
            break;
        case kPDFActionNamedGoBack:
            [self goBack:nil];
            break;
        case kPDFActionNamedGoForward:
            [self goForward:nil];
            break;
        case kPDFActionNamedZoomIn:
            [self zoomIn:nil];
            break;
        case kPDFActionNamedZoomOut:
            [self zoomOut:nil];
            break;
        case kPDFActionNamedFind:
            if ([delegate respondsToSelector:@selector(PDFViewPerformFind:)])
                ((void (*)(id, SEL, PDFView *))objc_msgSend)(delegate, @selector(PDFViewPerformFind:), self);
            break;
        case kPDFActionNamedGoToPage:
            if ([delegate respondsToSelector:@selector(PDFViewPerformGoToPage:)])
                ((void (*)(id, SEL, PDFView *))objc_msgSend)(delegate, @selector(PDFViewPerformGoToPage:), self);
            break;
        default:
            break;
        }
    }
}

- (void)setDocument:(PDFDocument *)document
{
    if (_document == document)
        return;
    _document = document;
    _layout = nil;
    _layoutDirty = YES;
    _framesValid = NO;
    _historyIndex = -1;
    [_history removeAllObjects];
    _currentSelection = nil;
    for (RevenantPDFPageView *view in _pageViews.allValues) {
        [view removeFromSuperview];
        [_reusablePageViews addObject:view];
    }
    [_pageViews removeAllObjects];
    _visibleIndexes = nil;
    _programmaticScrolls++;
    _scrollView.contentOffset = CGPointMake(-_scrollView.contentInset.left, -_scrollView.contentInset.top);
    _programmaticScrolls--;
    [self revenant_prepareLayout];
    _currentIndex = document.pageCount > 0 ? [self revenant_leadingIndexOfRowWithPage:0] : NSNotFound;
    if (_autoScales && _document != nil && !CGRectIsEmpty(self.bounds))
        _scaleFactor = [self scaleFactorForSizeToFit];
    [self revenant_relayout];
    [self setNeedsLayout];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:PDFViewDocumentChangedNotification object:self];
    if (_currentIndex != NSNotFound)
        [center postNotificationName:PDFViewPageChangedNotification object:self];
}

- (PDFPage *)currentPage
{
    return _currentIndex == NSNotFound ? nil : [_document pageAtIndex:_currentIndex];
}

- (NSUInteger)revenant_leadingIndexOfRowWithPage:(NSUInteger)index
{
    NSRange row = [_layout pagesSharingRowWithPageAtIndex:index];
    if (row.location == NSNotFound)
        return NSNotFound;
    return _displaysRTL ? NSMaxRange(row) - 1 : row.location;
}

- (void)revenant_setCurrentIndex:(NSUInteger)index
{
    [self revenant_prepareLayout];
    NSUInteger leading = [self revenant_leadingIndexOfRowWithPage:index];
    if (leading == NSNotFound || leading == _currentIndex)
        return;
    _currentIndex = leading;
    if (![self revenant_continuous]) {
        _framesValid = NO;
        [self revenant_relayout];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewPageChangedNotification object:self];
}

- (CGAffineTransform)revenant_transformForPage:(PDFPage *)page
{
    [self revenant_ensureFrames];
    NSUInteger index = [_document indexForPage:page];
    CGRect frame = [_layout frameOfPageAtIndex:index];
    if (CGRectIsNull(frame))
        return CGAffineTransformIdentity;
    CGAffineTransform transform = [page transformForBox:_displayBox];
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(_scaleFactor, -_scaleFactor));
    return CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(frame.origin.x, frame.origin.y + frame.size.height));
}

- (CGPoint)convertPoint:(CGPoint)point fromPage:(PDFPage *)page
{
    CGPoint inDocument = CGPointApplyAffineTransform(point, [self revenant_transformForPage:page]);
    return [_documentView convertPoint:inDocument toView:self];
}

- (CGPoint)convertPoint:(CGPoint)point toPage:(PDFPage *)page
{
    CGPoint inDocument = [self convertPoint:point toView:_documentView];
    return CGPointApplyAffineTransform(inDocument, CGAffineTransformInvert([self revenant_transformForPage:page]));
}

- (CGRect)convertRect:(CGRect)rect fromPage:(PDFPage *)page
{
    CGRect inDocument = CGRectApplyAffineTransform(rect, [self revenant_transformForPage:page]);
    return [_documentView convertRect:inDocument toView:self];
}

- (CGRect)convertRect:(CGRect)rect toPage:(PDFPage *)page
{
    CGRect inDocument = [self convertRect:rect toView:_documentView];
    return CGRectApplyAffineTransform(inDocument, CGAffineTransformInvert([self revenant_transformForPage:page]));
}

- (PDFPage *)revenant_pageAtDocumentPoint:(CGPoint)point nearest:(BOOL)nearest
{
    [self revenant_ensureFrames];
    NSUInteger index = [_layout pageNearestToPoint:point];
    if (index == NSNotFound)
        return nil;
    if (!nearest && !CGRectContainsPoint([_layout frameOfPageAtIndex:index], point))
        return nil;
    return [_document pageAtIndex:index];
}

- (PDFPage *)pageForPoint:(CGPoint)point nearest:(BOOL)nearest
{
    return [self revenant_pageAtDocumentPoint:[self convertPoint:point toView:_documentView] nearest:nearest];
}

- (NSArray<RevenantPDFHighlight *> *)revenant_highlightsForPage:(PDFPage *)page
{
    NSMutableArray<RevenantPDFHighlight *> *found = [NSMutableArray array];
    void (^collect)(PDFSelection *, UIColor *) = ^(PDFSelection *selection, UIColor *fallback) {
        if (![selection.pages containsObject:page])
            return;
        for (PDFSelection *line in [selection selectionsByLine]) {
            CGRect rect = [line boundsForPage:page];
            if (CGRectIsEmpty(rect))
                continue;
            RevenantPDFHighlight *highlight = [[RevenantPDFHighlight alloc] init];
            highlight.rect = rect;
            highlight.color = selection.color ?: fallback;
            [found addObject:highlight];
        }
    };
    for (PDFSelection *selection in _highlightedSelections)
        collect(selection, RevenantPDFHighlightColour());
    if (_currentSelection != nil)
        collect(_currentSelection, RevenantPDFSelectionColour());
    return found;
}

- (void)revenant_configureShadowOf:(RevenantPDFPageView *)view
{
    CALayer *layer = view.layer;
    if (!_pageShadowsEnabled) {
        layer.shadowOpacity = 0;
        layer.shadowPath = NULL;
        return;
    }
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = 0.4;
    layer.shadowRadius = 2;
    layer.shadowOffset = CGSizeMake(0, 1);
    layer.shadowPath = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
}

- (void)revenant_updatePageViews
{
    if (_layout == nil || _document == nil) {
        for (RevenantPDFPageView *view in _pageViews.allValues) {
            [view removeFromSuperview];
            [_reusablePageViews addObject:view];
        }
        [_pageViews removeAllObjects];
        return;
    }
    if (_updating)
        return;
    _updating = YES;
    CGRect visible = _scrollView.bounds;
    BOOL vertical = [self revenant_vertical];
    CGRect expanded = vertical ? CGRectInset(visible, 0, -visible.size.height / 2) : CGRectInset(visible, -visible.size.width / 2, 0);
    NSIndexSet *wanted = [_layout pagesIntersectingRect:expanded];
    for (NSNumber *key in [_pageViews allKeys]) {
        if ([wanted containsIndex:key.unsignedIntegerValue])
            continue;
        RevenantPDFPageView *view = _pageViews[key];
        [view removeFromSuperview];
        [_reusablePageViews addObject:view];
        [_pageViews removeObjectForKey:key];
    }
    [wanted enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        NSNumber *key = @(index);
        RevenantPDFPageView *view = self->_pageViews[key];
        if (view == nil) {
            view = [self->_reusablePageViews lastObject];
            if (view != nil)
                [self->_reusablePageViews removeLastObject];
            else
                view = [[RevenantPDFPageView alloc] initWithFrame:CGRectZero];
            view.owner = self;
            view.render = nil;
            self->_pageViews[key] = view;
            [self->_documentView addSubview:view];
        }
        CGRect frame = [self->_layout frameOfPageAtIndex:index];
        if (!CGRectEqualToRect(view.frame, frame)) {
            view.frame = frame;
            [self revenant_configureShadowOf:view];
        }
        RevenantPDFPageRender *render = view.render;
        if (render != nil && render.generation == self->_renderGeneration && render.page == [self->_document pageAtIndex:index])
            return;
        PDFPage *page = [self->_document pageAtIndex:index];
        RevenantPDFPageRender *updated = [[RevenantPDFPageRender alloc] init];
        updated.page = page;
        updated.size = frame.size;
        updated.scale = self->_scaleFactor;
        updated.box = self->_displayBox;
        updated.quality = RevenantPDFInterpolationQuality(self->_interpolationQuality);
        updated.highlights = [self revenant_highlightsForPage:page];
        updated.generation = self->_renderGeneration;
        view.render = updated;
        [self revenant_configureShadowOf:view];
        [view setNeedsDisplay];
    }];
    _updating = NO;
}

- (void)revenant_scrolled
{
    if (_updating || _document == nil || _layout == nil || !_framesValid)
        return;
    [self revenant_updatePageViews];
    CGRect visible = _scrollView.bounds;
    NSIndexSet *indexes = [_layout pagesIntersectingRect:visible];
    if (![indexes isEqualToIndexSet:_visibleIndexes]) {
        _visibleIndexes = indexes;
        [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewVisiblePagesChangedNotification object:self];
    }
    if (_programmaticScrolls > 0 || ![self revenant_continuous])
        return;
    NSUInteger probe = [_layout pageNearestToPoint:CGPointMake(CGRectGetMidX(visible), CGRectGetMidY(visible))];
    NSUInteger leading = probe == NSNotFound ? NSNotFound : [self revenant_leadingIndexOfRowWithPage:probe];
    if (leading != NSNotFound && leading != _currentIndex) {
        _currentIndex = leading;
        [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewPageChangedNotification object:self];
    }
}

- (NSArray<PDFPage *> *)visiblePages
{
    [self revenant_ensureFrames];
    NSMutableArray<PDFPage *> *pages = [NSMutableArray array];
    [[_layout pagesIntersectingRect:_scrollView.bounds] enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        PDFPage *page = [self->_document pageAtIndex:index];
        if (page != nil)
            [pages addObject:page];
    }];
    return pages;
}

- (void)layoutDocumentView
{
    _framesValid = NO;
    [self revenant_relayout];
}

- (void)annotationsChangedOnPage:(PDFPage *)page
{
    NSUInteger index = [_document indexForPage:page];
    if (index == NSNotFound)
        return;
    [_pageViews[@(index)] setNeedsDisplay];
}

- (CGSize)rowSizeForPage:(PDFPage *)page
{
    [self revenant_ensureFrames];
    NSUInteger index = [_document indexForPage:page];
    NSRange row = [_layout pagesSharingRowWithPageAtIndex:index];
    if (row.location == NSNotFound)
        return CGSizeZero;
    CGRect united = CGRectNull;
    for (NSUInteger member = row.location; member < NSMaxRange(row); member++)
        united = CGRectUnion(united, [_layout frameOfPageAtIndex:member]);
    return CGRectIsNull(united) ? CGSizeZero : united.size;
}

- (void)revenant_invalidateLayout
{
    _layoutDirty = YES;
    _framesValid = NO;
    if (_document == nil)
        return;
    [self revenant_prepareLayout];
    NSUInteger current = _currentIndex == NSNotFound ? NSNotFound : [self revenant_leadingIndexOfRowWithPage:_currentIndex];
    _currentIndex = current;
    if (_autoScales && !CGRectIsEmpty(self.bounds))
        _scaleFactor = [self scaleFactorForSizeToFit];
    [self revenant_relayout];
    if (current != NSNotFound)
        [self revenant_scrollToIndex:current];
    [self setNeedsLayout];
}

- (void)setDisplayMode:(NSInteger)displayMode
{
    if (_displayMode == displayMode)
        return;
    _displayMode = displayMode;
    [self revenant_invalidateLayout];
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewDisplayModeChangedNotification object:self];
}

- (void)setDisplayDirection:(NSInteger)displayDirection
{
    if (_displayDirection == displayDirection)
        return;
    _displayDirection = displayDirection;
    [self revenant_invalidateLayout];
}

- (void)setDisplaysPageBreaks:(BOOL)displaysPageBreaks
{
    if (_displaysPageBreaks == displaysPageBreaks)
        return;
    _displaysPageBreaks = displaysPageBreaks;
    [self revenant_invalidateLayout];
}

- (UIEdgeInsets)pageBreakMargins
{
    return _displaysPageBreaks ? _pageBreakMargins : UIEdgeInsetsZero;
}

- (void)setPageBreakMargins:(UIEdgeInsets)pageBreakMargins
{
    UIEdgeInsets clamped = UIEdgeInsetsMake(MAX(pageBreakMargins.top, 0), MAX(pageBreakMargins.left, 0), MAX(pageBreakMargins.bottom, 0), MAX(pageBreakMargins.right, 0));
    if (UIEdgeInsetsEqualToEdgeInsets(_pageBreakMargins, clamped))
        return;
    _pageBreakMargins = clamped;
    [self revenant_invalidateLayout];
}

- (void)setDisplaysAsBook:(BOOL)displaysAsBook
{
    if (_displaysAsBook == displaysAsBook)
        return;
    _displaysAsBook = displaysAsBook;
    [self revenant_invalidateLayout];
}

- (void)setDisplaysRTL:(BOOL)displaysRTL
{
    if (_displaysRTL == displaysRTL)
        return;
    _displaysRTL = displaysRTL;
    [self revenant_invalidateLayout];
}

- (void)setDisplayBox:(NSInteger)displayBox
{
    if (_displayBox == displayBox)
        return;
    _displayBox = displayBox;
    [self revenant_invalidateLayout];
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewDisplayBoxChangedNotification object:self];
}

- (void)setInterpolationQuality:(NSInteger)interpolationQuality
{
    _interpolationQuality = interpolationQuality;
    _renderGeneration++;
    [self revenant_updatePageViews];
}

- (void)enablePageShadows:(BOOL)enabled
{
    _pageShadowsEnabled = enabled;
    for (RevenantPDFPageView *view in _pageViews.allValues)
        [self revenant_configureShadowOf:view];
}

- (NSArray<PDFSelection *> *)highlightedSelections
{
    return _highlightedSelections;
}

- (void)setHighlightedSelections:(NSArray<PDFSelection *> *)highlightedSelections
{
    _highlightedSelections = [highlightedSelections copy];
    _renderGeneration++;
    [self revenant_updatePageViews];
}

- (void)setCurrentSelection:(PDFSelection *)selection
{
    [self setCurrentSelection:selection animate:NO];
}

- (void)setCurrentSelection:(PDFSelection *)selection animate:(BOOL)animate
{
    _currentSelection = selection;
    _renderGeneration++;
    [self revenant_updatePageViews];
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewSelectionChangedNotification object:self];
}

- (void)clearSelection
{
    [self setCurrentSelection:nil animate:NO];
}

- (void)selectAll:(id)sender
{
    if (_document == nil)
        return;
    PDFSelection *selection = [[PDFSelection alloc] initWithDocument:_document];
    for (NSUInteger index = 0; index < _document.pageCount; index++) {
        PDFPage *page = [_document pageAtIndex:index];
        NSUInteger length = page.string.length;
        if (length > 0)
            [selection revenant_addSpanOnPage:page range:NSMakeRange(0, length)];
    }
    [self setCurrentSelection:selection animate:NO];
}

- (void)scrollSelectionToVisible:(id)sender
{
    if (_currentSelection != nil)
        [self goToSelection:_currentSelection];
}

- (void)copy:(id)sender
{
    NSString *text = _currentSelection.string;
    if (text.length == 0)
        return;
    if (!_document.allowsCopying) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewCopyPermissionNotification object:self];
        return;
    }
    [UIPasteboard generalPasteboard].string = text;
}

- (void)drawPage:(PDFPage *)page toContext:(CGContextRef)context
{
    [page drawWithBox:_displayBox toContext:context];
}

- (void)drawPagePost:(PDFPage *)page toContext:(CGContextRef)context
{
}

- (void)revenant_scrollToIndex:(NSUInteger)index
{
    [self revenant_ensureFrames];
    CGRect frame = [_layout frameOfPageAtIndex:index];
    if (CGRectIsNull(frame))
        return;
    UIEdgeInsets inset = _scrollView.contentInset;
    CGPoint offset = _scrollView.contentOffset;
    UIEdgeInsets margins = self.pageBreakMargins;
    CGFloat leading = [self revenant_vertical] ? margins.top : margins.left;
    if ([self revenant_continuous]) {
        if ([self revenant_vertical])
            offset.y = frame.origin.y - leading - inset.top;
        else
            offset.x = frame.origin.x - leading - inset.left;
    } else {
        offset = CGPointMake(-inset.left, -inset.top);
    }
    [self revenant_scrollTo:offset];
}

- (void)revenant_moveToIndex:(NSUInteger)index
{
    if (_document == nil || index >= _document.pageCount)
        return;
    _programmaticScrolls++;
    [self revenant_setCurrentIndex:index];
    [self revenant_scrollToIndex:index];
    _programmaticScrolls--;
}

- (PDFDestination *)currentDestination
{
    PDFPage *page = self.currentPage;
    if (page == nil)
        return nil;
    CGPoint corner = CGPointMake(_scrollView.contentOffset.x + _scrollView.contentInset.left, _scrollView.contentOffset.y + _scrollView.contentInset.top);
    CGPoint point = CGPointApplyAffineTransform(corner, CGAffineTransformInvert([self revenant_transformForPage:page]));
    return [[PDFDestination alloc] initWithPage:page atPoint:point];
}

- (void)revenant_record
{
    PDFDestination *destination = self.currentDestination;
    if (destination == nil)
        return;
    if (_historyIndex < 0) {
        [_history removeAllObjects];
        [_history addObject:destination];
        _historyIndex = 0;
        return;
    }
    [_history removeObjectsInRange:NSMakeRange(_historyIndex + 1, _history.count - _historyIndex - 1)];
    [_history addObject:destination];
    if (_history.count > RevenantPDFHistoryLimit)
        [_history removeObjectAtIndex:0];
    _historyIndex = (NSInteger)_history.count - 1;
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewChangedHistoryNotification object:self];
}

- (void)revenant_ensureHistoryHasOrigin
{
    if (_historyIndex < 0)
        [self revenant_record];
}

- (void)revenant_navigateToDestination:(PDFDestination *)destination
{
    PDFPage *page = destination.page;
    NSUInteger index = [_document indexForPage:page];
    if (index == NSNotFound)
        return;
    _programmaticScrolls++;
    [self revenant_setCurrentIndex:index];
    [self revenant_ensureFrames];
    CGRect frame = [_layout frameOfPageAtIndex:index];
    CGPoint offset = _scrollView.contentOffset;
    UIEdgeInsets inset = _scrollView.contentInset;
    if (!CGRectIsNull(frame)) {
        CGPoint point = destination.point;
        CGFloat unspecified = kPDFDestinationUnspecifiedValue;
        CGPoint anchor = CGPointApplyAffineTransform(CGPointMake(point.x == unspecified ? 0 : point.x, point.y == unspecified ? CGRectGetMaxY([page boundsForBox:(CGPDFBox)_displayBox]) : point.y), [self revenant_transformForPage:page]);
        if (point.x != unspecified)
            offset.x = anchor.x - inset.left;
        else if (![self revenant_vertical])
            offset.x = frame.origin.x - inset.left;
        if (point.y != unspecified)
            offset.y = anchor.y - inset.top;
        else if ([self revenant_vertical])
            offset.y = frame.origin.y - inset.top;
    }
    [self revenant_scrollTo:offset];
    _programmaticScrolls--;
}

- (void)goToDestination:(PDFDestination *)destination
{
    [self revenant_ensureHistoryHasOrigin];
    [self revenant_navigateToDestination:destination];
    [self revenant_record];
}

- (void)goToPage:(PDFPage *)page
{
    NSUInteger index = [_document indexForPage:page];
    if (index == NSNotFound)
        return;
    [self revenant_ensureHistoryHasOrigin];
    [self revenant_moveToIndex:index];
    [self revenant_record];
}

- (void)goToRect:(CGRect)rect onPage:(PDFPage *)page
{
    NSUInteger index = [_document indexForPage:page];
    if (index == NSNotFound)
        return;
    [self revenant_ensureHistoryHasOrigin];
    _programmaticScrolls++;
    [self revenant_setCurrentIndex:index];
    [self revenant_ensureFrames];
    CGRect inDocument = CGRectApplyAffineTransform(rect, [self revenant_transformForPage:page]);
    CGSize size = _scrollView.bounds.size;
    [self revenant_scrollTo:CGPointMake(CGRectGetMidX(inDocument) - size.width / 2, CGRectGetMidY(inDocument) - size.height / 2)];
    _programmaticScrolls--;
    [self revenant_record];
}

- (void)goToSelection:(PDFSelection *)selection
{
    PDFPage *page = selection.pages.firstObject;
    if (page == nil)
        return;
    [self goToRect:[selection boundsForPage:page] onPage:page];
}

- (BOOL)canGoToFirstPage
{
    return _currentIndex != NSNotFound && _currentIndex > 0;
}

- (void)goToFirstPage:(id)sender
{
    if (_document.pageCount > 0)
        [self goToPage:[_document pageAtIndex:0]];
}

- (BOOL)canGoToLastPage
{
    return _currentIndex != NSNotFound && _currentIndex + 1 < _document.pageCount;
}

- (void)goToLastPage:(id)sender
{
    if (_document.pageCount > 0)
        [self goToPage:[_document pageAtIndex:_document.pageCount - 1]];
}

- (BOOL)canGoToNextPage
{
    if (_currentIndex == NSNotFound)
        return NO;
    [self revenant_prepareLayout];
    return [_layout firstPageOfRowAfterPageAtIndex:_currentIndex] != NSNotFound;
}

- (void)goToNextPage:(id)sender
{
    if (![self canGoToNextPage])
        return;
    [self goToPage:[_document pageAtIndex:[_layout firstPageOfRowAfterPageAtIndex:_currentIndex]]];
}

- (BOOL)canGoToPreviousPage
{
    if (_currentIndex == NSNotFound)
        return NO;
    [self revenant_prepareLayout];
    return [_layout firstPageOfRowBeforePageAtIndex:_currentIndex] != NSNotFound;
}

- (void)goToPreviousPage:(id)sender
{
    if (![self canGoToPreviousPage])
        return;
    [self goToPage:[_document pageAtIndex:[_layout firstPageOfRowBeforePageAtIndex:_currentIndex]]];
}

- (BOOL)canGoBack
{
    return _historyIndex > 0;
}

- (void)goBack:(id)sender
{
    if (![self canGoBack])
        return;
    _historyIndex--;
    [self revenant_navigateToDestination:_history[_historyIndex]];
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewChangedHistoryNotification object:self];
}

- (BOOL)canGoForward
{
    return _historyIndex >= 0 && _historyIndex + 1 < (NSInteger)_history.count;
}

- (void)goForward:(id)sender
{
    if (![self canGoForward])
        return;
    _historyIndex++;
    [self revenant_navigateToDestination:_history[_historyIndex]];
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFViewChangedHistoryNotification object:self];
}

@end
