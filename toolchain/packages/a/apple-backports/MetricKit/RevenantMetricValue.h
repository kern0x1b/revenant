#ifndef CHARON_METRIC_VALUE_H
#define CHARON_METRIC_VALUE_H

#import <Foundation/Foundation.h>
#import "CharonMetricKit.h"
#import "../CharonValueStore.h"

@class MXSignpostMetric;

#define CHARON_VALUE_STORE_DECLARATION                                                     \
    - (NSMutableDictionary *)charon_values;                                                \
    - (id)charon_valueForKey:(NSString *)key;                                              \
    - (void)charon_setValue:(id)value forKey:(NSString *)key;

#define CHARON_VALUE_CODING_DECLARATION                                                     \
    + (BOOL)supportsSecureCoding;                                                           \
    - (void)encodeWithCoder:(NSCoder *)coder;                                              \
    - (instancetype)initWithCoder:(NSCoder *)coder;

#define CHARON_VALUE_CODING_METHODS                                                         \
    - (void)charon_encodePropertiesWithCoder:(NSCoder *)coder                               \
    {                                                                                       \
        for (NSString *name in [CharonMetricValue propertyNamesOf:[self class]]) {           \
            id value = [self charon_valueForKey:name];                                       \
            if (value)                                                                      \
                [coder encodeObject:value forKey:name];                                      \
        }                                                                                   \
    }                                                                                       \
    - (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder                               \
    {                                                                                       \
        NSSet *allowed = [CharonMetricValue decodableClasses];                              \
        BOOL whole = YES;                                                                   \
        for (NSString *name in [CharonMetricValue propertyNamesOf:[self class]]) {           \
            if (![coder containsValueForKey:name])                                          \
                continue;                                                                    \
            id value = [coder decodeObjectOfClasses:allowed forKey:name];                     \
            if (value)                                                                       \
                [self charon_setValue:value forKey:name];                                    \
            else                                                                            \
                whole = NO;                                                                 \
        }                                                                                   \
        return whole;                                                                       \
    }

@class MXMetric, MXDiagnostic, MXAverage, MXHistogram, MXHistogramBucket, MXMetaData, MXMetricPayload,
        MXDiagnosticPayload, MXCrashDiagnosticObjectiveCExceptionReason, MXSignpostRecord,
        MXSignpostIntervalData, MXBackgroundExitData, MXForegroundExitData, MXCallStackTree,
        MXUnitAveragePixelLuminance, MXUnitSignalBars;

@interface MXMetric (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXDiagnostic (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXAverage (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXHistogram (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXHistogramBucket (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXMetaData (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface MXMetricPayload (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface MXDiagnosticPayload (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
@end

@interface MXCrashDiagnosticObjectiveCExceptionReason (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXSignpostRecord (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXSignpostIntervalData (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXBackgroundExitData (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXForegroundExitData (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXCallStackTree (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
- (void)charon_encodePropertiesWithCoder:(NSCoder *)coder;
- (BOOL)charon_decodePropertiesWithCoder:(NSCoder *)coder;
- (NSData *)JSONRepresentation;
- (NSDictionary *)dictionaryRepresentation;
+ (BOOL)supportsSecureCoding;
- (void)encodeWithCoder:(NSCoder *)coder;
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

@interface MXUnitAveragePixelLuminance (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end

@interface MXUnitSignalBars (CharonMetricValue)
- (NSMutableDictionary *)charon_values;
- (id)charon_valueForKey:(NSString *)key;
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end

@interface CharonMetricValue : NSObject

+ (NSArray<NSString *> *)propertyNamesOf:(Class)cls;

+ (NSDictionary *)dictionaryOf:(id)value;
+ (NSData *)jsonOf:(id)value;

+ (NSSet<Class> *)decodableClasses;

@end

#define CHARON_VALUE_STORE_IMPLEMENTATION                                                   \
    -(NSMutableDictionary *)charon_values { return CharonValueStore(self); }                \
    -(id)charon_valueForKey:(NSString *)key { return [self charon_values][key]; }            \
    -(void)charon_setValue:(id)value forKey:(NSString *)key { CharonValueSet(self, value, key); }

@interface MXHistogram (CharonMetricKitSetters)
- (void)charon_setTotalBucketCount:(NSUInteger)value;
- (void)charon_setBucketEnumerator:(id)value;
- (id)charon_bucketEnumerator;
@end

@interface MXHistogramBucket (CharonMetricKitSetters)
- (void)charon_setBucketStart:(id)value;
- (void)charon_setBucketEnd:(id)value;
- (void)charon_setBucketCount:(NSUInteger)value;
@end

FOUNDATION_EXPORT NSArray<MXSignpostMetric *> *CharonSignpostMetrics(void);

@interface MXSignpostMetric (CharonMetricKitSetters)
- (void)charon_setSignpostName:(id)value;
- (void)charon_setSignpostCategory:(id)value;
- (void)charon_setSignpostIntervalData:(id)value;
- (void)charon_setTotalCount:(NSUInteger)value;
- (id)charon_totalCount;
- (id)charon_signpostIntervalData;
@end

@interface MXSignpostIntervalData (CharonMetricKitSetters)
- (void)charon_setHistogrammedSignpostDuration:(id)value;
- (void)charon_setCumulativeCPUTime:(id)value;
- (id)charon_cumulativeCPUTime;
- (id)charon_histogrammedSignpostDuration;
@end


@interface MXAppLaunchMetric (CharonMetricKitSetters)
- (void)charon_setHistogrammedExtendedLaunch:(id)value;
- (void)charon_setHistogrammedTimeToFirstDraw:(id)value;
@end

#endif
