#import <Foundation/Foundation.h>
#import <MetricKit/MetricKit.h>
#import "metricvalue-cases.h"
#if defined(CHARON_METRICVALUE_PORT)
#import "CharonMetricValue.h"

@interface MXCPUMetric (CharonMetricValueCases)
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end

@interface MXAnimationMetric (CharonMetricValueCases)
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end
@interface MXMetaData (CharonMetricValueCases)
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end
@interface MXMetricPayload (CharonMetricValueCases)
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end
@interface MXCrashDiagnostic (CharonMetricValueCases)
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end
@interface MXDiagnostic (CharonMetricValueCases)
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end

@interface MXDiagnosticPayload (CharonMetricValueCases)
- (void)charon_setValue:(id)value forKey:(NSString *)key;
@end
#endif

static void recordRepresentation(CertificateRecorder record, id value)
{
    NSDictionary *dictionary = [value dictionaryRepresentation];
    record(@"empty.keyCount", [NSString stringWithFormat:@"%lu", (unsigned long)dictionary.count]);
    for (NSString *key in [dictionary.allKeys sortedArrayUsingSelector:@selector(compare:)])
        record(([NSString stringWithFormat:@"empty.key.%@", key]), ([dictionary[key] description] ?: @"(none)"));
    NSData *json = [value JSONRepresentation];
    record(@"empty.jsonIsObject", [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL] ? @"1" : @"0");
}

void metricvalue_run(CertificateRecorder record)
{
    recordRepresentation(record, [[MXCPUMetric alloc] init]);
    recordRepresentation(record, [[MXMetricPayload alloc] init]);

#ifdef CHARON_METRICVALUE_PORT

    MXCPUMetric *cpu = [[MXCPUMetric alloc] init];
    NSMeasurement *duration = [[NSMeasurement alloc] initWithDoubleValue:1.5
                                                                  unit:[NSUnitDuration seconds]];
    [cpu charon_setValue:duration forKey:@"cumulativeCPUTime"];
    NSDictionary *filled = [cpu dictionaryRepresentation];
    record(@"filled.keyCount", [NSString stringWithFormat:@"%lu", (unsigned long)filled.count]);
    record(@"filled.hasCumulativeCPUTime", (filled[@"cumulativeCPUTime"] ? @"1" : @"0"));
    record(@"filled.cumulativeCPUTime", ([filled[@"cumulativeCPUTime"] description] ?: @"(none)"));
    record(@"filled.unsetIsAbsent", (filled[@"cumulativeCPUInstructions"] ? @"1" : @"0"));
    NSData *json = [cpu JSONRepresentation];
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
    record(@"filled.jsonKeyCount", [NSString stringWithFormat:@"%lu", (unsigned long)parsed.count]);
    record(@"filled.jsonValue", ([parsed[@"cumulativeCPUTime"] description] ?: @"(none)"));

    MXDiagnosticPayload *payload = [[MXDiagnosticPayload alloc] init];
    NSDate *when = [NSDate dateWithTimeIntervalSinceReferenceDate:1000.5];
    [payload charon_setValue:when forKey:@"timeStampBegin"];
    NSDictionary *payloadDictionary = [payload dictionaryRepresentation];
    record(@"date.value", ([payloadDictionary[@"timeStampBegin"] description] ?: @"(none)"));
    record(@"date.endAbsent", (payloadDictionary[@"timeStampEnd"] ? @"1" : @"0"));

    NSMutableData *archive = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archive];
    archiver.requiresSecureCoding = YES;
    [archiver setClassName:NSStringFromClass([cpu class]) forClass:[MXCPUMetric class]];
    [archiver encodeObject:cpu forKey:@"payload"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    unarchiver.requiresSecureCoding = YES;
    record(@"archive.byteCount", [NSString stringWithFormat:@"%lu", (unsigned long)archive.length]);
    MXCPUMetric *read = nil;
    @try {
        read = [unarchiver decodeObjectOfClasses:[NSSet setWithArray:@[[MXCPUMetric class], [NSString class], [NSNumber class]]]
                                            forKey:@"payload"];
    } @catch (NSException *exception) {
        record(@"archive.raised", exception.reason ?: @"(none)");
    }
    [unarchiver finishDecoding];
    record(@"archive.class", read ? NSStringFromClass([read class]) : @"(nil)");
    NSDictionary *readBack = [read dictionaryRepresentation] ?: @{};
    record(@"archive.keyCount", [NSString stringWithFormat:@"%lu", (unsigned long)readBack.count]);
    record(@"archive.cumulativeCPUTime", ([readBack[@"cumulativeCPUTime"] description] ?: @"(none)"));
    record(@"archive.sameRepresentation",
           ([[read dictionaryRepresentation] isEqualToDictionary:[cpu dictionaryRepresentation]] ? @"1" : @"0"));

    NSArray *pairs = @[
#ifdef CHARON_METRICVALUE_PORT
        @[[MXAnimationMetric class], @"hitchTimeRatio", @"sentinel-measurement"],
        @[[MXMetaData class], @"bundleIdentifier", @"sentinel-bundle"],
        @[[MXMetaData class], @"lowPowerModeEnabled", @YES],
        @[[MXMetaData class], @"isTestFlightApp", @YES],
        @[[MXMetaData class], @"pid", @4242],
        @[[MXMetricPayload class], @"diskSpaceUsageMetrics", @"sentinel-disk"],
        @[[MXCrashDiagnostic class], @"exceptionReason", @"sentinel-reason"],
        @[[MXDiagnostic class], @"signpostData", @"sentinel-signpost"],
        @[[MXCPUMetric class], @"cumulativeCPUTime", @"sentinel-cpu"],
#endif
    ];
    for (NSArray *pair in pairs) {
        Class cls = pair[0];
        NSString *key = pair[1];
        id sentinel = pair[2];
        NSString *who = NSStringFromClass(cls);
        record(([NSString stringWithFormat:@"kvc.%@.%@.class", who, key]), cls ? @"1" : @"0");
        SEL selector = NSSelectorFromString(key);
        BOOL answers = [cls instancesRespondToSelector:selector];
        record(([NSString stringWithFormat:@"kvc.%@.%@.answers", who, key]), answers ? @"1" : @"0");
        if (!answers)
            continue;
        id instance = [[cls alloc] init];
        (void)[instance valueForKey:key];
        record(([NSString stringWithFormat:@"kvc.%@.%@.read", who, key]), (instance ? @"1" : @"0"));

        [instance charon_setValue:sentinel forKey:key];
        id back = [instance valueForKey:key];
        BOOL same = [back isKindOfClass:[NSString class]] ? [back isEqualToString:sentinel]
                                                          : [back isEqual:sentinel];
        record(([NSString stringWithFormat:@"kvc.%@.%@.roundTrip", who, key]), same ? @"1" : @"0");
    }
#endif
}
