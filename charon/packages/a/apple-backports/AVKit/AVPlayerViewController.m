#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
// The one declaration this object needs from the 16.0 speed object, for the play path's call. A
// declaration, not a definition: the method lives in AVPlayerViewControllerSpeeds16.m.
#import "CharonAVKitSpeeds.h"

// Rank 25 of coordination/corpus/band-frameworks.tsv, LOAD-FAIL: session strong-imports the class
// (Session and SignalUtilitiesKit bind _OBJC_CLASS_$_AVPlayerViewController), so the application
// dies in dyld before its first line without it. The armv7 cache ladder first carries the class at
// 8.0. It is a view controller around an AVPlayerLayer with its own playback controls, which is
// what this is: the same AVPlayerLayer iOS 6 already carries, with controls built of UIKit views
// the release has, picture in picture over this package's own AVPictureInPictureController, and
// the full screen presentation of an inline player as an ordinary modal view controller.
// What differs from the release is in facts/AVKit/AVPlayerViewController.md.

@class CharonAVPlayerPictureInPictureRelay;

// A display link retains its target; the controller is reached through this, so that it can go away.
@interface CharonAVPlayerFrameTicker : NSObject
@property (nonatomic, weak) id target;
- (void)tick:(CADisplayLink *)link;
@end

@implementation CharonAVPlayerFrameTicker

@synthesize target = _target;

- (void)tick:(CADisplayLink *)link
{
    [self.target performSelector:@selector(charon_drawFrame:) withObject:link];
}

@end

@interface CharonAVPlayerVideoView : UIView
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@end

@implementation CharonAVPlayerVideoView

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
    // Picture in picture takes the layer into its own window; it is laid out there, not here.
    if (_playerLayer.superlayer != self.layer)
        return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _playerLayer.frame = self.layer.bounds;
    [CATransaction commit];
}

@end

// Draws the controls' glyphs, since iOS 6 has no symbol images: white on clear, 22x22 points.
static UIImage *charon_glyph(void (^draw)(CGRect bounds))
{
    CGRect bounds = CGRectMake(0, 0, 22, 22);
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
    [[UIColor whiteColor] set];
    draw(bounds);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *charon_play_glyph(void)
{
    return charon_glyph(^(CGRect bounds) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(5, 3)];
        [path addLineToPoint:CGPointMake(19, 11)];
        [path addLineToPoint:CGPointMake(5, 19)];
        [path closePath];
        [path fill];
    });
}

static UIImage *charon_pause_glyph(void)
{
    return charon_glyph(^(CGRect bounds) {
        UIRectFill(CGRectMake(5, 3, 4, 16));
        UIRectFill(CGRectMake(13, 3, 4, 16));
    });
}

static UIImage *charon_picture_glyph(void)
{
    return charon_glyph(^(CGRect bounds) {
        UIBezierPath *frame = [UIBezierPath bezierPathWithRect:CGRectMake(2, 4, 18, 14)];
        frame.lineWidth = 1.5;
        [frame stroke];
        UIRectFill(CGRectMake(11, 11, 7, 5));
    });
}

