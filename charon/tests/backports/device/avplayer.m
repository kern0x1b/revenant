#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreVideo/CoreVideo.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static void spin(NSTimeInterval seconds)
{
    wait_until(^BOOL { return NO; }, seconds);
}

static void checkpoint(NSString *name, NSTimeInterval seconds)
{
    NSString *file = [results_folder stringByAppendingPathComponent:@"avplayer.checkpoint"];
    [name writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    printf("checkpoint %s\n", name.UTF8String);
    fflush(stdout);
    spin(seconds);
    [@"" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

// Three seconds of 320x240 at 30 frames a second: a band that moves across a colour that changes.
static NSURL *write_video(void)
{
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"avplayer.mp4"]];
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    NSError *error = nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:&error];
    NSDictionary *settings = @{AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: @320, AVVideoHeightKey: @240};
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    input.expectsMediaDataInRealTime = NO;
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                 (__bridge NSString *)kCVPixelBufferWidthKey: @320, (__bridge NSString *)kCVPixelBufferHeightKey: @240};
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                                                                                                                      sourcePixelBufferAttributes:attributes];
    [writer addInput:input];
    if (![writer startWriting]) {
        printf("measure writer start failed: %s\n", writer.error.description.UTF8String);
        return nil;
    }
    [writer startSessionAtSourceTime:kCMTimeZero];
    for (int frame = 0; frame < 90; frame++) {
        if (!wait_until(^BOOL { return input.readyForMoreMediaData; }, 5))
            break;
        CVPixelBufferRef pixels = NULL;
        CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pixels);
        if (!pixels)
            CVPixelBufferCreate(NULL, 320, 240, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attributes, &pixels);
        CVPixelBufferLockBaseAddress(pixels, 0);
        uint8_t *base = CVPixelBufferGetBaseAddress(pixels);
        size_t stride = CVPixelBufferGetBytesPerRow(pixels);
        for (int y = 0; y < 240; y++) {
            uint32_t *row = (uint32_t *)(base + y * stride);
            for (int x = 0; x < 320; x++) {
                BOOL band = x >= frame * 3 && x < frame * 3 + 40;
                uint8_t red = band ? 255 : (uint8_t)(frame * 2), green = band ? 255 : 64, blue = band ? 255 : (uint8_t)(200 - frame * 2);
                row[x] = 0xff000000u | ((uint32_t)red << 16) | ((uint32_t)green << 8) | blue;
            }
        }
        CVPixelBufferUnlockBaseAddress(pixels, 0);
        [adaptor appendPixelBuffer:pixels withPresentationTime:CMTimeMake(frame, 30)];
        CVPixelBufferRelease(pixels);
    }
    [input markAsFinished];
    __block BOOL finished = NO;
    [writer finishWritingWithCompletionHandler:^{
        finished = YES;
    }];
    wait_until(^BOOL { return finished; }, 20);
    printf("measure writer status %ld error %s\n", (long)writer.status, writer.error.description.UTF8String ?: "none");
    return writer.status == AVAssetWriterStatusCompleted ? url : nil;
}

@interface CharonPlayerDelegate : NSObject <AVPlayerViewControllerDelegate>
@property (nonatomic) int willStart, didStart, failed, willStop, didStop, restore, shouldDismiss;
@property (nonatomic) int willBeginFull, willEndFull, fullCoordinators, fullCompletions, fullCancelled;
@property (nonatomic, strong) UIViewController *presenter;
@end

@implementation CharonPlayerDelegate

- (void)charon_fullScreenCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.fullCoordinators += coordinator != nil;
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.fullCompletions++;
        self.fullCancelled += context.isCancelled;
    }];
}

- (void)playerViewController:(AVPlayerViewController *)controller willBeginFullScreenPresentationWithAnimationCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.willBeginFull++;
    [self charon_fullScreenCoordinator:coordinator];
}

- (void)playerViewController:(AVPlayerViewController *)controller willEndFullScreenPresentationWithAnimationCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.willEndFull++;
    [self charon_fullScreenCoordinator:coordinator];
}

- (void)playerViewControllerWillStartPictureInPicture:(AVPlayerViewController *)controller
{
    self.willStart++;
}

- (void)playerViewControllerDidStartPictureInPicture:(AVPlayerViewController *)controller
{
    self.didStart++;
}

