#import <UIKit/UIKit.h>
#import "RevenantPDFKit.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PDFViewDocumentChangedNotification;
extern NSString *const PDFViewChangedHistoryNotification;
extern NSString *const PDFViewPageChangedNotification;
extern NSString *const PDFViewScaleChangedNotification;
extern NSString *const PDFViewAnnotationHitNotification;
extern NSString *const PDFViewCopyPermissionNotification;
extern NSString *const PDFViewAnnotationWillHitNotification;
extern NSString *const PDFViewSelectionChangedNotification;
extern NSString *const PDFViewDisplayModeChangedNotification;
extern NSString *const PDFViewDisplayBoxChangedNotification;
extern NSString *const PDFViewVisiblePagesChangedNotification;

@interface PDFView : UIView <UIGestureRecognizerDelegate>

@property (nonatomic, strong, nullable) PDFDocument *document;

@property (nonatomic, readonly) BOOL canGoToFirstPage;
- (void)goToFirstPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoToLastPage;
- (void)goToLastPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoToNextPage;
- (void)goToNextPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoToPreviousPage;
- (void)goToPreviousPage:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoBack;
- (void)goBack:(nullable id)sender;
@property (nonatomic, readonly) BOOL canGoForward;
- (void)goForward:(nullable id)sender;

@property (nonatomic, readonly, nullable) PDFPage *currentPage;
- (void)goToPage:(PDFPage *)page;
@property (nonatomic, readonly, nullable) PDFDestination *currentDestination;
- (void)goToDestination:(PDFDestination *)destination;
- (void)goToSelection:(PDFSelection *)selection;
- (void)goToRect:(CGRect)rect onPage:(PDFPage *)page;

@property (nonatomic) NSInteger displayMode;
@property (nonatomic) NSInteger displayDirection;
@property (nonatomic) BOOL displaysPageBreaks;
@property (nonatomic) UIEdgeInsets pageBreakMargins;
@property (nonatomic) NSInteger displayBox;
@property (nonatomic) BOOL displaysAsBook;
@property (nonatomic) BOOL displaysRTL;
@property (nonatomic) NSInteger interpolationQuality;
@property (nonatomic, setter=enablePageShadows:) BOOL pageShadowsEnabled;
@property (nonatomic, weak, nullable) id delegate;

@property (nonatomic) CGFloat scaleFactor;
@property (nonatomic) CGFloat minScaleFactor;
@property (nonatomic) CGFloat maxScaleFactor;
@property (nonatomic) BOOL autoScales;
@property (nonatomic, readonly) CGFloat scaleFactorForSizeToFit;
- (void)zoomIn:(nullable id)sender;
@property (nonatomic, readonly) BOOL canZoomIn;
- (void)zoomOut:(nullable id)sender;
@property (nonatomic, readonly) BOOL canZoomOut;

- (void)performAction:(PDFAction *)action;

@property (nonatomic, strong, nullable) PDFSelection *currentSelection;
- (void)setCurrentSelection:(nullable PDFSelection *)selection animate:(BOOL)animate;
- (void)clearSelection;
- (void)selectAll:(nullable id)sender;
- (void)scrollSelectionToVisible:(nullable id)sender;
@property (nonatomic, copy, nullable) NSArray<PDFSelection *> *highlightedSelections;

- (void)drawPage:(PDFPage *)page toContext:(CGContextRef)context;
- (void)drawPagePost:(PDFPage *)page toContext:(CGContextRef)context;
- (void)copy:(nullable id)sender;

- (nullable PDFPage *)pageForPoint:(CGPoint)point nearest:(BOOL)nearest;
- (CGPoint)convertPoint:(CGPoint)point toPage:(PDFPage *)page;
- (CGRect)convertRect:(CGRect)rect toPage:(PDFPage *)page;
- (CGPoint)convertPoint:(CGPoint)point fromPage:(PDFPage *)page;
- (CGRect)convertRect:(CGRect)rect fromPage:(PDFPage *)page;

@property (nonatomic, readonly, nullable) UIView *documentView;
- (void)layoutDocumentView;
- (void)annotationsChangedOnPage:(PDFPage *)page;
- (CGSize)rowSizeForPage:(PDFPage *)page;
@property (nonatomic, readonly) NSArray<PDFPage *> *visiblePages;

@end

NS_ASSUME_NONNULL_END
