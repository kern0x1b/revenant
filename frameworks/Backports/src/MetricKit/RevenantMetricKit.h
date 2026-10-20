#ifndef REVENANT_METRICKIT_H
#define REVENANT_METRICKIT_H

#import <Foundation/Foundation.h>
#import <MetricKit/MetricKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef REVENANT_HOST_DIFFERENTIAL

@interface MXMetaData (RevenantMetricKit)
@property (nonatomic, readonly, assign) bool lowPowerModeEnabled;
@property (nonatomic, readonly, assign) bool isTestFlightApp;
@property (nonatomic, readonly, assign) pid_t pid;
@property (nonatomic, readonly, strong) NSString* bundleIdentifier;
@end

@interface MXDiagnostic (RevenantMetricKit)
@property (nonatomic, readonly, strong) NSArray<MXSignpostRecord *> *signpostData;
- (void)revenant_setSignpostData:(NSArray<MXSignpostRecord *> *)value;
@end

@interface MXMetricPayload (RevenantMetricKit)
@property (nonatomic, readonly, strong) MXDiskSpaceUsageMetric *diskSpaceUsageMetrics;
@end

@interface MXCrashDiagnostic (RevenantMetricKit)
@property (nonatomic, readonly, strong) MXCrashDiagnosticObjectiveCExceptionReason *exceptionReason;
@end

@interface MXAnimationMetric (RevenantMetricKit)
@property (nonatomic, readonly, strong) NSMeasurement<NSUnit *> *hitchTimeRatio;
@end

#endif

NS_ASSUME_NONNULL_END

#endif
