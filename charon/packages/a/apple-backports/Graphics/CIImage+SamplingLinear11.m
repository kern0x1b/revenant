#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// iOS 6's CoreImage samples every image linearly and has no way to ask for anything else (the
// nearest sampling of iOS 11 is not there), so an image already is its own linearly sampled image.

@implementation CIImage (CharonSamplingLinear)

- (CIImage *)imageBySamplingLinear
{
    return self;
}

@end
