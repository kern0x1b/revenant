#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import "RevenantAVKitSpeeds.h"

@class RevenantAVPlayerPictureInPictureRelay;

@interface RevenantAVPlayerFrameTicker : NSObject
@property (nonatomic, weak) id target;
- (void)tick:(CADisplayLink *)link;
@end

@implementation RevenantAVPlayerFrameTicker

@synthesize target = _target;

- (void)tick:(CADisplayLink *)link
{
    [self.target performSelector:@selector(revenant_drawFrame:) withObject:link];
}

@end

@interface RevenantAVPlayerVideoView : UIView
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@end

@implementation RevenantAVPlayerVideoView

@synthesize playerLayer = _playerLayer;

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor blackColor];
        _playerLayer = [AVPlayerLayer playerLayerWithPlayer:nil];
        _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [self.layer addSublayer:_playerLayer];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_playerLayer.superlayer != self.layer)
        return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _playerLayer.frame = self.layer.bounds;
    [CATransaction commit];
}

@end

static UIImage *revenant_glyph(void (^draw)(CGRect bounds))
{
    CGRect bounds = CGRectMake(0, 0, 22, 22);
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
    [[UIColor whiteColor] set];
    draw(bounds);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *revenant_play_glyph(void)
{
    return revenant_glyph(^(CGRect bounds) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(5, 3)];
        [path addLineToPoint:CGPointMake(19, 11)];
        [path addLineToPoint:CGPointMake(5, 19)];
        [path closePath];
        [path fill];
    });
}

static UIImage *revenant_pause_glyph(void)
{
    return revenant_glyph(^(CGRect bounds) {
        UIRectFill(CGRectMake(5, 3, 4, 16));
        UIRectFill(CGRectMake(13, 3, 4, 16));
    });
}

static UIImage *revenant_picture_glyph(void)
{
    return revenant_glyph(^(CGRect bounds) {
        UIBezierPath *frame = [UIBezierPath bezierPathWithRect:CGRectMake(2, 4, 18, 14)];
        frame.lineWidth = 1.5;
        [frame stroke];
        UIRectFill(CGRectMake(11, 11, 7, 5));
    });
}

static UIImage *revenant_full_screen_glyph(void)
{
    return revenant_glyph(^(CGRect bounds) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        path.lineWidth = 2;
        [path moveToPoint:CGPointMake(3, 9)];
        [path addLineToPoint:CGPointMake(3, 3)];
        [path addLineToPoint:CGPointMake(9, 3)];
        [path moveToPoint:CGPointMake(13, 19)];
        [path addLineToPoint:CGPointMake(19, 19)];
        [path addLineToPoint:CGPointMake(19, 13)];
        [path moveToPoint:CGPointMake(3, 3)];
        [path addLineToPoint:CGPointMake(9, 9)];
        [path moveToPoint:CGPointMake(19, 19)];
        [path addLineToPoint:CGPointMake(13, 13)];
        [path stroke];
    });
}

static NSString *revenant_time_text(CMTime time)
{
    if (!CMTIME_IS_NUMERIC(time))
        return @"--:--";
    NSInteger seconds = (NSInteger)floor(CMTimeGetSeconds(time));
    if (seconds < 0)
        seconds = 0;
    if (seconds >= 3600)
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)(seconds / 3600), (long)(seconds / 60 % 60), (long)(seconds % 60)];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
}

@interface RevenantAVPlayerFullScreenViewController : UIViewController
@end

@implementation RevenantAVPlayerFullScreenViewController

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.backgroundColor = [UIColor blackColor];
    self.view = view;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end

@interface AVPlayerViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong, readonly) RevenantAVPlayerVideoView *revenantVideoView;
- (void)revenant_pictureInPictureWillStart;
- (void)revenant_pictureInPictureDidStart;
- (void)revenant_pictureInPictureFailed:(NSError *)error;
- (void)revenant_pictureInPictureWillStop;
- (void)revenant_pictureInPictureRestore:(void (^)(BOOL restored))completion;
- (void)revenant_pictureInPictureDidStop;
@end

@interface RevenantAVPlayerPictureInPictureRelay : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, weak) AVPlayerViewController *owner;
@end

@implementation RevenantAVPlayerPictureInPictureRelay

@synthesize owner = _owner;

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner revenant_pictureInPictureWillStart];
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner revenant_pictureInPictureDidStart];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error
{
    [self.owner revenant_pictureInPictureFailed:error];
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner revenant_pictureInPictureWillStop];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completion
{
    AVPlayerViewController *owner = self.owner;
    if (owner)
        [owner revenant_pictureInPictureRestore:completion];
    else
        completion(NO);
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner revenant_pictureInPictureDidStop];
}

