#import "CharonMetal.h"

// -insertDebugCaptureBoundary marks a point in a GPU frame capture. A capture runs only under a tool
// that attaches to the process, and none does on a device; with no capture started Metal does nothing
// with the call, and neither does the port. facts/Metal/CommandBuffer.md has the measurements that
// fix this answer to the host's own.
@implementation CharonMetalQueue (Capture8)

- (void)insertDebugCaptureBoundary
{
}

@end
