#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const REVENANT_LAYOUT_LOG = @"/var/revenant/layout.txt";
static NSTimeInterval const REVENANT_CASE_HOLD = 4.0;
static const CGFloat REVENANT_EDGE_NONE = 0;
static const CGFloat REVENANT_EDGE_ALL = 15;

static void revenant_check(NSMutableString *log, BOOL ok, NSString *name)
{
    [log appendFormat:@"%@ %@\n", ok ? @"PASS" : @"FAIL", name];
}

@interface RevenantRecorder : NSObject <AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) NSMutableArray *received;
@end

@implementation RevenantRecorder

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    [self.received addObjectsFromArray:metadataObjects];
}

@end

@interface RevenantFakeMetadata : NSObject
@property (nonatomic, assign) CGRect bounds;
@end

@implementation RevenantFakeMetadata
@end

static RevenantFakeMetadata *revenant_fake(CGRect bounds)
{
    RevenantFakeMetadata *object = [[RevenantFakeMetadata alloc] init];
    object.bounds = bounds;
    return object;
}

static BOOL revenant_same_objects(NSArray *a, NSArray *b)
{
    if (a.count != b.count)
        return NO;
    for (NSUInteger index = 0; index < a.count; index++)
        if (a[index] != b[index])
            return NO;
    return YES;
}

static void revenant_test_rect_of_interest(NSMutableString *log)
{
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    revenant_check(log, CGRectEqualToRect(output.rectOfInterest, CGRectMake(0, 0, 1, 1)), @"rectOfInterest default is {0,0,1,1}");
    output.rectOfInterest = CGRectMake(0.25, 0, 0.5, 1);
    revenant_check(log, CGRectEqualToRect(output.rectOfInterest, CGRectMake(0.25, 0, 0.5, 1)), @"rectOfInterest returns the rect it was given");

    RevenantRecorder *recorder = [[RevenantRecorder alloc] init];
    recorder.received = [NSMutableArray array];
    [output setMetadataObjectsDelegate:recorder queue:dispatch_get_main_queue()];
    revenant_check(log, output.metadataObjectsDelegate == recorder, @"metadataObjectsDelegate returns the delegate that was set");

    id filter = objc_getAssociatedObject(output, (__bridge const void *)NSClassFromString(@"RevenantMetadataObjectsFilter"));
    RevenantFakeMetadata *inside = revenant_fake(CGRectMake(0.3, 0.1, 0.1, 0.1));
    RevenantFakeMetadata *outside = revenant_fake(CGRectMake(0.8, 0.1, 0.1, 0.1));
    RevenantFakeMetadata *straddling = revenant_fake(CGRectMake(0.2, 0.1, 0.2, 0.2));
    RevenantFakeMetadata *none = revenant_fake(CGRectZero);
    NSArray *batch = @[inside, outside, straddling, none];

    [filter captureOutput:output didOutputMetadataObjects:batch fromConnection:nil];
    revenant_check(log, revenant_same_objects(recorder.received, @[inside, straddling]),
        @"rectOfInterest {0.25,0,0.5,1}: only objects whose bounds intersect it are delivered");

    [recorder.received removeAllObjects];
    output.rectOfInterest = CGRectMake(0, 0, 1, 1);
    [filter captureOutput:output didOutputMetadataObjects:batch fromConnection:nil];
    revenant_check(log, revenant_same_objects(recorder.received, @[inside, outside, straddling]),
        @"default rectOfInterest: every object whose bounds intersect the frame is delivered");

    AVCaptureVideoPreviewLayer *preview = [AVCaptureVideoPreviewLayer layer];
    preview.frame = CGRectMake(0, 0, 320, 480);
    CGRect centred = [preview metadataOutputRectOfInterestForRect:CGRectMake(100, 180, 120, 120)];
    [log appendFormat:@"info metadataOutputRectOfInterestForRect centred = %@\n", NSStringFromCGRect(centred)];
    revenant_check(log, fabs(CGRectGetMidX(centred) - 0.5) < 0.001 && fabs(CGRectGetMidY(centred) - 0.5) < 0.001,
        @"a rect centred on the layer converts to a rect centred on the output");
    CGRect whole = [preview metadataOutputRectOfInterestForRect:CGRectMake(0, 0, 320, 480)];
    [log appendFormat:@"info metadataOutputRectOfInterestForRect whole layer = %@\n", NSStringFromCGRect(whole)];
}