@end

static void *const RevenantAVPlayerObservation = (void *)&RevenantAVPlayerObservation;

static NSMutableSet *revenant_players_in_picture(void)
{
    static NSMutableSet *held;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        held = [NSMutableSet set];
    });
    return held;
}

@implementation AVPlayerViewController
{
    UIView *_revenantStage;
    UIView *_revenantContentOverlayView;
    UIView *_revenantControls;
    UIToolbar *_revenantTopBar;
    UIView *_revenantBottomBar;
    UIBarButtonItem *_revenantDoneItem;
    UIButton *_revenantPlayButton;
    UIBarButtonItem *_revenantPictureItem;
    UIButton *_revenantFullScreenButton;
    UISlider *_revenantScrubber;
    UILabel *_revenantElapsedLabel;
    UILabel *_revenantRemainingLabel;
    UILabel *_revenantFailureLabel;
    UIActivityIndicatorView *_revenantSpinner;
    UITapGestureRecognizer *_revenantTap;
    AVPlayerItem *_revenantObservedItem;
    NSError *_revenantFailure;
    id _revenantTimeObserver;
    RevenantAVPlayerFullScreenViewController *_revenantFullScreen;
    AVPictureInPictureController *_revenantPicture;
    RevenantAVPlayerPictureInPictureRelay *_revenantPictureRelay;
    BOOL _revenantScrubbing;
    float _revenantRateBeforeScrubbing;
    BOOL _revenantWroteNowPlaying;
    BOOL _revenantControlsHidden;
    __weak id<AVPlayerViewControllerDelegate> _revenantDelegate;
    NSDictionary *_revenantPixelBufferAttributes;
    AVPlayerItemVideoOutput *_revenantVideoOutput;
    AVPlayerItem *_revenantOutputItem;
    CADisplayLink *_revenantFrameLink;
    CALayer *_revenantFrameLayer;
    CIContext *_revenantFrameContext;
    BOOL _revenantFrameRefusalLogged;
}

@synthesize player = _player;
@synthesize showsPlaybackControls = _showsPlaybackControls;
@synthesize videoGravity = _videoGravity;
@synthesize allowsPictureInPicturePlayback = _allowsPictureInPicturePlayback;
@synthesize updatesNowPlayingInfoCenter = _updatesNowPlayingInfoCenter;
@synthesize entersFullScreenWhenPlaybackBegins = _entersFullScreenWhenPlaybackBegins;
@synthesize exitsFullScreenWhenPlaybackEnds = _exitsFullScreenWhenPlaybackEnds;
@synthesize requiresLinearPlayback = _requiresLinearPlayback;
@synthesize revenantVideoView = _revenantVideoView;
@dynamic showsTimecodes, canStartPictureInPictureAutomaticallyFromInline, allowsVideoFrameAnalysis, speeds,
    selectedSpeed;

- (void)revenant_setUp
{
    _showsPlaybackControls = YES;
    _videoGravity = [AVLayerVideoGravityResizeAspect copy];
    _allowsPictureInPicturePlayback = YES;
    _updatesNowPlayingInfoCenter = YES;
    _revenantVideoView = [[RevenantAVPlayerVideoView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    _revenantVideoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _revenantContentOverlayView = [[UIView alloc] initWithFrame:_revenantVideoView.frame];
    _revenantContentOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _revenantContentOverlayView.backgroundColor = [UIColor clearColor];
}

- (instancetype)initWithNibName:(NSString *)name bundle:(NSBundle *)bundle
{
    if ((self = [super initWithNibName:name bundle:bundle]))
        [self revenant_setUp];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        [self revenant_setUp];
    return self;
}

- (void)dealloc
{
    [_revenantFrameLink invalidate];
    [self revenant_stopObservingPlayer];
    [self revenant_clearNowPlaying];
}

#pragma mark - Properties

- (void)setPlayer:(AVPlayer *)player
{
    if (player == _player)
        return;
    [self revenant_stopObservingPlayer];
    [self revenant_clearNowPlaying];
    _revenantFailure = nil;
    _player = player;
    _revenantVideoView.playerLayer.player = player;
    [self revenant_startObservingPlayer];
    [self revenant_update];
}

- (void)setShowsPlaybackControls:(BOOL)shows
{
    _showsPlaybackControls = shows;
    [self revenant_update];
}

- (void)setVideoGravity:(NSString *)gravity
{
    if (![gravity isEqualToString:AVLayerVideoGravityResizeAspect] && ![gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]
        && ![gravity isEqualToString:AVLayerVideoGravityResize])
        gravity = AVLayerVideoGravityResizeAspect;
    _videoGravity = [gravity copy];
    _revenantVideoView.playerLayer.videoGravity = _videoGravity;
    _revenantFrameLayer.contentsGravity = revenant_contents_gravity(_videoGravity);
}

#pragma mark - Pixel buffer attributes

static NSString *revenant_contents_gravity(NSString *videoGravity)
{
    if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill])
        return kCAGravityResizeAspectFill;
    if ([videoGravity isEqualToString:AVLayerVideoGravityResize])
        return kCAGravityResize;
    return kCAGravityResizeAspect;
}