static UIImage *charon_full_screen_glyph(void)
{
    return charon_glyph(^(CGRect bounds) {
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

static NSString *charon_time_text(CMTime time)
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

@interface CharonAVPlayerFullScreenViewController : UIViewController
@end

@implementation CharonAVPlayerFullScreenViewController

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
@property (nonatomic, strong, readonly) CharonAVPlayerVideoView *charonVideoView;
- (void)charon_pictureInPictureWillStart;
- (void)charon_pictureInPictureDidStart;
- (void)charon_pictureInPictureFailed:(NSError *)error;
- (void)charon_pictureInPictureWillStop;
- (void)charon_pictureInPictureRestore:(void (^)(BOOL restored))completion;
- (void)charon_pictureInPictureDidStop;
@end

// AVPictureInPictureController's delegate for the player view controller, so that the class does
// not claim a protocol the release's own does not answer to in conformsToProtocol:.
@interface CharonAVPlayerPictureInPictureRelay : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, weak) AVPlayerViewController *owner;
@end

@implementation CharonAVPlayerPictureInPictureRelay

@synthesize owner = _owner;

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner charon_pictureInPictureWillStart];
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner charon_pictureInPictureDidStart];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error
{
    [self.owner charon_pictureInPictureFailed:error];
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner charon_pictureInPictureWillStop];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completion
{
    AVPlayerViewController *owner = self.owner;
    if (owner)
        [owner charon_pictureInPictureRestore:completion];
    else
        completion(NO);
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller
{
    [self.owner charon_pictureInPictureDidStop];
}

@end

static void *const CharonAVPlayerObservation = (void *)&CharonAVPlayerObservation;

// A player view controller in picture in picture is held here, since the application may drop
// its last reference once the controller dismisses itself, as the release's own does.
static NSMutableSet *charon_players_in_picture(void)
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
    UIView *_charonStage;
    UIView *_charonContentOverlayView;
    UIView *_charonControls;
    UIToolbar *_charonTopBar;
    UIView *_charonBottomBar;
    UIBarButtonItem *_charonDoneItem;
    UIButton *_charonPlayButton;
    UIBarButtonItem *_charonPictureItem;
    UIButton *_charonFullScreenButton;
    UISlider *_charonScrubber;
    UILabel *_charonElapsedLabel;
    UILabel *_charonRemainingLabel;
    UILabel *_charonFailureLabel;
    UIActivityIndicatorView *_charonSpinner;
    UITapGestureRecognizer *_charonTap;
    AVPlayerItem *_charonObservedItem;
    NSError *_charonFailure;
    id _charonTimeObserver;
    CharonAVPlayerFullScreenViewController *_charonFullScreen;
    AVPictureInPictureController *_charonPicture;
    CharonAVPlayerPictureInPictureRelay *_charonPictureRelay;
    BOOL _charonScrubbing;
    float _charonRateBeforeScrubbing;
    BOOL _charonWroteNowPlaying;
    BOOL _charonControlsHidden;
    __weak id<AVPlayerViewControllerDelegate> _charonDelegate;
    NSDictionary *_charonPixelBufferAttributes;
    AVPlayerItemVideoOutput *_charonVideoOutput;
    AVPlayerItem *_charonOutputItem;
    CADisplayLink *_charonFrameLink;
    CALayer *_charonFrameLayer;
    CIContext *_charonFrameContext;
    BOOL _charonFrameRefusalLogged;
}

@synthesize player = _player;
@synthesize showsPlaybackControls = _showsPlaybackControls;
@synthesize videoGravity = _videoGravity;
@synthesize allowsPictureInPicturePlayback = _allowsPictureInPicturePlayback;
@synthesize updatesNowPlayingInfoCenter = _updatesNowPlayingInfoCenter;
@synthesize entersFullScreenWhenPlaybackBegins = _entersFullScreenWhenPlaybackBegins;
@synthesize exitsFullScreenWhenPlaybackEnds = _exitsFullScreenWhenPlaybackEnds;
@synthesize requiresLinearPlayback = _requiresLinearPlayback;
@synthesize charonVideoView = _charonVideoView;
// Declared by the header, not carried: without @dynamic clang would synthesize accessors that store
// a value and do nothing with it. See the registry's absent entries for why each is not built.
//
// `speeds` and `selectedSpeed` are on this line and STAY on it, though both are now implemented - in
// AVPlayerViewControllerSpeeds16.m, the object that owns the 16.0 API. Dropping them here is not
// neutral: this object has no @dynamic then, and clang synthesizes its own `speeds` and
// `selectedSpeed` that store a value and are never read. A class's own synthesized methods beat a
// category's, so the 16.0 implementation would never be reached. Measured: with the names removed
// from this line, otool -ov of THIS object lists -[AVPlayerViewController speeds] and
// -[AVPlayerViewController selectedSpeed], and the 16.0 object's category lists neither.
@dynamic showsTimecodes, canStartPictureInPictureAutomaticallyFromInline, allowsVideoFrameAnalysis, speeds,
    selectedSpeed;

