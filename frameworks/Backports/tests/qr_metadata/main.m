#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

static NSString *const REVENANT_QR_LOG = @"/var/revenant/qr-metadata.txt";
static NSTimeInterval const REVENANT_QR_PHASE = 20.0;

@interface RevenantQRRecorder : NSObject <AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) NSMutableArray *objects;
@property (nonatomic, assign) NSUInteger callbacks;
@end

@implementation RevenantQRRecorder

@synthesize objects = _objects;
@synthesize callbacks = _callbacks;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    self.callbacks++;
    [self.objects addObjectsFromArray:metadataObjects];
}

@end

@interface RevenantQRAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureMetadataOutput *metadata;
@property (nonatomic, strong) RevenantQRRecorder *recorder;
@property (nonatomic, strong) NSMutableString *log;
@end

@implementation RevenantQRAppDelegate

@synthesize window = _window;
@synthesize session = _session;
@synthesize metadata = _metadata;
@synthesize recorder = _recorder;
@synthesize log = _log;

- (void)check:(BOOL)ok name:(NSString *)name
{
    [self.log appendFormat:@"%@ %@\n", ok ? @"PASS" : @"FAIL", name];
}

- (void)finish
{
    [self.session stopRunning];
    NSError *error = nil;
    if (![self.log writeToFile:REVENANT_QR_LOG atomically:YES encoding:NSUTF8StringEncoding error:&error])
        NSLog(@"revenant: could not write %@: %@", REVENANT_QR_LOG, error);
}

- (void)phaseTwoEnd
{
    BOOL inside = YES;
    for (AVMetadataMachineReadableCodeObject *object in self.recorder.objects)
        if (object.bounds.origin.x < 0.5 - 0.01)
            inside = NO;
    [self check:inside name:@"no code outside the rectangle of interest is delivered"];
    [self.log appendFormat:@"phase two: %lu callbacks, %lu codes\n", (unsigned long)self.recorder.callbacks, (unsigned long)self.recorder.objects.count];
    [self finish];
}

- (void)startPhaseTwo
{
    [self.log appendString:@"phase one codes:\n"];
    for (AVMetadataMachineReadableCodeObject *object in self.recorder.objects)
        [self.log appendFormat:@"  %@ %@ %@\n", object.type, object.stringValue, NSStringFromCGRect(object.bounds)];
    self.recorder.objects = [NSMutableArray array];
    self.recorder.callbacks = 0;
    self.metadata.rectOfInterest = CGRectMake(0.5, 0, 0.5, 1);
    [self performSelector:@selector(phaseTwoEnd) withObject:nil afterDelay:REVENANT_QR_PHASE];
}

- (void)phaseOneEnd
{
    NSArray *objects = self.recorder.objects;
    [self check:objects.count > 0 name:@"the delegate received a QR code"];
    BOOL typed = YES, cornered = YES, valued = YES;
    for (AVMetadataMachineReadableCodeObject *object in objects) {
        if (![object.type isEqualToString:AVMetadataObjectTypeQRCode])
            typed = NO;
        if (object.corners.count != 4)
            cornered = NO;
        if (object.stringValue.length == 0)
            valued = NO;
    }
    [self check:typed name:@"every delivered code has the QR type"];
    [self check:cornered name:@"every delivered code has four corners"];
    [self check:valued name:@"every delivered code carries its string"];
    [self startPhaseTwo];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.log = [NSMutableString string];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *controller = [[UIViewController alloc] init];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];

    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        [self.log appendFormat:@"FAIL the camera input: %@\n", error];
        [self finish];
        return YES;
    }
    self.metadata = [[AVCaptureMetadataOutput alloc] init];
    self.recorder = [[RevenantQRRecorder alloc] init];
    self.recorder.objects = [NSMutableArray array];
    [self.session beginConfiguration];
    [self.session addInput:input];
    [self.session addOutput:self.metadata];
    [self.session commitConfiguration];

    [self check:[self.metadata.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode] name:@"QR is an available metadata type"];
    [self.metadata setMetadataObjectsDelegate:self.recorder queue:dispatch_get_main_queue()];
    self.metadata.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    [self check:[self.metadata.metadataObjectTypes isEqualToArray:@[AVMetadataObjectTypeQRCode]] name:@"the requested type reads back"];

    AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    preview.frame = controller.view.bounds;
    [controller.view.layer addSublayer:preview];
    [self.session startRunning];
    [self performSelector:@selector(phaseOneEnd) withObject:nil afterDelay:REVENANT_QR_PHASE];
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantQRAppDelegate class]));
    }
}
