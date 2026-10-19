#import "RevenantMetricKit.h"
#import "RevenantMetricValue.h"

@implementation MXDiskSpaceUsageMetric
@dynamic totalBinaryFileSize, totalBinaryFileCount, totalDataFileSize, totalDataFileCount, totalCacheFolderSize, totalCloneSize, totalDiskSpaceUsedSize, totalDiskSpaceCapacity;

REVENANT_VALUE_PROPERTY(NSMeasurement *, totalBinaryFileSize)
REVENANT_SCALAR_PROPERTY(NSInteger, totalBinaryFileCount)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalDataFileSize)
REVENANT_SCALAR_PROPERTY(NSInteger, totalDataFileCount)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalCacheFolderSize)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalCloneSize)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalDiskSpaceUsedSize)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalDiskSpaceCapacity)

@end