- (NSDictionary<NSString *, id> *)pixelBufferAttributes
{
    return _revenantPixelBufferAttributes;
}

- (void)setPixelBufferAttributes:(NSDictionary<NSString *, id> *)attributes
{
    _revenantPixelBufferAttributes = [attributes copy];
    [self revenant_attachVideoOutputTo:nil];
    [self revenant_attachVideoOutputTo:_player.currentItem];
}

- (void)revenant_attachVideoOutputTo:(AVPlayerItem *)item
{
    if (_revenantVideoOutput) {
        [_revenantOutputItem removeOutput:_revenantVideoOutput];
        _revenantVideoOutput = nil;
        _revenantOutputItem = nil;
    }
    if (!item || !_revenantPixelBufferAttributes) {
        [_revenantFrameLink invalidate];
        _revenantFrameLink = nil;
        [_revenantFrameLayer removeFromSuperlayer];
        _revenantFrameLayer = nil;
        return;
    }
    NSMutableDictionary *attributes = [_revenantPixelBufferAttributes mutableCopy];
    if (!attributes[(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey])
        attributes[(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey] = @{};
    _revenantVideoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:attributes];
    _revenantOutputItem = item;
    [item addOutput:_revenantVideoOutput];
    if (!_revenantFrameLayer) {
        _revenantFrameLayer = [CALayer layer];
        _revenantFrameLayer.contentsGravity = revenant_contents_gravity(_videoGravity);
        [_revenantVideoView.playerLayer addSublayer:_revenantFrameLayer];
    }
    if (!_revenantFrameContext)
        _revenantFrameContext = [CIContext contextWithOptions:nil];
    if (!_revenantFrameLink) {
        RevenantAVPlayerFrameTicker *ticker = [[RevenantAVPlayerFrameTicker alloc] init];
        ticker.target = self;
        _revenantFrameLink = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
        [_revenantFrameLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)revenant_drawFrame:(CADisplayLink *)link
{
    AVPlayerItemVideoOutput *output = _revenantVideoOutput;
    CALayer *layer = _revenantFrameLayer;
    CGRect bounds = layer.superlayer.bounds;
    if (!CGRectEqualToRect(layer.frame, bounds)) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        layer.frame = bounds;
        [CATransaction commit];
    }
    CMTime time = [output itemTimeForHostTime:CACurrentMediaTime()];
    if (!output || ![output hasNewPixelBufferForItemTime:time])
        return;
    CVPixelBufferRef buffer = [output copyPixelBufferForItemTime:time itemTimeForDisplay:NULL];
    if (!buffer)
        return;
    CIImage *image = [CIImage imageWithCVPixelBuffer:buffer];
    CGImageRef frame = image ? [_revenantFrameContext createCGImage:image fromRect:image.extent] : NULL;
    OSType format = CVPixelBufferGetPixelFormatType(buffer);
    CVPixelBufferRelease(buffer);
    if (!frame) {
        if (!_revenantFrameRefusalLogged)
            NSLog(@"AVPlayerViewController: CoreImage of this release draws no frame of pixel format '%c%c%c%c'; the player layer's own frames are shown",
                  (char)(format >> 24), (char)(format >> 16), (char)(format >> 8), (char)format);
        _revenantFrameRefusalLogged = YES;
        return;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.contents = (__bridge id)frame;
    [CATransaction commit];
    CGImageRelease(frame);
}

+ (NSSet *)keyPathsForValuesAffectingReadyForDisplay
{
    return [NSSet setWithObject:@"revenantVideoView.playerLayer.readyForDisplay"];
}

- (BOOL)isReadyForDisplay
{
    return _revenantVideoView.playerLayer.readyForDisplay;
}

+ (NSSet *)keyPathsForValuesAffectingVideoBounds
{
    return [NSSet setWithObjects:@"player.currentItem.presentationSize", @"videoGravity", nil];
}

- (CGRect)videoBounds
{
    CGSize size = self.player.currentItem.presentationSize;
    CGRect bounds = _revenantVideoView.bounds;
    if (size.width <= 0 || size.height <= 0 || CGRectIsEmpty(bounds))
        return CGRectZero;
    CGRect rect = bounds;
    if ([_videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        rect = AVMakeRectWithAspectRatioInsideRect(size, bounds);
    } else if ([_videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        CGFloat scale = MAX(bounds.size.width / size.width, bounds.size.height / size.height);
        CGSize filled = CGSizeMake(size.width * scale, size.height * scale);
        rect = CGRectMake(CGRectGetMidX(bounds) - filled.width / 2, CGRectGetMidY(bounds) - filled.height / 2, filled.width, filled.height);
    }
    return self.isViewLoaded ? [_revenantVideoView convertRect:rect toView:self.view] : rect;
}

- (UIView *)contentOverlayView
{
    return _revenantContentOverlayView;
}

- (id<AVPlayerViewControllerDelegate>)delegate
{
    return _revenantDelegate;
}

- (void)setDelegate:(id<AVPlayerViewControllerDelegate>)delegate
{
    _revenantDelegate = delegate;
}

- (void)setAllowsPictureInPicturePlayback:(BOOL)allows
{
    _allowsPictureInPicturePlayback = allows;
    [self revenant_update];
}

- (void)setUpdatesNowPlayingInfoCenter:(BOOL)updates
{
    _updatesNowPlayingInfoCenter = updates;
    if (updates)
        [self revenant_writeNowPlaying];
    else
        [self revenant_clearNowPlaying];
}

- (void)setRequiresLinearPlayback:(BOOL)requires
{
    _requiresLinearPlayback = requires;
    [self revenant_update];
}

#pragma mark - View

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    view.backgroundColor = [UIColor blackColor];
    view.clipsToBounds = YES;

    _revenantStage = [[UIView alloc] initWithFrame:view.bounds];
    _revenantStage.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _revenantStage.backgroundColor = [UIColor blackColor];
    [view addSubview:_revenantStage];

    _revenantVideoView.frame = _revenantStage.bounds;
    [_revenantStage addSubview:_revenantVideoView];
    _revenantContentOverlayView.frame = _revenantStage.bounds;
    [_revenantStage addSubview:_revenantContentOverlayView];

    _revenantSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _revenantSpinner.hidesWhenStopped = YES;
    _revenantSpinner.center = CGPointMake(CGRectGetMidX(_revenantStage.bounds), CGRectGetMidY(_revenantStage.bounds));
    _revenantSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
        | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [_revenantStage addSubview:_revenantSpinner];

    _revenantFailureLabel = [[UILabel alloc] initWithFrame:CGRectInset(_revenantStage.bounds, 16, 0)];
    _revenantFailureLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _revenantFailureLabel.backgroundColor = [UIColor clearColor];
    _revenantFailureLabel.textColor = [UIColor whiteColor];
    _revenantFailureLabel.textAlignment = NSTextAlignmentCenter;
    _revenantFailureLabel.numberOfLines = 0;
    _revenantFailureLabel.hidden = YES;
    [_revenantStage addSubview:_revenantFailureLabel];

    [self revenant_buildControls];
    self.view = view;

    _revenantTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_toggleControls:)];
    _revenantTap.delegate = self;
    [_revenantStage addGestureRecognizer:_revenantTap];
    [self revenant_update];
}

- (UIButton *)revenant_buttonWithImage:(UIImage *)image action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 44, 44);
    [button setImage:image forState:UIControlStateNormal];
    button.showsTouchWhenHighlighted = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)revenant_timeLabel
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 56, 44)];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:12];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    return label;
}