- (void)charon_setUp
{
    _showsPlaybackControls = YES;
    _videoGravity = [AVLayerVideoGravityResizeAspect copy];
    _allowsPictureInPicturePlayback = YES;
    _updatesNowPlayingInfoCenter = YES;
    _charonVideoView = [[CharonAVPlayerVideoView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    _charonVideoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _charonContentOverlayView = [[UIView alloc] initWithFrame:_charonVideoView.frame];
    _charonContentOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _charonContentOverlayView.backgroundColor = [UIColor clearColor];
}

- (instancetype)initWithNibName:(NSString *)name bundle:(NSBundle *)bundle
{
    if ((self = [super initWithNibName:name bundle:bundle]))
        [self charon_setUp];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        [self charon_setUp];
    return self;
}

- (void)dealloc
{
    [_charonFrameLink invalidate];
    [self charon_stopObservingPlayer];
    [self charon_clearNowPlaying];
}

#pragma mark - Properties

- (void)setPlayer:(AVPlayer *)player
{
    if (player == _player)
        return;
    [self charon_stopObservingPlayer];
    [self charon_clearNowPlaying];
    _charonFailure = nil;
    _player = player;
    _charonVideoView.playerLayer.player = player;
    [self charon_startObservingPlayer];
    [self charon_update];
}

- (void)setShowsPlaybackControls:(BOOL)shows
{
    _showsPlaybackControls = shows;
    [self charon_update];
}

- (void)setVideoGravity:(NSString *)gravity
{
    if (![gravity isEqualToString:AVLayerVideoGravityResizeAspect] && ![gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]
        && ![gravity isEqualToString:AVLayerVideoGravityResize])
        gravity = AVLayerVideoGravityResizeAspect;
    _videoGravity = [gravity copy];
    _charonVideoView.playerLayer.videoGravity = _videoGravity;
    _charonFrameLayer.contentsGravity = charon_contents_gravity(_videoGravity);
}

#pragma mark - Pixel buffer attributes

// 6.1.3's AVPlayerLayer takes no pixel format, and AVPlayerItemVideoOutput (6.0) does: with attributes set,
// the frames on screen are the output's, made with them, drawn over the layer, which stays for picture in
// picture, readiness and the video rectangle. facts/AVKit/AVPlayerViewController.md.
static NSString *charon_contents_gravity(NSString *videoGravity)
{
    if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill])
        return kCAGravityResizeAspectFill;
    if ([videoGravity isEqualToString:AVLayerVideoGravityResize])
        return kCAGravityResize;
    return kCAGravityResizeAspect;
}

- (NSDictionary<NSString *, id> *)pixelBufferAttributes
{
    return _charonPixelBufferAttributes;
}

- (void)setPixelBufferAttributes:(NSDictionary<NSString *, id> *)attributes
{
    _charonPixelBufferAttributes = [attributes copy];
    [self charon_attachVideoOutputTo:nil];
    [self charon_attachVideoOutputTo:_player.currentItem];
}

