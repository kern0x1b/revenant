#import "RevenantMetricKit.h"
#import "RevenantMetricValue.h"

@implementation MXAppLaunchMetric
@dynamic histogrammedTimeToFirstDraw, histogrammedApplicationResumeTime, histogrammedOptimizedTimeToFirstDraw, histogrammedExtendedLaunch;

REVENANT_VALUE_PROPERTY(MXHistogram *, histogrammedTimeToFirstDraw)
REVENANT_VALUE_PROPERTY(MXHistogram *, histogrammedApplicationResumeTime)
REVENANT_VALUE_PROPERTY(MXHistogram *, histogrammedOptimizedTimeToFirstDraw)
REVENANT_VALUE_PROPERTY(MXHistogram *, histogrammedExtendedLaunch)

@end
@implementation MXAppResponsivenessMetric
@dynamic histogrammedApplicationHangTime;

REVENANT_VALUE_PROPERTY(MXHistogram *, histogrammedApplicationHangTime)

@end
@implementation MXAppRunTimeMetric
@dynamic cumulativeForegroundTime, cumulativeBackgroundTime, cumulativeBackgroundAudioTime, cumulativeBackgroundLocationTime;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeForegroundTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeBackgroundTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeBackgroundAudioTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeBackgroundLocationTime)

@end
@implementation MXAverage
@dynamic averageMeasurement, sampleCount, standardDeviation;

REVENANT_VALUE_PROPERTY(NSMeasurement *, averageMeasurement)
REVENANT_SCALAR_PROPERTY(NSInteger, sampleCount)
REVENANT_DOUBLE_PROPERTY(double, standardDeviation)


@end
@implementation MXCPUMetric
@dynamic cumulativeCPUTime, cumulativeCPUInstructions;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUInstructions)

@end
@implementation MXCellularConditionMetric
@dynamic histogrammedCellularConditionTime;

REVENANT_VALUE_PROPERTY(MXHistogram *, histogrammedCellularConditionTime)

@end
@implementation MXDiskIOMetric
@dynamic cumulativeLogicalWrites;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeLogicalWrites)

@end
@implementation MXDisplayMetric
@dynamic averagePixelLuminance;

REVENANT_VALUE_PROPERTY(MXAverage *, averagePixelLuminance)

@end
@implementation MXGPUMetric
@dynamic cumulativeGPUTime;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeGPUTime)

@end
@implementation MXHistogram
@dynamic totalBucketCount, bucketEnumerator;

REVENANT_SCALAR_PROPERTY(NSUInteger, totalBucketCount)
REVENANT_VALUE_PROPERTY(NSEnumerator<MXHistogramBucket *> *, bucketEnumerator)

@end
@implementation MXHistogramBucket
@dynamic bucketStart, bucketEnd, bucketCount;

REVENANT_VALUE_PROPERTY(NSMeasurement *, bucketStart)
REVENANT_VALUE_PROPERTY(NSMeasurement *, bucketEnd)
REVENANT_SCALAR_PROPERTY(NSUInteger, bucketCount)

@end
@implementation MXLocationActivityMetric
@dynamic cumulativeBestAccuracyTime, cumulativeBestAccuracyForNavigationTime, cumulativeNearestTenMetersAccuracyTime, cumulativeHundredMetersAccuracyTime, cumulativeKilometerAccuracyTime, cumulativeThreeKilometersAccuracyTime;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeBestAccuracyTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeBestAccuracyForNavigationTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeNearestTenMetersAccuracyTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeHundredMetersAccuracyTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeKilometerAccuracyTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeThreeKilometersAccuracyTime)

@end
@implementation MXMemoryMetric
@dynamic peakMemoryUsage, averageSuspendedMemory;

REVENANT_VALUE_PROPERTY(NSMeasurement *, peakMemoryUsage)
REVENANT_VALUE_PROPERTY(MXAverage *, averageSuspendedMemory)

@end
@implementation MXMetaData
@dynamic regionFormat, osVersion, deviceType, applicationBuildVersion, platformArchitecture;

REVENANT_VALUE_PROPERTY(NSString *, regionFormat)
REVENANT_VALUE_PROPERTY(NSString *, osVersion)
REVENANT_VALUE_PROPERTY(NSString *, deviceType)
REVENANT_VALUE_PROPERTY(NSString *, applicationBuildVersion)
REVENANT_VALUE_PROPERTY(NSString *, platformArchitecture)

- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end
@implementation MXMetaData (RevenantMetricKit)
#ifndef REVENANT_HOST_DIFFERENTIAL
@dynamic lowPowerModeEnabled, isTestFlightApp, pid, bundleIdentifier;
#endif

