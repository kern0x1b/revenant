#import <VisionKit/VisionKit.h>

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>

#import "RevenantDocumentScan.h"
#import "RevenantVisionKit.h"

static const size_t RevenantLiveSide = 320;
static const size_t RevenantPageSide = 2048;
static const CGFloat RevenantPageQuality = 0.87;
static const CGFloat RevenantThumbnailSide = 120;
static const CGFloat RevenantTopBarHeight = 44;
static const CGFloat RevenantBottomBarHeight = 96;
static const NSTimeInterval RevenantHold = 1.2;
static const NSTimeInterval RevenantFrameInterval = 0.12;
static const NSTimeInterval RevenantHintAge = 0.6;
static const NSTimeInterval RevenantQuadFade = 0.4;
static const double RevenantMinimumArea = 0.12;

static UIImage *RevenantThumbnail(NSData *jpeg)
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL);
    if (source == NULL)
        return nil;
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize : @(RevenantThumbnailSide),
    };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (image == NULL)
        return nil;
    UIImage *thumbnail = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    return thumbnail;
}

static NSString *RevenantFlashTitle(AVCaptureFlashMode mode)
{
    switch (mode) {
        case AVCaptureFlashModeOn:
            return @"Flash: On";
        case AVCaptureFlashModeAuto:
            return @"Flash: Auto";
        default:
            return @"Flash: Off";
    }
}

@interface VNDocumentCameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, UIAlertViewDelegate>

@end

@implementation VNDocumentCameraViewController {
    AVCaptureSession *_session;
    AVCaptureDevice *_device;
    AVCaptureStillImageOutput *_stillOutput;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCaptureVideoPreviewLayer *_previewLayer;
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _frameQueue;
    dispatch_queue_t _processQueue;

    UIView *_previewView;
    CAShapeLayer *_quadLayer;
    UIView *_topBar;
    UIView *_bottomBar;
    UIButton *_flashButton;
    UIButton *_modeButton;
    UIButton *_cancelButton;
    UIButton *_saveButton;
    UIButton *_retakeButton;
    UIButton *_shutterButton;
    UIView *_shutterInner;
    UILabel *_hintLabel;
    UIImageView *_thumbnailView;
    UIActivityIndicatorView *_spinner;
    UIView *_flashView;
    UIAlertView *_alert;

    NSMutableArray<NSData *> *_pages;
    NSMutableArray<UIImage *> *_thumbnails;
    NSError *_startupError;
    AVCaptureFlashMode _flashMode;
    BOOL _automatic;
    BOOL _busy;
    BOOL _reported;
    BOOL _configured;

    RevenantDocumentTracker _tracker;
    RevenantDocumentQuad _shown;
    RevenantDocumentQuad _latest;
    BOOL _hasShown;
    BOOL _hasLatest;
    BOOL _quadVisible;
    NSTimeInterval _lastSeen;
    CGSize _videoSize;

    NSTimeInterval _lastFrame;
    uint8_t *_luma;
}

@synthesize delegate = _delegate;

+ (BOOL)isSupported
{
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] != nil;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _pages = [NSMutableArray array];
        _thumbnails = [NSMutableArray array];
        _automatic = YES;
        _flashMode = AVCaptureFlashModeOff;
        _videoSize = CGSizeMake(3, 4);
        _luma = malloc(RevenantLiveSide * RevenantLiveSide);
        _sessionQueue = dispatch_queue_create("org.revenant.visionkit.session", DISPATCH_QUEUE_SERIAL);
        _frameQueue = dispatch_queue_create("org.revenant.visionkit.frames", DISPATCH_QUEUE_SERIAL);
        _processQueue = dispatch_queue_create("org.revenant.visionkit.pages", DISPATCH_QUEUE_SERIAL);
        RevenantDocumentTrackerReset(&_tracker);
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _alert.delegate = nil;
    [_videoOutput setSampleBufferDelegate:nil queue:NULL];
    [_session stopRunning];
    free(_luma);
}

