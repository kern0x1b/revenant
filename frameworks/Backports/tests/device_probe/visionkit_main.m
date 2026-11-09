#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import <VisionKit/VisionKit.h>

#import "RevenantDocumentScan.h"

static NSString *const REVENANT_LOG = @"/var/revenant/visionkit-probe.txt";

static const size_t SCENE_WIDTH = 3264;
static const size_t SCENE_HEIGHT = 2448;
static const double PAGE_WIDTH = 1500;
static const double PAGE_HEIGHT = 2000;
static const double PAGE_ANGLE = 8.0 * M_PI / 180.0;

@interface VNDocumentCameraViewController (RevenantProbe)
- (void)capture;
- (void)save;
- (void)cancel;
- (void)failWithError:(NSError *)error;
- (void)toggleMode;
- (void)liveFrameWithSize:(CGSize)size quad:(const RevenantDocumentQuad *)quad;
@end

static CGImageRef makeScene(void)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, SCENE_WIDTH, SCENE_HEIGHT, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 0.16, 0.17, 0.19, 1);
    CGContextFillRect(context, CGRectMake(0, 0, SCENE_WIDTH, SCENE_HEIGHT));
    CGContextTranslateCTM(context, SCENE_WIDTH / 2.0, SCENE_HEIGHT / 2.0);
    CGContextRotateCTM(context, PAGE_ANGLE);
    CGContextSetRGBFillColor(context, 0.94, 0.94, 0.92, 1);
    CGContextFillRect(context, CGRectMake(-PAGE_WIDTH / 2, -PAGE_HEIGHT / 2, PAGE_WIDTH, PAGE_HEIGHT));
    double sw = 0.14 * PAGE_WIDTH, sh = 0.14 * PAGE_HEIGHT, mx = 0.04 * PAGE_WIDTH, my = 0.04 * PAGE_HEIGHT;
    double left = -PAGE_WIDTH / 2 + mx, right = PAGE_WIDTH / 2 - mx - sw, bottom = -PAGE_HEIGHT / 2 + my, top = PAGE_HEIGHT / 2 - my - sh;
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(left, top, sw, sh));
    CGContextSetRGBFillColor(context, 0, 1, 0, 1);
    CGContextFillRect(context, CGRectMake(right, top, sw, sh));
    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    CGContextFillRect(context, CGRectMake(right, bottom, sw, sh));
    CGContextSetRGBFillColor(context, 1, 1, 0, 1);
    CGContextFillRect(context, CGRectMake(left, bottom, sw, sh));
    CGContextSetRGBFillColor(context, 0.35, 0.35, 0.35, 1);
    for (int line = 0; line < 9; line++)
        CGContextFillRect(context, CGRectMake(-PAGE_WIDTH * 0.3, PAGE_HEIGHT * 0.25 - line * PAGE_HEIGHT * 0.06, PAGE_WIDTH * 0.6, PAGE_HEIGHT * 0.02));
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static NSData *jpegOf(CGImageRef image, int orientation)
{
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.jpeg"), 1, NULL);
    NSDictionary *options = @{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality : @0.9,
                              (__bridge NSString *)kCGImagePropertyOrientation : @(orientation)};
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return data;
}

static BOOL sampleJPEG(NSData *jpeg, double fx, double fy, int rgb[3])
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL);
    if (source == NULL)
        return NO;
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (image == NULL)
        return NO;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGImageRelease(image);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    const uint8_t *pixel = pixels + (size_t)(fy * height) * CGBitmapContextGetBytesPerRow(context) + (size_t)(fx * width) * 4;
    for (int i = 0; i < 3; i++)
        rgb[i] = pixel[i];
    CGContextRelease(context);
    return YES;
}

static BOOL colourNear(const int rgb[3], int red, int green, int blue, int tolerance)
{
    return abs(rgb[0] - red) <= tolerance && abs(rgb[1] - green) <= tolerance && abs(rgb[2] - blue) <= tolerance;
}

static RevenantDocumentQuad truth(void)
{
    double sx[4] = {-1, 1, 1, -1}, sy[4] = {1, 1, -1, -1};
    RevenantDocumentQuad quad;
    for (int i = 0; i < 4; i++) {
        double x = sx[i] * PAGE_WIDTH / 2, y = sy[i] * PAGE_HEIGHT / 2;
        quad.corners[i].x = (float)((x * cos(PAGE_ANGLE) - y * sin(PAGE_ANGLE) + SCENE_WIDTH / 2.0) / SCENE_WIDTH);
        quad.corners[i].y = (float)((x * sin(PAGE_ANGLE) + y * cos(PAGE_ANGLE) + SCENE_HEIGHT / 2.0) / SCENE_HEIGHT);
    }
    return quad;
}

