#import "CharonMetricKit.h"
#import "CharonMetricValue.h"

@implementation MXAppLaunchDiagnostic
@dynamic callStackTree, launchDuration;

CHARON_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
CHARON_VALUE_PROPERTY(NSMeasurement *, launchDuration)

@end
