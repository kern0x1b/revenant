#import <UIKit/UIKit.h>
#import "RevenantPDFView.h"
#import "check.h"

static void expect(BOOL ok, const char *name, NSString *seen)
{
    revenant_check(ok != revenant_negative, name, seen);
}

static NSData *makeDocument(void)
{
    NSMutableData *data = [NSMutableData data];
    UIGraphicsBeginPDFContextToData(data, CGRectZero, nil);
    CGRect boxes[3] = {CGRectMake(0, 0, 200, 300), CGRectMake(0, 0, 300, 200), CGRectMake(0, 0, 200, 300)};
    NSArray<NSString *> *lines = @[@"Alpha one", @"Beta two alpha", @"Gamma three"];
    for (NSUInteger index = 0; index < 3; index++) {
        UIGraphicsBeginPDFPageWithInfo(boxes[index], nil);
        [lines[index] drawAtPoint:CGPointMake(20, 20) withFont:[UIFont fontWithName:@"Helvetica" size:24]];
    }
    UIGraphicsEndPDFContext();
    return data;
}

static void spin(BOOL (^done)(void), NSTimeInterval limit)
{
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:limit];
    while (!done() && [end timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

@interface Finder : NSObject
@property (nonatomic) NSMutableArray *matches;
@property (nonatomic) NSInteger ended;
@property (nonatomic) NSInteger began;
@end

@implementation Finder

- (instancetype)init
{
    self = [super init];
    _matches = [NSMutableArray array];
    return self;
}

- (void)didMatchString:(PDFSelection *)instance
{
    [self.matches addObject:instance];
}

- (void)documentDidBeginDocumentFind:(NSNotification *)notification
{
    self.began++;
}

- (void)documentDidEndDocumentFind:(NSNotification *)notification
{
    self.ended++;
}

@end

@interface Counter : NSObject
@property (nonatomic) NSInteger pages;
@property (nonatomic) NSInteger scales;
@property (nonatomic) NSInteger selections;
@end

@implementation Counter

- (void)page:(NSNotification *)notification
{
    self.pages++;
}

- (void)scale:(NSNotification *)notification
{
    self.scales++;
}

- (void)selection:(NSNotification *)notification
{
    self.selections++;
}

@end

static BOOL near(CGFloat a, CGFloat b)
{
    return fabs(a - b) < 0.01;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        PDFDocument *document = [[PDFDocument alloc] initWithData:makeDocument()];
        expect(document != nil && document.pageCount == 3, "a generated three page document opens", [NSString stringWithFormat:@"%lu pages", (unsigned long)document.pageCount]);
        PDFPage *last = [document pageAtIndex:2];
        PDFPage *first = [document pageAtIndex:0];
        PDFPage *middle = [document pageAtIndex:1];
        expect([document indexForPage:last] == 2 && [document indexForPage:first] == 0 && [document pageAtIndex:2] == last, "pages read out of order keep their own index", [NSString stringWithFormat:@"%lu %lu", (unsigned long)[document indexForPage:last], (unsigned long)[document indexForPage:first]]);
        expect([first.string rangeOfString:@"Alpha one"].location != NSNotFound, "page text is extracted", first.string ?: @"nil");
        expect([document findString:@"alpha" withOptions:NSCaseInsensitiveSearch].count == 2, "a synchronous find counts both matches", @"");

        Finder *finder = [[Finder alloc] init];
        document.delegate = finder;
        [[NSNotificationCenter defaultCenter] addObserver:finder selector:@selector(documentDidEndDocumentFind:) name:PDFDocumentDidEndFindNotification object:document];
        [document beginFindString:@"alpha" withOptions:NSCaseInsensitiveSearch];
        expect(document.isFinding, "a find is running after it begins", @"");
        spin(^BOOL { return finder.ended > 0; }, 5);
        expect(finder.matches.count == 2 && finder.ended == 1 && !document.isFinding, "an asynchronous find reports each match and ends once", [NSString stringWithFormat:@"%lu matches, %ld ended", (unsigned long)finder.matches.count, (long)finder.ended]);
        [document beginFindString:@"gamma" withOptions:NSCaseInsensitiveSearch];
        [document cancelFindString];
        spin(^BOOL { return NO; }, 0.3);
        expect(finder.ended == 1 && !document.isFinding, "a cancelled find does not end", [NSString stringWithFormat:@"%ld ended", (long)finder.ended]);
        document.delegate = nil;

        Counter *counter = [[Counter alloc] init];
        PDFView *view = [[PDFView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        [[NSNotificationCenter defaultCenter] addObserver:counter selector:@selector(page:) name:PDFViewPageChangedNotification object:view];
        [[NSNotificationCenter defaultCenter] addObserver:counter selector:@selector(scale:) name:PDFViewScaleChangedNotification object:view];
        [[NSNotificationCenter defaultCenter] addObserver:counter selector:@selector(selection:) name:PDFViewSelectionChangedNotification object:view];
        expect(view.displayMode == 1 && view.displayDirection == 0 && view.displaysPageBreaks && view.displayBox == 1 && view.scaleFactor == 1 && view.minScaleFactor == 0.1 && view.maxScaleFactor == 100 && !view.autoScales && view.pageShadowsEnabled, "a new view has the defaults of the header", @"");
        expect(view.pageBreakMargins.top == 4.75 && view.pageBreakMargins.left == 4 && view.document == nil && view.currentPage == nil, "the page break margins default and there is no page", @"");
        view.displaysPageBreaks = NO;
        expect(UIEdgeInsetsEqualToEdgeInsets(view.pageBreakMargins, UIEdgeInsetsZero), "page break margins read zero without page breaks", @"");
        view.displaysPageBreaks = YES;

        view.autoScales = YES;
        view.document = document;
        [view layoutIfNeeded];
        CGFloat fit = (320 - 8) / 300.0;
        expect(near(view.scaleFactorForSizeToFit, fit) && near(view.scaleFactor, fit), "automatic scaling fits the widest page between the margins", [NSString stringWithFormat:@"%g %g", view.scaleFactor, view.scaleFactorForSizeToFit]);
        expect(view.currentPage == first && view.canGoToNextPage && !view.canGoToPreviousPage, "the first page is current at the start", @"");
        UIView *pages = view.documentView;
        expect(pages.subviews.count >= 1 && near(pages.subviews.firstObject.frame.size.width, 200 * fit), "the page views have the scaled size of their pages", [NSString stringWithFormat:@"%lu views", (unsigned long)pages.subviews.count]);
        expect(view.visiblePages.count >= 1 && view.visiblePages.firstObject == first, "the visible pages start with the first", @"");

        [view goToPage:last];
        expect(view.currentPage == last && counter.pages >= 1 && !view.canGoToNextPage && view.canGoToPreviousPage, "going to a page makes it current and posts the change", [NSString stringWithFormat:@"%ld posts", (long)counter.pages]);
        [view goToPreviousPage:nil];
        expect(view.currentPage == middle, "the previous page is the one before", @"");
        expect(view.canGoBack && !view.canGoForward, "history can go back after two moves", @"");
        [view goBack:nil];
        expect(view.currentPage == last && view.canGoForward, "going back returns to the earlier page", @"");
        [view goToFirstPage:nil];
        expect(view.currentPage == first && !view.canGoToFirstPage, "the first page can be reached directly", @"");

        CGPoint onPage = CGPointMake(100, 150);
        CGPoint inView = [view convertPoint:onPage fromPage:first];
        CGPoint back = [view convertPoint:inView toPage:first];
        expect(near(back.x, onPage.x) && near(back.y, onPage.y), "a point converts to the view and back", [NSString stringWithFormat:@"%g,%g", back.x, back.y]);
        expect([view pageForPoint:inView nearest:NO] == first, "the page at a converted point is its page", @"");
        CGRect rect = [view convertRect:CGRectMake(0, 0, 200, 300) fromPage:first];
        expect(near(rect.size.width, 200 * fit) && near(rect.size.height, 300 * fit), "a page rect converts to its scaled size", NSStringFromCGRect(rect));

        [view setScaleFactor:2];
        expect(view.scaleFactor == 2 && !view.autoScales && counter.scales >= 1, "setting the scale turns automatic scaling off and posts the change", [NSString stringWithFormat:@"%g", view.scaleFactor]);
        [view setScaleFactor:1000];
        expect(view.scaleFactor == 100 && !view.canZoomIn && view.canZoomOut, "the scale is limited by the maximum", [NSString stringWithFormat:@"%g", view.scaleFactor]);
        view.minScaleFactor = 0.5;
        [view setScaleFactor:0.1];
        expect(view.scaleFactor == 0.5 && !view.canZoomOut, "the scale is limited by the minimum", [NSString stringWithFormat:@"%g", view.scaleFactor]);
        [view setScaleFactor:1];
        [view zoomIn:nil];
        expect(near(view.scaleFactor, M_SQRT2), "zooming in multiplies the scale by the root of two", [NSString stringWithFormat:@"%g", view.scaleFactor]);
        [view setScaleFactor:1];

        view.displayMode = 3;
        CGSize row = [view rowSizeForPage:first];
        expect(near(row.width, 500 + 8) && near(row.height, 300), "a two-up row holds both pages and the break between", NSStringFromCGSize(row));
        view.displayMode = 1;

        NSArray<PDFSelection *> *matches = [document findString:@"alpha" withOptions:NSCaseInsensitiveSearch];
        view.highlightedSelections = matches;
        expect(view.highlightedSelections.count == 2, "highlighted selections read back", @"");
        view.currentSelection = matches.firstObject;
        expect(view.currentSelection == matches.firstObject && counter.selections >= 1, "the current selection is kept and posts the change", @"");
        [view goToSelection:matches.lastObject];
        expect(view.currentPage == middle, "going to a selection makes its page current", @"");
        view.highlightedSelections = nil;
        [view clearSelection];
        expect(view.currentSelection == nil, "the selection clears", @"");

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(200, 300), YES, 1);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, 200, 300));
        CGContextTranslateCTM(context, 0, 300);
        CGContextScaleCTM(context, 1, -1);
        [view drawPage:first toContext:context];
        UIImage *drawn = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CGImageRef image = drawn.CGImage;
        size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image);
        const unsigned char *bytes = pixels.bytes;
        NSUInteger dark = 0;
        for (size_t offset = 0; offset < width * height * 4; offset += 4)
            dark += (bytes[offset] < 128 && bytes[offset + 1] < 128 && bytes[offset + 2] < 128);
        CGContextRelease(bitmap);
        CGColorSpaceRelease(space);
        expect(dark > 40 && bytes[(height - 1) * width * 4] > 200, "the page draws its text on a white page", [NSString stringWithFormat:@"%lu dark pixels", (unsigned long)dark]);
    }
    return revenant_finish();
}
