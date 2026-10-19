#import "CharonLists.h"
#import "CharonSwipeViews.h"
#import <objc/message.h>
#import <objc/runtime.h>

static const char CharonListSwipeKey;

@interface CharonListSwipeController : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UICollectionView *view;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@property (nonatomic, strong) UITapGestureRecognizer *closeTap;
@property (nonatomic, strong) NSIndexPath *path;
@property (nonatomic, weak) UICollectionViewCell *cell;
@property (nonatomic, strong) NSArray<CharonSwipeItem *> *items;
@property (nonatomic, strong) CharonSwipeContainer *container;
@property (nonatomic, strong) NSArray<UIView *> *movers;
@property (nonatomic) NSInteger side;
@property (nonatomic) CGFloat total;
@property (nonatomic) CGFloat offset;
@property (nonatomic) BOOL fullSwipe;
@property (nonatomic) BOOL resting;
@property (nonatomic) CGFloat cellWidth;
@property (nonatomic, strong) NSIndexPath *pendingPath;
@property (nonatomic, strong) NSArray<CharonSwipeItem *> *pendingItems;
@property (nonatomic) NSInteger pendingSide;
@property (nonatomic) BOOL pendingFullSwipe;
- (BOOL)isOpen;
- (void)closeAnimated:(BOOL)animated;
- (void)validate;
@end

@implementation CharonListSwipeController
@synthesize view = _view;
@synthesize pan = _pan;
@synthesize closeTap = _closeTap;
@synthesize path = _path;
@synthesize cell = _cell;
@synthesize items = _items;
@synthesize container = _container;
@synthesize movers = _movers;
@synthesize side = _side;
@synthesize total = _total;
@synthesize offset = _offset;
@synthesize fullSwipe = _fullSwipe;
@synthesize resting = _resting;
@synthesize cellWidth = _cellWidth;
@synthesize pendingPath = _pendingPath;
@synthesize pendingItems = _pendingItems;
@synthesize pendingSide = _pendingSide;
@synthesize pendingFullSwipe = _pendingFullSwipe;

- (instancetype)initWithView:(UICollectionView *)view
{
    if ((self = [super init])) {
        _view = view;
        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
        _pan.delegate = self;
        _pan.maximumNumberOfTouches = 1;
        [view addGestureRecognizer:_pan];
        _closeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        _closeTap.delegate = self;
        _closeTap.enabled = NO;
        [view addGestureRecognizer:_closeTap];
        [view.panGestureRecognizer addTarget:self action:@selector(scrolled:)];
    }
    return self;
}

- (BOOL)isOpen
{
    return _container != nil;
}

- (NSArray<CharonSwipeItem *> *)itemsForSide:(NSInteger)side cell:(UICollectionViewCell *)cell path:(NSIndexPath *)path fullSwipe:(BOOL *)fullSwipe
{
    *fullSwipe = NO;
    UICollectionLayoutListConfiguration *configuration = [cell charon_layoutListConfiguration];
    UICollectionLayoutListSwipeActionsConfigurationProvider provider = side < 0 ? configuration.trailingSwipeActionsConfigurationProvider : configuration.leadingSwipeActionsConfigurationProvider;
    if (!provider)
        return @[];
    UISwipeActionsConfiguration *result = provider(path);
    NSMutableArray *items = [NSMutableArray array];
    for (UIContextualAction *action in result.actions) {
        CharonSwipeItem *item = [[CharonSwipeItem alloc] init];
        item.title = action.title;
        item.image = action.image;
        item.color = action.backgroundColor;
        item.action = action;
        item.width = charon_swipe_width(action.title);
        [items addObject:item];
    }
    *fullSwipe = result.performsFirstActionWithFullSwipe && items.count > 0;
    return items;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    if (recognizer != _pan)
        return [self isOpen];
    _pendingItems = nil;
    UICollectionView *view = _view;
    if ([view charon_editing])
        return NO;
    CGPoint velocity = [_pan velocityInView:view];
    if (fabs(velocity.x) <= fabs(velocity.y))
        return NO;
    NSIndexPath *path = [view indexPathForItemAtPoint:[_pan locationInView:view]];
    UICollectionViewCell *cell = path ? [view cellForItemAtIndexPath:path] : nil;
    if (![cell isKindOfClass:[UICollectionViewListCell class]])
        return NO;
    if ([self isOpen])
        return [path isEqual:_path];
    NSInteger side = velocity.x < 0 ? -1 : 1;
    BOOL fullSwipe = NO;
    NSArray *items = [self itemsForSide:side cell:cell path:path fullSwipe:&fullSwipe];
    if (!items.count)
        return NO;
    _pendingPath = path;
    _pendingSide = side;
    _pendingItems = items;
    _pendingFullSwipe = fullSwipe;
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
    if (recognizer == _closeTap)
        return [self isOpen] && ![touch.view isDescendantOfView:_container];
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return recognizer == _pan && other == _view.panGestureRecognizer;
}

