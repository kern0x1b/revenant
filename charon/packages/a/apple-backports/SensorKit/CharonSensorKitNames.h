#ifndef CHARON_SENSORKIT_NAMES_H
#define CHARON_SENSORKIT_NAMES_H

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#ifdef CHARON_SENSORKIT_NAMES_15_0

NSString * const SRSensorSiriSpeechMetrics = (NSString *)CFSTR("com.apple.SensorKit.speechMetrics.siri");
NSString * const SRSensorTelephonySpeechMetrics = (NSString *)CFSTR("com.apple.SensorKit.speechMetrics.telephony");

#endif

#ifdef CHARON_SENSORKIT_NAMES_15_4

NSString * const SRSensorAmbientPressure = (NSString *)CFSTR("com.apple.SensorKit.ambientPressure");

#endif

#ifdef CHARON_SENSORKIT_NAMES_16_4

NSString * const SRSensorMediaEvents = (NSString *)CFSTR("com.apple.SensorKit.mediaEvents");

#endif

#ifdef CHARON_SENSORKIT_NAMES_16_0

NSString * const SRSensorHeartRate = (NSString *)CFSTR("com.apple.SensorKit.heart.rate");
NSString * const SRSensorOdometer = (NSString *)CFSTR("com.apple.SensorKit.odometer");

#endif

#ifdef CHARON_SENSORKIT_NAMES_17_4

NSString * const SRPhotoplethysmogramOpticalSampleConditionSignalSaturation = (NSString *)CFSTR("SignalSaturation");
NSString * const SRPhotoplethysmogramOpticalSampleConditionUnreliableNoise = (NSString *)CFSTR("UnreliableNoise");
NSString * const SRPhotoplethysmogramSampleUsageForegroundHeartRate = (NSString *)CFSTR("ForegroundHeartRate");
NSString * const SRPhotoplethysmogramSampleUsageDeepBreathing = (NSString *)CFSTR("DeepBreathing");
NSString * const SRPhotoplethysmogramSampleUsageForegroundBloodOxygen = (NSString *)CFSTR("ForegroundBloodOxygen");
NSString * const SRPhotoplethysmogramSampleUsageBackgroundSystem = (NSString *)CFSTR("BackgroundSystem");

#endif

#ifdef CHARON_SENSORKIT_NAMES_18_0

NSString * const SRSensorFaceMetrics = (NSString *)CFSTR("com.apple.SensorKit.faceMetrics");
NSString * const SRSensorWristTemperature = (NSString *)CFSTR("com.apple.SensorKit.wristTemperature");
NSString * const SRSensorElectrocardiogram = (NSString *)CFSTR("com.apple.SensorKit.ECG");
NSString * const SRSensorPhotoplethysmogram = (NSString *)CFSTR("com.apple.SensorKit.PPG");

#endif

#ifdef CHARON_SENSORKIT_NAMES_26_0

NSString * const SRSensorAcousticSettings = (NSString *)CFSTR("com.apple.SensorKit.hearing.acousticSettings");
NSString * const SRSensorSleepSessions = (NSString *)CFSTR("com.apple.SensorKit.sleep.sessions");

#endif

#endif
