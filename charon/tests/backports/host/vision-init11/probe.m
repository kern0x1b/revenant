/* probe.m - what the answers of the iOS 11 Vision initialisers are, class by class, on the host and in the port.
 *
 * Each class's -init (and +new, where the class answers it) and its -initWithCompletionHandler: are called on a fresh allocation,
 * and the class of the answer is printed: a class name for an object, nil for nil. The headers mark each initialiser
 * NS_UNAVAILABLE, so no application calls them through the header; the answer is what the release's own NSObject-inherited
 * initialiser gives, and this probe is the proof that the port answers the same. */
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <objc/runtime.h>

static const char *answer(id object)
{
    return object ? object_getClassName(object) : "nil";
}

int main(void)
{
    NSArray *plain = @[@"VNFaceLandmarkRegion", @"VNCoreMLModel", @"VNCoreMLRequest", @"VNFaceLandmarks", @"VNImageRequestHandler",
                       @"VNTargetedImageRequest", @"VNTrackObjectRequest", @"VNTrackRectangleRequest", @"VNTrackingRequest"];
    for (NSString *name in plain) {
        Class cls = NSClassFromString(name);
        if (!cls) {
            printf("%s absent\n", [name UTF8String]);
            continue;
        }
        printf("%s -init %s +new %s\n", [name UTF8String], answer([[cls alloc] init]), answer([cls new]));
    }
    NSArray *handled = @[@"VNCoreMLRequest", @"VNTargetedImageRequest", @"VNTrackObjectRequest", @"VNTrackRectangleRequest", @"VNTrackingRequest"];
    for (NSString *name in handled) {
        Class cls = NSClassFromString(name);
        if (!cls) {
            printf("%s absent\n", [name UTF8String]);
            continue;
        }
        printf("%s -initWithCompletionHandler: %s\n", [name UTF8String],
               answer([[cls alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {}]));
    }
    return 0;
}
