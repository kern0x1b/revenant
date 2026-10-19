// AVCaptureDeferredStart26.m - the deferred-start surface of iOS 26 over the three classes it belongs to.
//
// WHAT DEFERRED START IS, and why this release has none of it. The 26.2 header describes it at
// AVCaptureSession.h:671 as a per-output choice of when an output starts, relative to the session's start, which
// AVCaptureOutput/deferredStartEnabled sets. It is a STARTUP-LATENCY feature: the session holds
// an output's resources back so an application can put its interface up first. 6.1.3's capture session has no
// member of any kind for it - measured, tools/corpus/objc-inventory.lua over the 6.1.3 armv7 cache: its
// AVCaptureSession owns none of the five selectors here and no deferred-start member at all - so this object is
// four categories on three classes the release already carries, and every answer is the header's own answer for a
// release that cannot defer anything.
//
// THE SESSION. The whole surface refuses, and the host's own class refuses it the same way, which is what makes
// this the same shape as the controls family (facts/AVFoundation/CaptureControls.md):
//
//   -setDeferredStartDelegate:deferredStartDelegateCallbackQueue:   NSObjectInaccessibleException
//       *** -[AVCaptureSession setDeferredStartDelegate:deferredStartDelegateCallbackQueue:] Deferred start not supported
//   -runDeferredStartWhenNeeded                                     NSObjectInaccessibleException
//       *** -[AVCaptureSession runDeferredStartWhenNeeded] Deferred start not supported
//
// Both measured on this host, and both character for character (the class in each prefix is the port's own class,
// so nothing is swapped). The order was measured too: the host raises this refusal for a delegate AND a real
// queue exactly as it does for a delegate and a NULL one, so the header's own "If deferredStartDelegate is not
// NULL, the session throws an exception if deferredStartDelegateCallbackQueue is nil" (:719) is never reached on a
// release that cannot defer anything, and the port does not add a second error for a case Apple never reaches -
// the same decision CaptureControls.md records for its NULL-queue rule.
//
// -isManualDeferredStartSupported   NO: there is nothing to run manually, and the header's rule for the property
//                                   beside it is the same: the header (:673) lets automaticallyRunsDeferredStart be made false
//                                   only where the session can start a deferred capture by hand.
// -automaticallyRunsDeferredStart   YES, the header's own default for the release an application links against
//                                   (:685 gives true for an app linked against iOS 26 or later). Measured on the host: 0, and that is macOS's own default rather than
//                                   this rule's, so the two columns differ and the row says why.
// -setAutomaticallyRunsDeferredStart:   YES is kept; NO refuses with NSInvalidArgumentException, which the header names
//                                   for a session without manual deferred start support (:686).
//                                   MEASURED DIVERGENCE, named: the host's own session ACCEPTS NO and stays
//                                   at 0, so here the port follows the header and not the host, which is the
//                                   same call the coordinator accepted for the locked-frame-duration setter.
// -deferredStartDelegate, ...CallbackQueue    nil, nil: nothing can be set, so there is no delegate and no queue,
//                                   and nothing is stored (a setter that refuses every value has no last accepted
//                                   one).
//
// THE OUTPUT AND THE PREVIEW LAYER. Both answer NO for their support flag - the release has nothing to defer -
// and the two flags answer NO, which is each header's own default: the output's flag is true by default for an app linked against
// iOS 26 or later where supported, and false otherwise (AVCaptureOutputBase.h:129); the preview layer's is false because it displays
// preview (AVCaptureVideoPreviewLayer.h:271). Setting YES refuses with NSInvalidArgumentException, which both headers name for an
// object without deferred start support (AVCaptureOutputBase.h:128, AVCaptureVideoPreviewLayer.h:275).
//
// TWO MORE MEASURED DIVERGENCES from the host, both named on their rows and both followed by the header here:
//   -setDeferredStartEnabled: on an OUTPUT raises on the host with Apple's own reason, "*** -
//   [AVCaptureVideoDataOutput setDeferredStartEnabled:] Not supported by this device" - and the port raises the
//   same tail with its own class (AVCaptureOutput, the class the header declares the property on; Apple's names
//   its concrete subclass).
//   -setDeferredStartEnabled: on a PREVIEW LAYER is ACCEPTED by the host, which reports deferredStartSupported
//   NO and then answers YES to the same value (measured, the getter reads 1 afterwards) - while the header says
//   the session throws. The port refuses.
#import "CharonAVCaptureDeferredStart26.h"
#import "../CharonProgramSDK.h"

// Where the port keeps the two values it can accept: the session's automaticallyRunsDeferredStart (which can only
// be YES here, and the default is YES, so this exists for symmetry with the rule rather than for a value) - no:
// nothing is stored at all. Every setter below either keeps the header's only documented value or refuses, so
// there is no associated object and no key in this file. That is stated here because a reader looking for the
// storage of deferredStartDelegate should be told where it is: nowhere, and why.