- (void)charon_attachVideoOutputTo:(AVPlayerItem *)item
{
    if (_charonVideoOutput) {
        [_charonOutputItem removeOutput:_charonVideoOutput];
        _charonVideoOutput = nil;
        _charonOutputItem = nil;
    }
    if (!item || !_charonPixelBufferAttributes) {
        [_charonFrameLink invalidate];
        _charonFrameLink = nil;
        [_charonFrameLayer removeFromSuperlayer];
        _charonFrameLayer = nil;
        return;
    }
    // The release decodes into IOSurfaces for its own layer, and CoreImage of 6.1.3 draws only a buffer
    // that is one, so the output is asked for that as well as for what the application gave.
    NSMutableDictionary *attributes = [_charonPixelBufferAttributes mutableCopy];
    if (!attributes[(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey])
        attributes[(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey] = @{};
    _charonVideoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:attributes];
    _charonOutputItem = item;
    [item addOutput:_charonVideoOutput];
    if (!_charonFrameLayer) {
        _charonFrameLayer = [CALayer layer];
        _charonFrameLayer.contentsGravity = charon_contents_gravity(_videoGravity);
        [_charonVideoView.playerLayer addSublayer:_charonFrameLayer];
    }
    if (!_charonFrameContext)
        _charonFrameContext = [CIContext contextWithOptions:nil];
    if (!_charonFrameLink) {
        CharonAVPlayerFrameTicker *ticker = [[CharonAVPlayerFrameTicker alloc] init];
        ticker.target = self;
        _charonFrameLink = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
        [_charonFrameLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)charon_drawFrame:(CADisplayLink *)link
{
    AVPlayerItemVideoOutput *output = _charonVideoOutput;
    CALayer *layer = _charonFrameLayer;
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
    CGImageRef frame = image ? [_charonFrameContext createCGImage:image fromRect:image.extent] : NULL;
    OSType format = CVPixelBufferGetPixelFormatType(buffer);
    CVPixelBufferRelease(buffer);
    if (!frame) {
        // What CoreImage of the release cannot draw stays under the layer's own frames, and is said once.
        if (!_charonFrameRefusalLogged)
            NSLog(@"AVPlayerViewController: CoreImage of this release draws no frame of pixel format '%c%c%c%c'; the player layer's own frames are shown",
                  (char)(format >> 24), (char)(format >> 16), (char)(format >> 8), (char)format);
        _charonFrameRefusalLogged = YES;
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
    return [NSSet setWithObject:@"charonVideoView.playerLayer.readyForDisplay"];
}

- (BOOL)isReadyForDisplay
{
    return _charonVideoView.playerLayer.readyForDisplay;
}

+ (NSSet *)keyPathsForValuesAffectingVideoBounds
{
    return [NSSet setWithObjects:@"player.currentItem.presentationSize", @"videoGravity", nil];
}

- (CGRect)videoBounds
{
    CGSize size = self.player.currentItem.presentationSize;
    CGRect bounds = _charonVideoView.bounds;
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
    return self.isViewLoaded ? [_charonVideoView convertRect:rect toView:self.view] : rect;
}

- (UIView *)contentOverlayView
{
    return _charonContentOverlayView;
}

- (id<AVPlayerViewControllerDelegate>)delegate
{
    return _charonDelegate;
}

- (void)setDelegate:(id<AVPlayerViewControllerDelegate>)delegate
{
    _charonDelegate = delegate;
}

- (void)setAllowsPictureInPicturePlayback:(BOOL)allows
{
    _allowsPictureInPicturePlayback = allows;
    [self charon_update];
}

- (void)setUpdatesNowPlayingInfoCenter:(BOOL)updates
{
    _updatesNowPlayingInfoCenter = updates;
    if (updates)
        [self charon_writeNowPlaying];
    else
        [self charon_clearNowPlaying];
}

- (void)setRequiresLinearPlayback:(BOOL)requires
{
    _requiresLinearPlayback = requires;
    [self charon_update];
}

#pragma mark - View

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    view.backgroundColor = [UIColor blackColor];
    view.clipsToBounds = YES;

    _charonStage = [[UIView alloc] initWithFrame:view.bounds];
    _charonStage.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _charonStage.backgroundColor = [UIColor blackColor];
    [view addSubview:_charonStage];

    _charonVideoView.frame = _charonStage.bounds;
    [_charonStage addSubview:_charonVideoView];
    _charonContentOverlayView.frame = _charonStage.bounds;
    [_charonStage addSubview:_charonContentOverlayView];

    _charonSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _charonSpinner.hidesWhenStopped = YES;
    _charonSpinner.center = CGPointMake(CGRectGetMidX(_charonStage.bounds), CGRectGetMidY(_charonStage.bounds));
    _charonSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
        | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [_charonStage addSubview:_charonSpinner];

    _charonFailureLabel = [[UILabel alloc] initWithFrame:CGRectInset(_charonStage.bounds, 16, 0)];
    _charonFailureLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _charonFailureLabel.backgroundColor = [UIColor clearColor];
    _charonFailureLabel.textColor = [UIColor whiteColor];
    _charonFailureLabel.textAlignment = NSTextAlignmentCenter;
    _charonFailureLabel.numberOfLines = 0;
    _charonFailureLabel.hidden = YES;
    [_charonStage addSubview:_charonFailureLabel];

    [self charon_buildControls];
    self.view = view;

    _charonTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(charon_toggleControls:)];
    _charonTap.delegate = self;
    [_charonStage addGestureRecognizer:_charonTap];
    [self charon_update];
}

- (UIButton *)charon_buttonWithImage:(UIImage *)image action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 44, 44);
    [button setImage:image forState:UIControlStateNormal];
    button.showsTouchWhenHighlighted = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)charon_timeLabel
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 56, 44)];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:12];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    return label;
}