@interface RevenantAllDelegate : NSObject <VNDocumentCameraViewControllerDelegate>
@property (nonatomic, strong) VNDocumentCameraScan *scan;
@property (nonatomic, assign) NSUInteger cancels;
@property (nonatomic, assign) NSUInteger failures;
@property (nonatomic, assign) BOOL dismissOnScan;
@end

@implementation RevenantAllDelegate

@synthesize scan = _scan;
@synthesize cancels = _cancels;
@synthesize failures = _failures;
@synthesize dismissOnScan = _dismissOnScan;

- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFinishWithScan:(VNDocumentCameraScan *)scan
{
    self.scan = scan;
    if (self.dismissOnScan)
        [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)documentCameraViewControllerDidCancel:(VNDocumentCameraViewController *)controller
{
    self.cancels++;
}

- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFailWithError:(NSError *)error
{
    self.failures++;
    NSLog(@"visionkit probe: the controller failed: %@", error);
}

@end

@interface RevenantScanOnlyDelegate : NSObject <VNDocumentCameraViewControllerDelegate>
@end

@implementation RevenantScanOnlyDelegate

- (void)documentCameraViewController:(VNDocumentCameraViewController *)controller didFinishWithScan:(VNDocumentCameraScan *)scan
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface RevenantProbeDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *root;
@property (nonatomic, strong) NSMutableString *log;
@property (nonatomic, strong) RevenantAllDelegate *all;
@property (nonatomic, strong) RevenantScanOnlyDelegate *scanOnly;
@property (nonatomic, strong) VNDocumentCameraViewController *controller;
@property (nonatomic, strong) NSMutableArray *pending;
@end

@implementation RevenantProbeDelegate

@synthesize window = _window;
@synthesize root = _root;
@synthesize log = _log;
@synthesize all = _all;
@synthesize scanOnly = _scanOnly;
@synthesize controller = _controller;
@synthesize pending = _pending;

- (void)check:(BOOL)ok name:(NSString *)name detail:(NSString *)detail
{
    [self.log appendFormat:@"%@ %@%@\n", ok ? @"PASS" : @"FAIL", name, ok || detail.length == 0 ? @"" : [@": " stringByAppendingString:detail]];
}

- (void)note:(NSString *)text
{
    [self.log appendFormat:@"measured: %@\n", text];
    [self.log writeToFile:REVENANT_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)finish
{
    [self.log appendString:@"done\n"];
    NSError *error = nil;
    if (![self.log writeToFile:REVENANT_LOG atomically:YES encoding:NSUTF8StringEncoding error:&error])
        NSLog(@"visionkit probe: could not write %@: %@", REVENANT_LOG, error);
    exit(0);
}

- (void)wait:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout then:(void (^)(BOOL met))then
{
    NSTimeInterval start = CACurrentMediaTime();
    __block void (^poll)(void) = nil;
    __weak RevenantProbeDelegate *weakSelf = self;
    poll = ^{
        BOOL met = condition();
        if (met || CACurrentMediaTime() - start >= timeout) {
            then(met);
            poll = nil;
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (weakSelf != nil && poll != nil)
                poll();
        });
    };
    poll();
}

- (void)pipeline
{
    CGImageRef scene = makeScene();
    NSTimeInterval start = CACurrentMediaTime();
    NSData *still = jpegOf(scene, 1);
    [self note:[NSString stringWithFormat:@"the %zu by %zu still is encoded in %.0f ms, %lu bytes", SCENE_WIDTH, SCENE_HEIGHT, (CACurrentMediaTime() - start) * 1000, (unsigned long)still.length]];

    start = CACurrentMediaTime();
    RevenantDocumentPage *page = RevenantDocumentPageFromJPEG(still, NULL, 2048, 0.87);
    NSTimeInterval spent = CACurrentMediaTime() - start;
    [self note:[NSString stringWithFormat:@"a full size still becomes a page in %.0f ms: %zu by %zu, %lu bytes", spent * 1000, page.width, page.height, (unsigned long)page.jpeg.length]];
    [self check:page != nil && page.detected name:@"the page in the still is found" detail:@""];
    if (page != nil) {
        RevenantDocumentQuad expected = truth();
        RevenantDocumentQuad found = page.quad;
        double distance = RevenantDocumentQuadDistance(&expected, &found);
        [self note:[NSString stringWithFormat:@"the worst corner is %.4f of the frame from the page", distance]];
        [self check:distance < 0.015 name:@"the corners are where the page is" detail:[NSString stringWithFormat:@"%f", distance]];
        [self check:labs((long)page.height - (long)PAGE_HEIGHT) <= 12 && labs((long)page.width - (long)PAGE_WIDTH) <= 12 name:@"the scan has the page's own size" detail:[NSString stringWithFormat:@"%zu by %zu", page.width, page.height]];
        int tl[3], tr[3], br[3], bl[3];
        BOOL sampled = sampleJPEG(page.jpeg, 0.11, 0.11, tl) && sampleJPEG(page.jpeg, 0.89, 0.11, tr) && sampleJPEG(page.jpeg, 0.89, 0.89, br) && sampleJPEG(page.jpeg, 0.11, 0.89, bl);
        [self check:sampled && colourNear(tl, 255, 0, 0, 60) && colourNear(tr, 0, 255, 0, 60) && colourNear(br, 0, 0, 255, 60) && colourNear(bl, 255, 255, 0, 60) name:@"the four marks keep their corners upright"
             detail:sampled ? [NSString stringWithFormat:@"%d,%d,%d %d,%d,%d %d,%d,%d %d,%d,%d", tl[0], tl[1], tl[2], tr[0], tr[1], tr[2], br[0], br[1], br[2], bl[0], bl[1], bl[2]] : @"no sample"];
    }

    NSData *turned = jpegOf(scene, 6);
    RevenantDocumentPage *rotated = RevenantDocumentPageFromJPEG(turned, NULL, 2048, 0.87);
    [self check:rotated != nil && rotated.height < rotated.width name:@"a still tagged for a quarter turn is turned by the decoder" detail:[NSString stringWithFormat:@"%zu by %zu", rotated.width, rotated.height]];

    size_t width = 852, height = 640;
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef frame = CGBitmapContextCreate(NULL, width, height, 8, width, gray, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(gray);
    CGContextSetInterpolationQuality(frame, kCGInterpolationHigh);
    CGContextDrawImage(frame, CGRectMake(0, 0, width, height), scene);
    uint8_t *luma = malloc(320 * 320);
    size_t luma_width = 0, luma_height = 0;
    int found = 0;
    start = CACurrentMediaTime();
    for (int i = 0; i < 20; i++) {
        RevenantDocumentLuminance(CGBitmapContextGetData(frame), width, height, CGBitmapContextGetBytesPerRow(frame), 1, 320, luma, &luma_width, &luma_height);
        RevenantDocumentQuad quad;
        found += RevenantDocumentFindQuad(luma, luma_width, luma_height, luma_width, NULL, &quad);
    }
    spent = (CACurrentMediaTime() - start) / 20;
    [self note:[NSString stringWithFormat:@"a live frame of %zu by %zu is turned, reduced to %zu by %zu and searched in %.1f ms, found %d of 20", width, height, luma_width, luma_height, spent * 1000, found]];
    [self check:found == 20 && luma_width == 213 && luma_height == 284 name:@"a live frame is found every time and comes out portrait" detail:[NSString stringWithFormat:@"%d, %zu by %zu", found, luma_width, luma_height]];
    free(luma);
    CGContextRelease(frame);
    CGImageRelease(scene);
}

- (void)present:(VNDocumentCameraViewController *)controller
{
    self.controller = controller;
    [self.root presentViewController:controller animated:NO completion:nil];
}

- (void)phaseLive
{
    [self check:[VNDocumentCameraViewController isSupported] name:@"the device supports the document camera" detail:@""];
    self.all = [[RevenantAllDelegate alloc] init];
    self.all.dismissOnScan = YES;
    VNDocumentCameraViewController *controller = [[VNDocumentCameraViewController alloc] init];
    controller.delegate = self.all;
    [self present:controller];
    NSTimeInterval start = CACurrentMediaTime();
    __weak RevenantProbeDelegate *weakSelf = self;
    [self wait:^BOOL{
        RevenantProbeDelegate *strongSelf = weakSelf;
        AVCaptureSession *session = [strongSelf.controller valueForKey:@"session"];
        return session.isRunning && [[strongSelf.controller valueForKey:@"lastFrame"] doubleValue] > 0;
    } timeout:12 then:^(BOOL met) {
        RevenantProbeDelegate *strongSelf = weakSelf;
        [strongSelf check:met name:@"the session runs and live frames are searched" detail:@""];
        [strongSelf note:[NSString stringWithFormat:@"the first live frame was searched %.2f s after the presentation", CACurrentMediaTime() - start]];
        [strongSelf check:strongSelf.all.failures == 0 name:@"the camera opened without a failure" detail:@""];
        CGSize size = [[strongSelf.controller valueForKey:@"videoSize"] CGSizeValue];
        [strongSelf note:[NSString stringWithFormat:@"live frames come out %.0f by %.0f", size.width, size.height]];
        [strongSelf check:size.width < size.height name:@"live frames are portrait" detail:@""];
        UIView *preview = [strongSelf.controller valueForKey:@"previewView"];
        UIView *bottom = [strongSelf.controller valueForKey:@"bottomBar"];
        [strongSelf check:strongSelf.controller.view.window != nil && strongSelf.root.presentedViewController == strongSelf.controller name:@"the controller is on the window" detail:@""];
        [strongSelf note:[NSString stringWithFormat:@"view %@, preview %@, bottom bar %@, quad hidden %d", NSStringFromCGRect(strongSelf.controller.view.frame), NSStringFromCGRect(preview.frame), NSStringFromCGRect(bottom.frame), [[[strongSelf.controller valueForKey:@"quadLayer"] valueForKey:@"hidden"] boolValue]]];
        [strongSelf.log appendString:@"live view up\n"];
        [strongSelf.log writeToFile:REVENANT_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        double hold = [[NSUserDefaults standardUserDefaults] objectForKey:@"hold"] != nil ? [[NSUserDefaults standardUserDefaults] doubleForKey:@"hold"] : 10;
        [strongSelf.controller toggleMode];
        [strongSelf injectFor:hold then:^{
            RevenantProbeDelegate *inner = weakSelf;
            [inner check:![[[inner.controller valueForKey:@"quadLayer"] valueForKey:@"hidden"] boolValue] name:@"a page seen by the detector is outlined" detail:@""];
            [inner check:[[inner.controller valueForKey:@"pages"] count] == 0 name:@"manual mode does not scan by itself" detail:@""];
            [inner phaseAutomatic];
        }];
    }];
}

- (void)injectFor:(NSTimeInterval)duration then:(void (^)(void))then
{
    NSTimeInterval end = CACurrentMediaTime() + duration;
    __block NSTimeInterval previous = CACurrentMediaTime();
    __block NSTimeInterval longest = 0;
    __block void (^step)(void) = nil;
    __weak RevenantProbeDelegate *weakSelf = self;
    step = ^{
        RevenantProbeDelegate *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        NSTimeInterval now = CACurrentMediaTime();
        if (now - previous > longest)
            longest = now - previous;
        previous = now;
        RevenantDocumentQuad quad = {{{0.15f, 0.86f}, {0.86f, 0.82f}, {0.88f, 0.22f}, {0.12f, 0.17f}}};
        [strongSelf.controller liveFrameWithSize:CGSizeMake(213, 284) quad:&quad];
        if (CACurrentMediaTime() < end) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (weakSelf != nil && step != nil)
                    step();
            });
        } else {
            [strongSelf note:[NSString stringWithFormat:@"the longest pause of the main thread in %.0f s of live view was %.0f ms", duration, longest * 1000]];
            then();
            step = nil;
        }
    };
    step();
}

