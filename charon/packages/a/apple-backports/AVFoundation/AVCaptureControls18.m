// AVCaptureControls18.m - AVCaptureSession's controls API, in one object: the class AVCaptureControl and the
// category that adds the session's eleven members.
//
// ONE OBJECT, and that is the placement rule rather than a preference. Every name in here arrived in iOS
// 18 (the eleven session members are 18.0 in the header and in the caches, and tools/symbol-first-release.lua
// puts _OBJC_CLASS_$_AVCaptureControl at 18.0), so one object holds API of one release. What the split buys
// is the other half of the rule: modules/apple/backports.lua's band() keeps an object in a band when the
// band's release exports NONE of its symbols, and drops it (re-exporting what it does export) when the
// release exports all of them. So in every band from 18.0 up this object is left out and Apple's own class
// and Apple's own session answer - which is what they should answer there, on hardware that has
// CaptureControls - and in every band below it, starting at the floor, this object carries the whole
// surface. Splitting the class from the category would put the category in the 18.0 and later bands too,
// where it would REPLACE Apple's implementations of eleven methods with this port's, on hardware that has
// the feature.
//
// THE ORACLE for every answer below is this host's own AVFoundation, measured by
// tests/backports/host/avf-globals/controls.m (the answers are that probe's output line for line, against a
// freshly created AVCaptureSession):
//
//   -supportsControls                      0
//   -maxControlsCount                      0
//   -controls                              empty, of class __NSArray0, the same object every call
//   -controlsDelegate                      nil
//   -controlsDelegateCallbackQueue         nil
//   -canAddControl:nil                     0, no exception
//   -addControl:                           NSObjectInaccessibleException
//                                          "*** -[AVCaptureSession addControl:] Controls are not supported"
//   -removeControl:                        NSObjectInaccessibleException
//                                          "*** -[AVCaptureSession removeControl:] Controls are not supported"
//   -setControlsDelegate:queue:            NSObjectInaccessibleException
//                                          "*** -[AVCaptureSession setControlsDelegate:queue:] Controls are not supported"
//                                          in all four combinations of a conforming delegate, a nil delegate,
//                                          a serial queue and a NULL queue - so the header's own NULL-queue
//                                          rule (AVCaptureSession.h:381) is not observable on this release,
//                                          and this port does not invent a second error for it
//
// This Mac has no camera, which is why its answers are the answers of a device without CaptureControls, and
// that is the class of device this port builds for: 6.1.3's capture session (measured through
// tools/corpus/objc-inventory.lua on the 6.1.3 armv7 cache) answers NONE of the eleven selectors below, and
// CaptureControls are hardware that did not exist when that release's devices shipped. Apple's header says
// as much: "AVCaptureControls are only supported on platforms with necessary hardware" (AVCaptureSession.h:377).
//
// What the class carries, measured on the same host through the runtime: superclass NSObject, fifteen own
// instance methods, and NO own class methods and no own -init. So +[AVCaptureControl new] and
//-[AVCaptureControl init] are NSObject's on Apple's class too, and this port defines neither: the rows for
// them carry the inherited answer. -isEnabled and -setEnabled: are its own, and there is no -enabled, because
// the property is declared getter=isEnabled. Out of the 18.0 arm64e cache the same class owns sixteen
// selectors, of which those two are the API and the rest (-overlay, -installObservers, -initSubclass, ...)
// are Apple's machinery behind a control overlay this port does not draw; both lists are on the record in
// facts/AVFoundation/CaptureControls.md.
#import "CharonAVCaptureControls18.h"
// The protocol's own declaration. It is CharonAVFoundationProtocols.h's, because the generated protocol
// source modules/apple/backports.lua writes from the registry row imports that one and names this protocol
// with @protocol(...); a second declaration beside it would be a duplicate definition.
#import "CharonAVFoundationProtocols.h"
#import <objc/runtime.h>

// Apple's own reason, with the selector filled in: measured above, and the port raises the exception Apple
// raises rather than one of its own, because NSObjectInaccessibleException is what "this platform has no
// CaptureControls" is, and packages/a/apple-backports/CoreData/NSBatchInsertRequest.m already answers two of
// its own APIs this way. Static and used only in this file, so no other object has to link against it.
static void charon_controls_unsupported(NSString *selector)
{
    [NSException raise:NSObjectInaccessibleException
                format:@"*** -[AVCaptureSession %@] Controls are not supported", selector];
}

// Whether this session records through an audio session of its own. Measured on an iPad 2 running 6.1.3: it
// does, and leaves the application's audio session, its category, its options and its mode as they were (see
// AVCaptureSession+ApplicationAudioSession7.m and facts/AVFoundation/CaptureZoomAudioSession.md), which is
// why usesApplicationAudioSession answers NO there. The header says the mix-with-others flag "has no effect
// when usesApplicationAudioSession is set to NO" (AVCaptureSession.h:582), so it is kept and read back and
// nothing on this release reads it.
static const char charon_mixes_with_others_key;

@implementation AVCaptureControl {
    // The value the port holds, where Apple's class holds it too. It starts at NO, and the header's "the
    // default value is YES" is about a control made through one of the concrete factories
    // (+[AVCaptureSlider controlWithType:] and its siblings), which this port does not carry:
    // AVCaptureSlider, AVCaptureToggle and AVCaptureIndexPicker are 18.0 rows of their own. The only
    // instance of this class a caller can make here is through NSObject's inherited -init, which this header
    // marks AV_INIT_UNAVAILABLE exactly as 26.2 does.
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
    // The empty array is a singleton, so two calls answer the same object, which is what Apple's does.
    return [NSArray array];
}

- (BOOL)canAddControl:(AVCaptureControl *)control API_AVAILABLE(ios(18))
{
    // The header's own rule (AVCaptureSession.h:449): a control may be added only where this answers YES,
    // and "some platforms do not support controls". The two conditions it names are therefore this
    // implementation and not a constant: this session does not support controls (-supportsControls above,
    // measured NO on Apple's own class on hardware without the feature), and it has no room for one
    // (-maxControlsCount, 0). Both are NO here, and the answer for every control - measured 0 for nil as
    // well - falls out of the rule rather than being written down.
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