- (UIButton *)barButton:(NSString *)title action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithWhite:1 alpha:0.4] forState:UIControlStateDisabled];
    button.titleLabel.font = [UIFont systemFontOfSize:16];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _previewView = [[UIView alloc] init];
    _previewView.backgroundColor = [UIColor blackColor];
    _previewView.clipsToBounds = YES;
    [self.view addSubview:_previewView];

    _quadLayer = [CAShapeLayer layer];
    _quadLayer.strokeColor = [UIColor colorWithRed:1 green:0.82 blue:0.1 alpha:1].CGColor;
    _quadLayer.fillColor = [UIColor colorWithRed:1 green:0.82 blue:0.1 alpha:0.22].CGColor;
    _quadLayer.lineWidth = 3;
    _quadLayer.lineJoin = kCALineJoinRound;
    _quadLayer.hidden = YES;
    [_previewView.layer addSublayer:_quadLayer];

    _flashView = [[UIView alloc] init];
    _flashView.backgroundColor = [UIColor whiteColor];
    _flashView.alpha = 0;
    _flashView.userInteractionEnabled = NO;
    [_previewView addSubview:_flashView];

    _topBar = [[UIView alloc] init];
    _topBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    [self.view addSubview:_topBar];

    _flashButton = [self barButton:RevenantFlashTitle(_flashMode) action:@selector(cycleFlash)];
    _flashButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _flashButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 0);
    _flashButton.hidden = YES;
    [_topBar addSubview:_flashButton];

    _modeButton = [self barButton:@"Auto" action:@selector(toggleMode)];
    _modeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    _modeButton.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 12);
    [_topBar addSubview:_modeButton];

    _bottomBar = [[UIView alloc] init];
    _bottomBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    [self.view addSubview:_bottomBar];

    _hintLabel = [[UILabel alloc] init];
    _hintLabel.backgroundColor = [UIColor clearColor];
    _hintLabel.textColor = [UIColor whiteColor];
    _hintLabel.textAlignment = NSTextAlignmentCenter;
    _hintLabel.font = [UIFont systemFontOfSize:14];
    [_bottomBar addSubview:_hintLabel];

    _retakeButton = [self barButton:@"Retake" action:@selector(retake)];
    _retakeButton.titleLabel.font = [UIFont systemFontOfSize:14];
    _retakeButton.hidden = YES;
    [_bottomBar addSubview:_retakeButton];

    _cancelButton = [self barButton:@"Cancel" action:@selector(cancel)];
    [_bottomBar addSubview:_cancelButton];

    _shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _shutterButton.layer.cornerRadius = 32;
    _shutterButton.layer.borderWidth = 4;
    _shutterButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [_shutterButton addTarget:self action:@selector(capture) forControlEvents:UIControlEventTouchUpInside];
    [_shutterButton addTarget:self action:@selector(shutterDown) forControlEvents:UIControlEventTouchDown];
    [_shutterButton addTarget:self action:@selector(shutterUp) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_bottomBar addSubview:_shutterButton];

    _shutterInner = [[UIView alloc] initWithFrame:CGRectMake(6, 6, 44, 44)];
    _shutterInner.backgroundColor = [UIColor whiteColor];
    _shutterInner.layer.cornerRadius = 22;
    _shutterInner.userInteractionEnabled = NO;
    [_shutterButton addSubview:_shutterInner];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.hidesWhenStopped = YES;
    _spinner.userInteractionEnabled = NO;
    [_shutterButton addSubview:_spinner];

    _thumbnailView = [[UIImageView alloc] init];
    _thumbnailView.contentMode = UIViewContentModeScaleAspectFit;
    _thumbnailView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    _thumbnailView.layer.borderColor = [UIColor whiteColor].CGColor;
    _thumbnailView.layer.borderWidth = 1;
    _thumbnailView.hidden = YES;
    [_bottomBar addSubview:_thumbnailView];

    _saveButton = [self barButton:@"Save" action:@selector(save)];
    _saveButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_bottomBar addSubview:_saveButton];

    [self updateControls];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    CGFloat aspect = _videoSize.width / _videoSize.height;
    CGFloat fitWidth = bounds.size.width;
    CGFloat fitHeight = fitWidth / aspect;
    if (fitHeight > bounds.size.height) {
        fitHeight = bounds.size.height;
        fitWidth = fitHeight * aspect;
    }
    CGFloat top = 0;
    if (bounds.size.height - fitHeight >= RevenantBottomBarHeight)
        top = (bounds.size.height - RevenantBottomBarHeight - fitHeight) / 2;
    _previewView.frame = CGRectMake(floor((bounds.size.width - fitWidth) / 2), floor(top), fitWidth, fitHeight);
    _flashView.frame = _previewView.bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _previewLayer.frame = _previewView.bounds;
    _quadLayer.frame = _previewView.bounds;
    [CATransaction commit];

    _topBar.frame = CGRectMake(0, 0, bounds.size.width, RevenantTopBarHeight);
    _flashButton.frame = CGRectMake(0, 0, 150, RevenantTopBarHeight);
    _modeButton.frame = CGRectMake(bounds.size.width - 150, 0, 150, RevenantTopBarHeight);

    CGFloat width = bounds.size.width;
    _bottomBar.frame = CGRectMake(0, bounds.size.height - RevenantBottomBarHeight, width, RevenantBottomBarHeight);
    _hintLabel.frame = CGRectMake(70, 4, width - 140, 20);
    _retakeButton.frame = CGRectMake(width - 68, 2, 64, 24);
    _cancelButton.frame = CGRectMake(4, 26, 84, 64);
    _shutterButton.frame = CGRectMake(floor(width / 2 - 32), 26, 64, 64);
    _spinner.center = CGPointMake(32, 32);
    _thumbnailView.frame = CGRectMake(floor(width / 2 + 42), 35, 34, 46);
    _saveButton.frame = CGRectMake(width - 84, 26, 80, 64);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (NSError *)unavailableError:(NSString *)reason
{
    return [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorDeviceNotConnected userInfo:@{NSLocalizedDescriptionKey : reason}];
}

