#ifndef REVENANT_METRIC_VALUE_H
#define REVENANT_METRIC_VALUE_H

#import <Foundation/Foundation.h>
#import "RevenantMetricKit.h"
#import "../RevenantValueStore.h"

@class MXSignpostMetric;

#define REVENANT_VALUE_STORE_DECLARATION                                                     \
    - (NSMutableDictionary *)revenant_values;                                                \
    - (id)revenant_valueForKey:(NSString *)key;                                              \
    - (void)revenant_setValue:(id)value forKey:(NSString *)key;

#define REVENANT_VALUE_CODING_DECLARATION                                                     \
    + (BOOL)supportsSecureCoding;                                                           \
    - (void)encodeWithCoder:(NSCoder *)coder;                                              \
    - (instancetype)initWithCoder:(NSCoder *)coder;

#define REVENANT_VALUE_CODING_METHODS                                                         \
    - (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder                               \
    {                                                                                       \
        for (NSString *name in [RevenantMetricValue propertyNamesOf:[self class]]) {           \
            id value = [self revenant_valueForKey:name];                                       \
            if (value)                                                                      \
                [coder encodeObject:value forKey:name];                                      \
        }                                                                                   \
    }                                                                                       \
    - (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder                               \
    {                                                                                       \
        NSSet *allowed = [RevenantMetricValue decodableClasses];                              \
        BOOL whole = YES;                                                                   \
        for (NSString *name in [RevenantMetricValue propertyNamesOf:[self class]]) {           \
            if (![coder containsValueForKey:name])                                          \
                continue;                                                                    \
            id value = [coder decodeObjectOfClasses:allowed forKey:name];                     \
            if (value)                                                                       \
                [self revenant_setValue:value forKey:name];                                    \
            else                                                                            \
                whole = NO;                                                                 \
        }                                                                                   \
        return whole;                                                                       \
    }

@class MXMetric, MXDiagnostic, MXAverage, MXHistogram, MXHistogramBucket, MXMetaData, MXMetricPayload,
        MXDiagnosticPayload, MXCrashDiagnosticObjectiveCExceptionReason, MXSignpostRecord,
        MXSignpostIntervalData, MXBackgroundExitData, MXForegroundExitData, MXCallStackTree,
        MXUnitAveragePixelLuminance, MXUnitSignalBars;

@interface MXMetric (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXDiagnostic (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXAverage (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXHistogram (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXHistogramBucket (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXMetaData (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface MXMetricPayload (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface MXDiagnosticPayload (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXCrashDiagnosticObjectiveCExceptionReason (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXSignpostRecord (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXSignpostIntervalData (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXBackgroundExitData (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXForegroundExitData (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXCallStackTree (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
- (void)revenant_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)revenant_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXUnitAveragePixelLuminance (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
@end

@interface MXUnitSignalBars (RevenantMetricValue)
- (NSMutableDictionary *)revenant_values;
- (id)revenant_valueForKey:(NSString *)key;
- (void)revenant_setValue:(id)value forKey:(NSString *)key;
@end

@interface RevenantMetricValue : NSObject

+ (NSArray<NSString *> *)propertyNamesOf:(Class)cls;

+ (NSDictionary *)dictionaryOf:(id)value;
+ (NSData *)jsonOf:(id)value;

+ (NSSet<Class> *)decodableClasses;

@end

#define REVENANT_VALUE_STORE_IMPLEMENTATION                                                   \
    -(NSMutableDictionary *)revenant_values { return RevenantValueStore(self); }                \
    -(id)revenant_valueForKey:(NSString *)key { return [self revenant_values][key]; }            \
    -(void)revenant_setValue:(id)value forKey:(NSString *)key { RevenantValueSet(self, value, key); }

@interface MXHistogram (RevenantMetricKitSetters)
- (void)revenant_setTotalBucketCount:(NSUInteger)value;
- (void)revenant_setBucketEnumerator:(id)value;
- (id)revenant_bucketEnumerator;
@end

@interface MXHistogramBucket (RevenantMetricKitSetters)
- (void)revenant_setBucketStart:(id)value;
- (void)revenant_setBucketEnd:(id)value;
- (void)revenant_setBucketCount:(NSUInteger)value;
@end

FOUNDATION_EXPORT NSArray<MXSignpostMetric *> *RevenantSignpostMetrics(void);

@interface MXSignpostMetric (RevenantMetricKitSetters)
- (void)revenant_setSignpostName:(id)value;
- (void)revenant_setSignpostCategory:(id)value;
- (void)revenant_setSignpostIntervalData:(id)value;
- (void)revenant_setTotalCount:(NSUInteger)value;
- (id)revenant_totalCount;
- (id)revenant_signpostIntervalData;
@end

@interface MXSignpostIntervalData (RevenantMetricKitSetters)
- (void)revenant_setHistogrammedSignpostDuration:(id)value;
- (void)revenant_setCumulativeCPUTime:(id)value;
- (id)revenant_cumulativeCPUTime;
- (id)revenant_histogrammedSignpostDuration;
@end


@interface MXAppLaunchMetric (RevenantMetricKitSetters)
- (void)revenant_setHistogrammedExtendedLaunch:(id)value;
- (void)revenant_setHistogrammedTimeToFirstDraw:(id)value;
@end

#endif
