#import <DeviceCheck/DeviceCheck.h>
#import <ARKit/ARKit.h>
#import <CoreNFC/CoreNFC.h>
#import <objc/runtime.h>
#import "check.h"

static NSString *bare(NSString *name)
{
    return [name stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
}

static Class port(NSString *name)
{
    Class found = NSClassFromString([@"CharonHost" stringByAppendingString:name]);
    CHECK(found != Nil, [[name stringByAppendingString:@" is carried"] UTF8String]);
    return found;
}

static void same_class(Class ours, Class theirs)
{
    NSString *what = NSStringFromClass(theirs);
    CHECK_EQUAL(bare(NSStringFromClass([ours superclass])), NSStringFromClass([theirs superclass]),
                [[what stringByAppendingString:@" has the release's superclass"] UTF8String]);
}

extern NSString *const CharonHostDCErrorDomain, *const CharonHostARErrorDomain, *const CharonHostARReferenceObjectArchiveExtension, *const CharonHostNFCErrorDomain;

static void device_check(void)
{
    Class mine = port(@"DCDevice");
    id ours = [mine currentDevice];
    CHECK(ours != nil && ours == [mine currentDevice], "DCDevice.currentDevice is one shared object");
    CHECK(DCDevice.currentDevice == DCDevice.currentDevice, "the host's DCDevice.currentDevice is one shared object");
    CHECK_EQUAL(@([ours isSupported]), @([DCDevice.currentDevice isSupported]), "-isSupported answers what DeviceCheck answers");
    CHECK([ours isSupported], "-isSupported answers YES, which no release ever answered otherwise");
    CHECK_EQUAL(CharonHostDCErrorDomain, DCErrorDomain, "DCErrorDomain is DeviceCheck's string");
    same_class(mine, [DCDevice class]);
}

static void augmented_reality(void)
{
    NSDictionary *pairs = @{@"ARConfiguration": [ARConfiguration class], @"ARWorldTrackingConfiguration": [ARWorldTrackingConfiguration class],
                            @"AROrientationTrackingConfiguration": [AROrientationTrackingConfiguration class],
                            @"ARFaceTrackingConfiguration": [ARFaceTrackingConfiguration class],
                            @"ARImageTrackingConfiguration": [ARImageTrackingConfiguration class],
                            @"ARObjectScanningConfiguration": [ARObjectScanningConfiguration class]};
    for (NSString *name in [pairs.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        Class ours = port(name), theirs = pairs[name];
        NSString *label = [name stringByAppendingString:@".isSupported answers what ARKit answers"];
        CHECK_EQUAL(@([ours isSupported]), @([theirs isSupported]), label.UTF8String);
        CHECK(![ours isSupported], [[name stringByAppendingString:@".isSupported is NO"] UTF8String]);
        same_class(ours, theirs);
    }
    CHECK_EQUAL(CharonHostARErrorDomain, ARErrorDomain, "ARErrorDomain is ARKit's string");
    CHECK_EQUAL(CharonHostARReferenceObjectArchiveExtension, ARReferenceObjectArchiveExtension,
                "ARReferenceObjectArchiveExtension is ARKit's string");
    Class world = port(@"ARWorldTrackingConfiguration");
    id copy = [[[world alloc] init] copy];
    CHECK([copy isKindOfClass:world] && [copy class] == world, "a copy of a configuration is one of the same class");
}

static void tag_reading(void)
{
    Class base = port(@"NFCReaderSession"), ndef = port(@"NFCNDEFReaderSession");
    CHECK_EQUAL(@([base readingAvailable]), @([NFCReaderSession readingAvailable]), "NFCReaderSession.readingAvailable answers what CoreNFC answers");
    CHECK_EQUAL(@([ndef readingAvailable]), @([NFCNDEFReaderSession readingAvailable]), "NFCNDEFReaderSession.readingAvailable answers what CoreNFC answers");
    CHECK(![base readingAvailable] && ![ndef readingAvailable], "reading is not available");
    same_class(base, [NFCReaderSession class]);
    same_class(ndef, [NFCNDEFReaderSession class]);
    CHECK([ndef superclass] == base, "NFCNDEFReaderSession is a subclass of NFCReaderSession");
    CHECK_EQUAL(CharonHostNFCErrorDomain, NFCErrorDomain, "NFCErrorDomain is CoreNFC's string");
}

static void absences(void)
{
    Class world = port(@"ARWorldTrackingConfiguration"), base = port(@"ARConfiguration");
    for (NSString *name in @[@"planeDetection", @"detectionImages", @"environmentTexturing", @"initialWorldMap", @"detectionObjects", @"autoFocusEnabled"])
        CHECK(![world instancesRespondToSelector:NSSelectorFromString(name)], [[name stringByAppendingString:@" is absent from a world tracking configuration"] UTF8String]);
    for (NSString *name in @[@"worldAlignment", @"videoFormat", @"lightEstimationEnabled", @"providesAudioData"])
        CHECK(![base instancesRespondToSelector:NSSelectorFromString(name)], [[name stringByAppendingString:@" is absent from a configuration"] UTF8String]);
    Class nfc = port(@"NFCReaderSession");
    for (NSString *name in @[@"beginSession", @"invalidateSession", @"delegate", @"sessionQueue", @"alertMessage"])
        CHECK_EQUAL(@([nfc instancesRespondToSelector:NSSelectorFromString(name)]), @([NFCReaderSession instancesRespondToSelector:NSSelectorFromString(name)]), [[name stringByAppendingString:@" is answered by a reader session as CoreNFC answers it"] UTF8String]);
    CHECK_EQUAL(@([port(@"NFCNDEFReaderSession") instancesRespondToSelector:@selector(initWithDelegate:queue:invalidateAfterFirstRead:)]), @([NFCNDEFReaderSession instancesRespondToSelector:@selector(initWithDelegate:queue:invalidateAfterFirstRead:)]), "a session is made by its initializer as CoreNFC makes it");
}

int main(void)
{
    @autoreleasepool {
        device_check();
        augmented_reality();
        tag_reading();
        absences();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
