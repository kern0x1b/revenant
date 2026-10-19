#import "insetref-cases.h"

@interface InsetSource : NSObject <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, copy) NSArray<NSNumber *> *counts;
@property (nonatomic, assign) BOOL delegateSizes;
@property (nonatomic, assign) BOOL delegateInsets;
@property (nonatomic, assign) BOOL headers;
@end

@implementation InsetSource

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(collectionView:layout:sizeForItemAtIndexPath:))
        return self.delegateSizes;
    if (selector == @selector(collectionView:layout:insetForSectionAtIndex:))
        return self.delegateInsets;
    if (selector == @selector(collectionView:layout:referenceSizeForHeaderInSection:))
        return self.headers;
    return [super respondsToSelector:selector];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)view { return self.counts.count; }
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return self.counts[section].integerValue; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path
{
    return [view dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:path];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)view viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)path
{
    return [view dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:path];
}

- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)path
{
    return CGSizeMake(60 + 10 * (path.item % 3), 40 + 6 * (path.item % 4));
}

- (UIEdgeInsets)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(4 + 3 * section, 6 + 5 * section, 8 + section, 10 + 4 * section);
}

- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeMake(0, 24);
}

@end

static NSString *describe(UICollectionView *view)
{
    [view layoutIfNeeded];
    UICollectionViewLayout *layout = view.collectionViewLayout;
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *all = [layout layoutAttributesForElementsInRect:CGRectMake(-5000, -5000, 10000, 10000)];
    all = [all sortedArrayUsingComparator:^NSComparisonResult(UICollectionViewLayoutAttributes *a, UICollectionViewLayoutAttributes *b) {
        NSInteger order = a.representedElementCategory - b.representedElementCategory;
        if (order)
            return order < 0 ? NSOrderedAscending : NSOrderedDescending;
        return [a.indexPath compare:b.indexPath];
    }];
    CGSize content = layout.collectionViewContentSize;
    [lines addObject:[NSString stringWithFormat:@"content %.2f %.2f", content.width, content.height]];
    for (UICollectionViewLayoutAttributes *attributes in all) {
        CGRect f = attributes.frame;
        [lines addObject:[NSString stringWithFormat:@"%ld/%ld/%ld %.2f %.2f %.2f %.2f", (long)attributes.representedElementCategory, (long)attributes.indexPath.section, (long)attributes.indexPath.item, f.origin.x, f.origin.y, f.size.width, f.size.height]];
    }
    return [lines componentsJoinedByString:@";"];
}

static NSString *scenario(NSInteger reference, CGFloat width, UIEdgeInsets contentInset, UIEdgeInsets margins, BOOL delegateSizes, BOOL delegateInsets, BOOL headers, BOOL estimated, NSArray<NSNumber *> *counts)
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(70, 50);
    layout.sectionInset = UIEdgeInsetsMake(10, 12, 14, 16);
    layout.minimumLineSpacing = 9;
    layout.minimumInteritemSpacing = 7;
    layout.sectionInsetReference = (UICollectionViewFlowLayoutSectionInsetReference)reference;
    if (estimated)
        layout.estimatedItemSize = CGSizeMake(60, 40);
    UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, width, 480) collectionViewLayout:layout];
    view.contentInset = contentInset;
    view.layoutMargins = margins;
    [view registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    [view registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
    InsetSource *source = [[InsetSource alloc] init];
    source.counts = counts;
    source.delegateSizes = delegateSizes;
    source.delegateInsets = delegateInsets;
    source.headers = headers;
    view.dataSource = source;
    view.delegate = source;
    [view reloadData];
    NSString *result = describe(view);
    view.dataSource = nil;
    view.delegate = nil;
    return result;
}

void insetref_run(UIWindow *window, InsetRefRecorder record)
{
    NSArray *counts = @[@7, @5, @1];
    UIEdgeInsets none = UIEdgeInsetsZero;
    UIEdgeInsets sides = UIEdgeInsetsMake(0, 8, 0, 8);
    for (NSInteger reference = 0; reference < 3; reference++) {
        NSString *tag = [NSString stringWithFormat:@"ref%ld", (long)reference];
        record([tag stringByAppendingString:@".plain.320"], scenario(reference, 320, none, sides, NO, NO, NO, NO, counts));
        record([tag stringByAppendingString:@".plain.375"], scenario(reference, 375, none, sides, NO, NO, NO, NO, counts));
        record([tag stringByAppendingString:@".delegate.320"], scenario(reference, 320, none, sides, YES, YES, YES, NO, counts));
        record([tag stringByAppendingString:@".sizes.768"], scenario(reference, 768, none, sides, YES, NO, NO, NO, counts));
        record([tag stringByAppendingString:@".contentInset"], scenario(reference, 320, UIEdgeInsetsMake(0, 20, 0, 30), sides, NO, NO, NO, NO, counts));
        record([tag stringByAppendingString:@".contentInset.delegate"], scenario(reference, 320, UIEdgeInsetsMake(0, 40, 0, 3), sides, YES, YES, YES, NO, counts));
        record([tag stringByAppendingString:@".margins"], scenario(reference, 320, none, UIEdgeInsetsMake(0, 30, 0, 5), NO, NO, NO, NO, counts));
        record([tag stringByAppendingString:@".margins.contentInset"], scenario(reference, 320, UIEdgeInsetsMake(0, 12, 0, 0), UIEdgeInsetsMake(0, 30, 0, 5), YES, YES, YES, NO, counts));
        record([tag stringByAppendingString:@".estimated.contentInset"], scenario(reference, 320, UIEdgeInsetsMake(0, 20, 0, 30), sides, YES, YES, YES, YES, @[@7, @5, @4]));
    }
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    record(@"default", [NSString stringWithFormat:@"%ld", (long)layout.sectionInsetReference]);
    layout.sectionInsetReference = UICollectionViewFlowLayoutSectionInsetFromSafeArea;
    record(@"set", [NSString stringWithFormat:@"%ld", (long)layout.sectionInsetReference]);
    layout.sectionInsetReference = UICollectionViewFlowLayoutSectionInsetFromLayoutMargins;
    record(@"set.margins", [NSString stringWithFormat:@"%ld", (long)layout.sectionInsetReference]);
    UICollectionViewFlowLayout *other = [[UICollectionViewFlowLayout alloc] init];
    record(@"separate", [NSString stringWithFormat:@"%ld %ld", (long)layout.sectionInsetReference, (long)other.sectionInsetReference]);
    record(@"values", [NSString stringWithFormat:@"%ld %ld %ld", (long)UICollectionViewFlowLayoutSectionInsetFromContentInset, (long)UICollectionViewFlowLayoutSectionInsetFromSafeArea, (long)UICollectionViewFlowLayoutSectionInsetFromLayoutMargins]);
}
