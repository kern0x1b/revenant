#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    CGFloat top;
    CGFloat left;
    CGFloat bottom;
    CGFloat right;
} RevenantPDFInsets;

typedef NS_ENUM(NSInteger, RevenantPDFLayoutMode) {
    RevenantPDFLayoutSinglePage = 0,
    RevenantPDFLayoutSinglePageContinuous = 1,
    RevenantPDFLayoutTwoUp = 2,
    RevenantPDFLayoutTwoUpContinuous = 3,
};

typedef NS_ENUM(NSInteger, RevenantPDFLayoutDirection) {
    RevenantPDFLayoutVertical = 0,
    RevenantPDFLayoutHorizontal = 1,
};

@interface RevenantPDFLayout : NSObject

- (instancetype)initWithPageSizes:(const CGSize *)sizes
                            count:(NSUInteger)count
                      displayMode:(RevenantPDFLayoutMode)mode
                        direction:(RevenantPDFLayoutDirection)direction
                displaysPageBreaks:(BOOL)displaysPageBreaks
                          margins:(RevenantPDFInsets)margins
                      displaysAsBook:(BOOL)displaysAsBook
                      rightToLeft:(BOOL)rightToLeft NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) NSUInteger pageCount;
@property (nonatomic, readonly) CGSize contentSize;

- (void)layoutAtScale:(CGFloat)scale currentPage:(NSUInteger)currentPage crossExtent:(CGFloat)crossExtent;
- (CGFloat)fitScaleForViewSize:(CGSize)viewSize currentPage:(NSUInteger)currentPage;
- (CGRect)frameOfPageAtIndex:(NSUInteger)index;
- (NSIndexSet *)pagesIntersectingRect:(CGRect)rect;
- (NSUInteger)pageNearestToPoint:(CGPoint)point;
- (NSRange)pagesSharingRowWithPageAtIndex:(NSUInteger)index;
- (NSUInteger)firstPageOfRowAfterPageAtIndex:(NSUInteger)index;
- (NSUInteger)firstPageOfRowBeforePageAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
