#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@class AVRoutePickerView;

@protocol AVRoutePickerViewDelegate <NSObject>
@optional
- (void)routePickerViewWillBeginPresentingRoutes:(AVRoutePickerView *)routePickerView;
- (void)routePickerViewDidEndPresentingRoutes:(AVRoutePickerView *)routePickerView;
@end

@interface AVRoutePickerView : UIView
@property (nonatomic, weak) id<AVRoutePickerViewDelegate> delegate;
@property (nonatomic, strong) UIColor *activeTintColor;
@property (nonatomic) BOOL prioritizesVideoDevices;
@end

@implementation AVRoutePickerView {
    MPVolumeView *_volumeView;
    UIControl *_routeButton;
    BOOL _presenting;
}

@synthesize delegate = _delegate;
@synthesize activeTintColor = _activeTintColor;
@synthesize prioritizesVideoDevices = _prioritizesVideoDevices;

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _volumeView = [[MPVolumeView alloc] initWithFrame:frame];
        _volumeView.showsVolumeSlider = NO;
        _volumeView.showsRouteButton = YES;
        [self addSubview:_volumeView];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(revenant_endPresentation:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(revenant_endPresentation:) name:@"UIPopoverControllerDidDismissPopoverNotification" object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _volumeView.frame = self.bounds;
    if (!_routeButton) {
        CGRect expected = [_volumeView routeButtonRectForBounds:_volumeView.bounds];
        _routeButton = [self revenant_routeButtonInView:_volumeView expected:expected];
        [_routeButton addTarget:self action:@selector(revenant_beginPresentation:) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (UIControl *)revenant_routeButtonInView:(UIView *)view expected:(CGRect)expected
{
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:[UIControl class]] && !child.hidden && CGRectIntersectsRect(child.frame, expected))
            return (UIControl *)child;
        UIControl *nested = [self revenant_routeButtonInView:child expected:expected];
        if (nested)
            return nested;
    }
    return nil;
}

- (void)revenant_beginPresentation:(id)sender
{
    _presenting = YES;
    if ([_delegate respondsToSelector:@selector(routePickerViewWillBeginPresentingRoutes:)])
        [_delegate routePickerViewWillBeginPresentingRoutes:self];
}

- (void)revenant_endPresentation:(NSNotification *)notification
{
    if (!_presenting)
        return;
    _presenting = NO;
    if ([_delegate respondsToSelector:@selector(routePickerViewDidEndPresentingRoutes:)])
        [_delegate routePickerViewDidEndPresentingRoutes:self];
}

- (void)setActiveTintColor:(UIColor *)activeTintColor
{
    _activeTintColor = activeTintColor ?: self.tintColor;
    self.tintColor = _activeTintColor;
}

@end
