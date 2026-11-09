#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "RevenantPDFLayout.h"
#import "check.h"

static const RevenantPDFInsets kMargins = {5, 4, 5, 4};

static void expect(BOOL ok, const char *name, NSString *seen)
{
    revenant_check(ok != revenant_negative, name, seen);
}

static void expect_rect(const char *name, CGRect actual, CGRect expected)
{
    expect(fabs(actual.origin.x - expected.origin.x) < 1e-6 && fabs(actual.origin.y - expected.origin.y) < 1e-6 &&
               fabs(actual.size.width - expected.size.width) < 1e-6 && fabs(actual.size.height - expected.size.height) < 1e-6,
           name, [NSString stringWithFormat:@"%@ is not %@", NSStringFromRect(actual), NSStringFromRect(expected)]);
}

static void expect_size(const char *name, CGSize actual, CGSize expected)
{
    expect(fabs(actual.width - expected.width) < 1e-6 && fabs(actual.height - expected.height) < 1e-6, name,
           [NSString stringWithFormat:@"%g x %g is not %g x %g", actual.width, actual.height, expected.width, expected.height]);
}

static RevenantPDFLayout *make(const CGSize *sizes, NSUInteger count, RevenantPDFLayoutMode mode, RevenantPDFLayoutDirection direction, BOOL breaks, BOOL book, BOOL rtl)
{
    return [[RevenantPDFLayout alloc] initWithPageSizes:sizes count:count displayMode:mode direction:direction displaysPageBreaks:breaks margins:kMargins displaysAsBook:book rightToLeft:rtl];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        CGSize mixed[3] = {{100, 200}, {200, 100}, {100, 200}};
        RevenantPDFLayout *column = make(mixed, 3, RevenantPDFLayoutSinglePageContinuous, RevenantPDFLayoutVertical, YES, NO, NO);
        [column layoutAtScale:1 currentPage:0 crossExtent:50];
        expect_size("a vertical column is as wide as its widest page plus the page break and as tall as the pages and breaks", column.contentSize, CGSizeMake(208, 530));
        expect_rect("the first page is centred across the column below the top margin", [column frameOfPageAtIndex:0], CGRectMake(54, 5, 100, 200));
        expect_rect("the widest page fills the column between the side margins", [column frameOfPageAtIndex:1], CGRectMake(4, 215, 200, 100));
        expect_rect("the third page follows after the margins of both pages", [column frameOfPageAtIndex:2], CGRectMake(54, 325, 100, 200));
        [column layoutAtScale:1 currentPage:0 crossExtent:408];
        expect_size("a view wider than the pages widens the content to the view", column.contentSize, CGSizeMake(408, 530));
        expect_rect("pages stay centred in a wider view", [column frameOfPageAtIndex:0], CGRectMake(154, 5, 100, 200));
        [column layoutAtScale:2 currentPage:0 crossExtent:50];
        expect_rect("a scale multiplies page sizes but not the page breaks", [column frameOfPageAtIndex:1], CGRectMake(4, 5 + 400 + 10, 400, 200));
        expect_size("a scaled column grows with the scale", column.contentSize, CGSizeMake(408, 10 + 1000 + 20));
        expect([column fitScaleForViewSize:CGSizeMake(408, 800) currentPage:0] == 2.0, "fit width of a continuous column is set by the widest page between the margins", @"");
        expect([column pageCount] == 3, "the layout counts its pages", @"");

        [column layoutAtScale:1 currentPage:0 crossExtent:50];
        NSIndexSet *top = [column pagesIntersectingRect:CGRectMake(0, 0, 208, 100)];
        expect([top isEqualToIndexSet:[NSIndexSet indexSetWithIndex:0]], "a rect over the first page finds only it", [top description]);
        NSMutableIndexSet *both = [NSMutableIndexSet indexSetWithIndex:0];
        [both addIndex:1];
        NSIndexSet *across = [column pagesIntersectingRect:CGRectMake(0, 100, 208, 200)];
        expect([across isEqualToIndexSet:both], "a rect over a page break finds both neighbours", [across description]);
        expect([column pageNearestToPoint:CGPointMake(100, 208)] == 0, "a point in the break takes the page above when it is nearer", @"");
        expect([column pageNearestToPoint:CGPointMake(100, 214)] == 1, "a point in the break takes the page below when it is nearer", @"");
        expect([column pageNearestToPoint:CGPointMake(-500, 9000)] == 2, "a point far outside takes the nearest page", @"");
        expect([column pageNearestToPoint:CGPointMake(100, 100)] == 0, "a point on a page takes that page", @"");

        RevenantPDFLayout *tight = make(mixed, 3, RevenantPDFLayoutSinglePageContinuous, RevenantPDFLayoutVertical, NO, NO, NO);
        [tight layoutAtScale:1 currentPage:0 crossExtent:0];
        expect_size("without page breaks the content is exactly the pages", tight.contentSize, CGSizeMake(200, 500));
        expect_rect("without page breaks the second page abuts the first", [tight frameOfPageAtIndex:1], CGRectMake(0, 200, 200, 100));

        CGSize four[4] = {{100, 200}, {100, 200}, {100, 200}, {100, 200}};
        RevenantPDFLayout *pairs = make(four, 4, RevenantPDFLayoutTwoUpContinuous, RevenantPDFLayoutVertical, YES, NO, NO);
        [pairs layoutAtScale:1 currentPage:0 crossExtent:0];
        expect_size("two-up rows hold two pages and the break between them", pairs.contentSize, CGSizeMake(216, 420));
        expect_rect("the left page of the first row", [pairs frameOfPageAtIndex:0], CGRectMake(4, 5, 100, 200));
        expect_rect("the right page of the first row", [pairs frameOfPageAtIndex:1], CGRectMake(112, 5, 100, 200));
        expect_rect("the second row starts below the first", [pairs frameOfPageAtIndex:2], CGRectMake(4, 215, 100, 200));
        expect([pairs firstPageOfRowAfterPageAtIndex:1] == 2, "the next row starts with its first page", @"");
        expect([pairs firstPageOfRowAfterPageAtIndex:3] == NSNotFound, "the last row has no next row", @"");
        expect([pairs firstPageOfRowBeforePageAtIndex:3] == 0, "the previous row starts with its first page", @"");
        expect([pairs firstPageOfRowBeforePageAtIndex:0] == NSNotFound, "the first row has no previous row", @"");
        expect(NSEqualRanges([pairs pagesSharingRowWithPageAtIndex:3], NSMakeRange(2, 2)), "the pages of a row are the two it holds", NSStringFromRange([pairs pagesSharingRowWithPageAtIndex:3]));

        RevenantPDFLayout *reversed = make(four, 4, RevenantPDFLayoutTwoUpContinuous, RevenantPDFLayoutVertical, YES, NO, YES);
        [reversed layoutAtScale:1 currentPage:0 crossExtent:0];
        expect_rect("right to left puts the first page on the right", [reversed frameOfPageAtIndex:0], CGRectMake(112, 5, 100, 200));
        expect_rect("right to left puts the second page on the left", [reversed frameOfPageAtIndex:1], CGRectMake(4, 5, 100, 200));

        CGSize three[3] = {{100, 200}, {100, 200}, {100, 200}};
        RevenantPDFLayout *book = make(three, 3, RevenantPDFLayoutTwoUpContinuous, RevenantPDFLayoutVertical, YES, YES, NO);
        [book layoutAtScale:1 currentPage:0 crossExtent:0];
        expect(NSEqualRanges([book pagesSharingRowWithPageAtIndex:0], NSMakeRange(0, 1)), "a book shows its cover alone", NSStringFromRange([book pagesSharingRowWithPageAtIndex:0]));
        expect(NSEqualRanges([book pagesSharingRowWithPageAtIndex:2], NSMakeRange(1, 2)), "a book pairs the pages after the cover", NSStringFromRange([book pagesSharingRowWithPageAtIndex:2]));
        expect_rect("a cover is centred in its own row", [book frameOfPageAtIndex:0], CGRectMake(58, 5, 100, 200));

        CGSize two[2] = {{100, 200}, {200, 100}};
        RevenantPDFLayout *strip = make(two, 2, RevenantPDFLayoutSinglePageContinuous, RevenantPDFLayoutHorizontal, YES, NO, NO);
        [strip layoutAtScale:1 currentPage:0 crossExtent:0];
        expect_size("a horizontal strip is as tall as its tallest page plus margins", strip.contentSize, CGSizeMake(316, 210));
        expect_rect("the first page leads the strip", [strip frameOfPageAtIndex:0], CGRectMake(4, 5, 100, 200));
        expect_rect("the second page follows centred on the cross axis", [strip frameOfPageAtIndex:1], CGRectMake(112, 55, 200, 100));
        expect([strip fitScaleForViewSize:CGSizeMake(500, 410) currentPage:0] == 2.0, "fit height of a horizontal strip is set by the tallest page", @"");
        RevenantPDFLayout *backwards = make(two, 2, RevenantPDFLayoutSinglePageContinuous, RevenantPDFLayoutHorizontal, YES, NO, YES);
        [backwards layoutAtScale:1 currentPage:0 crossExtent:0];
        expect_rect("right to left puts the first page at the end of a strip", [backwards frameOfPageAtIndex:0], CGRectMake(212, 5, 100, 200));
        expect_rect("right to left puts the last page at the start of a strip", [backwards frameOfPageAtIndex:1], CGRectMake(4, 55, 200, 100));

        RevenantPDFLayout *single = make(mixed, 3, RevenantPDFLayoutSinglePage, RevenantPDFLayoutVertical, YES, NO, NO);
        [single layoutAtScale:1 currentPage:1 crossExtent:0];
        expect(CGRectIsNull([single frameOfPageAtIndex:0]) && CGRectIsNull([single frameOfPageAtIndex:2]), "a single page layout places only the current page", @"");
        expect_rect("the current page sits alone with its margins", [single frameOfPageAtIndex:1], CGRectMake(4, 5, 200, 100));
        expect_size("the content of a single page is that page and its margins", single.contentSize, CGSizeMake(208, 110));
        expect([single fitScaleForViewSize:CGSizeMake(408, 300) currentPage:1] == 2.0, "best fit of a single page takes the smaller of width and height fits", @"");
        expect([single fitScaleForViewSize:CGSizeMake(1000, 220) currentPage:1] == 2.1, "best fit is limited by the height when the view is wide", [NSString stringWithFormat:@"%g", [single fitScaleForViewSize:CGSizeMake(1000, 220) currentPage:1]]);
        expect([single pagesIntersectingRect:CGRectMake(0, 0, 1000, 1000)].count == 1, "only the placed page can be found", @"");

        RevenantPDFLayout *empty = make(NULL, 0, RevenantPDFLayoutSinglePageContinuous, RevenantPDFLayoutVertical, YES, NO, NO);
        [empty layoutAtScale:1 currentPage:0 crossExtent:100];
        expect_size("an empty layout has the padding and the cross extent", empty.contentSize, CGSizeMake(100, 10));
        expect([empty pageNearestToPoint:CGPointZero] == NSNotFound, "an empty layout has no nearest page", @"");
        expect([empty fitScaleForViewSize:CGSizeMake(100, 100) currentPage:0] == 1, "an empty layout fits at actual size", @"");
    }
    return revenant_finish();
}