- (void)revenant_buildControls
{
    CGRect bounds = _revenantStage.bounds;
    _revenantControls = [[UIView alloc] initWithFrame:bounds];
    _revenantControls.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _revenantControls.backgroundColor = [UIColor clearColor];
    [_revenantStage addSubview:_revenantControls];

    _revenantTopBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 44)];
    _revenantTopBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _revenantTopBar.barStyle = UIBarStyleBlack;
    _revenantTopBar.translucent = YES;
    [_revenantControls addSubview:_revenantTopBar];
    _revenantDoneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(revenant_done:)];
    _revenantPictureItem = [[UIBarButtonItem alloc] initWithImage:revenant_picture_glyph() style:UIBarButtonItemStylePlain target:self
                                                         action:@selector(revenant_picture:)];

    _revenantBottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, bounds.size.height - 44, bounds.size.width, 44)];
    _revenantBottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _revenantBottomBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    [_revenantControls addSubview:_revenantBottomBar];

    _revenantPlayButton = [self revenant_buttonWithImage:revenant_play_glyph() action:@selector(revenant_playPause:)];
    [_revenantBottomBar addSubview:_revenantPlayButton];

    _revenantElapsedLabel = [self revenant_timeLabel];
    _revenantElapsedLabel.frame = CGRectMake(44, 0, 52, 44);
    [_revenantBottomBar addSubview:_revenantElapsedLabel];

    _revenantFullScreenButton = [self revenant_buttonWithImage:revenant_full_screen_glyph() action:@selector(revenant_fullScreen:)];
    _revenantFullScreenButton.frame = CGRectMake(bounds.size.width - 44, 0, 44, 44);
    _revenantFullScreenButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_revenantBottomBar addSubview:_revenantFullScreenButton];

    _revenantRemainingLabel = [self revenant_timeLabel];
    _revenantRemainingLabel.frame = CGRectMake(bounds.size.width - 44 - 56, 0, 56, 44);
    _revenantRemainingLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_revenantBottomBar addSubview:_revenantRemainingLabel];

    _revenantScrubber = [[UISlider alloc] initWithFrame:CGRectMake(100, 0, bounds.size.width - 100 - 44 - 60, 44)];
    _revenantScrubber.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _revenantScrubber.minimumValue = 0;
    _revenantScrubber.maximumValue = 1;
    [_revenantScrubber addTarget:self action:@selector(revenant_scrubBegan:) forControlEvents:UIControlEventTouchDown];
    [_revenantScrubber addTarget:self action:@selector(revenant_scrubMoved:) forControlEvents:UIControlEventValueChanged];
    [_revenantScrubber addTarget:self action:@selector(revenant_scrubEnded:)
              forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_revenantBottomBar addSubview:_revenantScrubber];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self revenant_update];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self revenant_layOutBottomBar];
}

