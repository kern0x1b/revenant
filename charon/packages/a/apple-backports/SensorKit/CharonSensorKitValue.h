#ifndef CHARON_SENSORKIT_VALUE_H
#define CHARON_SENSORKIT_VALUE_H

#import <Foundation/Foundation.h>
#import "CharonSensorKit.h"

#define CHARON_SENSORKIT_VALUE_STORE_DECLARATION                                        \
    - (NSMutableDictionary *)charon_values;                                              \
    - (id)charon_valueForKey:(NSString *)key;                                            \
    - (void)charon_setValue:(id)value forKey:(NSString *)key;

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

#define CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION                                     \
    -(NSMutableDictionary *)charon_values { return CharonValueStore(self); }              \
    -(id)charon_valueForKey:(NSString *)key { return [self charon_values][key]; }         \
    -(void)charon_setValue:(id)value forKey:(NSString *)key {                            \
        if (!key) return;                                                                  \
        if (value) CharonValueStore(self)[key] = value;                                   \
        else [CharonValueStore(self) removeObjectForKey:key];                             \
    }

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
