#import "CharonMetal.h"


// The 12.0 blits. -optimizeContentsFor{CPU,GPU}Access: is a hint about where a resource's bytes
// should live for speed, and on this device the answer is already the case for every resource: a
// buffer is its own bytes and a texture is an OpenGL ES 2.0 texture the port reads and writes on the
// CPU, so there is nothing to move and nothing to migrate. The API asks for a performance, not for
// a value, and the performance is the one it asks for, which is why these do what doing nothing
// means here rather than refusing.
//
// The three indirect-command-buffer blits of 12.0 take an MTLIndirectCommandBuffer, which this port
// does not carry; MTLIndirectCommandBuffer is in registry/Metal/absent_Metal.json as absent, with the
// effect that says so.

// The four access hints do nothing, and that is the real behaviour: with every resource CPU-resident,
// there is no residency to move a resource between, so no observable effect exists to produce.
// facts/Metal/Blits.md says so, and tests/backports/host/metalblit/differential.m checks that Metal's own
// hints leave a texture's bytes as they were, and that the port's take the same texture and change nothing.
@implementation CharonMetalBlitEncoder (Optimize)

- (void)optimizeContentsForCPUAccess:(id<MTLTexture>)texture
{
}

- (void)optimizeContentsForCPUAccess:(id<MTLTexture>)texture slice:(NSUInteger)slice level:(NSUInteger)level
{
}

- (void)optimizeContentsForGPUAccess:(id<MTLTexture>)texture
{
}

- (void)optimizeContentsForGPUAccess:(id<MTLTexture>)texture slice:(NSUInteger)slice level:(NSUInteger)level
{
}

@end