@interface RevenantLayoutController : UIViewController
@property (nonatomic, assign) BOOL wantsFull;
@property (nonatomic, assign) BOOL setWants;
@property (nonatomic, assign) CGFloat edges;
@property (nonatomic, assign) BOOL setEdges;
@property (nonatomic, assign) CGFloat afterEdges;
@property (nonatomic, copy) void (^recorded)(RevenantLayoutController *);
@end

@implementation RevenantLayoutController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor redColor];
    if (self.setWants)
        self.wantsFullScreenLayout = self.wantsFull;
    if (self.setEdges)
        ((void (*)(id, SEL, NSUInteger))objc_msgSend)(self, sel_registerName("setEdgesForExtendedLayout:"), (NSUInteger)self.edges);
    if (self.afterEdges >= 0)
        ((void (*)(id, SEL, NSUInteger))objc_msgSend)(self, sel_registerName("setEdgesForExtendedLayout:"), (NSUInteger)self.afterEdges);
    UITableView *table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:table];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self performSelector:@selector(report) withObject:nil afterDelay:1.0];
}

- (void)report
{
    if (self.recorded)
        self.recorded(self);
}

@end

@interface RevenantLayoutDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableString *log;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preview;
@end

@implementation RevenantLayoutDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.log = [NSMutableString string];
    [self.log appendFormat:@"iOS %@ setTranslucent=%d\n",
        [[UIDevice currentDevice] systemVersion],
        [UINavigationBar instancesRespondToSelector:@selector(setTranslucent:)]];
    revenant_test_rect_of_interest(self.log);
    [self.window makeKeyAndVisible];
    [self startSession];
    [self performSelector:@selector(measureSession) withObject:nil afterDelay:3.0];
    [self next];
    return YES;
}

- (void)startSession
{
    self.session = [[AVCaptureSession alloc] init];
    NSError *error = nil;
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = camera ? [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error] : nil;
    if (input && [self.session canAddInput:input])
        [self.session addInput:input];
    AVCaptureMetadataOutput *metadata = [[AVCaptureMetadataOutput alloc] init];
    if ([self.session canAddOutput:metadata])
        [self.session addOutput:metadata];
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.preview.frame = self.window.layer.bounds;
    [self.window.layer addSublayer:self.preview];
    [self.session startRunning];
    [self.log appendFormat:@"info session input=%d output=%d running=%d error=%@\n",
        input != nil, [self.session.outputs count] > 0, self.session.isRunning, error];
}

- (void)measureSession
{
    CGRect bounds = self.preview.bounds;
    CGRect centred = [self.preview metadataOutputRectOfInterestForRect:CGRectMake(CGRectGetMidX(bounds) - 60, CGRectGetMidY(bounds) - 60, 120, 120)];
    [self.log appendFormat:@"info session running=%d centred = %@\n", self.session.isRunning, NSStringFromCGRect(centred)];
    revenant_check(self.log, fabs(CGRectGetMidX(centred) - 0.5) < 0.01 && fabs(CGRectGetMidY(centred) - 0.5) < 0.01,
        @"session: a rect centred on the layer converts to a rect centred on the output");
    CGRect whole = [self.preview metadataOutputRectOfInterestForRect:bounds];
    [self.log appendFormat:@"info session whole layer = %@\n", NSStringFromCGRect(whole)];
}