- (void)revenant_layOutBottomBar
{
    CGFloat width = _revenantBottomBar.bounds.size.width;
    CGFloat right = _revenantFullScreenButton.hidden ? width : width - 44;
    _revenantRemainingLabel.frame = CGRectMake(right - 56, 0, 56, 44);
    _revenantScrubber.frame = CGRectMake(100, 0, MAX(0, right - 56 - 100 - 4), 44);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
    for (UIView *view = touch.view; view; view = view.superview) {
        if ([view isKindOfClass:[UIControl class]] || view == _revenantTopBar || view == _revenantBottomBar)
            return NO;
    }
    return YES;
}

#pragma mark - State

- (BOOL)revenant_presentedItself
{
    return self.presentingViewController != nil && self.parentViewController == nil;
}

- (BOOL)revenant_pictureActive
{
    return _revenantPicture.pictureInPictureActive;
}

- (void)revenant_update
{
    if (!self.isViewLoaded)
        return;
    AVPlayerItem *item = self.player.currentItem;
    BOOL failed = _revenantFailure != nil || item.status == AVPlayerItemStatusFailed || self.player.status == AVPlayerStatusFailed;
    _revenantFailureLabel.hidden = !failed;
    if (failed)
        _revenantFailureLabel.text = (_revenantFailure ?: item.error ?: self.player.error).localizedDescription ?: @"This video cannot be played.";

    BOOL playing = self.player.rate != 0;
    [_revenantPlayButton setImage:playing ? revenant_pause_glyph() : revenant_play_glyph() forState:UIControlStateNormal];
    _revenantPlayButton.enabled = self.player != nil && !failed;

    BOOL waiting = playing && item != nil && !item.playbackLikelyToKeepUp && item.status != AVPlayerItemStatusFailed;
    if (waiting || (item && item.status == AVPlayerItemStatusUnknown))
        [_revenantSpinner startAnimating];
    else
        [_revenantSpinner stopAnimating];

    BOOL full = _revenantFullScreen != nil;
    BOOL done = full || [self revenant_presentedItself];
    BOOL picture = _allowsPictureInPicturePlayback && [AVPictureInPictureController isPictureInPictureSupported] && ![self revenant_pictureActive];
    _revenantFullScreenButton.hidden = done;
    NSMutableArray *items = [NSMutableArray array];
    if (done)
        [items addObject:_revenantDoneItem];
    [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL]];
    if (picture)
        [items addObject:_revenantPictureItem];
    _revenantTopBar.items = items;
    _revenantTopBar.hidden = !done && !picture;
    _revenantScrubber.enabled = !_requiresLinearPlayback && item != nil && CMTIME_IS_NUMERIC(item.duration);

    BOOL controls = _showsPlaybackControls && !(_revenantControlsHidden && playing);
    _revenantControls.hidden = !controls;
    _revenantTap.enabled = _showsPlaybackControls;
    [self revenant_layOutBottomBar];
    [self revenant_updateTime];
}

