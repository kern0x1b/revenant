// A collection view shows an element whose frame reaches past both ends of the rectangle it checks.
// iOS 6's UICollectionViewData files the attributes a layout answers under the pages of its frame's
// corners inside that rectangle and so loses such an element; the compositional layout gives it a
// second attributes first, its frame cut to the rectangle (facts/UIKit/UICollectionViewCompositionalLayout.md).
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import "check.h"

static CGSize const kContent = {320, 244};

@interface CharonPlainLayout : UICollectionViewLayout
@end

@implementation CharonPlainLayout
- (CGSize)collectionViewContentSize { return kContent; }
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path
{
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:path];
    attributes.frame = CGRectMake(234, -1, 160, 246);
    return attributes;
}
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    return @[[self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]];
}
@end

@interface CharonPagesSource : NSObject <UICollectionViewDataSource>
@property (nonatomic) NSInteger count;
@end

@implementation CharonPagesSource
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return self.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path
{
    return [view dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:path];
}
@end

static UICollectionView *show(UICollectionViewLayout *layout, CharonPagesSource *source, CGFloat height)
{
    UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, height) collectionViewLayout:layout];
    [view registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    view.dataSource = source;
    UIWindow *window = [[UIWindow alloc] initWithFrame:view.frame];
    [window addSubview:view];
    [window makeKeyAndVisible];
    [view reloadData];
    [view layoutIfNeeded];
    return view;
}

static void settle(UICollectionView *view)
{
    [view layoutIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    [view layoutIfNeeded];
}

static UICollectionViewCell *cell_at(UICollectionView *view, NSInteger item)
{
    return [view cellForItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:0]];
}

static UICollectionViewLayout *tall_layout(void)
{
    NSCollectionLayoutSize *whole = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                                                                   heightDimension:[NSCollectionLayoutDimension fractionalHeightDimension:1]];
    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:whole];
    NSCollectionLayoutSize *page = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                                                                  heightDimension:[NSCollectionLayoutDimension absoluteDimension:700]];
    NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:page subitem:item count:1];
    return [[UICollectionViewCompositionalLayout alloc] initWithSection:[NSCollectionLayoutSection sectionWithGroup:group]];
}

// The release's own answer for a plain layout, the cause the compositional layout works around. Only
// reported: on a release that files no such way the element is shown and this says so.
static void release_files_by_pages(void)
{
    CharonPagesSource *source = [[CharonPagesSource alloc] init];
    source.count = 1;
    UICollectionView *view = show([[CharonPlainLayout alloc] init], source, 480);
    settle(view);
    printf("note the release %s an item whose frame reaches past both ends of the rectangle it checks\n", cell_at(view, 0) ? "shows" : "loses");
}

static void spanning_items(void)
{
    CharonPagesSource *source = [[CharonPagesSource alloc] init];
    source.count = 3;
    UICollectionView *view = show(tall_layout(), source, 480);
    CGSize content = view.contentSize;
    CHECK(content.width == 320 && content.height == 2100, "three groups of 700 make the content 320 x 2100");
    settle(view);
    CHECK(cell_at(view, 0) != nil && !CGRectIsEmpty(cell_at(view, 0).frame), "at the top the first item has its view");
    CHECK_EQUAL(NSStringFromCGRect(cell_at(view, 0).frame), NSStringFromCGRect(CGRectMake(0, 0, 320, 700)), "at the top the first item is 320 x 700");
    CHECK(cell_at(view, 1) == nil, "at the top the second item, below the bounds, has no view");

    // The item reaches past both ends of the bounds: 0 to 700 against 100 to 580.
    view.contentOffset = CGPointMake(0, 100);
    settle(view);
    CHECK(cell_at(view, 0) != nil, "an item reaching past both ends of the bounds has its view");
    CHECK_EQUAL(NSStringFromCGRect(cell_at(view, 0).frame), NSStringFromCGRect(CGRectMake(0, 0, 320, 700)), "and it is 320 x 700 where the layout put it, not the piece the bounds show");
    CHECK(view.visibleCells.count == 1 && view.indexPathsForVisibleItems.count == 1, "it is the only view, once");
    CHECK(cell_at(view, 1) == nil, "the second item, below the bounds, has none");

    view.contentOffset = CGPointMake(0, 900);
    settle(view);
    CHECK(cell_at(view, 0) == nil, "scrolled past the first item it has no view");
    CHECK(cell_at(view, 1) != nil, "the second item, reaching past both ends of the bounds 900 to 1380, has its view");
    CHECK_EQUAL(NSStringFromCGRect(cell_at(view, 1).frame), NSStringFromCGRect(CGRectMake(0, 700, 320, 700)), "at 700 to 1400");
    CHECK(view.visibleCells.count == 1, "it is the only view");

    view.contentOffset = CGPointMake(0, 500);
    settle(view);
    CHECK(cell_at(view, 0) != nil && cell_at(view, 1) != nil && view.visibleCells.count == 2, "with an end of both in the bounds each has one view");

    UICollectionViewLayout *layout = view.collectionViewLayout;
    NSArray *asked = [layout layoutAttributesForElementsInRect:CGRectMake(0, 100, 320, 480)];
    NSArray *item = [asked filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"indexPath.item == 0"]];
    if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1) {
        CHECK(item.count == 2, "on iOS 6 the layout answers the item twice");
        CHECK_EQUAL(NSStringFromCGRect([item.firstObject frame]), NSStringFromCGRect(CGRectMake(0, 100, 320, 480)), "first with the frame cut to the rectangle");
        CHECK_EQUAL(NSStringFromCGRect([item.lastObject frame]), NSStringFromCGRect(CGRectMake(0, 0, 320, 700)), "then with its own frame");
    } else {
        CHECK(item.count == 1, "the layout answers the item once");
    }
    CHECK_EQUAL(NSStringFromCGRect([layout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]].frame), NSStringFromCGRect(CGRectMake(0, 0, 320, 700)), "-layoutAttributesForItemAtIndexPath: answers the item's own frame");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        release_files_by_pages();
        spanning_items();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
    }
    return charon_failures ? 1 : 0;
}