- (void)playerViewController:(AVPlayerViewController *)controller failedToStartPictureInPictureWithError:(NSError *)error
{
    self.failed++;
}

- (void)playerViewControllerWillStopPictureInPicture:(AVPlayerViewController *)controller
{
    self.willStop++;
}

- (void)playerViewControllerDidStopPictureInPicture:(AVPlayerViewController *)controller
{
    self.didStop++;
}

- (BOOL)playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart:(AVPlayerViewController *)controller
{
    self.shouldDismiss++;
    return YES;
}

- (void)playerViewController:(AVPlayerViewController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completion
{
    self.restore++;
    [self.presenter presentViewController:controller animated:NO completion:^{
        completion(YES);
    }];
}

@end

@interface CharonReadyObserver : NSObject
@property (nonatomic) int changes;
@end

@implementation CharonReadyObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    self.changes++;
}

@end

static BOOL near(CGFloat a, CGFloat b)
{
    return fabs(a - b) < 1.5;
}

static void check_surface(void)
{
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    CHECK([controller isKindOfClass:[UIViewController class]], "AVPlayerViewController is a UIViewController");
    CHECK(controller.showsPlaybackControls, "showsPlaybackControls defaults to YES");
    CHECK([controller.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect], "videoGravity defaults to ResizeAspect");
    CHECK(controller.allowsPictureInPicturePlayback, "allowsPictureInPicturePlayback defaults to YES");
    CHECK(controller.updatesNowPlayingInfoCenter, "updatesNowPlayingInfoCenter defaults to YES");
    CHECK(!controller.requiresLinearPlayback, "requiresLinearPlayback defaults to NO");
    CHECK(controller.player == nil, "player starts nil");
    CHECK(controller.contentOverlayView != nil, "contentOverlayView is there");
    CHECK(CGRectEqualToRect(controller.videoBounds, CGRectZero), "videoBounds is zero without a player");
    CHECK(controller.pixelBufferAttributes == nil, "pixelBufferAttributes starts nil");
    const char *absent[] = {"showsTimecodes", "setShowsTimecodes:", "speeds", "selectedSpeed", "selectSpeed:",
                            "canStartPictureInPictureAutomaticallyFromInline", "allowsVideoFrameAnalysis"};
    for (size_t i = 0; i < sizeof absent / sizeof *absent; i++) {
        char label[160];
        snprintf(label, sizeof label, "does not answer %s", absent[i]);
        CHECK(![controller respondsToSelector:sel_registerName(absent[i])], label);
    }
    const char *present[] = {"setRequiresLinearPlayback:", "setEntersFullScreenWhenPlaybackBegins:", "setExitsFullScreenWhenPlaybackEnds:",
                             "setUpdatesNowPlayingInfoCenter:", "setAllowsPictureInPicturePlayback:", "setDelegate:",
                             "pixelBufferAttributes", "setPixelBufferAttributes:"};
    for (size_t i = 0; i < sizeof present / sizeof *present; i++) {
        char label[160];
        snprintf(label, sizeof label, "answers %s", present[i]);
        CHECK([controller respondsToSelector:sel_registerName(present[i])], label);
    }
    AVPictureInPictureController *picture = [[AVPictureInPictureController alloc] initWithPlayerLayer:[AVPlayerLayer layer]];
    CHECK(![picture respondsToSelector:@selector(contentSource)], "AVPictureInPictureController does not answer contentSource");
    CHECK(![picture respondsToSelector:@selector(canStartPictureInPictureAutomaticallyFromInline)],
          "AVPictureInPictureController does not answer canStartPictureInPictureAutomaticallyFromInline");
    CHECK(!picture.pictureInPictureSuspended, "AVPictureInPictureController is not suspended");
}

