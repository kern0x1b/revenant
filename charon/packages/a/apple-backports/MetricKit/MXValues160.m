#import "CharonMetricKit.h"
#import "CharonMetricValue.h"
// The value classes of this framework that arrived in iOS 16.0, one file for that release alone: an
// object carries API that arrived in one release, so this is the iOS 16.0 half and no two of them are one
// object.

@implementation MXAppLaunchDiagnostic
@dynamic callStackTree, launchDuration;

CHARON_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
CHARON_VALUE_PROPERTY(NSMeasurement *, launchDuration)

@end
