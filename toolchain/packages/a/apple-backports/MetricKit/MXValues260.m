#import "CharonMetricKit.h"
#import "CharonMetricValue.h"

@implementation MXDiskSpaceUsageMetric
@dynamic totalBinaryFileSize, totalBinaryFileCount, totalDataFileSize, totalDataFileCount, totalCacheFolderSize, totalCloneSize, totalDiskSpaceUsedSize, totalDiskSpaceCapacity;

CHARON_VALUE_PROPERTY(NSMeasurement *, totalBinaryFileSize)
CHARON_SCALAR_PROPERTY(NSInteger, totalBinaryFileCount)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalDataFileSize)
CHARON_SCALAR_PROPERTY(NSInteger, totalDataFileCount)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalCacheFolderSize)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalCloneSize)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalDiskSpaceUsedSize)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalDiskSpaceCapacity)

@end
