#import "CharonMPSTemporaryImage.h"

@interface CharonMPSTemporaryImageAllocator : NSObject <MPSImageAllocator>
@end

@implementation CharonMPSTemporaryImageAllocator

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    (void)aCoder;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    (void)aDecoder;
    return [self init];
}

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