- (BOOL)configureSession:(NSError **)error
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device == nil) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{NSLocalizedDescriptionKey : @"This device has no camera for scanning documents."}];
        return NO;
    }
    NSError *inputError = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&inputError];
    if (input == nil) {
        *error = inputError ?: [self unavailableError:@"The camera could not be opened."];
        return NO;
    }
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    if ([session canSetSessionPreset:AVCaptureSessionPresetPhoto])
        session.sessionPreset = AVCaptureSessionPresetPhoto;
    if (![session canAddInput:input]) {
        *error = [self unavailableError:@"The camera could not be used by the scanner."];
        return NO;
    }
    [session addInput:input];

    AVCaptureVideoDataOutput *video = [[AVCaptureVideoDataOutput alloc] init];
    video.alwaysDiscardsLateVideoFrames = YES;
    video.videoSettings = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    [video setSampleBufferDelegate:self queue:_frameQueue];
    AVCaptureStillImageOutput *still = [[AVCaptureStillImageOutput alloc] init];
    still.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
    if (![session canAddOutput:video] || ![session canAddOutput:still]) {
        *error = [self unavailableError:@"The camera could not deliver pictures to the scanner."];
        return NO;
    }
    [session addOutput:video];
    [session addOutput:still];

    NSError *lockError = nil;
    if ([device lockForConfiguration:&lockError]) {
        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        if (device.hasFlash && [device isFlashModeSupported:_flashMode])
            device.flashMode = _flashMode;
        [device unlockForConfiguration];
    }

    _device = device;
    _videoOutput = video;
    _stillOutput = still;
    _session = session;
    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    if (_previewLayer.connection.isVideoOrientationSupported)
        _previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    _previewLayer.frame = _previewView.bounds;
    [_previewView.layer insertSublayer:_previewLayer atIndex:0];
    _flashButton.hidden = !device.hasFlash;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionFailed:) name:AVCaptureSessionRuntimeErrorNotification object:session];
    _configured = YES;
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!_configured && _startupError == nil) {
        NSError *error = nil;
        if (![self configureSession:&error])
            _startupError = error;
    }
    if (_session != nil) {
        AVCaptureSession *session = _session;
        dispatch_async(_sessionQueue, ^{
            if (!session.isRunning)
                [session startRunning];
        });
    }
    [self updateControls];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_startupError != nil) {
        NSError *error = _startupError;
        _startupError = nil;
        [self failWithError:error];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self stopSession];
}

- (void)stopSession
{
    AVCaptureSession *session = _session;
    if (session == nil)
        return;
    dispatch_async(_sessionQueue, ^{
        if (session.isRunning)
            [session stopRunning];
    });
}

- (void)sessionFailed:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey] ?: [self unavailableError:@"The camera stopped working."];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self failWithError:error];
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSTimeInterval now = CACurrentMediaTime();
    if (now - _lastFrame < RevenantFrameInterval)
        return;
    _lastFrame = now;
    CVImageBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (buffer == NULL || CVPixelBufferGetPlaneCount(buffer) < 1)
        return;
    size_t luma_width = 0, luma_height = 0;
    RevenantDocumentQuad quad;
    BOOL found = NO;
    BOOL converted = NO;
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    const uint8_t *plane = CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
    size_t width = CVPixelBufferGetWidthOfPlane(buffer, 0), height = CVPixelBufferGetHeightOfPlane(buffer, 0);
    size_t rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0);
    if (plane != NULL)
        converted = RevenantDocumentLuminance(plane, width, height, rowBytes, width > height ? 1 : 0, RevenantLiveSide, _luma, &luma_width, &luma_height) == 1;
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    if (!converted)
        return;
    found = RevenantDocumentFindQuad(_luma, luma_width, luma_height, luma_width, NULL, &quad) == 1;
    CGSize size = CGSizeMake((CGFloat)luma_width, (CGFloat)luma_height);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self liveFrameWithSize:size quad:found ? &quad : NULL];
    });
}

