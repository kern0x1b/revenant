#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wprotocol"

NSString *const UILargeContentViewerInteractionEnabledStatusDidChangeNotification = @"UILargeContentViewerInteractionEnabledStatusDidChangeNotification";

static const char revenant_shows_key, revenant_title_key, revenant_image_key, revenant_scales_key, revenant_insets_key;

static const NSTimeInterval RevenantLargeViewerFade = 0.2;
static const CGFloat RevenantLargeViewerPanelWidth = 240;
static const CGFloat RevenantLargeViewerImageSide = 200;
static const CGFloat RevenantLargeViewerTitleHeight = 44;

static UIView *revenant_large_item(UIView *view, CGPoint point)
{
    for (UIView *child in [view.subviews reverseObjectEnumerator]) {
        if (child.hidden || child.alpha < 0.01)
            continue;
        CGPoint local = [view convertPoint:point toView:child];
        if (![child pointInside:local withEvent:nil])
            continue;
        UIView *found = revenant_large_item(child, local);
        if (found)
            return found;
        if (child.showsLargeContentViewer)
            return child;
    }
    return nil;
}

@interface RevenantLargeContentView : UIView
- (instancetype)initWithItem:(id<UILargeContentViewerItem>)item;
@end

@implementation RevenantLargeContentView {
@private
    UIView *_panel;
    UIImageView *_image;
    UILabel *_title;
}

- (instancetype)initWithItem:(id<UILargeContentViewerItem>)item
{
    if ((self = [super initWithFrame:CGRectZero])) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
        self.userInteractionEnabled = NO;
        _panel = [[UIView alloc] initWithFrame:CGRectZero];
        _panel.backgroundColor = [UIColor colorWithWhite:0.96 alpha:0.97];
        _panel.layer.cornerRadius = 14;
        [self addSubview:_panel];
        UIImage *picture = item.largeContentImage;
        if (picture) {
            _image = [[UIImageView alloc] initWithImage:picture];
            _image.contentMode = UIViewContentModeScaleAspectFit;
            [_panel addSubview:_image];
        }
        if (item.largeContentTitle.length) {
            _title = [[UILabel alloc] initWithFrame:CGRectZero];
            _title.text = item.largeContentTitle;
            _title.font = [UIFont boldSystemFontOfSize:17];
            _title.textColor = [UIColor blackColor];
            _title.backgroundColor = [UIColor clearColor];
            _title.textAlignment = NSTextAlignmentCenter;
            _title.numberOfLines = 2;
            [_panel addSubview:_title];
        }
        CGSize natural = picture ? picture.size : CGSizeZero;
        CGFloat scale = 1;
        if (item.scalesLargeContentImage && MAX(natural.width, natural.height) > 0)
            scale = RevenantLargeViewerImageSide / MAX(natural.width, natural.height);
        CGFloat width = picture ? natural.width * scale : 0;
        CGFloat height = picture ? natural.height * scale : 0;
        UIEdgeInsets insets = item.largeContentImageInsets;
        _image.frame = CGRectMake((RevenantLargeViewerPanelWidth - width) / 2 + (insets.left - insets.right) / 2,
                                  (RevenantLargeViewerImageSide - height) / 2 + (insets.top - insets.bottom) / 2, width, height);
        _title.frame = CGRectMake(12, RevenantLargeViewerImageSide, RevenantLargeViewerPanelWidth - 24, _title ? RevenantLargeViewerTitleHeight : 0);
        _panel.frame = CGRectMake(0, 0, RevenantLargeViewerPanelWidth, RevenantLargeViewerImageSide + (_title ? RevenantLargeViewerTitleHeight : 0));
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect panel = _panel.frame;
    panel.origin = CGPointMake((CGRectGetWidth(self.bounds) - CGRectGetWidth(panel)) / 2, (CGRectGetHeight(self.bounds) - CGRectGetHeight(panel)) / 2);
    _panel.frame = panel;
}

@end

@implementation UIView (RevenantLargeContentViewer)

- (BOOL)showsLargeContentViewer
{
    return [objc_getAssociatedObject(self, &revenant_shows_key) boolValue];
}