- (void)revenant_updateTime
{
    if (!self.isViewLoaded || !self.player)
        return;
    AVPlayerItem *item = self.player.currentItem;
    CMTime now = self.player.currentTime;
    CMTime duration = item ? item.duration : kCMTimeInvalid;
    _revenantElapsedLabel.text = revenant_time_text(now);
    if (CMTIME_IS_NUMERIC(duration) && CMTIME_IS_NUMERIC(now))
        _revenantRemainingLabel.text = [@"-" stringByAppendingString:revenant_time_text(CMTimeSubtract(duration, now))];
    else
        _revenantRemainingLabel.text = revenant_time_text(duration);
    if (!_revenantScrubbing && CMTIME_IS_NUMERIC(duration) && CMTimeGetSeconds(duration) > 0)
        _revenantScrubber.value = (float)(CMTimeGetSeconds(now) / CMTimeGetSeconds(duration));
}

- (void)revenant_scheduleHidingControls
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(revenant_hideControls) object:nil];
    if (self.player.rate != 0)
        [self performSelector:@selector(revenant_hideControls) withObject:nil afterDelay:3];
}

- (void)revenant_hideControls
{
    if (_revenantScrubbing || self.player.rate == 0)
        return;
    _revenantControlsHidden = YES;
    [self revenant_update];
}

#pragma mark - Observation

- (void)revenant_startObservingPlayer
{
    AVPlayer *player = _player;
    if (!player)
        return;
    [player addObserver:self forKeyPath:@"rate" options:0 context:RevenantAVPlayerObservation];
    [player addObserver:self forKeyPath:@"currentItem" options:0 context:RevenantAVPlayerObservation];
    [player addObserver:self forKeyPath:@"status" options:0 context:RevenantAVPlayerObservation];
    __weak AVPlayerViewController *weakSelf = self;
    _revenantTimeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMake(1, 4) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf revenant_updateTime];
    }];
    [self revenant_observeItem:player.currentItem];
}

- (void)revenant_stopObservingPlayer
{
    AVPlayer *player = _player;
    if (!player)
        return;
    [self revenant_observeItem:nil];
    if (_revenantTimeObserver)
        [player removeTimeObserver:_revenantTimeObserver];
    _revenantTimeObserver = nil;
    [player removeObserver:self forKeyPath:@"rate" context:RevenantAVPlayerObservation];
    [player removeObserver:self forKeyPath:@"currentItem" context:RevenantAVPlayerObservation];
    [player removeObserver:self forKeyPath:@"status" context:RevenantAVPlayerObservation];
}

- (void)revenant_observeItem:(AVPlayerItem *)item
{
    if (item == _revenantObservedItem)
        return;
    NSArray *keys = @[@"status", @"duration", @"playbackLikelyToKeepUp"];
    if (_revenantObservedItem) {
        for (NSString *key in keys)
            [_revenantObservedItem removeObserver:self forKeyPath:key context:RevenantAVPlayerObservation];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_revenantObservedItem];
    }
    _revenantObservedItem = item;
    [self revenant_attachVideoOutputTo:item];
    if (item) {
        _revenantFailure = nil;
        for (NSString *key in keys)
            [item addObserver:self forKeyPath:key options:0 context:RevenantAVPlayerObservation];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(revenant_playedToEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification object:item];
        __weak AVPlayerViewController *weakSelf = self;
        [item.asset loadValuesAsynchronouslyForKeys:@[@"commonMetadata"] completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf revenant_writeNowPlaying];
            });
        }];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != RevenantAVPlayerObservation) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        });
        return;
    }
    if (object == _revenantObservedItem && [keyPath isEqualToString:@"status"] && _revenantObservedItem.status == AVPlayerItemStatusFailed)
        _revenantFailure = _revenantObservedItem.error;
    if (object == _player && [keyPath isEqualToString:@"status"] && _player.status == AVPlayerStatusFailed)
        _revenantFailure = _player.error;
    if (object == _player && [keyPath isEqualToString:@"currentItem"]) {
        [self revenant_observeItem:_player.currentItem];
    } else if (object == _player && [keyPath isEqualToString:@"rate"]) {
        [self revenant_rateChanged];
    }
    [self revenant_update];
    [self revenant_writeNowPlaying];
}

