#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <Vision/Vision.h>
#include <dlfcn.h>
#import "check.h"
#import "vision-cases.h"
#import "vision-expectations.h"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static CGImageRef white_image(void)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 64, 64, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 64, 64));
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return image;
}

static BOOL close_enough(NSString *expected, NSString *actual, double tolerance)
{
    if (!actual)
        return NO;
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"; ,"];
    NSArray *left = [expected componentsSeparatedByCharactersInSet:separators];
    NSArray *right = [actual componentsSeparatedByCharactersInSet:separators];
    if (left.count != right.count)
        return NO;
    for (NSUInteger index = 0; index < left.count; index++) {
        const char *a = [left[index] UTF8String], *b = [right[index] UTF8String];
        char *endA = NULL, *endB = NULL;
        double x = strtod(a, &endA), y = strtod(b, &endB);
        BOOL numeric = *a && !*endA && *b && !*endB;
        if (numeric ? fabs(x - y) > tolerance : ![left[index] isEqualToString:right[index]])
            return NO;
    }
    return YES;
}

static void compare(void)
{
    NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:vision_expectations length:strlen(vision_expectations)] options:0 error:NULL];
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    vision_run(^(NSString *name, NSString *value) { records[name] = value; });
    for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        BOOL floats = [name isEqualToString:@"geometry"] || [name isEqualToString:@"faces"];
        if (floats ? close_enough(expected[name], records[name], 0.001) : [expected[name] isEqualToString:records[name]])
            charon_check(YES, name.UTF8String, nil);
        else
            charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
    }
    CHECK(records.count == expected.count, "the device answers every record the host did and no other");
}

static void release_values(void)
{
    CHECK_EQUAL(VNErrorDomain, @"com.apple.vis", "the error domain of iOS 12");
    CHECK(VNVisionVersionNumber == 2.0, "the version number of Vision in iOS 12");
    CHECK_EQUAL(image_of([VNRequest class]), @"libVisionBackports.dylib", "VNRequest comes from the backports");
    CHECK_EQUAL(image_of([VNImageRequestHandler class]), @"libVisionBackports.dylib", "VNImageRequestHandler comes from the backports");
    CHECK([[VNDetectFaceRectanglesRequest supportedRevisions] isEqualToIndexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)]], "the face rectangles request has revisions 1 and 2");
    CHECK([VNDetectFaceRectanglesRequest defaultRevision] == 2 && [VNDetectFaceRectanglesRequest currentRevision] == 2, "and takes the latest by default");
    CHECK([[VNDetectRectanglesRequest supportedRevisions] isEqualToIndexSet:[NSIndexSet indexSetWithIndex:1]] && [VNDetectRectanglesRequest defaultRevision] == 1, "the rectangles request has revision 1");
    CHECK([[VNTrackObjectRequest supportedRevisions] isEqualToIndexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)]], "the object tracking request has revisions 1 and 2");
    CHECK([[VNDetectFaceRectanglesRequest alloc] init].revision == 2, "a new request takes its class's default revision");

    CGRect box = CGRectMake(0.1, 0.2, 0.3, 0.4);
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@0 yaw:@0] != nil, "a face observation of roll and yaw in range is made");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:nil yaw:@0] == nil, "one with no roll is nil");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@0 yaw:nil] == nil, "one with no yaw is nil");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@(-3.14159) yaw:@(-1.5707)] != nil, "the lowest roll and yaw are in range");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@(-M_PI) yaw:@0] == nil, "minus pi as a double is under minus pi as the float the check reads");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@(M_PI) yaw:@0] == nil, "a roll of pi is not");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@(-4) yaw:@0] == nil, "nor a roll under minus pi");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@0 yaw:@(M_PI_2)] == nil, "nor a yaw of half a pi");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@0 yaw:@(-2)] == nil, "nor a yaw under minus half a pi");
    CHECK([VNFaceObservation faceObservationWithRequestRevision:1 boundingBox:box roll:@3.0 yaw:@1.5] != nil, "the highest values under the limits are in range");
}

