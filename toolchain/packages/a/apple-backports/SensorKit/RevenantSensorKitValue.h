#ifndef REVENANT_SENSORKIT_VALUE_H
#define REVENANT_SENSORKIT_VALUE_H

#import <Foundation/Foundation.h>
#import "RevenantSensorKit.h"

#define REVENANT_SENSORKIT_VALUE_STORE_DECLARATION                                        \
    - (NSMutableDictionary *)revenant_values;                                              \
    - (id)revenant_valueForKey:(NSString *)key;                                            \
    - (void)revenant_setValue:(id)value forKey:(NSString *)key;

#define REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(Name)                                       \
    @interface Name (RevenantSensorKitValue)                                               \
    REVENANT_SENSORKIT_VALUE_STORE_DECLARATION                                             \
    @end

REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRAmbientLightSample)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettings)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsAccessibility)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsAccessibilityBackgroundSounds)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsAccessibilityHeadphoneAccommodations)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRAcousticSettingsMusicEQ)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRAudioLevel)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRApplicationUsage)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRDeletionRecord)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRDevice)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRDeviceUsageReport)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRElectrocardiogramData)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRElectrocardiogramSample)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRElectrocardiogramSession)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRFetchRequest)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRFetchResult)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRFaceMetrics)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRFaceMetricsExpression)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRKeyboardMetrics)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRKeyboardProbabilityMetric)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRMediaEvent)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRMessagesUsageReport)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRNotificationUsage)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRPhotoplethysmogramSample)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRPhotoplethysmogramAccelerometerSample)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRPhotoplethysmogramOpticalSample)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRPhoneUsageReport)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRSensorReader)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRSleepSession)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRSpeechExpression)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRSpeechMetrics)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRSupplementalCategory)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRTextInputSession)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRVisit)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRWebUsage)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRWristDetection)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRWristTemperature)
REVENANT_DECLARE_SENSORKIT_VALUE_CLASS(SRWristTemperatureSession)

#define REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION                                     \
    -(NSMutableDictionary *)revenant_values { return RevenantValueStore(self); }              \
    -(id)revenant_valueForKey:(NSString *)key { return [self revenant_values][key]; }         \
    -(void)revenant_setValue:(id)value forKey:(NSString *)key {                            \
        if (!key) return;                                                                  \
        if (value) RevenantValueStore(self)[key] = value;                                   \
        else [RevenantValueStore(self) removeObjectForKey:key];                             \
    }

#define REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(reason_text)                           \
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
