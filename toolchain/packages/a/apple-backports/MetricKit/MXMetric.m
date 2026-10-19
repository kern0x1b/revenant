#import "CharonMetricValue.h"
#import "CharonMetricKit.h"

@interface MXMetric (CharonConstruction)
+ (instancetype)charon_metric;
@end

@implementation MXMetric (CharonConstruction)

+ (instancetype)charon_metric
{
    return [[self alloc] init];
}

@end