- (void)phaseAutomatic
{
    [self.controller toggleMode];
    NSTimeInterval start = CACurrentMediaTime();
    __weak RevenantProbeDelegate *weakSelf = self;
    [self injectFor:4 then:^{
        [weakSelf wait:^BOOL{
            return [[weakSelf.controller valueForKey:@"pages"] count] >= 1 && ![[weakSelf.controller valueForKey:@"busy"] boolValue];
        } timeout:25 then:^(BOOL met) {
            RevenantProbeDelegate *strongSelf = weakSelf;
            [strongSelf check:met name:@"a page held still is scanned by itself" detail:@""];
            [strongSelf note:[NSString stringWithFormat:@"an automatic scan took %.2f s from the first sight of the page", CACurrentMediaTime() - start]];
            [strongSelf injectFor:3 then:^{
                RevenantProbeDelegate *inner = weakSelf;
                [inner check:[[inner.controller valueForKey:@"pages"] count] == 1 name:@"the same page is not scanned twice" detail:[NSString stringWithFormat:@"%lu pages", (unsigned long)[[inner.controller valueForKey:@"pages"] count]]];
                [inner phaseCapture];
            }];
        }];
    }];
}

- (void)phaseCapture
{
    NSUInteger before = [[self.controller valueForKey:@"pages"] count];
    NSTimeInterval start = CACurrentMediaTime();
    [self.controller capture];
    __weak RevenantProbeDelegate *weakSelf = self;
    [self wait:^BOOL{
        RevenantProbeDelegate *strongSelf = weakSelf;
        return [[strongSelf.controller valueForKey:@"pages"] count] > before && ![[strongSelf.controller valueForKey:@"busy"] boolValue];
    } timeout:30 then:^(BOOL met) {
        RevenantProbeDelegate *strongSelf = weakSelf;
        [strongSelf check:met name:@"a capture adds a page" detail:@""];
        [strongSelf note:[NSString stringWithFormat:@"a capture from the shutter to the page took %.2f s", CACurrentMediaTime() - start]];
        NSData *jpeg = [[strongSelf.controller valueForKey:@"pages"] lastObject];
        [strongSelf note:[NSString stringWithFormat:@"the page of the room is %lu bytes", (unsigned long)jpeg.length]];
        [strongSelf.controller save];
        [strongSelf wait:^BOOL{
            return weakSelf.all.scan != nil;
        } timeout:5 then:^(BOOL delivered) {
            RevenantProbeDelegate *inner = weakSelf;
            VNDocumentCameraScan *scan = inner.all.scan;
            [inner check:delivered && scan.pageCount == 2 name:@"save delivers the scan with its pages" detail:[NSString stringWithFormat:@"%lu", (unsigned long)scan.pageCount]];
            UIImage *image = [scan imageOfPageAtIndex:0];
            [inner check:image != nil && image.size.width > 100 && image.size.height > 100 name:@"the page reads back as an image" detail:NSStringFromCGSize(image.size)];
            [inner note:[NSString stringWithFormat:@"the delivered page is %.0f by %.0f, titled '%@'", image.size.width, image.size.height, scan.title]];
            [inner check:[scan.title hasPrefix:@"Scan "] name:@"the scan has a title" detail:scan.title];
            [inner check:[scan imageOfPageAtIndex:2] == nil name:@"a page beyond the count is nil" detail:@""];
            [inner wait:^BOOL{
                return weakSelf.root.presentedViewController == nil;
            } timeout:5 then:^(BOOL gone) {
                [weakSelf check:gone name:@"the delegate's dismissal removes the controller" detail:@""];
                [weakSelf phaseQuiet:YES];
            }];
        }];
    }];
}