- (void)next
{
    NSArray *cases = @[
        @[@NO, @NO, @NO, @0, @NO, @(-1)],
        @[@NO, @YES, @YES, @0, @NO, @(-1)],
        @[@YES, @NO, @NO, @0, @NO, @(-1)],
        @[@YES, @YES, @YES, @0, @NO, @(-1)],
        @[@NO, @NO, @NO, @(REVENANT_EDGE_NONE), @YES, @(-1)],
        @[@NO, @NO, @NO, @(REVENANT_EDGE_ALL), @YES, @(-1)],
        @[@YES, @NO, @NO, @(REVENANT_EDGE_NONE), @YES, @(-1)],
        @[@YES, @NO, @NO, @(REVENANT_EDGE_ALL), @YES, @(-1)],
        @[@NO, @NO, @NO, @(REVENANT_EDGE_ALL), @YES, @(REVENANT_EDGE_NONE)],
        @[@YES, @NO, @NO, @(REVENANT_EDGE_ALL), @YES, @(REVENANT_EDGE_NONE)],
    ];
    if (self.index >= (NSInteger)cases.count) {
        [self.log writeToFile:REVENANT_LAYOUT_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        return;
    }
    NSArray *c = cases[self.index];
    BOOL translucent = [c[0] boolValue];
    BOOL wants = [c[1] boolValue];
    BOOL setWants = [c[2] boolValue];
    CGFloat edges = [c[3] doubleValue];
    BOOL setEdges = [c[4] boolValue];
    CGFloat afterEdges = [c[5] doubleValue];
    CGFloat finalEdges = afterEdges >= 0 ? afterEdges : edges;
    NSInteger index = self.index;
    if (setEdges && ![UIViewController instancesRespondToSelector:@selector(setEdgesForExtendedLayout:)]) {
        [self.log appendFormat:@"case %ld skipped: edgesForExtendedLayout is absent on this release\n", (long)index];
        self.index = index + 1;
        [self next];
        return;
    }
    RevenantLayoutController *controller = [[RevenantLayoutController alloc] init];
    controller.wantsFull = wants;
    controller.setWants = setWants;
    controller.edges = edges;
    controller.setEdges = setEdges;
    controller.afterEdges = afterEdges;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    if ([nav.navigationBar respondsToSelector:@selector(setTranslucent:)])
        nav.navigationBar.translucent = translucent;
    __weak RevenantLayoutDelegate *weakSelf = self;
    controller.recorded = ^(RevenantLayoutController *top) {
        CGRect view = [top.view.superview convertRect:top.view.frame toView:nil];
        CGRect bar = [top.navigationController.navigationBar.superview convertRect:top.navigationController.navigationBar.frame toView:nil];
        UITableView *table = nil;
        for (UIView *subview in top.view.subviews)
            if ([subview isKindOfClass:[UITableView class]])
                table = (UITableView *)subview;
        NSString *expect = @"";
        if (setEdges) {
            BOOL below = finalEdges == REVENANT_EDGE_NONE || !translucent;
            BOOL matches = below ? fabs(CGRectGetMinY(view) - CGRectGetMaxY(bar)) < 0.5 : fabs(CGRectGetMinY(view)) < 0.5;
            expect = [NSString stringWithFormat:@" iOS7expectation=%@ match=%d", below ? @"below-bars" : @"under-translucent-bar", matches];
        }
        [weakSelf.log appendFormat:@"case %ld translucentBar=%d setWants=%d wants=%d setEdges=%d edges=%d barMaxY=%.1f viewY=%.1f viewH=%.1f tableY=%.1f tableInsetTop=%.1f statusBarH=%.1f barIsTranslucent=%d%@\n",
            (long)index, translucent, setWants, wants, setEdges, (int)finalEdges, CGRectGetMaxY(bar), CGRectGetMinY(view), CGRectGetHeight(view),
            table ? CGRectGetMinY([table.superview convertRect:table.frame toView:nil]) : -1,
            table ? table.contentInset.top : -1,
            [[UIApplication sharedApplication] statusBarFrame].size.height,
            [top.navigationController.navigationBar respondsToSelector:@selector(isTranslucent)] ? [top.navigationController.navigationBar isTranslucent] : -1,
            expect];
        [weakSelf.log writeToFile:REVENANT_LAYOUT_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        weakSelf.index = index + 1;
        [weakSelf.window setRootViewController:nil];
        [weakSelf performSelector:@selector(next) withObject:nil afterDelay:REVENANT_CASE_HOLD];
    };
    [self.window setRootViewController:nav];
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantLayoutDelegate class]));
    }
}
