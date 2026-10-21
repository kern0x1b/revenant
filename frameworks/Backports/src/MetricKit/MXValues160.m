#import "RevenantMetricKit.h"
#import "RevenantMetricValue.h"

@implementation MXAppLaunchDiagnostic
@dynamic callStackTree, launchDuration;

REVENANT_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
REVENANT_VALUE_PROPERTY(NSMeasurement *, launchDuration)

@end