- (void)revenant_rateChanged
{
    if (_player.rate != 0) {
        [self revenant_scheduleHidingControls];
        if (_entersFullScreenWhenPlaybackBegins && !_revenantFullScreen && ![self revenant_presentedItself] && self.isViewLoaded && self.view.window)
            [self revenant_enterFullScreen];
    } else {
        _revenantControlsHidden = NO;
    }
}

- (void)revenant_playedToEnd:(NSNotification *)notification
{
    _revenantControlsHidden = NO;
    [self revenant_update];
    if (!_exitsFullScreenWhenPlaybackEnds)
        return;
    if (_revenantFullScreen)
        [self revenant_exitFullScreen];
    else if ([self revenant_presentedItself])
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Now playing

- (void)revenant_writeNowPlaying
{
    if (!_updatesNowPlayingInfoCenter || !_player.currentItem)
        return;
    AVPlayerItem *item = _player.currentItem;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if ([item.asset statusOfValueForKey:@"commonMetadata" error:NULL] == AVKeyValueStatusLoaded) {
        NSArray *titles = [AVMetadataItem metadataItemsFromArray:item.asset.commonMetadata withKey:AVMetadataCommonKeyTitle
                                                        keySpace:AVMetadataKeySpaceCommon];
        NSString *title = titles.count > 0 ? [titles[0] stringValue] : nil;
        if (title)
            info[MPMediaItemPropertyTitle] = title;
    }
    if (CMTIME_IS_NUMERIC(item.duration))
        info[MPMediaItemPropertyPlaybackDuration] = @(CMTimeGetSeconds(item.duration));
    CMTime now = _player.currentTime;
    if (CMTIME_IS_NUMERIC(now))
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(now));
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(_player.rate);
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    _revenantWroteNowPlaying = YES;
}

- (void)revenant_clearNowPlaying
{
    if (!_revenantWroteNowPlaying)
        return;
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    _revenantWroteNowPlaying = NO;
}

#pragma mark - Actions

- (void)revenant_toggleControls:(UITapGestureRecognizer *)recognizer
{
    _revenantControlsHidden = !_revenantControls.hidden;
    [self revenant_update];
    if (!_revenantControlsHidden)
        [self revenant_scheduleHidingControls];
}

- (void)revenant_playPause:(id)sender
{
    if (_player.rate != 0) {
        [_player pause];
        return;
    }
    AVPlayerItem *item = _player.currentItem;
    if (item && CMTIME_IS_NUMERIC(item.duration) && CMTimeCompare(_player.currentTime, item.duration) >= 0)
        [_player seekToTime:kCMTimeZero];
    [_player play];
    if ([self respondsToSelector:@selector(revenant_applySelectedSpeed)])
        [self revenant_applySelectedSpeed];
}

- (void)revenant_scrubBegan:(UISlider *)slider
{
    _revenantScrubbing = YES;
    _revenantRateBeforeScrubbing = _player.rate;
    [_player pause];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(revenant_hideControls) object:nil];
}

