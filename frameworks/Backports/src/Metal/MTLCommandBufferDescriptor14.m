#include "../revenant_impl.h"
#import "RevenantMetal.h"


NSString *const BACKPORT_IMPL(MTLCommandBufferEncoderInfoErrorKey) = @"MTLCommandBufferEncoderInfoErrorKey";

@implementation MTLCommandBufferDescriptor

- (instancetype)init
{
    if ((self = [super init]))
        self.retainedReferences = YES;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLCommandBufferDescriptor *copy = [[MTLCommandBufferDescriptor alloc] init];
    copy.retainedReferences = self.retainedReferences;
    copy.errorOptions = self.errorOptions;
    return copy;
}

@end
