#import "RevenantMetricKit.h"
#import "RevenantMetricValue.h"

@implementation MXAnimationMetric
@dynamic scrollHitchTimeRatio;

REVENANT_VALUE_PROPERTY(NSMeasurement *, scrollHitchTimeRatio)

@end
@implementation MXAnimationMetric (RevenantMetricKit)
#ifndef REVENANT_HOST_DIFFERENTIAL
@dynamic hitchTimeRatio;
#endif

REVENANT_VALUE_PROPERTY(NSMeasurement *, hitchTimeRatio)

@end
@implementation MXAppExitMetric
@dynamic foregroundExitData, backgroundExitData;

REVENANT_VALUE_PROPERTY(MXForegroundExitData *, foregroundExitData)
REVENANT_VALUE_PROPERTY(MXBackgroundExitData *, backgroundExitData)

@end
@implementation MXBackgroundExitData
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self revenant_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self revenant_decodePropertiesWithCoder:coder];
    return self;
}
@dynamic cumulativeNormalAppExitCount, cumulativeMemoryResourceLimitExitCount, cumulativeCPUResourceLimitExitCount, cumulativeMemoryPressureExitCount, cumulativeBadAccessExitCount, cumulativeAbnormalExitCount, cumulativeIllegalInstructionExitCount, cumulativeAppWatchdogExitCount, cumulativeSuspendedWithLockedFileExitCount, cumulativeBackgroundTaskAssertionTimeoutExitCount;

REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeNormalAppExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeMemoryResourceLimitExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeCPUResourceLimitExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeMemoryPressureExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeBadAccessExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeAbnormalExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeIllegalInstructionExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeAppWatchdogExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeSuspendedWithLockedFileExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeBackgroundTaskAssertionTimeoutExitCount)

@end
@implementation MXCPUExceptionDiagnostic
@dynamic callStackTree, totalCPUTime, totalSampledTime;

REVENANT_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalCPUTime)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalSampledTime)

@end
@implementation MXCallStackTree
@end
@implementation MXCrashDiagnostic
@dynamic callStackTree, terminationReason, virtualMemoryRegionInfo, exceptionType, exceptionCode, signal;

REVENANT_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
REVENANT_VALUE_PROPERTY(NSString *, terminationReason)
REVENANT_VALUE_PROPERTY(NSString *, virtualMemoryRegionInfo)
REVENANT_VALUE_PROPERTY(NSNumber *, exceptionType)
REVENANT_VALUE_PROPERTY(NSNumber *, exceptionCode)
REVENANT_VALUE_PROPERTY(NSNumber *, signal)

@end
@implementation MXCrashDiagnostic (RevenantMetricKit)
#ifndef REVENANT_HOST_DIFFERENTIAL
@dynamic exceptionReason;
#endif

REVENANT_VALUE_PROPERTY(MXCrashDiagnosticObjectiveCExceptionReason *, exceptionReason)

@end
@implementation MXDiagnostic
@end
@implementation MXDiagnosticPayload
- (NSData *)JSONRepresentation { return [RevenantMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [RevenantMetricValue dictionaryOf:self]; }
@dynamic cpuExceptionDiagnostics, diskWriteExceptionDiagnostics, hangDiagnostics, appLaunchDiagnostics, crashDiagnostics, timeStampBegin, timeStampEnd;

REVENANT_VALUE_PROPERTY(NSArray *, cpuExceptionDiagnostics)
REVENANT_VALUE_PROPERTY(NSArray *, diskWriteExceptionDiagnostics)
REVENANT_VALUE_PROPERTY(NSArray *, hangDiagnostics)
REVENANT_VALUE_PROPERTY(NSArray *, appLaunchDiagnostics)
REVENANT_VALUE_PROPERTY(NSArray *, crashDiagnostics)
REVENANT_VALUE_PROPERTY(NSDate *, timeStampBegin)
REVENANT_VALUE_PROPERTY(NSDate *, timeStampEnd)

@end
@implementation MXDiskWriteExceptionDiagnostic
@dynamic callStackTree, totalWritesCaused;

REVENANT_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
REVENANT_VALUE_PROPERTY(NSMeasurement *, totalWritesCaused)

@end
@implementation MXForegroundExitData
@dynamic cumulativeNormalAppExitCount, cumulativeMemoryResourceLimitExitCount, cumulativeBadAccessExitCount, cumulativeAbnormalExitCount, cumulativeIllegalInstructionExitCount, cumulativeAppWatchdogExitCount;

REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeNormalAppExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeMemoryResourceLimitExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeBadAccessExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeAbnormalExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeIllegalInstructionExitCount)
REVENANT_SCALAR_PROPERTY(NSUInteger, cumulativeAppWatchdogExitCount)

@end
@implementation MXHangDiagnostic
@dynamic callStackTree, hangDuration;

REVENANT_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
REVENANT_VALUE_PROPERTY(NSMeasurement *, hangDuration)

@end
