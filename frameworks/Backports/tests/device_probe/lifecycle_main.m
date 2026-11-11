#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

static CFAbsoluteTime REVENANT_START;
static NSMutableString *REVENANT_LOG;

static void revenant_event(NSString *text)
{
    NSString *line = [NSString stringWithFormat:@"t=%.2f %@\n", CFAbsoluteTimeGetCurrent() - REVENANT_START, text];
    [REVENANT_LOG appendString:line];
    printf("%s", [line UTF8String]);
    fflush(stdout);
    [REVENANT_LOG writeToFile:@"/var/revenant/lifecycle-probe.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@interface RevenantLifecycleView : UIView
@end

@implementation RevenantLifecycleView

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

@end

@interface RevenantLifecycleProbe : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantLifecycleProbe {
    id<MTLCommandQueue> _queue;
    CAMetalLayer *_layer;
    CADisplayLink *_link;
    BOOL _backgrounded;
    BOOL _resumed;
    NSUInteger _foregroundFrames;
    NSUInteger _backgroundFrames;
    NSUInteger _resumedFrames;
    NSUInteger _nilDrawables;
    NSUInteger _droppedBuffers;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    REVENANT_START = CFAbsoluteTimeGetCurrent();
    REVENANT_LOG = [NSMutableString string];
    revenant_event([NSString stringWithFormat:@"launched applicationState=%ld", (long)application.applicationState]);

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *controller = [[UIViewController alloc] init];
    RevenantLifecycleView *view = [[RevenantLifecycleView alloc] initWithFrame:self.window.bounds];
    controller.view = view;
    self.window.rootViewController = controller;

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    _queue = [device newCommandQueue];
    _layer = (CAMetalLayer *)view.layer;
    _layer.device = device;
    _layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    CGFloat scale = [UIScreen mainScreen].scale;
    _layer.drawableSize = CGSizeMake(view.bounds.size.width * scale, view.bounds.size.height * scale);
    revenant_event([NSString stringWithFormat:@"layer device %@ drawable %.0fx%.0f", device ? @"set" : @"missing", _layer.drawableSize.width, _layer.drawableSize.height]);

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

    [self.window makeKeyAndVisible];
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    return YES;
}

- (void)tick:(CADisplayLink *)link
{
    if (_resumedFrames >= 120) {
        revenant_event([NSString stringWithFormat:@"DONE foreground=%lu background=%lu resumed=%lu nilDrawables=%lu droppedBuffers=%lu",
                        (unsigned long)_foregroundFrames, (unsigned long)_backgroundFrames, (unsigned long)_resumedFrames,
                        (unsigned long)_nilDrawables, (unsigned long)_droppedBuffers]);
        exit(0);
    }
    [self render];
}

- (void)render
{
    id<CAMetalDrawable> drawable = [_layer nextDrawable];
    if (!drawable) {
        _nilDrawables++;
        return;
    }
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.4, 0.8, 1.0);
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder endEncoding];
    [buffer presentDrawable:drawable];
    [buffer addCompletedHandler:^(id<MTLCommandBuffer> finished) {
        if (finished.status == MTLCommandBufferStatusError)
            _droppedBuffers++;
    }];
    [buffer commit];
    if (_resumed)
        _resumedFrames++;
    else if (_backgrounded)
        _backgroundFrames++;
    else
        _foregroundFrames++;
}

- (void)didEnterBackground:(NSNotification *)note
{
    _backgrounded = YES;
    revenant_event([NSString stringWithFormat:@"DidEnterBackground frames=%lu", (unsigned long)_foregroundFrames]);
}

- (void)willEnterForeground:(NSNotification *)note
{
    _resumed = YES;
    revenant_event([NSString stringWithFormat:@"WillEnterForeground background-frames=%lu", (unsigned long)_backgroundFrames]);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantLifecycleProbe class]));
    }
}