- (void)liveFrameWithSize:(CGSize)size quad:(const RevenantDocumentQuad *)quad
{
    if (_reported || _session == nil)
        return;
    if (!CGSizeEqualToSize(size, _videoSize)) {
        _videoSize = size;
        [self.view setNeedsLayout];
    }
    NSTimeInterval now = CACurrentMediaTime();
    BOOL large = quad != NULL && RevenantDocumentQuadArea(quad) >= RevenantMinimumArea;
    BOOL ready = RevenantDocumentTrackerUpdate(&_tracker, large ? quad : NULL, now, RevenantHold) == 1;
    if (quad != NULL) {
        _latest = *quad;
        _hasLatest = YES;
        _lastSeen = now;
        [self showQuad:quad];
    } else if (_quadVisible && now - _lastSeen > RevenantQuadFade) {
        _quadVisible = NO;
        _hasShown = NO;
        _quadLayer.hidden = YES;
    }
    [self updateHintFound:large ready:ready];
    if (ready && _automatic && !_busy)
        [self capture];
}

- (void)showQuad:(const RevenantDocumentQuad *)quad
{
    RevenantDocumentQuad target = *quad;
    if (_hasShown && RevenantDocumentQuadDistance(&_shown, quad) < 0.25) {
        for (int i = 0; i < 4; i++) {
            target.corners[i].x = 0.5f * _shown.corners[i].x + 0.5f * quad->corners[i].x;
            target.corners[i].y = 0.5f * _shown.corners[i].y + 0.5f * quad->corners[i].y;
        }
    }
    _shown = target;
    _hasShown = YES;
    CGSize size = _previewView.bounds.size;
    UIBezierPath *path = [UIBezierPath bezierPath];
    for (int i = 0; i < 4; i++) {
        CGPoint point = CGPointMake(target.corners[i].x * size.width, (1 - target.corners[i].y) * size.height);
        if (i == 0)
            [path moveToPoint:point];
        else
            [path addLineToPoint:point];
    }
    [path closePath];
    [CATransaction begin];
    [CATransaction setAnimationDuration:RevenantFrameInterval];
    _quadLayer.path = path.CGPath;
    _quadLayer.hidden = NO;
    [CATransaction commit];
    _quadVisible = YES;
}

- (void)updateHintFound:(BOOL)found ready:(BOOL)ready
{
    NSString *text;
    if (_busy)
        text = @"Processing";
    else if (!found)
        text = @"Point at a document";
    else if (_automatic)
        text = ready ? @"Scanning" : @"Hold still";
    else
        text = @"Tap the shutter";
    if (![_hintLabel.text isEqualToString:text])
        _hintLabel.text = text;
}

- (void)updateControls
{
    BOOL idle = !_busy;
    _shutterButton.enabled = idle && _session != nil;
    _shutterButton.alpha = _shutterButton.enabled ? 1 : 0.4;
    _saveButton.enabled = idle && _pages.count > 0;
    [_saveButton setTitle:_pages.count > 0 ? [NSString stringWithFormat:@"Save (%lu)", (unsigned long)_pages.count] : @"Save" forState:UIControlStateNormal];
    _retakeButton.hidden = _pages.count == 0;
    _retakeButton.enabled = idle;
    _thumbnailView.hidden = _pages.count == 0;
    _thumbnailView.image = _thumbnails.lastObject;
    if (_busy)
        [_spinner startAnimating];
    else
        [_spinner stopAnimating];
    _shutterInner.hidden = _busy;
    [self updateHintFound:_hasLatest && CACurrentMediaTime() - _lastSeen < RevenantHintAge ready:NO];
}

- (void)shutterDown
{
    _shutterInner.alpha = 0.6;
}

- (void)shutterUp
{
    _shutterInner.alpha = 1;
}

- (void)cycleFlash
{
    AVCaptureFlashMode modes[3] = {AVCaptureFlashModeOff, AVCaptureFlashModeAuto, AVCaptureFlashModeOn};
    int index = 0;
    for (int i = 0; i < 3; i++)
        if (modes[i] == _flashMode)
            index = i;
    for (int step = 1; step <= 3; step++) {
        AVCaptureFlashMode mode = modes[(index + step) % 3];
        if (![_device isFlashModeSupported:mode])
            continue;
        NSError *error = nil;
        if ([_device lockForConfiguration:&error]) {
            _device.flashMode = mode;
            [_device unlockForConfiguration];
            _flashMode = mode;
        }
        break;
    }
    [_flashButton setTitle:RevenantFlashTitle(_flashMode) forState:UIControlStateNormal];
}

