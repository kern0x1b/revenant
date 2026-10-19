#import "CharonMetal.h"


@implementation MTLSamplerDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        self.normalizedCoordinates = YES;
        self.maxAnisotropy = 1;
        self.lodMaxClamp = FLT_MAX;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLSamplerDescriptor *d = [[MTLSamplerDescriptor alloc] init];
    d.minFilter = self.minFilter;
    d.magFilter = self.magFilter;
    d.mipFilter = self.mipFilter;
    d.sAddressMode = self.sAddressMode;
    d.tAddressMode = self.tAddressMode;
    d.normalizedCoordinates = self.normalizedCoordinates;
    return d;
}

@end
