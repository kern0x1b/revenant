#import <UIKit/UIKit.h>

static const CGFloat CharonSwipeFullSwipeFraction = 0.65;
static const NSTimeInterval CharonSwipeDuration = 0.28;

@interface CharonSwipeItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) id action;
@property (nonatomic) CGFloat width;
@end

@interface CharonSwipeButton : UIControl
@property (nonatomic, strong) CharonSwipeItem *item;
@property (nonatomic) CGFloat edgeInsetLeft;
@property (nonatomic) CGFloat edgeInsetRight;
- (instancetype)initWithItem:(CharonSwipeItem *)item;
@end

@interface CharonSwipeContainer : UIView
@property (nonatomic, strong) NSArray<CharonSwipeButton *> *buttons;
@property (nonatomic) NSInteger side;
@property (nonatomic) CGFloat totalWidth;
- (void)setOffset:(CGFloat)offset inCellWidth:(CGFloat)cellWidth height:(CGFloat)height;
@end

CGFloat charon_swipe_width(NSString *title);

void charon_install_list_swipe(UICollectionView *view);
void charon_close_list_swipe(UICollectionView *view, BOOL animated);
