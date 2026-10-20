#import "RevenantMetal.h"

@interface RevenantMTLCaptureScope : NSObject <MTLCaptureScope>
- (instancetype)initWithDevice:(id<MTLDevice>)device commandQueue:(id<MTLCommandQueue>)commandQueue;
@end

@implementation RevenantMTLCaptureScope
{
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
}

@synthesize label;

- (instancetype)initWithDevice:(id<MTLDevice>)device commandQueue:(id<MTLCommandQueue>)commandQueue
{
    if ((self = [super init])) {
        _device = device;
        _commandQueue = commandQueue;
    }
    return self;
}

- (void)beginScope
{
}

- (void)endScope
{
}

- (id<MTLDevice>)device
{
    return _device;
}

- (id<MTLCommandQueue>)commandQueue
{
    return _commandQueue;
}

@end

@implementation MTLCaptureManager

+ (MTLCaptureManager *)sharedCaptureManager
{
    static MTLCaptureManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MTLCaptureManager alloc] initRevenant];
    });
    return shared;
}

- (instancetype)initRevenant
{
    return [super init];
}

- (id<MTLCaptureScope>)newCaptureScopeWithDevice:(id<MTLDevice>)device
{
    return [[RevenantMTLCaptureScope alloc] initWithDevice:device commandQueue:nil];
}

- (id<MTLCaptureScope>)newCaptureScopeWithCommandQueue:(id<MTLCommandQueue>)commandQueue
{
    return [[RevenantMTLCaptureScope alloc] initWithDevice:commandQueue.device commandQueue:commandQueue];
}

- (void)startCaptureWithDevice:(id<MTLDevice>)device
{
}

- (void)startCaptureWithCommandQueue:(id<MTLCommandQueue>)commandQueue
{
}

- (void)startCaptureWithScope:(id<MTLCaptureScope>)captureScope
{
}

- (void)stopCapture
{
}

- (BOOL)isCapturing
{
    return NO;
}

@end