- (void)charon_buildControls
{
    CGRect bounds = _charonStage.bounds;
    _charonControls = [[UIView alloc] initWithFrame:bounds];
    _charonControls.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _charonControls.backgroundColor = [UIColor clearColor];
    [_charonStage addSubview:_charonControls];

    // The system's own Done, titled and localized by UIKit.
    _charonTopBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 44)];
    _charonTopBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _charonTopBar.barStyle = UIBarStyleBlack;
    _charonTopBar.translucent = YES;
    [_charonControls addSubview:_charonTopBar];
    _charonDoneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(charon_done:)];
    _charonPictureItem = [[UIBarButtonItem alloc] initWithImage:charon_picture_glyph() style:UIBarButtonItemStylePlain target:self
                                                         action:@selector(charon_picture:)];

    _charonBottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, bounds.size.height - 44, bounds.size.width, 44)];
    _charonBottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _charonBottomBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    [_charonControls addSubview:_charonBottomBar];

    _charonPlayButton = [self charon_buttonWithImage:charon_play_glyph() action:@selector(charon_playPause:)];
    [_charonBottomBar addSubview:_charonPlayButton];

    _charonElapsedLabel = [self charon_timeLabel];
    _charonElapsedLabel.frame = CGRectMake(44, 0, 52, 44);
    [_charonBottomBar addSubview:_charonElapsedLabel];

    _charonFullScreenButton = [self charon_buttonWithImage:charon_full_screen_glyph() action:@selector(charon_fullScreen:)];
    _charonFullScreenButton.frame = CGRectMake(bounds.size.width - 44, 0, 44, 44);
    _charonFullScreenButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_charonBottomBar addSubview:_charonFullScreenButton];

    _charonRemainingLabel = [self charon_timeLabel];
    _charonRemainingLabel.frame = CGRectMake(bounds.size.width - 44 - 56, 0, 56, 44);
    _charonRemainingLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_charonBottomBar addSubview:_charonRemainingLabel];

    _charonScrubber = [[UISlider alloc] initWithFrame:CGRectMake(100, 0, bounds.size.width - 100 - 44 - 60, 44)];
    _charonScrubber.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _charonScrubber.minimumValue = 0;
    _charonScrubber.maximumValue = 1;
    [_charonScrubber addTarget:self action:@selector(charon_scrubBegan:) forControlEvents:UIControlEventTouchDown];
    [_charonScrubber addTarget:self action:@selector(charon_scrubMoved:) forControlEvents:UIControlEventValueChanged];
    [_charonScrubber addTarget:self action:@selector(charon_scrubEnded:)
              forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_charonBottomBar addSubview:_charonScrubber];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self charon_update];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self charon_layOutBottomBar];
}

- (void)charon_layOutBottomBar
{
    CGFloat width = _charonBottomBar.bounds.size.width;
    CGFloat right = _charonFullScreenButton.hidden ? width : width - 44;
    _charonRemainingLabel.frame = CGRectMake(right - 56, 0, 56, 44);
    _charonScrubber.frame = CGRectMake(100, 0, MAX(0, right - 56 - 100 - 4), 44);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
    for (UIView *view = touch.view; view; view = view.superview) {
        if ([view isKindOfClass:[UIControl class]] || view == _charonTopBar || view == _charonBottomBar)
            return NO;
    }
    return YES;
}

#pragma mark - State

- (BOOL)charon_presentedItself
{
    return self.presentingViewController != nil && self.parentViewController == nil;
}

- (BOOL)charon_pictureActive
{
    return _charonPicture.pictureInPictureActive;
}

