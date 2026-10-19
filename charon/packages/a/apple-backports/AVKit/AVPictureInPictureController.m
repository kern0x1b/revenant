#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// Rank 18 of coordination/corpus/crash-demand-top.tsv, LOAD-FAIL, class_confirmed against both
// telegram and yattee's own trees - five of telegram's own submodules confirm this is real
// picture-in-picture for calls, not merely an availability check. Two-step check first:
// apple.objc.inventory() against the armv7 shared cache of 6.1.3 found no
// AVPictureInPictureController/AVPictureInPictureControllerDelegate under any name - a genuine
// gap - while AVPlayerLayer, the real class -initWithPlayerLayer: takes, is already real and
// exported. grep of this tree's own .m files found no orphaned implementation.
//
// AVKit.framework does not exist at all on this release - not merely missing this one class, the
// way MediaPlayer.framework carries older API around its missing command surface. Nor does any
// cross-app window-compositing surface exist for a third-party dylib to draw into: the real
// system's picture-in-picture floats a window SpringBoard itself owns and composites above every
// app, the same wall CoreSpotlightBackports' own search bundle hit trying to reach the system
// search UI, and the same one CallKitBackports' CharonCallScreen answers by shipping only the
// application's own half of a two-process design (Darwin notifications and a shared file), never
// pretending its process alone can draw the other side. No SpringBoard-side companion exists in
// this tree for picture-in-picture, so this port cannot make the video survive the host app
// leaving the foreground - that dimension is out of reach without one.
//
// What is real and in reach: everything picture-in-picture does *while the host app stays in the
// foreground*, which is what a call screen actually needs. This class floats the real
// AVPlayerLayer the caller already owns into a draggable UIWindow above the host app's own
// content - the same CALayer, still attached to the same AVPlayer, still decoding and rendering
// real frames - and reparents it back exactly where it came from on -stopPictureInPicture. This
// is not a stub: video keeps playing, the user can drag the window around, and closing it restores
// the original layout, all for real. What differs from the system feature, honestly, is that it
// does not outlive the app losing focus.

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

// AVKitErrorDomain, ios(9.0) - the one constant this library declares.
//
// The VALUE is measured, not assumed, and the measurement is in
// facts/AVKit/AVPictureInPictureController.md. The point of measuring it is that the name is not the
// value: coordination/corpus/queue's header records three constants whose value is not their name, and
// the same header's rule is that a name is never a value. Read out of Apple's own data - the AVKit
// image out of the armv7 shared cache of 9.0, through tools/corpus/cache-value.lua (the reader of
// modules/apple/dyld.lua), its symbol AVKitErrorDomain read as a constant string:
//
//     $ CHARON_ROOT=$PWD xmake l tools/corpus/cache-value.lua ~/.charon/dyld/9.0/dyld_shared_cache_armv7 symbols.tsv
//       (symbols.tsv holds the line "AVKitErrorDomain<TAB>p<TAB>p<TAB>s"; the reply's text column is the string)
//
// so the two do coincide here, and now that is a reading rather than a hope. The 8.0 image is the
// control for the date: it carries the cstring but no _AVKitErrorDomain symbol at all, which is what
// AVError.h's own ios(9.0) says.
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
// Declared by the header, not carried: without @dynamic clang synthesizes accessors that store a
// value and do nothing with it (measured with nm on the object). canStopPictureInPicture is tvOS's.
//
// `contentSource` and `-initWithContentSource:` are implemented, in
// AVPictureInPictureControllerContentSource15.m, the object that owns the 15.0 API - and they stay on
// this @dynamic line for the reason the 8.0 object gives for `speeds`: with the name dropped, this
// object synthesizes its own `contentSource` and `setContentSource:` over the 15.0 category's, and a
// class's own methods beat a category's. Measured with otool -ov, same shape.
@dynamic contentSource, canStartPictureInPictureAutomaticallyFromInline, canStopPictureInPicture;

- (BOOL)isPictureInPictureSuspended
{
    // The floating window is the application's own and is never suspended while the application
    // runs; when the application leaves the foreground, nothing of it runs to ask.
    return NO;
}

+ (BOOL)isPictureInPictureSupported
{
    // Real, unconditionally YES: unlike the system feature this substitutes for, an in-app
    // floating window needs no hardware entitlement or background-video capability - it works on
    // every device this release runs on.
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
        // -1001 is AVKitErrorPictureInPictureStartFailed, the code AVError.h:31 gives for exactly
        // this failure; the -1000 that was here before is AVKitErrorUnknown, which is what the
        // framework answers when it does not know which error it is, and this port does know. The
        // domain is the measured constant above, not a literal.
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
