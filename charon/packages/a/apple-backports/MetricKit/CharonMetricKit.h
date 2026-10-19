#ifndef CHARON_METRICKIT_H
#define CHARON_METRICKIT_H

#import <Foundation/Foundation.h>
#import <MetricKit/MetricKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef CHARON_HOST_DIFFERENTIAL

@interface MXSignpostRecord : NSObject <NSSecureCoding>
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
@property (nonatomic, readonly, strong) NSString *subsystem;
@property (nonatomic, readonly, strong) NSString *category;
@property (nonatomic, readonly, strong) NSString *name;
@property (nonatomic, readonly, strong) NSDate *beginTimeStamp;
@property (nonatomic, readonly, strong) NSDate *endTimeStamp;
@property (nonatomic, readonly, strong) NSMeasurement<NSUnitDuration *> *duration;
@property (nonatomic, readonly, assign) BOOL isInterval;
@end

@interface MXDiskSpaceUsageMetric : MXMetric <NSSecureCoding>
@property (nonatomic, readonly, strong) NSMeasurement<NSUnitInformationStorage *> *totalBinaryFileSize;
@property (nonatomic, readonly, assign) NSInteger totalBinaryFileCount;
@property (nonatomic, readonly, strong) NSMeasurement<NSUnitInformationStorage *> *totalDataFileSize;
@property (nonatomic, readonly, assign) NSInteger totalDataFileCount;
@property (nonatomic, readonly, strong) NSMeasurement<NSUnitInformationStorage *> *totalCacheFolderSize;
@property (nonatomic, readonly, strong) NSMeasurement<NSUnitInformationStorage *> *totalCloneSize;
@property (nonatomic, readonly, strong) NSMeasurement<NSUnitInformationStorage *> *totalDiskSpaceUsedSize;
@property (nonatomic, readonly, strong) NSMeasurement<NSUnitInformationStorage *> *totalDiskSpaceCapacity;
@end

@interface MXCrashDiagnosticObjectiveCExceptionReason : NSObject <NSSecureCoding>
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
@property (nonatomic, readonly, strong) NSString *composedMessage;
@property (nonatomic, readonly, strong) NSString *formatString;
@property (nonatomic, readonly, strong) NSArray<NSString *>*arguments;
@property (nonatomic, readonly, strong) NSString *exceptionType;
@property (nonatomic, readonly, strong) NSString *className;
@property (nonatomic, readonly, strong) NSString *exceptionName;
@end

@interface MXMetaData (CharonMetricKit)
@property (nonatomic, readonly, assign) bool lowPowerModeEnabled;
@property (nonatomic, readonly, assign) bool isTestFlightApp;
@property (nonatomic, readonly, assign) pid_t pid;
@property (nonatomic, readonly, strong) NSString* bundleIdentifier;
@end

@interface MXDiagnostic (CharonMetricKit)
@property (nonatomic, readonly, strong) NSArray<MXSignpostRecord *> *signpostData;
- (void)charon_setSignpostData:(NSArray<MXSignpostRecord *> *)value;
@end

@interface MXMetricPayload (CharonMetricKit)
@property (nonatomic, readonly, strong) MXDiskSpaceUsageMetric *diskSpaceUsageMetrics;
@end

@interface MXCrashDiagnostic (CharonMetricKit)
@property (nonatomic, readonly, strong) MXCrashDiagnosticObjectiveCExceptionReason *exceptionReason;
@end

@interface MXAnimationMetric (CharonMetricKit)
@property (nonatomic, readonly, strong) NSMeasurement<NSUnit *> *hitchTimeRatio;
@end

#endif

NS_ASSUME_NONNULL_END

#endif
