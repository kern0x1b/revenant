#import "CharonAVCaptureControls18.h"
#import "CharonAVFoundationProtocols.h"
#import <objc/runtime.h>

static void charon_controls_unsupported(NSString *selector)
{
    [NSException raise:NSObjectInaccessibleException
                format:@"*** -[AVCaptureSession %@] Controls are not supported", selector];
}

static const char charon_mixes_with_others_key;

@implementation AVCaptureControl {
    BOOL _enabled;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

@end

@implementation AVCaptureSession (CharonCaptureControls18)

- (BOOL)supportsControls
{
    return NO;
}

- (NSInteger)maxControlsCount
{
    return 0;
}

- (NSArray<__kindof AVCaptureControl *> *)controls API_AVAILABLE(ios(18))
{
    return [NSArray array];
}

- (BOOL)canAddControl:(AVCaptureControl *)control API_AVAILABLE(ios(18))
{
    if (!control || !self.supportsControls) {
        return NO;
    }
    return self.controls.count < (NSUInteger)self.maxControlsCount;
}

- (void)addControl:(AVCaptureControl *)control API_AVAILABLE(ios(18))
{
    charon_controls_unsupported(@"addControl:");
}

- (void)removeControl:(AVCaptureControl *)control API_AVAILABLE(ios(18))
{
    charon_controls_unsupported(@"removeControl:");
}

- (void)setControlsDelegate:(id<AVCaptureSessionControlsDelegate>)controlsDelegate
                      queue:(dispatch_queue_t)controlsDelegateCallbackQueue
{
    charon_controls_unsupported(@"setControlsDelegate:queue:");
}

- (id<AVCaptureSessionControlsDelegate>)controlsDelegate
{
    return nil;
}

- (dispatch_queue_t)controlsDelegateCallbackQueue
{
    return nil;
}

- (BOOL)configuresApplicationAudioSessionToMixWithOthers
{
    NSNumber *mixes = objc_getAssociatedObject(self, &charon_mixes_with_others_key);
    return mixes ? mixes.boolValue : NO;
}

- (void)setConfiguresApplicationAudioSessionToMixWithOthers:(BOOL)mixes
{
    objc_setAssociatedObject(self, &charon_mixes_with_others_key, @(mixes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