- (void)charon_update
{
    if (!self.isViewLoaded)
        return;
    AVPlayerItem *item = self.player.currentItem;
    // The release takes a failed item out of the player, so the failure is kept until another item comes.
    BOOL failed = _charonFailure != nil || item.status == AVPlayerItemStatusFailed || self.player.status == AVPlayerStatusFailed;
    _charonFailureLabel.hidden = !failed;
    if (failed)
        _charonFailureLabel.text = (_charonFailure ?: item.error ?: self.player.error).localizedDescription ?: @"This video cannot be played.";

    BOOL playing = self.player.rate != 0;
    [_charonPlayButton setImage:playing ? charon_pause_glyph() : charon_play_glyph() forState:UIControlStateNormal];
    _charonPlayButton.enabled = self.player != nil && !failed;

    BOOL waiting = playing && item != nil && !item.playbackLikelyToKeepUp && item.status != AVPlayerItemStatusFailed;
    if (waiting || (item && item.status == AVPlayerItemStatusUnknown))
        [_charonSpinner startAnimating];
    else
        [_charonSpinner stopAnimating];

    BOOL full = _charonFullScreen != nil;
    BOOL done = full || [self charon_presentedItself];
    BOOL picture = _allowsPictureInPicturePlayback && [AVPictureInPictureController isPictureInPictureSupported] && ![self charon_pictureActive];
    _charonFullScreenButton.hidden = done;
    NSMutableArray *items = [NSMutableArray array];
    if (done)
        [items addObject:_charonDoneItem];
    [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL]];
    if (picture)
        [items addObject:_charonPictureItem];
    _charonTopBar.items = items;
    _charonTopBar.hidden = !done && !picture;
    _charonScrubber.enabled = !_requiresLinearPlayback && item != nil && CMTIME_IS_NUMERIC(item.duration);

    BOOL controls = _showsPlaybackControls && !(_charonControlsHidden && playing);
    _charonControls.hidden = !controls;
    _charonTap.enabled = _showsPlaybackControls;
    [self charon_layOutBottomBar];
    [self charon_updateTime];
}

- (void)charon_updateTime
{
    if (!self.isViewLoaded || !self.player)
        return;
    AVPlayerItem *item = self.player.currentItem;
    CMTime now = self.player.currentTime;
    CMTime duration = item ? item.duration : kCMTimeInvalid;
    _charonElapsedLabel.text = charon_time_text(now);
    if (CMTIME_IS_NUMERIC(duration) && CMTIME_IS_NUMERIC(now))
        _charonRemainingLabel.text = [@"-" stringByAppendingString:charon_time_text(CMTimeSubtract(duration, now))];
    else
        _charonRemainingLabel.text = charon_time_text(duration);
    if (!_charonScrubbing && CMTIME_IS_NUMERIC(duration) && CMTimeGetSeconds(duration) > 0)
        _charonScrubber.value = (float)(CMTimeGetSeconds(now) / CMTimeGetSeconds(duration));
}

- (void)charon_scheduleHidingControls
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(charon_hideControls) object:nil];
    if (self.player.rate != 0)
        [self performSelector:@selector(charon_hideControls) withObject:nil afterDelay:3];
}

- (void)charon_hideControls
{
    if (_charonScrubbing || self.player.rate == 0)
        return;
    _charonControlsHidden = YES;
    [self charon_update];
}

#pragma mark - Observation

- (void)charon_startObservingPlayer
{
    AVPlayer *player = _player;
    if (!player)
        return;
    [player addObserver:self forKeyPath:@"rate" options:0 context:CharonAVPlayerObservation];
    [player addObserver:self forKeyPath:@"currentItem" options:0 context:CharonAVPlayerObservation];
    [player addObserver:self forKeyPath:@"status" options:0 context:CharonAVPlayerObservation];
    __weak AVPlayerViewController *weakSelf = self;
    _charonTimeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMake(1, 4) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf charon_updateTime];
    }];
    [self charon_observeItem:player.currentItem];
}

- (void)charon_stopObservingPlayer
{
    AVPlayer *player = _player;
    if (!player)
        return;
    [self charon_observeItem:nil];
    if (_charonTimeObserver)
        [player removeTimeObserver:_charonTimeObserver];
    _charonTimeObserver = nil;
    [player removeObserver:self forKeyPath:@"rate" context:CharonAVPlayerObservation];
    [player removeObserver:self forKeyPath:@"currentItem" context:CharonAVPlayerObservation];
    [player removeObserver:self forKeyPath:@"status" context:CharonAVPlayerObservation];
}