// Apple's own reason for the whole feature being absent, measured on this host character for character.
static void charon_deferred_start_unsupported(NSString *selector)
{
    [NSException raise:NSObjectInaccessibleException
                format:@"*** -[AVCaptureSession %@] Deferred start not supported", selector];
}

@implementation AVCaptureSession (CharonCaptureDeferredStart26)

- (BOOL)isManualDeferredStartSupported
{
    return NO;
}

- (BOOL)automaticallyRunsDeferredStart
{
    // The header gives true as the default for an app linked against iOS 26 or later (:685). The condition is
    // about the APPLICATION, not about this port, so it is READ from the main executable's own load command
    // (packages/a/apple-backports/CharonProgramSDK.h): every band of this repository links against SDK 16.4,
    // which is the sdk field of the binary, and so every band here answers NO - the value the same header
    // gives an application linked before 26, since the sentence names no default for that case and the
    // property's own default before 26 is the one that does not defer anything. An application linked against
    // 26 or later against THIS library would read YES, because its own load command says so.
    //
    // The same read governs the two deferredStartEnabled defaults below, so all three of the header's
    // linked-on-or-after defaults are decided by one fact read one way. Nothing is stored: the setter accepts
    // the value the condition gives and refuses the other, so there is no last accepted one.
    return charon_program_linked_on_or_after(26.0, 0);
}

- (void)setAutomaticallyRunsDeferredStart:(BOOL)automaticallyRunsDeferredStart
{
    // The header's own note (:686): setting it to false needs manual deferred start, and this release has none.
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
    // Refused for the whole feature, in the order measured on the host: the refusal for "deferred start not
    // supported" comes first, for a delegate with a real queue exactly as for one with a NULL queue, so the
    // header's own NULL-queue rule (:719) is never reached here and the port does not invent a second error.
    charon_deferred_start_unsupported(@"setDeferredStartDelegate:deferredStartDelegateCallbackQueue:");
}

- (void)runDeferredStartWhenNeeded
{
    charon_deferred_start_unsupported(@"runDeferredStartWhenNeeded");
}

@end

@implementation AVCaptureOutput (CharonCaptureDeferredStart26)

- (BOOL)isDeferredStartSupported
{
    return NO;
}

- (BOOL)isDeferredStartEnabled
{
    // The header's own sentence needs three things at once (AVCaptureOutputBase.h:126): for an app linked against iOS 26 or later,
    // the property is true for AVCapturePhotoOutput and AVCaptureFileOutput subclasses where supported, and false otherwise.
    // The first is read the same way as the
    // session's default above - one fact, one read - and the second is NO for every output on this port, so
    // the answer is false in EITHER reading of the first, which is what "and false otherwise" says. All three
    // terms are written because the header's rule has three.
    if (!charon_program_linked_on_or_after(26.0, 0))
        return NO;
    if (!self.isDeferredStartSupported)
        return NO;
    return [self isKindOfClass:[AVCapturePhotoOutput class]];
}

- (void)setDeferredStartEnabled:(BOOL)deferredStartEnabled
{
    // The header's own rule (AVCaptureOutputBase.h:128), with Apple's own reason for it measured on this host
    // against its own concrete subclass: "*** -[AVCaptureVideoDataOutput setDeferredStartEnabled:] Not
    // supported by this device". The tail is Apple's character for character and the class is this port's own,
    // because the header declares the property on AVCaptureOutput.
    if (!deferredStartEnabled)
        return;
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureOutput %@] Not supported by this device", NSStringFromSelector(_cmd)];
}

@end

@implementation AVCaptureVideoPreviewLayer (CharonCaptureDeferredStart26)

- (BOOL)isDeferredStartSupported
{
    return NO;
}

- (BOOL)isDeferredStartEnabled
{
    // The preview layer's own default is false, because the object is used to display preview (AVCaptureVideoPreviewLayer.h:271).
    // This one has NO linked-on-or-after clause of its
    // own, so the read above does not decide it and the answer is false in both readings; it is asked in both
    // builds anyway, so a header that grew the clause later would be caught here rather than pass unnoticed.
    return NO;
}

- (void)setDeferredStartEnabled:(BOOL)deferredStartEnabled
{
    // The same header rule for the preview layer (AVCaptureVideoPreviewLayer.h:275), which the host's own layer
    // does not enforce: it reports deferredStartSupported NO and accepts YES (measured, the getter reads 1
    // afterwards). The port follows the header, and the row carries both columns.
    if (!deferredStartEnabled)
        return;
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureVideoPreviewLayer %@] deferredStartSupported is false, so the preview"
                       @" layer's start cannot be deferred",
                           NSStringFromSelector(_cmd)];
}

@end
