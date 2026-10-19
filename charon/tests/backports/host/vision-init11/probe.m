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
