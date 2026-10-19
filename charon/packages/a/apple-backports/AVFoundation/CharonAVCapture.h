#import <AVFoundation/AVFoundation.h>

#define CHARON_DUAL_CAMERA_TYPE @"AVCaptureDeviceTypeBuiltInDualCamera"

// The -init of a class whose SDK header closes it, and +new with it, with AV_INIT_UNAVAILABLE, where the
// class's OWN metadata says the class implements -init and the measured answer is nil rather than a refusal.
//
// AV_INIT_UNAVAILABLE is a promise about source: expanding it declares - (instancetype)init NS_UNAVAILABLE and
// + (instancetype)new NS_UNAVAILABLE, and an unavailable redeclaration forces no definition, so the class's own
// metadata decides (the rule the coordinator settled, QUEUE 2026-10-03). MEASURED for the one class of this
// framework that needs it, AVCaptureDeviceDiscoverySession, through tools/corpus/objc-inventory.lua over the held
// caches - 10.0.1 arm64: own instance methods -_initWithDeviceTypes:mediaType:position:, -dealloc, -description,
// -devices, -init, and the metaclass's own list holds only +discoverySessionWithDeviceTypes:mediaType:position:;
// 12.0 and 16.0 arm64(e): -init is still its own, the metaclass still never lists +new - and through the host's own
// class at run time, where `[[AVCaptureDeviceDiscoverySession alloc] init]` answers nil and raises nothing.
//
// So -init is owed and answers nil, and +new is NOT owed: Apple's class does not implement it, every class
// inherits +[NSObject new] (measured: `new` is in NSObject's own metaclass list of 115 entries and not in this
// class's metaclass list of 16), and defining it in the port would put a selector in the port's metadata where
// Apple's class has none. tests/backports/host/unavailable-init holds both halves of this.
#define CHARON_AVFOUNDATION_UNAVAILABLE_INIT                                                                   \
    -(instancetype)init                                                                                       \
    {                                                                                                         \
        /* Measured: nil, with no exception. See the comment above: the release's answer for the                 \
           initialiser its own header closes with AV_INIT_UNAVAILABLE is nil, and the session an                  \
           application can use comes from +discoverySessionWithDeviceTypes:mediaType:position:. */             \
        return nil;                                                                                           \
    }

NSArray *charon_capture_devices(NSArray *deviceTypes, NSString *mediaType, AVCaptureDevicePosition position);

// Posted, with the session as its object, after a capture session gains an input or an output, starts
// running or commits a configuration, and after a preview layer is given the session.
#define CHARON_CAPTURE_SESSION_CHANGED @"CharonCaptureSessionChanged"

@interface AVCaptureDevice (CharonCaptureSessions)
// The sessions an input of this device was added to, held weakly.
- (NSArray<AVCaptureSession *> *)charon_captureSessions;
@end

@interface AVCaptureSession (CharonCaptureSessions)
// The preview layers given this session, held weakly.
- (NSArray<AVCaptureVideoPreviewLayer *> *)charon_previewLayers;
@end