- (void)setShowsLargeContentViewer:(BOOL)showsLargeContentViewer
{
    objc_setAssociatedObject(self, &revenant_shows_key, @(showsLargeContentViewer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)largeContentTitle
{
    return objc_getAssociatedObject(self, &revenant_title_key);
}

- (void)setLargeContentTitle:(NSString *)largeContentTitle
{
    objc_setAssociatedObject(self, &revenant_title_key, largeContentTitle, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIImage *)largeContentImage
{
    return objc_getAssociatedObject(self, &revenant_image_key);
}

- (void)setLargeContentImage:(UIImage *)largeContentImage
{
    objc_setAssociatedObject(self, &revenant_image_key, largeContentImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)scalesLargeContentImage
{
    return [objc_getAssociatedObject(self, &revenant_scales_key) boolValue];
}

- (void)setScalesLargeContentImage:(BOOL)scalesLargeContentImage
{
    objc_setAssociatedObject(self, &revenant_scales_key, @(scalesLargeContentImage), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)largeContentImageInsets
{
    NSValue *held = objc_getAssociatedObject(self, &revenant_insets_key);
    return held ? [held UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (void)setLargeContentImageInsets:(UIEdgeInsets)largeContentImageInsets
{
    objc_setAssociatedObject(self, &revenant_insets_key, [NSValue valueWithUIEdgeInsets:largeContentImageInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UILargeContentViewerInteraction {
@private
    __weak id<UILargeContentViewerInteractionDelegate> _delegate;
    __weak UIView *_view;
    UILongPressGestureRecognizer *_recognizer;
    id<UILargeContentViewerItem> _item;
    RevenantLargeContentView *_overlay;
}

+ (BOOL)isEnabled
{
    return YES;
}

- (instancetype)initWithDelegate:(id<UILargeContentViewerInteractionDelegate>)delegate
{
    if ((self = [super init]))
        _delegate = delegate;
    return self;
}

- (instancetype)init
{
    return [self initWithDelegate:nil];
}

- (id<UILargeContentViewerInteractionDelegate>)delegate
{
    return _delegate;
}

- (UIGestureRecognizer *)gestureRecognizerForExclusionRelationship
{
    return _recognizer;
}

- (UIView *)view
{
    return _view;
}

- (id<UILargeContentViewerItem>)itemAtPoint:(CGPoint)point
{
    if ([_delegate respondsToSelector:@selector(largeContentViewerInteraction:itemAtPoint:)])
        return [_delegate largeContentViewerInteraction:self itemAtPoint:point];
    UIView *found = revenant_large_item(_view, point);
    if (!found && _view.showsLargeContentViewer)
        found = _view;
    return found;
}

- (void)revenant_show:(id<UILargeContentViewerItem>)item
{
    UIView *host = nil;
    if ([_delegate respondsToSelector:@selector(viewControllerForLargeContentViewerInteraction:)])
        host = [_delegate viewControllerForLargeContentViewerInteraction:self].view;
    if (!host)
        host = _view.window;
    if (!host)
        return;
    [self revenant_hide];
    RevenantLargeContentView *overlay = [[RevenantLargeContentView alloc] initWithItem:item];
    overlay.frame = host.bounds;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.alpha = 0;
    [host addSubview:overlay];
    _overlay = overlay;
    [UIView animateWithDuration:RevenantLargeViewerFade animations:^{
        overlay.alpha = 1;
    }];
}

- (void)revenant_hide
{
    RevenantLargeContentView *overlay = _overlay;
    _overlay = nil;
    if (!overlay)
        return;
    [UIView animateWithDuration:RevenantLargeViewerFade animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

- (void)revenant_longPress:(UILongPressGestureRecognizer *)recognizer
{
    CGPoint point = [recognizer locationInView:_view];
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            _item = [self itemAtPoint:point];
            if (_item)
                [self revenant_show:_item];
            break;
        case UIGestureRecognizerStateEnded: {
            id<UILargeContentViewerItem> item = _item;
            _item = nil;
            [self revenant_hide];
            id<UILargeContentViewerInteractionDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(largeContentViewerInteraction:didEndOnItem:atPoint:)])
                [delegate largeContentViewerInteraction:self didEndOnItem:item atPoint:point];
            else if ([item isKindOfClass:[UIControl class]])
                [(UIControl *)item sendActionsForControlEvents:UIControlEventTouchUpInside];
            break;
        }
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _item = nil;
            [self revenant_hide];
            break;
        default:
            break;
    }
}

- (void)willMoveToView:(UIView *)view
{
    [self revenant_hide];
    if (_recognizer) {
        [_view removeGestureRecognizer:_recognizer];
        _recognizer = nil;
    }
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (!view)
        return;
    _recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_longPress:)];
    [view addGestureRecognizer:_recognizer];
}

@end
