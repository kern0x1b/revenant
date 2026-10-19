#ifndef CHARON_METRICKIT_H
#define CHARON_METRICKIT_H

#import <Foundation/Foundation.h>
#import <MetricKit/MetricKit.h>

// The build compiles against the lowered 16.4 SDK, and MetricKit grew past it: three of the classes of
// SDK 26.2 and four of its properties are not in those headers at all. They are declared here the way
// SecurityUI's SFCertificatePresentation is - the same superclass, the same selectors, the same property
// types and no ivars, so an application compiled against the real 26.2 headers finds exactly the classes
// and properties this library exports. Only the availability annotations are left out, which is what the
// other redeclarations in this package do (CharonSecurityUI.h, CharonAVAudioBuffer.h, CharonCallKit.h): they
// would be refused against this deployment target and mean nothing in a translation unit that is not the
// application's.

NS_ASSUME_NONNULL_BEGIN

// The host's own MetricKit is newer than the SDK this package builds against and already declares
// these, so a host comparison compiles with -DCHARON_HOST_DIFFERENTIAL and takes the host's
// declarations instead of ours. That is the same macro Foundation/NSDirectoryEnumerator+PostOrder13.m
// uses for exactly this - a source built differently for a host comparison, and here is what differs -
// and it is why this header is the port's for the armv7 build and not for anybody's.
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

#endif // CHARON_HOST_DIFFERENTIAL

NS_ASSUME_NONNULL_END

#endif
