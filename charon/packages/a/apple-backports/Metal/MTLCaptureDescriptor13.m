#import "CharonMetal.h"


NSString *const MTLCaptureErrorDomain = @"MTLCaptureErrorDomain";

@implementation MTLCaptureDescriptor

- (id)copyWithZone:(NSZone *)zone
{
    MTLCaptureDescriptor *copy = [[MTLCaptureDescriptor alloc] init];
    copy.captureObject = self.captureObject;
    copy.destination = self.destination;
    copy.outputURL = self.outputURL;
    return copy;
}

@end

@implementation MTLCaptureManager (CharonCaptureDescriptor13)

- (BOOL)supportsDestination:(MTLCaptureDestination)destination
{
    return NO;
}

- (BOOL)startCaptureWithDescriptor:(MTLCaptureDescriptor *)descriptor error:(NSError **)error
{
    if (error)
        *error = [NSError errorWithDomain:MTLCaptureErrorDomain code:MTLCaptureErrorNotSupported
                                  userInfo:@{NSLocalizedDescriptionKey: @"this device runs Metal over OpenGL ES 2.0 and has no GPU trace capture backend"}];
    return NO;
}

@end
