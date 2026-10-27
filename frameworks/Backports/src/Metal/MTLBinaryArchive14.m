#import "RevenantMetal.h"
#import "RevenantMetalBinaryArchive.h"

@implementation RevenantMetalDevice (BinaryArchive14)

- (id<MTLBinaryArchive>)newBinaryArchiveWithDescriptor:(MTLBinaryArchiveDescriptor *)descriptor error:(NSError **)error
{
    return [[RevenantMetalBinaryArchive alloc] initWithDevice:self descriptor:descriptor error:error];
}

@end
