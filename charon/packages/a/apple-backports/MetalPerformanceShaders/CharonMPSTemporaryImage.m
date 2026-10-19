// CharonMPSTemporaryImage.m - the allocator behind MPSImage.h:930's +defaultAllocator.
//
// It exports ONE symbol, CharonMPSTemporaryImageDefaultAllocator, whose name begins `charon_` so that
// tools/release-split.lua's internal() excludes it from this file's release set. That is not a
// convenience: the class this file defines has no SDK header under its name, so its _OBJC_CLASS_$_
// symbol answers for NO release, and beside a release's own API in one object that reads as two
// releases. See CharonMPSTemporaryImage.h for the measured run and the reason in charon/AGENTS.md.

#import "CharonMPSTemporaryImage.h"

// This package's own allocator, where the release's MPSTemporaryImageDefaultAllocator is a name the
// release carries and this port does not. The protocol's one required method is
// -imageForCommandBuffer:imageDescriptor:kernel:, MPSImage.h:246-249.
@interface CharonMPSTemporaryImageAllocator : NSObject <MPSImageAllocator>
@end

@implementation CharonMPSTemporaryImageAllocator

+ (BOOL)supportsSecureCoding
{
    // MPSImage.h:236-238 makes NSSecureCoding part of the protocol rather than a convenience, so this
    // is a requirement and not a convenience of its own.
    return YES;
}

// MPSImage.h:178-185 is the release's own example of this class, and it encodes nothing beyond its
// superclass. There is nothing here to encode either: a temporary image's storage belongs to a command
// buffer and is gone when it completes, so an archive of this allocator is an allocator and nothing
// more. NSObject declares neither of NSSecureCoding's two instance methods on this surface, so there
// is no super implementation to chain to and none to chain to: the requirement is met by answering it.
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    (void)aCoder;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    (void)aDecoder;
    return [self init];
}

// MPSImage.h:246-249: the one required method. The header says the release's own implementations "don't
// need" the kernel argument (:250-251) - it is the kernel that will overwrite the image, and the image
// is built from the descriptor alone - and neither does this one.
- (MPSImage *)imageForCommandBuffer:(id<MTLCommandBuffer>)cmdBuf
                     imageDescriptor:(MPSImageDescriptor *)descriptor
                              kernel:(MPSKernel *)kernel
{
    (void)kernel;
    return [MPSTemporaryImage temporaryImageWithCommandBuffer:cmdBuf imageDescriptor:descriptor];
}

@end

id<MPSImageAllocator> CharonMPSTemporaryImageDefaultAllocator(void)
{
    static id<MPSImageAllocator> shared = nil;
    if (!shared)
        shared = [[CharonMPSTemporaryImageAllocator alloc] init];
    return shared;
}
