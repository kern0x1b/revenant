#import "CharonMetricKit.h"
#import "CharonMetricValue.h"

@implementation MXAnimationMetric
@dynamic scrollHitchTimeRatio;

CHARON_VALUE_PROPERTY(NSMeasurement *, scrollHitchTimeRatio)

@end
@implementation MXAnimationMetric (CharonMetricKit)
#ifndef CHARON_HOST_DIFFERENTIAL
@dynamic hitchTimeRatio;
#endif

CHARON_VALUE_PROPERTY(NSMeasurement *, hitchTimeRatio)

@end
@implementation MXAppExitMetric
@dynamic foregroundExitData, backgroundExitData;

CHARON_VALUE_PROPERTY(MXForegroundExitData *, foregroundExitData)
CHARON_VALUE_PROPERTY(MXBackgroundExitData *, backgroundExitData)

@end
@implementation MXBackgroundExitData
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [self charon_encodePropertiesWithCoder:coder]; }
- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        [self charon_decodePropertiesWithCoder:coder];
    return self;
}
@dynamic cumulativeNormalAppExitCount, cumulativeMemoryResourceLimitExitCount, cumulativeCPUResourceLimitExitCount, cumulativeMemoryPressureExitCount, cumulativeBadAccessExitCount, cumulativeAbnormalExitCount, cumulativeIllegalInstructionExitCount, cumulativeAppWatchdogExitCount, cumulativeSuspendedWithLockedFileExitCount, cumulativeBackgroundTaskAssertionTimeoutExitCount;

CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeNormalAppExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeMemoryResourceLimitExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeCPUResourceLimitExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeMemoryPressureExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeBadAccessExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeAbnormalExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeIllegalInstructionExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeAppWatchdogExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeSuspendedWithLockedFileExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeBackgroundTaskAssertionTimeoutExitCount)

@end
@implementation MXCPUExceptionDiagnostic
@dynamic callStackTree, totalCPUTime, totalSampledTime;

CHARON_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalCPUTime)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalSampledTime)

@end
@implementation MXCallStackTree
@end
@implementation MXCrashDiagnostic
@dynamic callStackTree, terminationReason, virtualMemoryRegionInfo, exceptionType, exceptionCode, signal;

CHARON_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
CHARON_VALUE_PROPERTY(NSString *, terminationReason)
CHARON_VALUE_PROPERTY(NSString *, virtualMemoryRegionInfo)
CHARON_VALUE_PROPERTY(NSNumber *, exceptionType)
CHARON_VALUE_PROPERTY(NSNumber *, exceptionCode)
CHARON_VALUE_PROPERTY(NSNumber *, signal)

@end
@implementation MXCrashDiagnostic (CharonMetricKit)
#ifndef CHARON_HOST_DIFFERENTIAL
@dynamic exceptionReason;
#endif

CHARON_VALUE_PROPERTY(MXCrashDiagnosticObjectiveCExceptionReason *, exceptionReason)

@end
@implementation MXDiagnostic
@end
@implementation MXDiagnosticPayload
- (NSData *)JSONRepresentation { return [CharonMetricValue jsonOf:self]; }
- (NSDictionary *)dictionaryRepresentation { return [CharonMetricValue dictionaryOf:self]; }
@dynamic cpuExceptionDiagnostics, diskWriteExceptionDiagnostics, hangDiagnostics, appLaunchDiagnostics, crashDiagnostics, timeStampBegin, timeStampEnd;

CHARON_VALUE_PROPERTY(NSArray *, cpuExceptionDiagnostics)
CHARON_VALUE_PROPERTY(NSArray *, diskWriteExceptionDiagnostics)
CHARON_VALUE_PROPERTY(NSArray *, hangDiagnostics)
CHARON_VALUE_PROPERTY(NSArray *, appLaunchDiagnostics)
CHARON_VALUE_PROPERTY(NSArray *, crashDiagnostics)
CHARON_VALUE_PROPERTY(NSDate *, timeStampBegin)
CHARON_VALUE_PROPERTY(NSDate *, timeStampEnd)

@end
@implementation MXDiskWriteExceptionDiagnostic
@dynamic callStackTree, totalWritesCaused;

CHARON_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
CHARON_VALUE_PROPERTY(NSMeasurement *, totalWritesCaused)

@end
@implementation MXForegroundExitData
@dynamic cumulativeNormalAppExitCount, cumulativeMemoryResourceLimitExitCount, cumulativeBadAccessExitCount, cumulativeAbnormalExitCount, cumulativeIllegalInstructionExitCount, cumulativeAppWatchdogExitCount;

CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeNormalAppExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeMemoryResourceLimitExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeBadAccessExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeAbnormalExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeIllegalInstructionExitCount)
CHARON_SCALAR_PROPERTY(NSUInteger, cumulativeAppWatchdogExitCount)

@end
@implementation MXHangDiagnostic
@dynamic callStackTree, hangDuration;

CHARON_VALUE_PROPERTY(MXCallStackTree *, callStackTree)
CHARON_VALUE_PROPERTY(NSMeasurement *, hangDuration)

@end