- (void)scrolled:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan && [self isOpen] && _pan.state != UIGestureRecognizerStateBegan && _pan.state != UIGestureRecognizerStateChanged)
        [self closeAnimated:YES];
}

- (void)tapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded)
        [self closeAnimated:YES];
}

- (void)validate
{
    if (![self isOpen])
        return;
    UICollectionViewCell *cell = _cell;
    if (!cell || cell.superview != _view || ![[_view indexPathForCell:cell] isEqual:_path] || fabs(cell.bounds.size.width - _cellWidth) > 0.5)
        [self closeAnimated:NO];
}

- (void)applyOffset:(CGFloat)offset
{
    _offset = offset;
    UICollectionViewCell *cell = _cell;
    if (!cell)
        return;
    for (UIView *view in _movers)
        view.transform = CGAffineTransformMakeTranslation(offset, 0);
    [_container setOffset:offset inCellWidth:cell.bounds.size.width height:cell.bounds.size.height];
}

- (void)beginOnPath:(NSIndexPath *)path side:(NSInteger)side items:(NSArray<CharonSwipeItem *> *)items fullSwipe:(BOOL)fullSwipe
{
    UICollectionViewCell *cell = [_view cellForItemAtIndexPath:path];
    _path = path;
    _cell = cell;
    _cellWidth = cell.bounds.size.width;
    _side = side;
    _items = items;
    _fullSwipe = fullSwipe;
    CGFloat total = 0;
    NSMutableArray *buttons = [NSMutableArray array];
    for (CharonSwipeItem *item in items) {
        total += item.width;
        CharonSwipeButton *button = [[CharonSwipeButton alloc] initWithItem:item];
        [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:button];
    }
    _total = total;
    _container = [[CharonSwipeContainer alloc] initWithFrame:CGRectZero];
    _container.side = side;
    _container.totalWidth = total;
    _container.buttons = buttons;
    _container.clipsToBounds = YES;
    for (UIView *button in buttons)
        [_container addSubview:button];
    [cell insertSubview:_container aboveSubview:cell.contentView];
    NSMutableArray *movers = [NSMutableArray array];
    for (UIView *view in cell.subviews) {
        NSString *name = NSStringFromClass([view class]);
        if (view == _container || view == cell.backgroundView || view == cell.selectedBackgroundView || [name hasSuffix:@"BackgroundView"] || [name hasSuffix:@"RowSeparatorView"])
            continue;
        [movers addObject:view];
    }
    _movers = movers;
    _closeTap.enabled = YES;
}

- (void)finishClose
{
    for (UIView *view in _movers)
        view.transform = CGAffineTransformIdentity;
    [_container removeFromSuperview];
    _container = nil;
    _movers = nil;
    _items = nil;
    _cell = nil;
    _path = nil;
    _offset = 0;
    _resting = NO;
    _closeTap.enabled = NO;
}

- (void)settleAt:(CGFloat)offset animated:(BOOL)animated completion:(void (^)(void))completion
{
    void (^apply)(void) = ^{
        [self applyOffset:offset];
    };
    void (^done)(BOOL) = ^(BOOL finished) {
        if (completion)
            completion();
    };
    if (animated)
        [UIView animateWithDuration:CharonSwipeDuration delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:apply completion:done];
    else {
        apply();
        done(YES);
    }
}

- (void)closeAnimated:(BOOL)animated
{
    if (![self isOpen])
        return;
    _resting = NO;
    [self settleAt:0 animated:animated completion:^{
        if (!self->_resting)
            [self finishClose];
    }];
}

- (void)openAnimated:(BOOL)animated
{
    _resting = YES;
    [self settleAt:_side * _total animated:animated completion:nil];
}

