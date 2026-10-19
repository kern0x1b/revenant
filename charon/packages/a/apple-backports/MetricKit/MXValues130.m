#import "CharonMetricKit.h"
#import "CharonMetricValue.h"
// The value classes of this framework that arrived in iOS 13.0, one file for that release alone: an
// object carries API that arrived in one release, so this is the iOS 13.0 half and no two of them are one
// object.

@implementation MXAppLaunchMetric
@dynamic histogrammedTimeToFirstDraw, histogrammedApplicationResumeTime, histogrammedOptimizedTimeToFirstDraw, histogrammedExtendedLaunch;

CHARON_VALUE_PROPERTY(MXHistogram *, histogrammedTimeToFirstDraw)
CHARON_VALUE_PROPERTY(MXHistogram *, histogrammedApplicationResumeTime)
CHARON_VALUE_PROPERTY(MXHistogram *, histogrammedOptimizedTimeToFirstDraw)
CHARON_VALUE_PROPERTY(MXHistogram *, histogrammedExtendedLaunch)

@end
@implementation MXAppResponsivenessMetric
@dynamic histogrammedApplicationHangTime;

CHARON_VALUE_PROPERTY(MXHistogram *, histogrammedApplicationHangTime)

@end
@implementation MXAppRunTimeMetric
@dynamic cumulativeForegroundTime, cumulativeBackgroundTime, cumulativeBackgroundAudioTime, cumulativeBackgroundLocationTime;

CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeForegroundTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeBackgroundTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeBackgroundAudioTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeBackgroundLocationTime)

@end
@implementation MXAverage
@dynamic averageMeasurement, sampleCount, standardDeviation;

CHARON_VALUE_PROPERTY(NSMeasurement *, averageMeasurement)
CHARON_SCALAR_PROPERTY(NSInteger, sampleCount)
CHARON_DOUBLE_PROPERTY(double, standardDeviation)


@end
@implementation MXCPUMetric
@dynamic cumulativeCPUTime, cumulativeCPUInstructions;

CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUInstructions)

@end
@implementation MXCellularConditionMetric
@dynamic histogrammedCellularConditionTime;

CHARON_VALUE_PROPERTY(MXHistogram *, histogrammedCellularConditionTime)

@end
@implementation MXDiskIOMetric
@dynamic cumulativeLogicalWrites;

CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeLogicalWrites)

@end
@implementation MXDisplayMetric
@dynamic averagePixelLuminance;

CHARON_VALUE_PROPERTY(MXAverage *, averagePixelLuminance)

@end
@implementation MXGPUMetric
@dynamic cumulativeGPUTime;

CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeGPUTime)

@end
@implementation MXHistogram
@dynamic totalBucketCount, bucketEnumerator;

CHARON_SCALAR_PROPERTY(NSUInteger, totalBucketCount)
CHARON_VALUE_PROPERTY(NSEnumerator<MXHistogramBucket *> *, bucketEnumerator)

@end
@implementation MXHistogramBucket
@dynamic bucketStart, bucketEnd, bucketCount;

CHARON_VALUE_PROPERTY(NSMeasurement *, bucketStart)
CHARON_VALUE_PROPERTY(NSMeasurement *, bucketEnd)
CHARON_SCALAR_PROPERTY(NSUInteger, bucketCount)

@end
@implementation MXLocationActivityMetric
@dynamic cumulativeBestAccuracyTime, cumulativeBestAccuracyForNavigationTime, cumulativeNearestTenMetersAccuracyTime, cumulativeHundredMetersAccuracyTime, cumulativeKilometerAccuracyTime, cumulativeThreeKilometersAccuracyTime;

CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeBestAccuracyTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeBestAccuracyForNavigationTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeNearestTenMetersAccuracyTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeHundredMetersAccuracyTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeKilometerAccuracyTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeThreeKilometersAccuracyTime)

@end
@implementation MXMemoryMetric
@dynamic peakMemoryUsage, averageSuspendedMemory;

CHARON_VALUE_PROPERTY(NSMeasurement *, peakMemoryUsage)
CHARON_VALUE_PROPERTY(MXAverage *, averageSuspendedMemory)

@end
@implementation MXMetaData
@dynamic regionFormat, osVersion, deviceType, applicationBuildVersion, platformArchitecture;

CHARON_VALUE_PROPERTY(NSString *, regionFormat)
CHARON_VALUE_PROPERTY(NSString *, osVersion)
CHARON_VALUE_PROPERTY(NSString *, deviceType)
CHARON_VALUE_PROPERTY(NSString *, applicationBuildVersion)
CHARON_VALUE_PROPERTY(NSString *, platformArchitecture)

// Its own header gives it the two representations.
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end
// The properties the lowered SDK does not declare, in a category because a property a
// category declares is implemented in a category - and only there: a host build takes the
// host's own, newer, declarations, and the host's own class supplies these accessors.
@implementation MXMetaData (CharonMetricKit)
#ifndef CHARON_HOST_DIFFERENTIAL
@dynamic lowPowerModeEnabled, isTestFlightApp, pid, bundleIdentifier;
#endif

