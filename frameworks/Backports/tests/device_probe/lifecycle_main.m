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
    id<MTLTexture> _target;
    NSData *_last;
    BOOL _compared;
    uint8_t _frame;
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
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:64 height:64 mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    _target = [device newTextureWithDescriptor:descriptor];
    revenant_event([NSString stringWithFormat:@"target %@ 64x64 BGRA8", _target ? @"created" : @"missing"]);
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
    if (_resumed && !_compared) {
        _compared = YES;
        [self comparePixels];
    }
    [self render];
}

- (void)comparePixels
{
    if (!_last) {
        revenant_event(@"PIXELS skipped: no frame was drawn before the background");
        return;
    }
    NSMutableData *now = [NSMutableData dataWithLength:_last.length];
    [_target getBytes:now.mutableBytes bytesPerRow:64 * 4 fromRegion:MTLRegionMake2D(0, 0, 64, 64) mipmapLevel:0];
    const uint8_t *before = _last.bytes;
    const uint8_t *after = now.bytes;
    NSInteger first = -1;
    for (NSUInteger i = 0; i < _last.length; i++) {
        if (before[i] != after[i]) {
            first = (NSInteger)i;
            break;
        }
    }
    if (first < 0)
        revenant_event([NSString stringWithFormat:@"PIXELS match bytes=%lu", (unsigned long)_last.length]);
    else
        revenant_event([NSString stringWithFormat:@"PIXELS MISMATCH bytes=%lu first=%ld before=%02x after=%02x",
                        (unsigned long)_last.length, (long)first, before[first], after[first]]);
}

- (void)render
{
    id<CAMetalDrawable> drawable = [_layer nextDrawable];
    if (!drawable) {
        _nilDrawables++;
        return;
    }
    uint8_t shade = _frame++;
    MTLRenderPassDescriptor *clear = [MTLRenderPassDescriptor renderPassDescriptor];
    clear.colorAttachments[0].texture = _target;
    clear.colorAttachments[0].loadAction = MTLLoadActionClear;
    clear.colorAttachments[0].storeAction = MTLStoreActionStore;
    clear.colorAttachments[0].clearColor = MTLClearColorMake(shade / 255.0, 0.5, 0.25, 1.0);
    id<MTLCommandBuffer> offscreen = [_queue commandBuffer];
    [[offscreen renderCommandEncoderWithDescriptor:clear] endEncoding];
    [offscreen commit];
    [offscreen waitUntilCompleted];
    uint8_t pattern[32 * 32 * 4];
    for (NSUInteger y = 0; y < 32; y++) {
        for (NSUInteger x = 0; x < 32; x++) {
            uint8_t *p = pattern + (y * 32 + x) * 4;
            p[0] = (uint8_t)x;
            p[1] = (uint8_t)y;
            p[2] = shade ^ (uint8_t)(x * y);
            p[3] = 255;
        }
    }
    [_target replaceRegion:MTLRegionMake2D(0, 0, 32, 32) mipmapLevel:0 withBytes:pattern bytesPerRow:32 * 4];
    NSMutableData *drawn = [NSMutableData dataWithLength:64 * 64 * 4];
    [_target getBytes:drawn.mutableBytes bytesPerRow:64 * 4 fromRegion:MTLRegionMake2D(0, 0, 64, 64) mipmapLevel:0];
    _last = drawn;
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
    _compared = NO;
    revenant_event([NSString stringWithFormat:@"WillEnterForeground background-frames=%lu", (unsigned long)_backgroundFrames]);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantLifecycleProbe class]));
    }
}