- (void)charon_observeItem:(AVPlayerItem *)item
{
    if (item == _charonObservedItem)
        return;
    NSArray *keys = @[@"status", @"duration", @"playbackLikelyToKeepUp"];
    if (_charonObservedItem) {
        for (NSString *key in keys)
            [_charonObservedItem removeObserver:self forKeyPath:key context:CharonAVPlayerObservation];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_charonObservedItem];
    }
    _charonObservedItem = item;
    [self charon_attachVideoOutputTo:item];
    if (item) {
        _charonFailure = nil;
        for (NSString *key in keys)
            [item addObserver:self forKeyPath:key options:0 context:CharonAVPlayerObservation];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(charon_playedToEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification object:item];
        __weak AVPlayerViewController *weakSelf = self;
        [item.asset loadValuesAsynchronouslyForKeys:@[@"commonMetadata"] completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf charon_writeNowPlaying];
            });
        }];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != CharonAVPlayerObservation) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        });
        return;
    }
    if (object == _charonObservedItem && [keyPath isEqualToString:@"status"] && _charonObservedItem.status == AVPlayerItemStatusFailed)
        _charonFailure = _charonObservedItem.error;
    if (object == _player && [keyPath isEqualToString:@"status"] && _player.status == AVPlayerStatusFailed)
        _charonFailure = _player.error;
    if (object == _player && [keyPath isEqualToString:@"currentItem"]) {
        [self charon_observeItem:_player.currentItem];
    } else if (object == _player && [keyPath isEqualToString:@"rate"]) {
        [self charon_rateChanged];
    }
    [self charon_update];
    [self charon_writeNowPlaying];
}

- (void)charon_rateChanged
{
    if (_player.rate != 0) {
        [self charon_scheduleHidingControls];
        if (_entersFullScreenWhenPlaybackBegins && !_charonFullScreen && ![self charon_presentedItself] && self.isViewLoaded && self.view.window)
            [self charon_enterFullScreen];
    } else {
        _charonControlsHidden = NO;
    }
}

- (void)charon_playedToEnd:(NSNotification *)notification
{
    _charonControlsHidden = NO;
    [self charon_update];
    if (!_exitsFullScreenWhenPlaybackEnds)
        return;
    if (_charonFullScreen)
        [self charon_exitFullScreen];
    else if ([self charon_presentedItself])
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Now playing

- (void)charon_writeNowPlaying
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
    _charonWroteNowPlaying = YES;
}

- (void)charon_clearNowPlaying
{
    if (!_charonWroteNowPlaying)
        return;
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    _charonWroteNowPlaying = NO;
}

#pragma mark - Actions

- (void)charon_toggleControls:(UITapGestureRecognizer *)recognizer
{
    _charonControlsHidden = !_charonControls.hidden;
    [self charon_update];
    if (!_charonControlsHidden)
        [self charon_scheduleHidingControls];
}

- (void)charon_playPause:(id)sender
{
    if (_player.rate != 0) {
        [_player pause];
        return;
    }
    AVPlayerItem *item = _player.currentItem;
    if (item && CMTIME_IS_NUMERIC(item.duration) && CMTimeCompare(_player.currentTime, item.duration) >= 0)
        [_player seekToTime:kCMTimeZero];
    [_player play];
    // A playback speed selected while paused is applied here, which is the event AVPlaybackSpeed.h:51
    // names. The method belongs to the 16.0 object, so it is asked for rather than sent blindly: this
    // object also links in the bands that do not carry it.
    if ([self respondsToSelector:@selector(charon_applySelectedSpeed)])
        [self charon_applySelectedSpeed];
}

- (void)charon_scrubBegan:(UISlider *)slider
{
    _charonScrubbing = YES;
    _charonRateBeforeScrubbing = _player.rate;
    [_player pause];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(charon_hideControls) object:nil];
}

