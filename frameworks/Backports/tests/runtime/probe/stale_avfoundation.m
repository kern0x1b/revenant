#import <Foundation/Foundation.h>

// Stands in, at link time only, for the libAVFoundationBackports of a build that defined AVSampleBufferDisplayLayer itself:
// the probe that links this library binds the class to the install name below, as an app linked against that build does.
// The harness copies this file into the guest under its own name; nothing there loads it, because the probe's load command
// names the install name of the real library, which is the one the case tests.
@interface AVSampleBufferDisplayLayer : NSObject
@end

@implementation AVSampleBufferDisplayLayer
@end
