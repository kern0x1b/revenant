#import "flowauto-cases.h"

typedef NS_ENUM(NSInteger, AutoMode) { AutoModeFixedWidth, AutoModeIntrinsic, AutoModeHeightOnly, AutoModeWidth200, AutoModeWidth90 };

@interface AutoCell : UICollectionViewCell
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, assign) AutoMode mode;
@end

@implementation AutoCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.label = [[UILabel alloc] init];
    self.label.numberOfLines = 0;
    self.label.font = [UIFont fontWithName:@"Courier" size:14];
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.label];
    NSDictionary *views = @{@"l": self.label};
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[l]-8-|" options:0 metrics:nil views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-6-[l]-6-|" options:0 metrics:nil views:views]];
    return self;
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes
{
    if (self.mode == AutoModeHeightOnly) {
        self.label.preferredMaxLayoutWidth = attributes.size.width - 16;
        [self setNeedsLayout];
        [self layoutIfNeeded];
        CGSize fitted = [self.contentView systemLayoutSizeFittingSize:CGSizeMake(attributes.size.width, UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
        UICollectionViewLayoutAttributes *copy = [attributes copy];
        CGRect frame = copy.frame;
        frame.size.height = ceil(fitted.height);
        copy.frame = frame;
        return copy;
    }
    return [super preferredLayoutAttributesFittingAttributes:attributes];
}

@end

@interface PlainCell : UICollectionViewCell
@end

@implementation PlainCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    label.text = @"plain";
    [self.contentView addSubview:label];
    return self;
}

@end

@interface FlowAutoSource : NSObject <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, copy) NSArray<NSNumber *> *counts;
@property (nonatomic, copy) NSArray<NSString *> *texts;
@property (nonatomic, assign) AutoMode mode;
@property (nonatomic, assign) BOOL delegateSizes;
@property (nonatomic, assign) BOOL headers;
@property (nonatomic, assign) BOOL plain;
@property (nonatomic, assign) UIEdgeInsets insets;
@end

@implementation FlowAutoSource

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(collectionView:layout:sizeForItemAtIndexPath:))
        return self.delegateSizes;
    return [super respondsToSelector:selector];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)view { return self.counts.count; }
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return self.counts[section].integerValue; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path
{
    if (self.plain)
        return [view dequeueReusableCellWithReuseIdentifier:@"plain" forIndexPath:path];
    AutoCell *cell = [view dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:path];
    cell.mode = self.mode;
    cell.label.text = self.texts[(path.section * 7 + path.item) % self.texts.count];
    if (self.mode == AutoModeFixedWidth || self.mode == AutoModeWidth200 || self.mode == AutoModeWidth90) {
        cell.label.preferredMaxLayoutWidth = (self.mode == AutoModeWidth200 ? 200 : (self.mode == AutoModeWidth90 ? 90 : view.bounds.size.width - self.insets.left - self.insets.right)) - 16;
        for (NSLayoutConstraint *c in cell.contentView.constraints)
            if (c.firstItem == cell.contentView && c.firstAttribute == NSLayoutAttributeWidth)
                [cell.contentView removeConstraint:c];
        [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:cell.contentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:self.mode == AutoModeWidth200 ? 200 : (self.mode == AutoModeWidth90 ? 90 : view.bounds.size.width - self.insets.left - self.insets.right)]];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)path
{
    return CGSizeMake(view.bounds.size.width - self.insets.left - self.insets.right, 70);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)view viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)path
{
    UICollectionReusableView *header = [view dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:path];
    header.backgroundColor = [UIColor grayColor];
    return header;
}

- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section
{
    return self.headers ? CGSizeMake(0, 30) : CGSizeZero;
}

@end

static NSString *frames(UICollectionView *view, UICollectionViewFlowLayout *layout)
{
    NSMutableArray *lines = [NSMutableArray array];
    for (NSInteger section = 0; section < view.numberOfSections; section++)
        for (NSInteger item = 0; item < [view numberOfItemsInSection:section]; item++) {
            CGRect f = [layout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:section]].frame;
            [lines addObject:[NSString stringWithFormat:@"%ld.%ld=%g,%g,%g,%g", (long)section, (long)item, f.origin.x, f.origin.y, f.size.width, f.size.height]];
        }
    return [NSString stringWithFormat:@"content=%@ %@", NSStringFromCGSize(layout.collectionViewContentSize), [lines componentsJoinedByString:@" "]];
}