- (void)toggleMode
{
    _automatic = !_automatic;
    [_modeButton setTitle:_automatic ? @"Auto" : @"Manual" forState:UIControlStateNormal];
    [_modeButton setTitleColor:_automatic ? [UIColor colorWithRed:1 green:0.82 blue:0.1 alpha:1] : [UIColor whiteColor] forState:UIControlStateNormal];
    RevenantDocumentTrackerReset(&_tracker);
}

- (void)flashPreview
{
    _flashView.alpha = 0.8;
    [UIView animateWithDuration:0.3 animations:^{
        self->_flashView.alpha = 0;
    }];
}

- (void)capture
{
    if (_busy || _reported || _session == nil || !_session.isRunning)
        return;
    AVCaptureConnection *connection = [_stillOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection == nil)
        return;
    _busy = YES;
    RevenantDocumentTrackerCaptured(&_tracker);
    BOOL hinted = _hasLatest && CACurrentMediaTime() - _lastSeen < RevenantHintAge;
    RevenantDocumentQuad hint = _latest;
    [self updateControls];
    [self flashPreview];
    dispatch_queue_t process = _processQueue;
    __weak VNDocumentCameraViewController *weakSelf = self;
    [_stillOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef sample, NSError *error) {
        NSData *jpeg = sample != NULL ? [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sample] : nil;
        dispatch_async(process, ^{
            RevenantDocumentPage *page = jpeg != nil ? RevenantDocumentPageFromJPEG(jpeg, hinted ? &hint : NULL, RevenantPageSide, RevenantPageQuality) : nil;
            UIImage *thumbnail = page != nil ? RevenantThumbnail(page.jpeg) : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf pageReady:page thumbnail:thumbnail error:jpeg == nil ? (error ?: [weakSelf unavailableError:@"The camera did not return a picture."]) : nil];
            });
        });
    }];
}

- (void)pageReady:(RevenantDocumentPage *)page thumbnail:(UIImage *)thumbnail error:(NSError *)error
{
    _busy = NO;
    if (error != nil) {
        [self failWithError:error];
        return;
    }
    if (page != nil) {
        [_pages addObject:page.jpeg];
        [_thumbnails addObject:thumbnail ?: [UIImage imageWithData:page.jpeg]];
    }
    [self updateControls];
    if (page == nil)
        _hintLabel.text = @"That page could not be scanned";
}

- (void)retake
{
    if (_busy || _pages.count == 0)
        return;
    [_pages removeLastObject];
    [_thumbnails removeLastObject];
    RevenantDocumentTrackerReset(&_tracker);
    [self updateControls];
}

- (NSString *)defaultTitle
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd HH.mm";
    return [@"Scan " stringByAppendingString:[formatter stringFromDate:[NSDate date]]];
}

- (void)save
{
    if (_busy || _reported || _pages.count == 0)
        return;
    _reported = YES;
    [self stopSession];
    VNDocumentCameraScan *scan = [[VNDocumentCameraScan alloc] initWithRevenantPages:_pages title:[self defaultTitle]];
    id<VNDocumentCameraViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(documentCameraViewController:didFinishWithScan:)])
        [delegate documentCameraViewController:self didFinishWithScan:scan];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancel
{
    if (_reported)
        return;
    if (_pages.count == 0) {
        [self finishCancelled];
        return;
    }
    NSString *message = _pages.count == 1 ? @"The scanned page will be deleted." : [NSString stringWithFormat:@"The %lu scanned pages will be deleted.", (unsigned long)_pages.count];
    _alert = [[UIAlertView alloc] initWithTitle:@"Discard scans?" message:message delegate:self cancelButtonTitle:@"Keep Scanning" otherButtonTitles:@"Discard", nil];
    [_alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex)
        [self finishCancelled];
}

- (void)finishCancelled
{
    if (_reported)
        return;
    _reported = YES;
    [self stopSession];
    id<VNDocumentCameraViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(documentCameraViewControllerDidCancel:)])
        [delegate documentCameraViewControllerDidCancel:self];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)failWithError:(NSError *)error
{
    if (_reported)
        return;
    _reported = YES;
    [self stopSession];
    id<VNDocumentCameraViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(documentCameraViewController:didFailWithError:)])
        [delegate documentCameraViewController:self didFailWithError:error];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}

@end