CHARON_SCALAR_PROPERTY(bool, lowPowerModeEnabled)
CHARON_SCALAR_PROPERTY(bool, isTestFlightApp)
CHARON_SCALAR_PROPERTY(pid_t, pid)
CHARON_VALUE_PROPERTY(NSString *, bundleIdentifier)

// Its own header gives it the two representations.
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end
@implementation MXMetric
@end

@implementation MXMetricPayload
@dynamic latestApplicationVersion, includesMultipleApplicationVersions, timeStampBegin, timeStampEnd, cpuMetrics, gpuMetrics, cellularConditionMetrics, applicationTimeMetrics, locationActivityMetrics, networkTransferMetrics, applicationLaunchMetrics, applicationResponsivenessMetrics, diskIOMetrics, memoryMetrics, displayMetrics, animationMetrics, applicationExitMetrics, signpostMetrics, metaData;

CHARON_VALUE_PROPERTY(NSString *, latestApplicationVersion)
CHARON_SCALAR_PROPERTY(BOOL, includesMultipleApplicationVersions)
CHARON_VALUE_PROPERTY(NSDate *, timeStampBegin)
CHARON_VALUE_PROPERTY(NSDate *, timeStampEnd)
CHARON_VALUE_PROPERTY(MXCPUMetric *, cpuMetrics)
CHARON_VALUE_PROPERTY(MXGPUMetric *, gpuMetrics)
CHARON_VALUE_PROPERTY(MXCellularConditionMetric *, cellularConditionMetrics)
CHARON_VALUE_PROPERTY(MXAppRunTimeMetric *, applicationTimeMetrics)
CHARON_VALUE_PROPERTY(MXLocationActivityMetric *, locationActivityMetrics)
CHARON_VALUE_PROPERTY(MXNetworkTransferMetric *, networkTransferMetrics)
CHARON_VALUE_PROPERTY(MXAppLaunchMetric *, applicationLaunchMetrics)
CHARON_VALUE_PROPERTY(MXAppResponsivenessMetric *, applicationResponsivenessMetrics)
CHARON_VALUE_PROPERTY(MXDiskIOMetric *, diskIOMetrics)
CHARON_VALUE_PROPERTY(MXMemoryMetric *, memoryMetrics)
CHARON_VALUE_PROPERTY(MXDisplayMetric *, displayMetrics)
CHARON_VALUE_PROPERTY(MXAnimationMetric *, animationMetrics)
CHARON_VALUE_PROPERTY(MXAppExitMetric *, applicationExitMetrics)
CHARON_VALUE_PROPERTY(NSArray *, signpostMetrics)
CHARON_VALUE_PROPERTY(MXMetaData *, metaData)

// Its own header gives it the two representations.
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end
// The properties the lowered SDK does not declare, in a category because a property a
// category declares is implemented in a category - and only there: a host build takes the
// host's own, newer, declarations, and the host's own class supplies these accessors.
@implementation MXMetricPayload (CharonMetricKit)
#ifndef CHARON_HOST_DIFFERENTIAL
@dynamic diskSpaceUsageMetrics;
#endif

CHARON_VALUE_PROPERTY(MXDiskSpaceUsageMetric *, diskSpaceUsageMetrics)

// Its own header gives it the two representations.
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@end
@implementation MXNetworkTransferMetric
@dynamic cumulativeWifiUpload, cumulativeWifiDownload, cumulativeCellularUpload, cumulativeCellularDownload;

CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeWifiUpload)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeWifiDownload)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeCellularUpload)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeCellularDownload)

@end
@implementation MXSignpostIntervalData
@dynamic histogrammedSignpostDuration, cumulativeCPUTime, averageMemory, cumulativeLogicalWrites, cumulativeHitchTimeRatio;

CHARON_VALUE_PROPERTY(MXHistogram *, histogrammedSignpostDuration)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeCPUTime)
CHARON_VALUE_PROPERTY(MXAverage *, averageMemory)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeLogicalWrites)
CHARON_VALUE_PROPERTY(NSMeasurement *, cumulativeHitchTimeRatio)

@end
@implementation MXSignpostMetric
@dynamic signpostName, signpostCategory, signpostIntervalData, totalCount;

CHARON_VALUE_PROPERTY(NSString *, signpostName)
CHARON_VALUE_PROPERTY(NSString *, signpostCategory)
CHARON_VALUE_PROPERTY(MXSignpostIntervalData *, signpostIntervalData)
CHARON_SCALAR_PROPERTY(NSUInteger, totalCount)

@end
@implementation MXUnitAveragePixelLuminance
@dynamic apl;

CHARON_VALUE_PROPERTY(MXUnitAveragePixelLuminance *, apl)

@end
@implementation MXUnitSignalBars
@dynamic bars;

CHARON_VALUE_PROPERTY(MXUnitSignalBars *, bars)

@end
