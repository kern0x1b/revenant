#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

// Rank 6 of coordination/corpus/crash-demand-top.tsv, LOAD-FAIL for telegram and provenance: a
// hard, non-weak reference to this class name kills the application at launch, not merely on
// first use. AVMetadataObject itself is real on iOS 6.1.3 already - AVMetadataFaceObject ships
// with the release's own face detection - so this is an ordinary subclass of a real class, not a
// bridge over a private one; no name collision (confirmed against the armv7 shared cache of
// 6.1.3 with apple.objc.inventory() before writing a line of this file).
//
// AVCaptureMetadataOutput, the class that would actually produce one of these from a live camera
// feed, does not exist on this release and is not part of this row - carrying it is separate,
// larger work this row does not claim. What this class answers today: any code path that names
// AVMetadataMachineReadableCodeObject at compile time - an isKindOfClass: check, an import, a
// category - no longer kills the process at launch for referencing a symbol that is not there.
@interface AVMetadataMachineReadableCodeObject ()
@property (nonatomic, copy) NSString *charonStringValue;
@property (nonatomic, copy) NSArray<NSDictionary *> *charonCorners;
@end

@implementation AVMetadataMachineReadableCodeObject

@synthesize charonStringValue = _charonStringValue;
@synthesize charonCorners = _charonCorners;

// Not Apple's own designated initializer - AVFoundation's real capture pipeline builds these
// through its own private path this port does not reach. This is this port's own, for whatever
// constructs one directly rather than receiving it from AVCaptureMetadataOutput's delegate.
- (instancetype)initWithStringValue:(NSString *)stringValue corners:(NSArray<NSDictionary *> *)corners
{
    // AVMetadataObject's header marks -init NS_UNAVAILABLE to steer callers toward Apple's own
    // capture-pipeline factory, which this port does not reach - not a runtime restriction, so
    // the real -init is still what a plain objc_msgSend reaches here.
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _charonStringValue = [stringValue copy];
        _charonCorners = [corners copy] ?: @[];
    }
    return self;
}

- (NSString *)stringValue
{
    return self.charonStringValue;
}

- (NSArray<NSDictionary *> *)corners
{
    return self.charonCorners ?: @[];
}

@end
