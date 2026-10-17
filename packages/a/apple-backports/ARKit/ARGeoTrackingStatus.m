// ARGeoTrackingStatus.m - whether geographic tracking is working, and why not, at 14.0.
//
// A status is reported by a geo-tracking session, and this port runs none: its geo-tracking configuration is carried
// but not supported on this device (ARGeoTrackingConfiguration.m), so no session reports one. The class is carried so the name resolves; its three
// members are the synthesised accessors of the SDK's properties, and answer their zero values. facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARGeoTrackingStatus

@synthesize state = _state;
@synthesize accuracy = _accuracy;
@synthesize stateReason = _stateReason;

@end

NS_ASSUME_NONNULL_END
