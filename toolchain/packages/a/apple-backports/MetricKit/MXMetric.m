#import "RevenantMetricValue.h"
#import "RevenantMetricKit.h"

@interface MXMetric (RevenantConstruction)
+ (instancetype)revenant_metric;
@end

@implementation MXMetric (RevenantConstruction)

+ (instancetype)revenant_metric
{
    return [[self alloc] init];
}

@end