- (void)revenant_scrubMoved:(UISlider *)slider
{
    CMTime duration = _player.currentItem.duration;
    if (!CMTIME_IS_NUMERIC(duration))
        return;
    CMTime target = CMTimeMultiplyByFloat64(duration, slider.value);
    [_player seekToTime:target toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    _revenantElapsedLabel.text = revenant_time_text(target);
    _revenantRemainingLabel.text = [@"-" stringByAppendingString:revenant_time_text(CMTimeSubtract(duration, target))];
}

- (void)revenant_scrubEnded:(UISlider *)slider
{
    _revenantScrubbing = NO;
    if (_revenantRateBeforeScrubbing != 0)
        _player.rate = _revenantRateBeforeScrubbing;
    [self revenant_scheduleHidingControls];
}

- (void)revenant_done:(id)sender
{
    if (_revenantFullScreen) {
        [self revenant_exitFullScreen];
        return;
    }
    [_player pause];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)revenant_fullScreen:(id)sender
{
    [self revenant_enterFullScreen];
}

- (void)revenant_picture:(id)sender
{
    if (!_revenantPicture) {
        _revenantPictureRelay = [[RevenantAVPlayerPictureInPictureRelay alloc] init];
        _revenantPictureRelay.owner = self;
        _revenantPicture = [[AVPictureInPictureController alloc] initWithPlayerLayer:_revenantVideoView.playerLayer];
        _revenantPicture.delegate = _revenantPictureRelay;
    }
    [_revenantPicture startPictureInPicture];
}

#pragma mark - Full screen

- (void)revenant_enterFullScreen
{
    if (_revenantFullScreen || !self.isViewLoaded)
        return;
    UIViewController *presenter = self.view.window.rootViewController;
    while (presenter.presentedViewController)
        presenter = presenter.presentedViewController;
    if (!presenter)
        return;
    RevenantAVPlayerFullScreenViewController *full = [[RevenantAVPlayerFullScreenViewController alloc] init];
    full.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    UIView *view = full.view;
    _revenantStage.frame = view.bounds;
    [view addSubview:_revenantStage];
    _revenantFullScreen = full;
    [self revenant_update];
    [presenter presentViewController:full animated:YES completion:nil];
    [self revenant_tellDelegateFullScreenBegins:YES of:full];
}

- (void)revenant_tellDelegateFullScreenBegins:(BOOL)begins of:(UIViewController *)full
{
    id<AVPlayerViewControllerDelegate> delegate = _revenantDelegate;
    SEL selector = begins ? @selector(playerViewController:willBeginFullScreenPresentationWithAnimationCoordinator:)
                          : @selector(playerViewController:willEndFullScreenPresentationWithAnimationCoordinator:);
    if (![delegate respondsToSelector:selector])
        return;
    id<UIViewControllerTransitionCoordinator> coordinator = full.transitionCoordinator;
    NSAssert(coordinator, @"UIKitBackports gives every presentation a transition coordinator");
    if (begins)
        [delegate playerViewController:self willBeginFullScreenPresentationWithAnimationCoordinator:coordinator];
    else
        [delegate playerViewController:self willEndFullScreenPresentationWithAnimationCoordinator:coordinator];
}

- (void)revenant_exitFullScreen
{
    RevenantAVPlayerFullScreenViewController *full = _revenantFullScreen;
    if (!full)
        return;
    [full.presentingViewController dismissViewControllerAnimated:YES completion:^{
        self->_revenantStage.frame = self.view.bounds;
        [self.view addSubview:self->_revenantStage];
        self->_revenantFullScreen = nil;
        [self revenant_update];
    }];
    [self revenant_tellDelegateFullScreenBegins:NO of:full];
}

#pragma mark - Picture in picture

- (void)revenant_pictureInPictureWillStart
{
    [revenant_players_in_picture() addObject:self];
    id<AVPlayerViewControllerDelegate> delegate = _revenantDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerWillStartPictureInPicture:)])
        [delegate playerViewControllerWillStartPictureInPicture:self];
}

- (void)revenant_pictureInPictureDidStart
{
    [self revenant_update];
    id<AVPlayerViewControllerDelegate> delegate = _revenantDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerDidStartPictureInPicture:)])
        [delegate playerViewControllerDidStartPictureInPicture:self];
    BOOL dismiss = YES;
    if ([delegate respondsToSelector:@selector(playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart:)])
        dismiss = [delegate playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart:self];
    if (!dismiss)
        return;
    if (_revenantFullScreen)
        [self revenant_exitFullScreen];
    else if ([self revenant_presentedItself])
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)revenant_pictureInPictureFailed:(NSError *)error
{
    [revenant_players_in_picture() removeObject:self];
    id<AVPlayerViewControllerDelegate> delegate = _revenantDelegate;
    if ([delegate respondsToSelector:@selector(playerViewController:failedToStartPictureInPictureWithError:)])
        [delegate playerViewController:self failedToStartPictureInPictureWithError:error];
}

- (void)revenant_pictureInPictureWillStop
{
    id<AVPlayerViewControllerDelegate> delegate = _revenantDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerWillStopPictureInPicture:)])
        [delegate playerViewControllerWillStopPictureInPicture:self];
}

- (void)revenant_pictureInPictureRestore:(void (^)(BOOL restored))completion
{
    id<AVPlayerViewControllerDelegate> delegate = _revenantDelegate;
    if ([delegate respondsToSelector:@selector(playerViewController:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:)])
        [delegate playerViewController:self restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:completion];
    else
        completion(NO);
}

- (void)revenant_pictureInPictureDidStop
{
    [self.view setNeedsLayout];
    [self revenant_update];
    id<AVPlayerViewControllerDelegate> delegate = _revenantDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerDidStopPictureInPicture:)])
        [delegate playerViewControllerDidStopPictureInPicture:self];
    [revenant_players_in_picture() removeObject:self];
}

@end