REVENANT_SCALAR_PROPERTY(bool, lowPowerModeEnabled)
REVENANT_SCALAR_PROPERTY(bool, isTestFlightApp)
REVENANT_SCALAR_PROPERTY(pid_t, pid)
REVENANT_VALUE_PROPERTY(NSString *, bundleIdentifier)

- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end
@implementation MXMetric
@end

@implementation MXMetricPayload
@dynamic latestApplicationVersion, includesMultipleApplicationVersions, timeStampBegin, timeStampEnd, cpuMetrics, gpuMetrics, cellularConditionMetrics, applicationTimeMetrics, locationActivityMetrics, networkTransferMetrics, applicationLaunchMetrics, applicationResponsivenessMetrics, diskIOMetrics, memoryMetrics, displayMetrics, animationMetrics, applicationExitMetrics, signpostMetrics, metaData;

REVENANT_VALUE_PROPERTY(NSString *, latestApplicationVersion)
REVENANT_SCALAR_PROPERTY(BOOL, includesMultipleApplicationVersions)
REVENANT_VALUE_PROPERTY(NSDate *, timeStampBegin)
REVENANT_VALUE_PROPERTY(NSDate *, timeStampEnd)
REVENANT_VALUE_PROPERTY(MXCPUMetric *, cpuMetrics)
REVENANT_VALUE_PROPERTY(MXGPUMetric *, gpuMetrics)
REVENANT_VALUE_PROPERTY(MXCellularConditionMetric *, cellularConditionMetrics)
REVENANT_VALUE_PROPERTY(MXAppRunTimeMetric *, applicationTimeMetrics)
REVENANT_VALUE_PROPERTY(MXLocationActivityMetric *, locationActivityMetrics)
REVENANT_VALUE_PROPERTY(MXNetworkTransferMetric *, networkTransferMetrics)
REVENANT_VALUE_PROPERTY(MXAppLaunchMetric *, applicationLaunchMetrics)
REVENANT_VALUE_PROPERTY(MXAppResponsivenessMetric *, applicationResponsivenessMetrics)
REVENANT_VALUE_PROPERTY(MXDiskIOMetric *, diskIOMetrics)
REVENANT_VALUE_PROPERTY(MXMemoryMetric *, memoryMetrics)
REVENANT_VALUE_PROPERTY(MXDisplayMetric *, displayMetrics)
REVENANT_VALUE_PROPERTY(MXAnimationMetric *, animationMetrics)
REVENANT_VALUE_PROPERTY(MXAppExitMetric *, applicationExitMetrics)
REVENANT_VALUE_PROPERTY(NSArray *, signpostMetrics)
REVENANT_VALUE_PROPERTY(MXMetaData *, metaData)

- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end
@implementation MXMetricPayload (RevenantMetricKit)
#ifndef REVENANT_HOST_DIFFERENTIAL
@dynamic diskSpaceUsageMetrics;
#endif

REVENANT_VALUE_PROPERTY(MXDiskSpaceUsageMetric *, diskSpaceUsageMetrics)

- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@end
@implementation MXNetworkTransferMetric
@dynamic cumulativeWifiUpload, cumulativeWifiDownload, cumulativeCellularUpload, cumulativeCellularDownload;

REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeWifiUpload)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeWifiDownload)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCellularUpload)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCellularDownload)

@end
@implementation MXSignpostIntervalData
@dynamic histogrammedSignpostDuration, cumulativeCPUTime, averageMemory, cumulativeLogicalWrites, cumulativeHitchTimeRatio;

REVENANT_VALUE_PROPERTY(MXHistogram *, histogrammedSignpostDuration)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUTime)
REVENANT_VALUE_PROPERTY(MXAverage *, averageMemory)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeLogicalWrites)
REVENANT_VALUE_PROPERTY(NSMeasurement *, cumulativeHitchTimeRatio)

@end
@implementation MXSignpostMetric
@dynamic signpostName, signpostCategory, signpostIntervalData, totalCount;

REVENANT_VALUE_PROPERTY(NSString *, signpostName)
REVENANT_VALUE_PROPERTY(NSString *, signpostCategory)
REVENANT_VALUE_PROPERTY(MXSignpostIntervalData *, signpostIntervalData)
REVENANT_SCALAR_PROPERTY(NSUInteger, totalCount)

@end
@implementation MXUnitAveragePixelLuminance
@dynamic apl;

REVENANT_VALUE_PROPERTY(MXUnitAveragePixelLuminance *, apl)

@end
@implementation MXUnitSignalBars
@dynamic bars;

REVENANT_VALUE_PROPERTY(MXUnitSignalBars *, bars)

@end