static void performing(void)
{
    CGImageRef image = white_image();
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image options:@{}];
    __block int called = 0;
    __block NSError *given = nil;
    VNDetectRectanglesRequest *rectangles = [[VNDetectRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {
        called++;
        given = error;
    }];
    NSError *error = nil;
    BOOL ok = [handler performRequests:@[rectangles] error:&error];
    CHECK(!ok, "a request the port cannot run makes performRequests fail");
    CHECK_EQUAL(error.domain, VNErrorDomain, "in the domain of Vision");
    CHECK(error.code == VNErrorNotImplemented, "with the code for a function that is not implemented");
    CHECK(error.localizedDescription.length > 0, "and a description");
    CHECK(called == 1 && [given isEqual:error], "the completion handler is called once with that error");
    CHECK(rectangles.results == nil, "and the request has no results");

    VNDetectRectanglesRequest *first = [[VNDetectRectanglesRequest alloc] init];
    VNDetectFaceRectanglesRequest *second = [[VNDetectFaceRectanglesRequest alloc] init];
    second.revision = 99;
    error = nil;
    ok = [handler performRequests:@[first, second] error:&error];
    CHECK(!ok && error.code == VNErrorNotImplemented, "the error given is that of the first request that failed");
    error = nil;
    ok = [handler performRequests:@[second] error:&error];
    CHECK(!ok && error.code == VNErrorUnsupportedRevision, "a revision the class does not have fails as unsupported");

    VNCoreMLRequest *coreml = [[VNCoreMLRequest alloc] initWithModel:nil];
    error = nil;
    ok = [handler performRequests:@[coreml] error:&error];
    CHECK(!ok && error.code == VNErrorInvalidModel, "a Core ML request with no model fails as an invalid model");
    error = nil;
    VNCoreMLModel *model = [VNCoreMLModel modelForMLModel:nil error:&error];
    CHECK(model == nil && error.code == VNErrorInvalidModel, "a Core ML model cannot be made, for the release has no Core ML");

    VNSequenceRequestHandler *sequence = [[VNSequenceRequestHandler alloc] init];
    CIImage *ci = [CIImage imageWithCGImage:image];
    NSURL *url = [NSURL fileURLWithPath:@"/private/var/tmp/none.png"];
    NSData *data = [NSData dataWithBytes:"x" length:1];
    NSArray *requests = @[[[VNDetectHorizonRequest alloc] init]];
    int failures = 0;
    NSArray<NSNumber *> *results = @[
        @([sequence performRequests:requests onCGImage:image error:NULL]), @([sequence performRequests:requests onCGImage:image orientation:kCGImagePropertyOrientationRight error:NULL]),
        @([sequence performRequests:requests onCIImage:ci error:NULL]), @([sequence performRequests:requests onCIImage:ci orientation:kCGImagePropertyOrientationDown error:NULL]),
        @([sequence performRequests:requests onImageURL:url error:NULL]), @([sequence performRequests:requests onImageURL:url orientation:kCGImagePropertyOrientationUp error:NULL]),
        @([sequence performRequests:requests onImageData:data error:NULL]), @([sequence performRequests:requests onImageData:data orientation:kCGImagePropertyOrientationLeft error:NULL]),
    ];
    for (NSNumber *value in results)
        if (value.boolValue)
            failures++;
    CHECK(failures == 0, "every entry of the sequence handler fails a request the port cannot run");

    CVPixelBufferRef buffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, 8, 8, kCVPixelFormatType_32BGRA, NULL, &buffer);
    NSArray *handlers = @[
        [[VNImageRequestHandler alloc] initWithCVPixelBuffer:buffer options:@{}], [[VNImageRequestHandler alloc] initWithCVPixelBuffer:buffer orientation:kCGImagePropertyOrientationUp options:@{}],
        [[VNImageRequestHandler alloc] initWithCIImage:ci options:@{}], [[VNImageRequestHandler alloc] initWithCIImage:ci orientation:kCGImagePropertyOrientationUp options:@{}],
        [[VNImageRequestHandler alloc] initWithURL:url options:@{}], [[VNImageRequestHandler alloc] initWithURL:url orientation:kCGImagePropertyOrientationUp options:@{}],
        [[VNImageRequestHandler alloc] initWithData:data options:@{}], [[VNImageRequestHandler alloc] initWithData:data orientation:kCGImagePropertyOrientationUp options:@{}],
    ];
    int made = 0;
    for (VNImageRequestHandler *each in handlers)
        if (each && ![each performRequests:requests error:NULL])
            made++;
    CHECK(made == 8, "a request handler is made from a pixel buffer, an image, a URL or data, and fails the request");
    CVPixelBufferRelease(buffer);
    CGImageRelease(image);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        compare();
        release_values();
        performing();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
