#ifndef CHARON_SENSORKIT_VALUE_H
#define CHARON_SENSORKIT_VALUE_H

#import <Foundation/Foundation.h>
#import "CharonSensorKit.h"

// Every SensorKit class is a value object the system filled in, and its properties are readonly, so the
// port holds each one's values in a store keyed by the property's own name - the same arrangement
// MetricKit's CharonMetricValue.h holds, and for the same reason: there is one spelling of each
// property's name, in the header, and the key a value is filed under is that name.
//
// Unlike MetricKit, SensorKit's classes do not promise a dictionary or a JSON representation - the
// framework's own surface has neither - so nothing here writes one. What a SensorKit value is used for
// is being read, and a metric payload from another framework that embeds one asks it for its own
// dictionary, which the shared conversion in CharonValueStore.h does through the store's accessor.

#define CHARON_SENSORKIT_VALUE_STORE_DECLARATION                                        \
    - (NSMutableDictionary *)charon_values;                                              \
    - (id)charon_valueForKey:(NSString *)key;                                            \
    - (void)charon_setValue:(id)value forKey:(NSString *)key;

// One declaration per class, the same macro as MetricKit uses for its sixteen roots.
#define CHARON_DECLARE_SENSORKIT_VALUE_CLASS(Name)                                       \
    @interface Name (CharonSensorKitValue)                                               \
    CHARON_SENSORKIT_VALUE_STORE_DECLARATION                                             \
    @end

CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRAmbientLightSample)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettings)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsAccessibility)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsAccessibilityBackgroundSounds)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsAccessibilityHeadphoneAccommodations)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsMusicEQ)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRAudioLevel)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRApplicationUsage)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRDeletionRecord)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRDevice)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRDeviceUsageReport)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRElectrocardiogramData)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRElectrocardiogramSample)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRElectrocardiogramSession)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRFetchRequest)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRFetchResult)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRFaceMetrics)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRFaceMetricsExpression)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRKeyboardMetrics)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRKeyboardProbabilityMetric)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRMediaEvent)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRMessagesUsageReport)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRNotificationUsage)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRPhotoplethysmogramSample)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRPhotoplethysmogramAccelerometerSample)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRPhotoplethysmogramOpticalSample)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRPhoneUsageReport)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRSensorReader)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRSleepSession)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRSpeechExpression)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRSpeechMetrics)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRSupplementalCategory)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRTextInputSession)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRVisit)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRWebUsage)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRWristDetection)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRWristTemperature)
CHARON_DECLARE_SENSORKIT_VALUE_CLASS(SRWristTemperatureSession)

// The store's own implementation, one pair of functions for every class above: the dictionary is
// created on first use, so a value the port only reads costs nothing.
#define CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION                                     \
    -(NSMutableDictionary *)charon_values { return CharonValueStore(self); }              \
    -(id)charon_valueForKey:(NSString *)key { return [self charon_values][key]; }         \
    -(void)charon_setValue:(id)value forKey:(NSString *)key {                            \
        if (!key) return;                                                                  \
        if (value) CharonValueStore(self)[key] = value;                                   \
        else [CharonValueStore(self) removeObjectForKey:key];                             \
    }

// -init and +new, the pair the 26.2 headers of these classes close: every one of the eighteen
// declares `- (instancetype)init NS_UNAVAILABLE;` and `+ (instancetype)new NS_UNAVAILABLE;`
// immediately before its @end - SRSleepSession.h:17 and :18, SRDeviceUsageCategories.h:67 and :68
// for the two the corpus dates at 16.4, and the same two lines in each of the other sixteen headers.
//
// NS_UNAVAILABLE is a promise about source and adds nothing at run time, so what the framework does
// with the pair is a separate question and it has two answers, not one. Measured on the host's own
// SensorKit over all eighteen classes, in tests/backports/host/sensorkit-value/host-answers.m:
//
//   - fourteen classes implement BOTH, and both raise NSInternalInconsistencyException. The reason
//     string differs per class and is carried here as it was measured: "Not available" for the four
//     that have no other door (SRFaceMetrics, SRFaceMetricsExpression, SRFetchResult and
//     SRSupplementalCategory), "Use initWithSensor:" for SRSensorReader, which has one, and the empty
//     string for the other nine.
//   - four classes implement NEITHER - SRAcousticSettings, SRSleepSession, and the two
//     photoplethysmogram samples that are channels of the sample their parent already guards - so a
//     caller that reaches the pair reaches NSObject's and gets a new empty value object.
//
// The port answers the fourteen and leaves the four to NSObject, and the difference is the point: a
// definition would put -init and +new in the port's class metadata where Apple's class metadata has
// neither, which changes what the class IS and answers the caller exactly what NSObject's already
// answers. Their rows are `absent` with this measurement as the reason, and a corpus row reading
// `missing` for a selector Apple's own class does not carry is the tool's question about a class's own
// method list rather than a gap in the port.

// The fourteen that refuse. `reason_text` is the host's own reason string for that class, which is
// what the exception carries: the name is NSInternalInconsistencyException for all fourteen, and
// +new is +alloc/-init, so the one raise answers both rows.
#define CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(reason_text)                           \
    -(instancetype)init                                                                   \
    {                                                                                    \
        [NSException raise:NSInternalInconsistencyException format:reason_text];          \
        return nil;                                                                      \
    }                                                                                    \
                                                                                         \
    +(instancetype)new                                                                   \
    {                                                                                    \
        return [[self alloc] init];                                                      \
    }

#endif