- (void)charon_scrubMoved:(UISlider *)slider
{
    CMTime duration = _player.currentItem.duration;
    if (!CMTIME_IS_NUMERIC(duration))
        return;
    CMTime target = CMTimeMultiplyByFloat64(duration, slider.value);
    [_player seekToTime:target toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    _charonElapsedLabel.text = charon_time_text(target);
    _charonRemainingLabel.text = [@"-" stringByAppendingString:charon_time_text(CMTimeSubtract(duration, target))];
}

- (void)charon_scrubEnded:(UISlider *)slider
{
    _charonScrubbing = NO;
    if (_charonRateBeforeScrubbing != 0)
        _player.rate = _charonRateBeforeScrubbing;
    [self charon_scheduleHidingControls];
}

- (void)charon_done:(id)sender
{
    if (_charonFullScreen) {
        [self charon_exitFullScreen];
        return;
    }
    [_player pause];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)charon_fullScreen:(id)sender
{
    [self charon_enterFullScreen];
}

- (void)charon_picture:(id)sender
{
    if (!_charonPicture) {
        _charonPictureRelay = [[CharonAVPlayerPictureInPictureRelay alloc] init];
        _charonPictureRelay.owner = self;
        _charonPicture = [[AVPictureInPictureController alloc] initWithPlayerLayer:_charonVideoView.playerLayer];
        _charonPicture.delegate = _charonPictureRelay;
    }
    [_charonPicture startPictureInPicture];
}

#pragma mark - Full screen

- (void)charon_enterFullScreen
{
    if (_charonFullScreen || !self.isViewLoaded)
        return;
    UIViewController *presenter = self.view.window.rootViewController;
    while (presenter.presentedViewController)
        presenter = presenter.presentedViewController;
    if (!presenter)
        return;
    CharonAVPlayerFullScreenViewController *full = [[CharonAVPlayerFullScreenViewController alloc] init];
    full.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    UIView *view = full.view;
    _charonStage.frame = view.bounds;
    [view addSubview:_charonStage];
    _charonFullScreen = full;
    [self charon_update];
    [presenter presentViewController:full animated:YES completion:nil];
    [self charon_tellDelegateFullScreenBegins:YES of:full];
}

// The transition coordinator is the one UIKitBackports (which this library links) attaches to the full
// screen controller when its presentViewController: or dismissViewControllerAnimated: starts, and keeps
// until the transition ends: the delegate animates alongside it and sees whether it was cancelled.
- (void)charon_tellDelegateFullScreenBegins:(BOOL)begins of:(UIViewController *)full
{
    id<AVPlayerViewControllerDelegate> delegate = _charonDelegate;
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

- (void)charon_exitFullScreen
{
    CharonAVPlayerFullScreenViewController *full = _charonFullScreen;
    if (!full)
        return;
    [full.presentingViewController dismissViewControllerAnimated:YES completion:^{
        self->_charonStage.frame = self.view.bounds;
        [self.view addSubview:self->_charonStage];
        self->_charonFullScreen = nil;
        [self charon_update];
    }];
    [self charon_tellDelegateFullScreenBegins:NO of:full];
}

#pragma mark - Picture in picture

- (void)charon_pictureInPictureWillStart
{
    [charon_players_in_picture() addObject:self];
    id<AVPlayerViewControllerDelegate> delegate = _charonDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerWillStartPictureInPicture:)])
        [delegate playerViewControllerWillStartPictureInPicture:self];
}

- (void)charon_pictureInPictureDidStart
{
    [self charon_update];
    id<AVPlayerViewControllerDelegate> delegate = _charonDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerDidStartPictureInPicture:)])
        [delegate playerViewControllerDidStartPictureInPicture:self];
    BOOL dismiss = YES;
    if ([delegate respondsToSelector:@selector(playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart:)])
        dismiss = [delegate playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart:self];
    if (!dismiss)
        return;
    if (_charonFullScreen)
        [self charon_exitFullScreen];
    else if ([self charon_presentedItself])
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)charon_pictureInPictureFailed:(NSError *)error
{
    [charon_players_in_picture() removeObject:self];
    id<AVPlayerViewControllerDelegate> delegate = _charonDelegate;
    if ([delegate respondsToSelector:@selector(playerViewController:failedToStartPictureInPictureWithError:)])
        [delegate playerViewController:self failedToStartPictureInPictureWithError:error];
}

- (void)charon_pictureInPictureWillStop
{
    id<AVPlayerViewControllerDelegate> delegate = _charonDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerWillStopPictureInPicture:)])
        [delegate playerViewControllerWillStopPictureInPicture:self];
}

- (void)charon_pictureInPictureRestore:(void (^)(BOOL restored))completion
{
    id<AVPlayerViewControllerDelegate> delegate = _charonDelegate;
    if ([delegate respondsToSelector:@selector(playerViewController:restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:)])
        [delegate playerViewController:self restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:completion];
    else
        completion(NO);
}

- (void)charon_pictureInPictureDidStop
{
    [self.view setNeedsLayout];
    [self charon_update];
    id<AVPlayerViewControllerDelegate> delegate = _charonDelegate;
    if ([delegate respondsToSelector:@selector(playerViewControllerDidStopPictureInPicture:)])
        [delegate playerViewControllerDidStopPictureInPicture:self];
    [charon_players_in_picture() removeObject:self];
}

@end
