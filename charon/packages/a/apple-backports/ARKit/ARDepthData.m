// ARDepthData.m - a depth map and its confidence map, at 14.0 where scene depth arrived.
//
// The maps are read out of a depth sensor, and this device has none, so no session gives one out and no
// application can make one: the SDK gives the class no initialiser of its own. The class is carried
// so that a reference to it resolves, and its two maps are the ones a frame would hand over, which is
// none. See facts/ARKit/SensorShells.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARDepthData

@synthesize depthMap = _depthMap;
@synthesize confidenceMap = _confidenceMap;

@end

NS_ASSUME_NONNULL_END
