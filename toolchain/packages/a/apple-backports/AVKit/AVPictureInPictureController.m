#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface AVPictureInPictureController ()
@property (nonatomic, strong, readwrite) AVPlayerLayer *playerLayer;
@end

@interface CharonPictureInPictureWindow : UIWindow
@property (nonatomic, weak) AVPictureInPictureController *charonController;
@end

@implementation CharonPictureInPictureWindow

@synthesize charonController = _charonController;

- (void)charon_pan:(UIPanGestureRecognizer *)recognizer
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

- (void)charon_close:(UITapGestureRecognizer *)recognizer
{
    [self.charonController stopPictureInPicture];
}

@end

NSString * const AVKitErrorDomain = @"AVKitErrorDomain";

@implementation AVPictureInPictureController
{
    CharonPictureInPictureWindow *_charonWindow;
    CALayer *_charonOriginalSuperlayer;
    NSInteger _charonOriginalSublayerIndex;
    CGRect _charonOriginalFrame;
    __weak id<AVPictureInPictureControllerDelegate> _charonDelegate;
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
    return _charonDelegate;
}

- (void)setDelegate:(id<AVPictureInPictureControllerDelegate>)delegate
{
    _charonDelegate = delegate;
}

- (BOOL)isPictureInPictureActive
{
    return _charonWindow != nil;
}

- (BOOL)isPictureInPicturePossible
{
    return self.playerLayer.readyForDisplay && self.playerLayer.player != nil;
}

- (void)startPictureInPicture
{
    if (_charonWindow)
        return;
    CALayer *layer = self.playerLayer;
    CALayer *superlayer = layer.superlayer;
    if (!superlayer || !self.isPictureInPicturePossible) {
        NSError *error = [NSError errorWithDomain:AVKitErrorDomain code:-1001
                                          userInfo:@{NSLocalizedDescriptionKey: @"Picture in Picture could not be started"}];
        if ([_charonDelegate respondsToSelector:@selector(pictureInPictureController:failedToStartPictureInPictureWithError:)])
            [_charonDelegate pictureInPictureController:self failedToStartPictureInPictureWithError:error];
        return;
    }

    if ([_charonDelegate respondsToSelector:@selector(pictureInPictureControllerWillStartPictureInPicture:)])
        [_charonDelegate pictureInPictureControllerWillStartPictureInPicture:self];

    _charonOriginalSuperlayer = superlayer;
    _charonOriginalFrame = layer.frame;
    _charonOriginalSublayerIndex = [superlayer.sublayers indexOfObject:layer];

    CGSize screen = [UIScreen mainScreen].bounds.size;
    CGSize size = CGSizeMake(160, 90);
    CGRect frame = CGRectMake(screen.width - size.width - 16, screen.height - size.height - 64, size.width, size.height);

    _charonWindow = [[CharonPictureInPictureWindow alloc] initWithFrame:frame];
    _charonWindow.charonController = self;
    _charonWindow.windowLevel = UIWindowLevelAlert - 1;
    _charonWindow.backgroundColor = [UIColor blackColor];
    _charonWindow.layer.cornerRadius = 8;
    _charonWindow.clipsToBounds = YES;
    _charonWindow.hidden = NO;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.frame = _charonWindow.bounds;
    [_charonWindow.layer addSublayer:layer];
    [CATransaction commit];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:_charonWindow action:@selector(charon_pan:)];
    [_charonWindow addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:_charonWindow action:@selector(charon_close:)];
    tap.numberOfTapsRequired = 2;
    [_charonWindow addGestureRecognizer:tap];

    if ([_charonDelegate respondsToSelector:@selector(pictureInPictureControllerDidStartPictureInPicture:)])
        [_charonDelegate pictureInPictureControllerDidStartPictureInPicture:self];
}

- (void)stopPictureInPicture
{
    if (!_charonWindow)
        return;

    if ([_charonDelegate respondsToSelector:@selector(pictureInPictureControllerWillStopPictureInPicture:)])
        [_charonDelegate pictureInPictureControllerWillStopPictureInPicture:self];

    CALayer *layer = self.playerLayer;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [layer removeFromSuperlayer];
    layer.frame = _charonOriginalFrame;
    NSArray<CALayer *> *siblings = _charonOriginalSuperlayer.sublayers;
    if (_charonOriginalSublayerIndex != NSNotFound && _charonOriginalSublayerIndex <= (NSInteger)siblings.count)
        [_charonOriginalSuperlayer insertSublayer:layer atIndex:(unsigned)_charonOriginalSublayerIndex];
    else
        [_charonOriginalSuperlayer addSublayer:layer];
    [CATransaction commit];

    _charonWindow.hidden = YES;
    _charonWindow = nil;
    _charonOriginalSuperlayer = nil;

    void (^finish)(void) = ^{
        if ([self->_charonDelegate respondsToSelector:@selector(pictureInPictureControllerDidStopPictureInPicture:)])
            [self->_charonDelegate pictureInPictureControllerDidStopPictureInPicture:self];
    };
    if ([_charonDelegate respondsToSelector:@selector(pictureInPictureController:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:)]) {
        [_charonDelegate pictureInPictureController:self restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:^(BOOL restored) {
            (void)restored;
            finish();
        }];
    } else {
        finish();
    }
}

@end
