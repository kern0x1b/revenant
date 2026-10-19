#import <UIKit/UIKit.h>

static const CGFloat RevenantSwipeFullSwipeFraction = 0.65;
static const NSTimeInterval RevenantSwipeDuration = 0.28;

@interface RevenantSwipeItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) id action;
@property (nonatomic) CGFloat width;
@end

@interface RevenantSwipeButton : UIControl
@property (nonatomic, strong) RevenantSwipeItem *item;
@property (nonatomic) CGFloat edgeInsetLeft;
@property (nonatomic) CGFloat edgeInsetRight;
- (instancetype)initWithItem:(RevenantSwipeItem *)item;
@end

@interface RevenantSwipeContainer : UIView
@property (nonatomic, strong) NSArray<RevenantSwipeButton *> *buttons;
@property (nonatomic) NSInteger side;
@property (nonatomic) CGFloat totalWidth;
- (void)setOffset:(CGFloat)offset inCellWidth:(CGFloat)cellWidth height:(CGFloat)height;
@end

CGFloat revenant_swipe_width(NSString *title);

void revenant_install_list_swipe(UICollectionView *view);
void revenant_close_list_swipe(UICollectionView *view, BOOL animated);