- (void)perform:(CharonSwipeItem *)item
{
    UIContextualAction *contextual = item.action;
    UIView *source = nil;
    for (CharonSwipeButton *button in _container.buttons)
        if (button.item == item)
            source = button;
    __weak CharonListSwipeController *weakSelf = self;
    if (contextual.handler)
        contextual.handler(contextual, source, ^(BOOL performed) {
            [weakSelf closeAnimated:YES];
        });
    else
        [self closeAnimated:YES];
}

- (void)buttonTapped:(CharonSwipeButton *)button
{
    [self perform:button.item];
}

- (void)panned:(UIPanGestureRecognizer *)recognizer
{
    UICollectionView *view = _view;
    CGFloat translation = [recognizer translationInView:view].x;
    switch (recognizer.state) {
    case UIGestureRecognizerStateBegan:
        view.panGestureRecognizer.enabled = NO;
        view.panGestureRecognizer.enabled = YES;
        if ([self isOpen] || !_pendingItems)
            break;
        [self beginOnPath:_pendingPath side:_pendingSide items:_pendingItems fullSwipe:_pendingFullSwipe];
        _pendingItems = nil;
        _resting = NO;
        break;
    case UIGestureRecognizerStateChanged: {
        if (![self isOpen])
            return;
        CGFloat offset = (_resting ? _side * _total : 0) + translation;
        offset = _side < 0 ? MIN(0, offset) : MAX(0, offset);
        CGFloat limit = view.bounds.size.width;
        if (fabs(offset) > limit)
            offset = _side * limit;
        if (!_fullSwipe && fabs(offset) > _total)
            offset = _side * (_total + (fabs(offset) - _total) * 0.25f);
        [self applyOffset:offset];
        break;
    }
    case UIGestureRecognizerStateEnded: {
        if (![self isOpen])
            return;
        CGFloat velocity = [recognizer velocityInView:view].x;
        CGFloat shown = fabs(_offset);
        BOOL towardsOpen = velocity * _side > 0;
        if (_fullSwipe && shown > CharonSwipeFullSwipeFraction * view.bounds.size.width) {
            CharonSwipeItem *first = _items[0];
            __weak CharonListSwipeController *weakSelf = self;
            [self settleAt:_side * view.bounds.size.width animated:YES completion:^{
                [weakSelf perform:first];
            }];
        } else if (fabs(velocity) > 300 ? towardsOpen : shown > _total / 2) {
            [self openAnimated:YES];
        } else {
            [self closeAnimated:YES];
        }
        break;
    }
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
        if ([self isOpen])
            _resting ? [self openAnimated:YES] : [self closeAnimated:YES];
        break;
    default:
        break;
    }
}

@end

static CharonListSwipeController *charon_list_swipe(UICollectionView *view)
{
    return objc_getAssociatedObject(view, &CharonListSwipeKey);
}

void charon_install_list_swipe(UICollectionView *view)
{
    if (charon_list_swipe(view))
        return;
    objc_setAssociatedObject(view, &CharonListSwipeKey, [[CharonListSwipeController alloc] initWithView:view], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void charon_close_list_swipe(UICollectionView *view, BOOL animated)
{
    [charon_list_swipe(view) closeAnimated:animated];
}

@interface CharonListSwipeHooks : NSObject
@end

@implementation CharonListSwipeHooks

+ (void)load
{
    Class cls = [UICollectionView class];
    for (NSString *name in @[@"reloadData", @"performBatchUpdates:completion:", @"deleteItemsAtIndexPaths:", @"insertItemsAtIndexPaths:", @"reloadItemsAtIndexPaths:", @"moveItemAtIndexPath:toIndexPath:", @"deleteSections:",
                             @"insertSections:", @"reloadSections:", @"moveSection:toSection:"]) {
        SEL selector = NSSelectorFromString(name);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method)
            continue;
        IMP original = method_getImplementation(method);
        IMP replacement = imp_implementationWithBlock(^(UICollectionView *view, void *first, void *second) {
            charon_close_list_swipe(view, NO);
            ((void (*)(id, SEL, void *, void *))original)(view, selector, first, second);
        });
        class_replaceMethod(cls, selector, replacement, method_getTypeEncoding(method));
    }
    SEL layout = @selector(layoutSubviews);
    IMP original = class_getMethodImplementation(cls, layout);
    class_replaceMethod(cls, layout, imp_implementationWithBlock(^(UICollectionView *view) {
        ((void (*)(id, SEL))original)(view, layout);
        [charon_list_swipe(view) validate];
    }), method_getTypeEncoding(class_getInstanceMethod(cls, layout)));
}

@end