static void spin(void)
{
    for (int i = 0; i < 6; i++)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

static void scenario(UIWindow *window, FlowAutoRecorder record, NSString *name, void (^setup)(UICollectionViewFlowLayout *layout, FlowAutoSource *source))
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    FlowAutoSource *source = [[FlowAutoSource alloc] init];
    source.counts = @[@6];
    source.texts = @[@"Short", @"A somewhat longer line of text that will wrap over several lines in a narrow cell", @"Medium length text here", @"x", @"Another rather long sentence with quite a few words in it to make it wrap around twice", @"Ok", @"Line one\nLine two\nLine three"];
    source.insets = UIEdgeInsetsZero;
    setup(layout, source);
    UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) collectionViewLayout:layout];
    view.dataSource = source;
    view.delegate = source;
    [view registerClass:[AutoCell class] forCellWithReuseIdentifier:@"cell"];
    [view registerClass:[PlainCell class] forCellWithReuseIdentifier:@"plain"];
    [view registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
    UIViewController *root = [[UIViewController alloc] init];
    window.rootViewController = root;
    [root.view addSubview:view];
    [window layoutIfNeeded];
    spin();
    record(name, frames(view, layout));
    [view removeFromSuperview];
}

void flowauto_run(UIWindow *window, FlowAutoRecorder record)
{
    scenario(window, record, @"plainFixedWidth", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(320, 40);
        source.mode = AutoModeFixedWidth;
    });
    scenario(window, record, @"heightOnly", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(320, 40);
        source.mode = AutoModeHeightOnly;
    });
    scenario(window, record, @"intrinsicGrid", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(100, 40);
        source.mode = AutoModeIntrinsic;
    });
    scenario(window, record, @"insetsSpacing", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(280, 40);
        layout.sectionInset = UIEdgeInsetsMake(10, 20, 15, 20);
        layout.minimumLineSpacing = 7;
        source.insets = layout.sectionInset;
        source.mode = AutoModeHeightOnly;
        source.counts = @[@3, @3];
        source.headers = YES;
    });
    scenario(window, record, @"delegateSizeWins", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(320, 40);
        source.mode = AutoModeHeightOnly;
        source.delegateSizes = YES;
    });
    scenario(window, record, @"horizontal", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.estimatedItemSize = CGSizeMake(60, 100);
        source.mode = AutoModeIntrinsic;
    });
    scenario(window, record, @"automaticSize", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize;
        source.mode = AutoModeFixedWidth;
    });
    scenario(window, record, @"single200", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(50, 40);
        source.mode = AutoModeWidth200;
        source.counts = @[@4];
    });
    scenario(window, record, @"grid90", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(50, 40);
        source.mode = AutoModeWidth90;
        source.counts = @[@6];
        layout.sectionInset = UIEdgeInsetsMake(5, 12, 5, 12);
        layout.minimumInteritemSpacing = 6;
        source.headers = YES;
    });
    scenario(window, record, @"grid90noEstimate", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.itemSize = CGSizeMake(90, 30);
        source.mode = AutoModeWidth90;
        source.counts = @[@7, @2];
        layout.sectionInset = UIEdgeInsetsMake(5, 12, 5, 12);
        layout.minimumInteritemSpacing = 6;
        source.headers = YES;
    });
    scenario(window, record, @"lastLineMixed", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(50, 40);
        source.mode = AutoModeIntrinsic;
        source.texts = @[@"aaaaaaaaaaaa", @"bbbbbbbbbb", @"cccccccc", @"dddddd", @"eeeeeeeeee", @"ffff", @"gggggggggggggggg", @"hhhhh"];
        source.counts = @[@8];
    });
    scenario(window, record, @"lastLineTwo", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(50, 40);
        source.mode = AutoModeIntrinsic;
        source.texts = @[@"aaaaaaaaaaaa", @"bbbbbbbbbb", @"cccccccc", @"dddddd", @"eeeeeeeeee", @"ffff", @"gggggggggggggggg", @"hhhhh"];
        source.counts = @[@5];
    });
    scenario(window, record, @"plainCells", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(100, 60);
        source.plain = YES;
        source.counts = @[@5];
    });
    scenario(window, record, @"longList", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(320, 40);
        source.mode = AutoModeHeightOnly;
        source.counts = @[@40];
    });
    scenario(window, record, @"longListDelegate", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        layout.estimatedItemSize = CGSizeMake(320, 40);
        source.mode = AutoModeHeightOnly;
        source.delegateSizes = YES;
        source.counts = @[@40];
    });
    scenario(window, record, @"noEstimate", ^(UICollectionViewFlowLayout *layout, FlowAutoSource *source) {
        source.mode = AutoModeFixedWidth;
    });
}
