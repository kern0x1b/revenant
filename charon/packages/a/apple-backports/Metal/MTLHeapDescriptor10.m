// MTLHeapDescriptor, the SDK's own class of iOS 10.0, on its own.
//
// An application makes one and sets its properties, so the port gives it the defaults Apple's header
// documents and copies it. iOS 6 carries no class of this name, so this is the only one there is, and
// registry/Metal/ios10heap.json carries the row (and the three members of 13.0 beside it) with a
// minimum of 6.0, which is the band below: the class is the port's own from the oldest band up.
//
// This is an object of its own because an object is dropped from the release that exports its API, and
// the release has carried MTLHeapDescriptor since iOS 10.0. The file this implementation was in before
// also holds the port's own CharonMetalHeap - a class of Charon's, which every band keeps - and two
// files that no band drops are categories over it (MTLHeap11.m and MTLHeap13.m). Beside the
// descriptor, one band's API decided the whole file's, and a band from 10.0.1 had no heap at all:
//
//   Undefined symbols for architecture armv7:
//     "_OBJC_CLASS_$_CharonMetalHeap", referenced from:
//         -[CharonMetalHeap(AllocatedSize) currentAllocatedSize] in MTLHeap11.o
//         -[CharonMetalHeap(Placement) ...] in MTLHeap13.o
//
// The heap class and its two categories are back in every band with the file named MTLHeap10.m, which
// is where they were written; this file carries the descriptor and nothing else, so band() re-exports
// the release's own MTLHeapDescriptor from 10.0.1 exactly as it did for the pair.

#import "CharonMetal.h"

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