- (void)phaseQuiet:(BOOL)cancel
{
    self.scanOnly = [[RevenantScanOnlyDelegate alloc] init];
    VNDocumentCameraViewController *controller = [[VNDocumentCameraViewController alloc] init];
    controller.delegate = self.scanOnly;
    [self present:controller];
    __weak RevenantProbeDelegate *weakSelf = self;
    [self wait:^BOOL{
        AVCaptureSession *session = [weakSelf.controller valueForKey:@"session"];
        return session.isRunning;
    } timeout:12 then:^(BOOL met) {
        RevenantProbeDelegate *strongSelf = weakSelf;
        [strongSelf check:met name:[NSString stringWithFormat:@"the session runs for the %@ check", cancel ? @"cancel" : @"failure"] detail:@""];
        if (cancel)
            [strongSelf.controller cancel];
        else
            [strongSelf.controller failWithError:[NSError errorWithDomain:@"probe" code:1 userInfo:nil]];
        [strongSelf wait:^BOOL{
            return weakSelf.root.presentedViewController == nil;
        } timeout:5 then:^(BOOL gone) {
            [weakSelf check:gone name:cancel ? @"cancel dismisses a controller whose delegate has no cancel method" : @"a failure dismisses a controller whose delegate has no failure method" detail:@""];
            if (cancel)
                [weakSelf phaseQuiet:NO];
            else
                [weakSelf finish];
        }];
    }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.log = [NSMutableString string];
    [self.log writeToFile:REVENANT_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.root = [[UIViewController alloc] init];
    self.root.view.backgroundColor = [UIColor darkGrayColor];
    self.window.rootViewController = self.root;
    [self.window makeKeyAndVisible];
    __weak RevenantProbeDelegate *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakSelf pipeline];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf phaseLive];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantProbeDelegate class]));
    }
}
