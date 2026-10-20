#import "RevenantAVCaptureDeferredStart26.h"
#import "../RevenantProgramSDK.h"

static void revenant_deferred_start_unsupported(NSString *selector)
{
    [NSException raise:NSObjectInaccessibleException
                format:@"*** -[AVCaptureSession %@] Deferred start not supported", selector];
}

@implementation AVCaptureSession (RevenantCaptureDeferredStart26)

- (BOOL)isManualDeferredStartSupported
{
    return NO;
}

- (BOOL)automaticallyRunsDeferredStart
{
    return revenant_program_linked_on_or_after(26.0, 0);
}

- (void)setAutomaticallyRunsDeferredStart:(BOOL)automaticallyRunsDeferredStart
{
    if (!automaticallyRunsDeferredStart) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVCaptureSession %@] manualDeferredStartSupported is false, so the deferred"
                           @" start cannot be run by hand",
                           NSStringFromSelector(_cmd)];
        return;
    }
}

- (id<AVCaptureSessionDeferredStartDelegate>)deferredStartDelegate
{
    return nil;
}

- (dispatch_queue_t)deferredStartDelegateCallbackQueue
{
    return nil;
}

- (void)setDeferredStartDelegate:(id<AVCaptureSessionDeferredStartDelegate>)deferredStartDelegate
  deferredStartDelegateCallbackQueue:(dispatch_queue_t)deferredStartDelegateCallbackQueue
{
    revenant_deferred_start_unsupported(@"setDeferredStartDelegate:deferredStartDelegateCallbackQueue:");
}

- (void)runDeferredStartWhenNeeded
{
    revenant_deferred_start_unsupported(@"runDeferredStartWhenNeeded");
}

@end

@implementation AVCaptureOutput (RevenantCaptureDeferredStart26)

- (BOOL)isDeferredStartSupported
{
    return NO;
}

- (BOOL)isDeferredStartEnabled
{
    if (!revenant_program_linked_on_or_after(26.0, 0))
        return NO;
    if (!self.isDeferredStartSupported)
        return NO;
    return [self isKindOfClass:[AVCapturePhotoOutput class]];
}

- (void)setDeferredStartEnabled:(BOOL)deferredStartEnabled
{
    if (!deferredStartEnabled)
        return;
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureOutput %@] Not supported by this device", NSStringFromSelector(_cmd)];
}

@end

@implementation AVCaptureVideoPreviewLayer (RevenantCaptureDeferredStart26)

- (BOOL)isDeferredStartSupported
{
    return NO;
}

- (BOOL)isDeferredStartEnabled
{
    return NO;
}

- (void)setDeferredStartEnabled:(BOOL)deferredStartEnabled
{
    if (!deferredStartEnabled)
        return;
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureVideoPreviewLayer %@] deferredStartSupported is false, so the preview"
                       @" layer's start cannot be deferred",
                           NSStringFromSelector(_cmd)];
}

@end