static void check_presented(UIViewController *root, NSURL *url)
{
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    CharonReadyObserver *observer = [[CharonReadyObserver alloc] init];
    [controller addObserver:observer forKeyPath:@"readyForDisplay" options:0 context:NULL];
    controller.player = [AVPlayer playerWithURL:url];
    [root presentViewController:controller animated:NO completion:nil];
    CHECK(wait_until(^BOOL { return controller.readyForDisplay; }, 10), "presented: readyForDisplay turns YES");
    CHECK(observer.changes > 0, "presented: readyForDisplay is key-value observed");
    [controller removeObserver:observer forKeyPath:@"readyForDisplay"];
    CGRect bounds = controller.view.bounds;
    CGRect expected = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(320, 240), bounds);
    CGRect video = controller.videoBounds;
    printf("measure presented view %s videoBounds %s\n", NSStringFromCGRect(bounds).UTF8String, NSStringFromCGRect(video).UTF8String);
    CHECK(near(video.origin.x, expected.origin.x) && near(video.origin.y, expected.origin.y) && near(video.size.width, expected.size.width)
          && near(video.size.height, expected.size.height), "presented: videoBounds is the aspect fit of 320x240 in the view");
    UIView *overlay = controller.contentOverlayView;
    CHECK([overlay isDescendantOfView:controller.view], "presented: contentOverlayView is in the controller's view");
    UIToolbar *bar = [controller valueForKey:@"_charonTopBar"];
    UIBarButtonItem *done = [controller valueForKey:@"_charonDoneItem"];
    UIButton *full = [controller valueForKey:@"_charonFullScreenButton"];
    printf("measure the Done item's title: %s\n", [done.title UTF8String] ?: "(system item)");
    CHECK(done && [bar.items containsObject:done] && !bar.hidden, "presented: Done is shown");
    CHECK(full && full.hidden, "presented: full screen is not shown");
    [controller.player play];
    CHECK(wait_until(^BOOL { return CMTimeGetSeconds(controller.player.currentTime) > 0.5; }, 5), "presented: playback advances");
    [controller.player pause];
    NSDictionary *info = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
    printf("measure now playing %s\n", info.description.UTF8String);
    CHECK(fabs([info[MPMediaItemPropertyPlaybackDuration] doubleValue] - 3) < 0.1, "presented: now playing carries the duration");
    CHECK(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] != nil, "presented: now playing carries the elapsed time");
    checkpoint(@"presented-paused", 8);

    controller.requiresLinearPlayback = YES;
    UISlider *scrubber = [controller valueForKey:@"_charonScrubber"];
    CHECK(!scrubber.enabled, "presented: requiresLinearPlayback disables the scrubber");
    controller.requiresLinearPlayback = NO;
    CHECK(scrubber.enabled, "presented: the scrubber comes back");
    controller.showsPlaybackControls = NO;
    UIView *controls = [controller valueForKey:@"_charonControls"];
    CHECK(controls.hidden, "presented: showsPlaybackControls NO hides the controls");
    controller.showsPlaybackControls = YES;
    CHECK(!controls.hidden, "presented: the controls come back");

    [controller.player play];
    [[UIApplication sharedApplication] sendAction:done.action to:done.target from:done forEvent:nil];
    CHECK(wait_until(^BOOL { return root.presentedViewController == nil; }, 5), "presented: Done dismisses");
    CHECK(controller.player.rate == 0, "presented: Done pauses");
    controller.player = nil;
    printf("measure now playing right after the player goes: %s\n", [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo.description.UTF8String ?: "nil");
    CHECK(wait_until(^BOOL { return [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo == nil; }, 3), "presented: now playing is cleared with the player");
    printf("measure now playing 3 s later: %s\n", [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo.description.UTF8String ?: "nil");
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{MPMediaItemPropertyTitle: @"probe"};
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    printf("measure control: set and cleared directly, read back %s\n", [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo.description.UTF8String ?: "nil");
}

static void check_picture(UIViewController *root, NSURL *url)
{
    CharonPlayerDelegate *delegate = [[CharonPlayerDelegate alloc] init];
    delegate.presenter = root;
    __weak AVPlayerViewController *weakController;
    AVPlayerLayer *layer;
    @autoreleasepool {
        AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
        weakController = controller;
        controller.delegate = delegate;
        controller.player = [AVPlayer playerWithURL:url];
        [root presentViewController:controller animated:NO completion:nil];
        CHECK(wait_until(^BOOL { return controller.readyForDisplay; }, 10), "picture: ready");
        [controller.player play];
        UIBarButtonItem *button = [controller valueForKey:@"_charonPictureItem"];
        CHECK(button && [((UIToolbar *)[controller valueForKey:@"_charonTopBar"]).items containsObject:button], "picture: the button is shown");
        [[UIApplication sharedApplication] sendAction:button.action to:button.target from:button forEvent:nil];
        CHECK(wait_until(^BOOL { return delegate.didStart == 1; }, 5), "picture: will and did start are sent");
        CHECK(delegate.willStart == 1 && delegate.shouldDismiss == 1 && delegate.failed == 0, "picture: once each, no failure");
        layer = [[controller valueForKey:@"charonVideoView"] valueForKey:@"playerLayer"];
    }
    CHECK(wait_until(^BOOL { return root.presentedViewController == nil; }, 5), "picture: the controller dismisses itself");
    // Every read of weakController autoreleases the controller; a pool around each keeps the run
    // loop iteration that runs these checks from holding it.
    @autoreleasepool {
        CHECK(weakController != nil, "picture: the controller outlives the application's references");
    }
    UIWindow *main = root.view.window;
    CHECK(layer.superlayer != nil && ![layer.superlayer isEqual:main.layer], "picture: the layer is out of the controller");
    UIWindow *floating = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows)
        if (window != main && !window.hidden && window.layer == layer.superlayer)
            floating = window;
    CHECK(floating != nil, "picture: the layer is in a floating window");
    printf("measure floating window %s\n", NSStringFromCGRect(floating.frame).UTF8String);
    checkpoint(@"picture-floating", 8);
    @autoreleasepool {
        AVPictureInPictureController *picture = [weakController valueForKey:@"_charonPicture"];
        [picture stopPictureInPicture];
    }
    CHECK(wait_until(^BOOL { return delegate.didStop == 1; }, 5), "picture: will and did stop are sent");
    CHECK(delegate.willStop == 1 && delegate.restore == 1, "picture: restore is asked once");
    @autoreleasepool {
        CHECK(root.presentedViewController == weakController, "picture: the delegate presented the controller again");
        CHECK(layer.superlayer == ((UIView *)[weakController valueForKey:@"charonVideoView"]).layer, "picture: the layer is back in the controller");
        [weakController.player pause];
        [root dismissViewControllerAnimated:NO completion:nil];
        wait_until(^BOOL { return root.presentedViewController == nil; }, 5);
        weakController.player = nil;
    }
    CHECK(wait_until(^BOOL {
              @autoreleasepool {
                  return weakController == nil;
              }
          }, 6), "picture: the controller goes once the application lets it go");
}

static void check_full_screen(UIViewController *root, NSURL *url)
{
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    [root addChildViewController:controller];
    controller.view.frame = CGRectMake(0, 40, root.view.bounds.size.width, 180);
    [root.view addSubview:controller.view];
    [controller didMoveToParentViewController:root];
    controller.entersFullScreenWhenPlaybackBegins = YES;
    controller.exitsFullScreenWhenPlaybackEnds = YES;
    CharonPlayerDelegate *delegate = [[CharonPlayerDelegate alloc] init];
    controller.delegate = delegate;
    controller.player = [AVPlayer playerWithURL:url];
    CHECK(wait_until(^BOOL { return controller.readyForDisplay; }, 10), "inline: ready");
    UIToolbar *bar = [controller valueForKey:@"_charonTopBar"];
    UIBarButtonItem *done = [controller valueForKey:@"_charonDoneItem"];
    UIButton *full = [controller valueForKey:@"_charonFullScreenButton"];
    CHECK(![bar.items containsObject:done] && !full.hidden, "inline: full screen shown, Done not");
    checkpoint(@"inline", 5);
    [controller.player play];
    CHECK(wait_until(^BOOL { return [NSStringFromClass([root.presentedViewController class]) isEqualToString:@"CharonAVPlayerFullScreenViewController"]; }, 5),
          "inline: playback begins in full screen");
    CHECK([bar.items containsObject:done], "full screen: Done is shown");
    CHECK(delegate.willBeginFull == 1 && delegate.willEndFull == 0, "full screen: the delegate is told it begins, once");
    CHECK(wait_until(^BOOL { return delegate.fullCompletions == 1; }, 3), "full screen: with a coordinator whose completion runs");
    checkpoint(@"full-screen", 1.5);
    CHECK(wait_until(^BOOL { return root.presentedViewController == nil; }, 8), "full screen: left when playback ends");
    UIView *stage = [controller valueForKey:@"_charonStage"];
    CHECK(stage.superview == controller.view, "inline: the content is back in the controller");
    CHECK(delegate.willEndFull == 1, "full screen: the delegate is told it ends, once");
    CHECK(wait_until(^BOOL { return delegate.fullCompletions == 2; }, 3) && delegate.fullCoordinators == 2 && delegate.fullCancelled == 0,
          "full screen: both coordinators there, completed, not cancelled");
    [controller willMoveToParentViewController:nil];
    [controller.view removeFromSuperview];
    [controller removeFromParentViewController];
    controller.player = nil;
}

// The frames come from an AVPlayerItemVideoOutput made with the attributes, drawn over the player layer.
static void check_pixel_buffer(UIViewController *root, NSURL *url, OSType format, const char *name)
{
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(format)};
    controller.pixelBufferAttributes = attributes;
    CHECK([controller.pixelBufferAttributes isEqual:attributes], "pixel buffer: the attributes read back");
    controller.player = [AVPlayer playerWithURL:url];
    [root presentViewController:controller animated:NO completion:nil];
    CHECK(wait_until(^BOOL { return controller.readyForDisplay; }, 10), "pixel buffer: ready");
    AVPlayerItemVideoOutput *output = [controller valueForKey:@"_charonVideoOutput"];
    CHECK([controller.player.currentItem.outputs containsObject:output], "pixel buffer: a video output is on the item");
    [controller.player play];
    CALayer *frame = [controller valueForKey:@"_charonFrameLayer"];
    BOOL drawn = wait_until(^BOOL { return frame.contents != nil; }, 3);
    printf("measure pixel buffer %s: drawn %d, frame %zux%zu\n", name, drawn, drawn ? CGImageGetWidth((__bridge CGImageRef)frame.contents) : 0,
           drawn ? CGImageGetHeight((__bridge CGImageRef)frame.contents) : 0);
    if (format == kCVPixelFormatType_32BGRA) {
        CHECK(drawn && CGImageGetWidth((__bridge CGImageRef)frame.contents) == 320 && CGImageGetHeight((__bridge CGImageRef)frame.contents) == 240,
              "pixel buffer: 32BGRA frames of the video are drawn");
        checkpoint(@"pixel-buffer", 3);
    }
    controller.pixelBufferAttributes = nil;
    CHECK(controller.player.currentItem.outputs.count == 0 && frame.superlayer == nil, "pixel buffer: nil takes the output and its frames away");
    [controller.player pause];
    [root dismissViewControllerAnimated:NO completion:nil];
    wait_until(^BOOL { return root.presentedViewController == nil; }, 5);
    controller.player = nil;
}

static void check_failure(UIViewController *root)
{
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    controller.player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:@"/private/var/backports/no-such-video.mp4"]];
    [root presentViewController:controller animated:NO completion:nil];
    AVPlayerItem *item = controller.player.currentItem;
    CHECK(wait_until(^BOOL { return item.status == AVPlayerItemStatusFailed; }, 10), "failure: the item fails");
    spin(1);
    printf("measure after the failure: player status %ld, current item %s, player error %s\n", (long)controller.player.status,
           controller.player.currentItem ? "kept" : "nil", controller.player.error.description.UTF8String ?: "none");
    UILabel *label = [controller valueForKey:@"_charonFailureLabel"];
    CHECK(!label.hidden, "failure: the controller says so, and keeps saying it");
    checkpoint(@"failure", 5);
    printf("measure failure text %s\n", label.text.UTF8String);
    [root dismissViewControllerAnimated:NO completion:nil];
    wait_until(^BOOL { return root.presentedViewController == nil; }, 5);
    controller.player = nil;
}

@interface CharonPlayerAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonPlayerAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor darkGrayColor];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(run) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)run
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"avplayer.log"]);
    UIViewController *root = self.window.rootViewController;
    check_surface();
    NSURL *url = write_video();
    CHECK(url != nil, "the device writes a three second H.264 video");
    if (url) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        printf("measure video duration %.3f\n", CMTimeGetSeconds(asset.duration));
        check_presented(root, url);
        check_picture(root, url);
        check_full_screen(root, url);
        check_pixel_buffer(root, url, kCVPixelFormatType_32BGRA, "32BGRA");
        check_pixel_buffer(root, url, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, "420f");
    }
    check_failure(root);
    NSString *summary = [NSString stringWithFormat:@"checks=%d failures=%d\n", charon_checks, charon_failures];
    printf("%s", summary.UTF8String);
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"avplayer.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonPlayerAppDelegate");
    }
}
