#import "CharonMetricKit.h"
#import "CharonMetricValue.h"
// The value classes of this framework that arrived in iOS 26.0, one file for that release alone: an
// object carries API that arrived in one release, so this is the iOS 26.0 half and no two of them are one
// object.

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
