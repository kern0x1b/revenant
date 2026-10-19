#import "CharonMetal.h"

// The 10.0 debug markers of a buffer. A marker names a range of the buffer for a capture, and changes no
// byte of it, as the host measured (tests/backports/device/buffer-probe/host-expectations.txt). The port
// has no capture to put a marker in, so a marker is accepted and nothing is kept, the same as the signpost
// of an encoder (facts/Metal/Buffers.md).
@implementation CharonMetalBuffer (DebugMarkers10)

- (void)addDebugMarker:(NSString *)marker range:(NSRange)range
{
}

- (void)removeAllDebugMarkers
{
}

@end
