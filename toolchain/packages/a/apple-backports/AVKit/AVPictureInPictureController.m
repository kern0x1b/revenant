#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface AVPictureInPictureController ()
@property (nonatomic, strong, readwrite) AVPlayerLayer *playerLayer;
@end

@interface RevenantPictureInPictureWindow : UIWindow
@property (nonatomic, weak) AVPictureInPictureController *revenantController;
@end

@implementation RevenantPictureInPictureWindow

@synthesize revenantController = _revenantController;

- (void)revenant_pan:(UIPanGestureRecognizer *)recognizer
{
    UIView *dragged = recognizer.view.window ?: recognizer.view;
    CGPoint translation = [recognizer translationInView:dragged.superview ?: dragged];
    CGRect frame = self.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    [recognizer setTranslation:CGPointZero inView:dragged.superview ?: dragged];

    CGRect bounds = [UIScreen mainScreen].bounds;
    frame.origin.x = MAX(0, MIN(frame.origin.x, bounds.size.width - frame.size.width));
    frame.origin.y = MAX(0, MIN(frame.origin.y, bounds.size.height - frame.size.height));
    self.frame = frame;
}

- (void)revenant_close:(UITapGestureRecognizer *)recognizer
{
    [self.revenantController stopPictureInPicture];
}

@end

NSString * const AVKitErrorDomain = @"AVKitErrorDomain";

@implementation AVPictureInPictureController
{
    RevenantPictureInPictureWindow *_revenantWindow;
    CALayer *_revenantOriginalSuperlayer;
    NSInteger _revenantOriginalSublayerIndex;
    CGRect _revenantOriginalFrame;
    __weak id<AVPictureInPictureControllerDelegate> _revenantDelegate;
}

@synthesize playerLayer = _playerLayer;
@synthesize requiresLinearPlayback = _requiresLinearPlayback;
@dynamic contentSource, canStartPictureInPictureAutomaticallyFromInline, canStopPictureInPicture;

- (BOOL)isPictureInPictureSuspended
{
    return NO;
}

+ (BOOL)isPictureInPictureSupported
{
    return YES;
}

- (nullable instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer
{
    if (!playerLayer)
        return nil;
    if ((self = [super init]))
        self.playerLayer = playerLayer;
    return self;
}

- (id<AVPictureInPictureControllerDelegate>)delegate
{
    return _revenantDelegate;
}

- (void)setDelegate:(id<AVPictureInPictureControllerDelegate>)delegate
{
    _revenantDelegate = delegate;
}

- (BOOL)isPictureInPictureActive
{
    return _revenantWindow != nil;
}

- (BOOL)isPictureInPicturePossible
{
    return self.playerLayer.readyForDisplay && self.playerLayer.player != nil;
}

- (void)startPictureInPicture
{
    if (_revenantWindow)
        return;
    CALayer *layer = self.playerLayer;
    CALayer *superlayer = layer.superlayer;
    if (!superlayer || !self.isPictureInPicturePossible) {
        NSError *error = [NSError errorWithDomain:AVKitErrorDomain code:-1001
                                          userInfo:@{NSLocalizedDescriptionKey: @"Picture in Picture could not be started"}];
        if ([_revenantDelegate respondsToSelector:@selector(pictureInPictureController:failedToStartPictureInPictureWithError:)])
            [_revenantDelegate pictureInPictureController:self failedToStartPictureInPictureWithError:error];
        return;
    }

    if ([_revenantDelegate respondsToSelector:@selector(pictureInPictureControllerWillStartPictureInPicture:)])
        [_revenantDelegate pictureInPictureControllerWillStartPictureInPicture:self];

    _revenantOriginalSuperlayer = superlayer;
    _revenantOriginalFrame = layer.frame;
    _revenantOriginalSublayerIndex = [superlayer.sublayers indexOfObject:layer];

    CGSize screen = [UIScreen mainScreen].bounds.size;
    CGSize size = CGSizeMake(160, 90);
    CGRect frame = CGRectMake(screen.width - size.width - 16, screen.height - size.height - 64, size.width, size.height);

    _revenantWindow = [[RevenantPictureInPictureWindow alloc] initWithFrame:frame];
    _revenantWindow.revenantController = self;
    _revenantWindow.windowLevel = UIWindowLevelAlert - 1;
    _revenantWindow.backgroundColor = [UIColor blackColor];
    _revenantWindow.layer.cornerRadius = 8;
    _revenantWindow.clipsToBounds = YES;
    _revenantWindow.hidden = NO;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.frame = _revenantWindow.bounds;
    [_revenantWindow.layer addSublayer:layer];
    [CATransaction commit];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:_revenantWindow action:@selector(revenant_pan:)];
    [_revenantWindow addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:_revenantWindow action:@selector(revenant_close:)];
    tap.numberOfTapsRequired = 2;
    [_revenantWindow addGestureRecognizer:tap];

    if ([_revenantDelegate respondsToSelector:@selector(pictureInPictureControllerDidStartPictureInPicture:)])
        [_revenantDelegate pictureInPictureControllerDidStartPictureInPicture:self];
}

- (void)stopPictureInPicture
{
    if (!_revenantWindow)
        return;

    if ([_revenantDelegate respondsToSelector:@selector(pictureInPictureControllerWillStopPictureInPicture:)])
        [_revenantDelegate pictureInPictureControllerWillStopPictureInPicture:self];

    CALayer *layer = self.playerLayer;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [layer removeFromSuperlayer];
    layer.frame = _revenantOriginalFrame;
    NSArray<CALayer *> *siblings = _revenantOriginalSuperlayer.sublayers;
    if (_revenantOriginalSublayerIndex != NSNotFound && _revenantOriginalSublayerIndex <= (NSInteger)siblings.count)
        [_revenantOriginalSuperlayer insertSublayer:layer atIndex:(unsigned)_revenantOriginalSublayerIndex];
    else
        [_revenantOriginalSuperlayer addSublayer:layer];
    [CATransaction commit];

    _revenantWindow.hidden = YES;
    _revenantWindow = nil;
    _revenantOriginalSuperlayer = nil;

    void (^finish)(void) = ^{
        if ([self->_revenantDelegate respondsToSelector:@selector(pictureInPictureControllerDidStopPictureInPicture:)])
            [self->_revenantDelegate pictureInPictureControllerDidStopPictureInPicture:self];
    };
    if ([_revenantDelegate respondsToSelector:@selector(pictureInPictureController:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:)]) {
        [_revenantDelegate pictureInPictureController:self restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:^(BOOL restored) {
            (void)restored;
            finish();
        }];
    } else {
        finish();
    }
}

@end
