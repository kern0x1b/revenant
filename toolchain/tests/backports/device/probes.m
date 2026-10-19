#import <DeviceCheck/DeviceCheck.h>
#import <ARKit/ARConfiguration.h>
#import <ARKit/ARError.h>
#import <ARKit/ARReferenceObject.h>
#import <CoreNFC/CoreNFC.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"

static NSString *image_of_class(Class class)
{
    Dl_info info;
    void *address = (__bridge void *)class;
    if (!address || !dladdr(address, &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static NSString *image_of_method(Class class, SEL selector, BOOL classMethod)
{
    Method method = classMethod ? class_getClassMethod(class, selector) : class_getInstanceMethod(class, selector);
    Dl_info info;
    if (!method || !dladdr((void *)method_getImplementation(method), &info) || !info.dli_fname)
        return @"<missing>";
    return @(info.dli_fname).lastPathComponent;
}

static void carried(NSString *name, BOOL *present)
{
    Class found = NSClassFromString(name);
    CHECK(found != Nil, [[name stringByAppendingString:@" is there"] UTF8String]);
    if (present)
        *present = found != Nil;
}

static void device_check(void)
{
    NSString *library = @"libFoundationBackports.dylib";
    BOOL present = NO;
    carried(@"DCDevice", &present);
    if (!present)
        return;
    CHECK_EQUAL(image_of_method([DCDevice class], @selector(isSupported), NO), library, "-[DCDevice isSupported] comes from the backports");
    CHECK_EQUAL(image_of_method([DCDevice class], @selector(generateTokenWithCompletionHandler:), NO), library,
                "-[DCDevice generateTokenWithCompletionHandler:] comes from the backports");
    DCDevice *device = DCDevice.currentDevice;
    CHECK(device != nil && device == DCDevice.currentDevice, "+currentDevice answers one shared object");
    CHECK(device.isSupported, "-isSupported answers YES, as the release does");
    CHECK_EQUAL(DCErrorDomain, @"com.apple.devicecheck.error", "DCErrorDomain is the release's string");
    CHECK(DCErrorFeatureUnsupported == 1 && DCErrorUnknownSystemFailure == 0 && DCErrorServerUnavailable == 4, "the codes are the header's");

    __block NSData *token = (NSData *)@"unset";
    __block NSError *error = nil;
    __block BOOL onMain = YES;
    __block BOOL called = NO;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [device generateTokenWithCompletionHandler:^(NSData *data, NSError *failure) {
        token = data;
        error = failure;
        onMain = [NSThread isMainThread];
        called = YES;
        dispatch_semaphore_signal(done);
    }];
    CHECK(!called, "the handler is not called before -generateTokenWithCompletionHandler: has returned");
    CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0, "the handler is called");
    CHECK(token == nil, "the handler hears no token");
    CHECK_EQUAL(error.domain, @"com.apple.devicecheck.error", "the error is in the DeviceCheck domain");
    CHECK(error.code == DCErrorFeatureUnsupported, "the error is DCErrorFeatureUnsupported");
    CHECK(error.userInfo.count == 0, "the error carries no user info");
    CHECK(!onMain, "the handler is called from a background queue");
    [device generateTokenWithCompletionHandler:nil];
    CHECK(YES, "a nil handler is ignored");
}

static void augmented_reality(void)
{
    NSString *library = @"libFoundationBackports.dylib";
    NSArray *names = @[@"ARConfiguration", @"ARWorldTrackingConfiguration", @"AROrientationTrackingConfiguration", @"ARFaceTrackingConfiguration",
                       @"ARImageTrackingConfiguration", @"ARObjectScanningConfiguration"];
    for (NSString *name in names) {
        BOOL present = NO;
        carried(name, &present);
        if (!present)
            continue;
        Class class = NSClassFromString(name);
        CHECK_EQUAL(image_of_class(class), library, [[name stringByAppendingString:@" comes from the backports"] UTF8String]);
        CHECK(![class isSupported], [[name stringByAppendingString:@".isSupported is NO"] UTF8String]);
        if (![name isEqualToString:@"ARConfiguration"])
            CHECK([class superclass] == [ARConfiguration class], [[name stringByAppendingString:@" is a subclass of ARConfiguration"] UTF8String]);
    }
    CHECK_EQUAL([ARConfiguration superclass], [NSObject class], "ARConfiguration is a subclass of NSObject");
    CHECK_EQUAL(ARErrorDomain, @"com.apple.arkit.error", "ARErrorDomain is the release's string");
    CHECK_EQUAL(ARReferenceObjectArchiveExtension, @"arobject", "ARReferenceObjectArchiveExtension is the release's string");
    ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
    id copy = [configuration copy];
    CHECK(copy != nil && copy != configuration && [copy class] == [ARWorldTrackingConfiguration class], "a copy is a new object of the same class");
    for (NSString *name in @[@"planeDetection", @"detectionImages", @"environmentTexturing", @"initialWorldMap", @"detectionObjects", @"worldAlignment", @"videoFormat"])
        CHECK(![configuration respondsToSelector:NSSelectorFromString(name)], [[name stringByAppendingString:@" is absent from a configuration"] UTF8String]);
    for (NSString *name in @[@"ARSession", @"ARFrame", @"ARAnchor", @"ARSCNView", @"ARSKView", @"ARReferenceImage", @"ARWorldMap"])
        CHECK(NSClassFromString(name) == Nil, [[name stringByAppendingString:@" is absent"] UTF8String]);
}

static void tag_reading(void)
{
    NSString *library = @"libFoundationBackports.dylib";
    BOOL present = NO;
    carried(@"NFCReaderSession", &present);
    carried(@"NFCNDEFReaderSession", NULL);
    if (!present)
        return;
    CHECK_EQUAL(image_of_method(object_getClass([NFCReaderSession class]), @selector(readingAvailable), NO), library,
                "+[NFCReaderSession readingAvailable] comes from the backports");
    CHECK(![NFCReaderSession readingAvailable], "NFCReaderSession.readingAvailable is NO");
    CHECK(![NFCNDEFReaderSession readingAvailable], "NFCNDEFReaderSession.readingAvailable is NO");
    CHECK([NFCNDEFReaderSession superclass] == [NFCReaderSession class], "NFCNDEFReaderSession is a subclass of NFCReaderSession");
    CHECK([NFCReaderSession conformsToProtocol:@protocol(NFCReaderSession)], "NFCReaderSession adopts its protocol");
    CHECK_EQUAL(NFCErrorDomain, @"NFCError", "NFCErrorDomain is CoreNFC's string");
    for (NSString *name in @[@"beginSession", @"invalidateSession", @"delegate", @"sessionQueue", @"alertMessage"])
        CHECK(![NFCReaderSession instancesRespondToSelector:NSSelectorFromString(name)], [[name stringByAppendingString:@" is absent from a reader session"] UTF8String]);
    CHECK(![NFCNDEFReaderSession instancesRespondToSelector:@selector(initWithDelegate:queue:invalidateAfterFirstRead:)], "a session cannot be made");
    for (NSString *name in @[@"NFCNDEFMessage", @"NFCNDEFPayload"])
        CHECK(NSClassFromString(name) == Nil, [[name stringByAppendingString:@" is absent"] UTF8String]);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        device_check();
        augmented_reality();
        tag_reading();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
