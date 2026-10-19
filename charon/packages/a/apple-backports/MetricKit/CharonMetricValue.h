#ifndef CHARON_METRIC_VALUE_H
#define CHARON_METRIC_VALUE_H

#import <Foundation/Foundation.h>
#import "CharonMetricKit.h"
#import "../CharonValueStore.h"

// The property list, the two representations, the archiver walk and the store are the shared ones in
// CharonValueStore.h, which this framework and every other whose classes are value objects include;
// what is here is MetricKit's own shape - the sixteen roots that hold a store, and the accessors the
// snapshot and the manager fill values in through. It is a header of static inlines rather than a
// class in a library because a library of this package exports only the names the registry lists, and
// nothing of ours is linkable from another of our libraries.

@class MXSignpostMetric;

// Every MetricKit class is a value object the system fills in, and Apple's own headers give them no
// initialiser, no setter and one representation method each. So the storage here is one dictionary per
// object, keyed by the property's own name, and each property is one of the three macros below: the
// accessor the header declares plus the port's own setter for it. That is what makes 142 properties a
// line each instead of 284 hand-written accessors, and it makes the three things that must walk the
// values - the dictionary, the JSON and the archiver - walk one list of properties rather than a
// hand-written list per class that could drift from the header.
//
// Sixteen of the framework's classes are NSObject subclasses in Apple's own hierarchy rather than
// MXMetric's or MXDiagnostic's, so each holds the store itself; MXMetric and MXDiagnostic hold theirs
// and their leaf classes inherit. The categories below are on this port's own classes, not on NSObject,
// so nothing is added to every object in the process.

#define CHARON_VALUE_STORE_DECLARATION                                                     \
    - (NSMutableDictionary *)charon_values;                                                \
    - (id)charon_valueForKey:(NSString *)key;                                              \
    - (void)charon_setValue:(id)value forKey:(NSString *)key;

// The archiving, which is one walk of the same list: the classes whose own header declares
// NSSecureCoding, and the two that are not NSObject subclasses of either root.
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

// The three property macros - CHARON_VALUE_PROPERTY, CHARON_SCALAR_PROPERTY and
// CHARON_DOUBLE_PROPERTY - are the shared ones in CharonValueStore.h: the accessor the SDK header
// declares, and the port's own setter for it, which is what the store, a decoder and the manager fill
// a value in through.

@class MXMetric, MXDiagnostic, MXAverage, MXHistogram, MXHistogramBucket, MXMetaData, MXMetricPayload,
        MXDiagnosticPayload, MXCrashDiagnosticObjectiveCExceptionReason, MXSignpostRecord,
        MXSignpostIntervalData, MXBackgroundExitData, MXForegroundExitData, MXCallStackTree,
        MXUnitAveragePixelLuminance, MXUnitSignalBars;

// The store on each of the sixteen, and on each of them the archiving and the two
// representations that class's own header declares.
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

// The property names an object of a class has, its own class first and then each superclass, and
// without NSObject's own. This is the one place that knows what a MetricKit object is made of, and the
// dictionary, the JSON and the archiver all walk it.
+ (NSArray<NSString *> *)propertyNamesOf:(Class)cls;

// The two representations, for any MetricKit value. A key is the property's own name, the spelling the
// SDK 26.2 header gives it, and a value is converted the way JSON can carry it (CharonMetricValue.m
// names each conversion and why).
+ (NSDictionary *)dictionaryOf:(id)value;
+ (NSData *)jsonOf:(id)value;

// The classes a decoded MetricKit value may be: every class this library carries, found through the
// runtime by its own MX prefix, and the Foundation value types those hold. An archive naming a class
// outside it is not decoded.
+ (NSSet<Class> *)decodableClasses;

@end

// CHARON_VALUE_STORE_IMPLEMENTATION - the three store methods, one line each over the shared
// CharonValueStore() / CharonValueSet() pair - is the shared macro in CharonValueStore.h.
#define CHARON_VALUE_STORE_IMPLEMENTATION                                                   \
    -(NSMutableDictionary *)charon_values { return CharonValueStore(self); }                \
    -(id)charon_valueForKey:(NSString *)key { return [self charon_values][key]; }            \
    -(void)charon_setValue:(id)value forKey:(NSString *)key { CharonValueSet(self, value, key); }

// The classes the port fills a value in through, named so that a translation unit other than the one
// the macro is used in can see the setters - the manager, which builds one MXAppLaunchMetric out of a
// real measurement.
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

// The metrics, read out of the port's signpost store. Charon-prefixed, so it is the port's own API and
// the registry has nothing to describe: the private snapshot itself is typed by the SDK's own
// MXSignpost_Private.h as a non-NULL opaque pointer, and a function of ours that returned a public
// class would be a different function with the same name.
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
