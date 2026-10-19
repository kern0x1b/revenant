#import "RevenantMetal.h"

@implementation MTLHeapDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        self.size = 0;
        self.storageMode = MTLStorageModePrivate;
        self.cpuCacheMode = MTLCPUCacheModeDefaultCache;
        self.type = MTLHeapTypeAutomatic;
        self.hazardTrackingMode = MTLHazardTrackingModeDefault;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLHeapDescriptor *d = [[MTLHeapDescriptor alloc] init];
    d.size = self.size;
    d.storageMode = self.storageMode;
    d.cpuCacheMode = self.cpuCacheMode;
    d.type = self.type;
    d.hazardTrackingMode = self.hazardTrackingMode;
    d.resourceOptions = self.resourceOptions;
    return d;
}

@end
